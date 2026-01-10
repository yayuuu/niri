use std::any::Any;
use std::sync::Arc;

use smithay::input::dnd::{DndFocus, OfferData, Source};
use smithay::input::pointer::{
    AxisFrame, ButtonEvent, GestureHoldBeginEvent, GestureHoldEndEvent, GesturePinchBeginEvent,
    GesturePinchEndEvent, GesturePinchUpdateEvent, GestureSwipeBeginEvent, GestureSwipeEndEvent,
    GestureSwipeUpdateEvent, GrabStartData as PointerGrabStartData, MotionEvent as PointerMotionEvent,
    PointerGrab, PointerInnerHandle, RelativeMotionEvent,
};
use smithay::input::{Seat, SeatHandler};
use smithay::reexports::wayland_server::DisplayHandle;
use smithay::reexports::wayland_server::protocol::wl_data_source::WlDataSource;
use smithay::reexports::wayland_server::Resource;
use smithay::utils::{IsAlive, Logical, Point, Serial};

use crate::handlers::State;

type PointerFocus = <State as SeatHandler>::PointerFocus;

/// Copy of smithay's pointer DnD grab with a workaround for smithay#1887.
///
/// We mark drops as not validated to avoid Chromium/Electron freezing when self-dropping links.
pub struct WorkaroundDndGrab<S: Source + Any> {
    dh: DisplayHandle,
    pointer_start_data: PointerGrabStartData<State>,
    last_position: Point<f64, Logical>,
    data_source: Arc<S>,
    current_focus: Option<PointerFocus>,
    offer_data: Option<<PointerFocus as DndFocus<State>>::OfferData<S>>,
    seat: Seat<State>,
}

impl<S: Source + Any> WorkaroundDndGrab<S> {
    pub fn new_pointer(
        dh: &DisplayHandle,
        start_data: PointerGrabStartData<State>,
        source: S,
        seat: Seat<State>,
    ) -> Self {
        let last_position = start_data.location;
        Self {
            dh: dh.clone(),
            pointer_start_data: start_data,
            last_position,
            data_source: Arc::new(source),
            current_focus: None,
            offer_data: None,
            seat,
        }
    }

    fn update_focus(
        &mut self,
        data: &mut State,
        focus: Option<(PointerFocus, Point<f64, Logical>)>,
        location: Point<f64, Logical>,
        serial: Serial,
        time: u32,
    ) {
        if self
            .current_focus
            .as_ref()
            .is_some_and(|current| focus.as_ref().is_none_or(|(f, _)| f != current))
        {
            if let Some(focus) = self.current_focus.take() {
                <PointerFocus as DndFocus<State>>::leave(&focus, data, self.offer_data.as_mut(), &self.seat);

                if let Some(offer_data) = self.offer_data.take() {
                    offer_data.disable();
                }
            }
        }

        if let Some((focus, surface_location)) = focus {
            if !focus.alive() {
                return;
            }

            let (x, y) = (location - surface_location).into();
            if self.current_focus.is_none() {
                if self
                    .data_source
                    .metadata()
                    .is_some_and(|metadata| metadata.mime_types.is_empty())
                {
                    return;
                }

                self.offer_data = <PointerFocus as DndFocus<State>>::enter(
                    &focus,
                    data,
                    &self.dh,
                    self.data_source.clone(),
                    &self.seat,
                    Point::new(x, y),
                    &serial,
                );
                self.current_focus = Some(focus);
            } else {
                <PointerFocus as DndFocus<State>>::motion(
                    &focus,
                    data,
                    self.offer_data.as_mut(),
                    &self.seat,
                    Point::new(x, y),
                    time,
                );
            }
        }
    }

    fn finish_drop(&mut self, data: &mut State) {
        // Avoid Chromium/Electron freezing on self-drops (smithay#1887) by treating those drops as
        // cancelled (validated = false). Cross-client drops keep normal validation.
        let same_client = self.current_focus.as_ref().and_then(|focus| {
            focus.client().and_then(|surface_client| {
                (&*self.data_source as &dyn Any)
                    .downcast_ref::<WlDataSource>()
                    .and_then(|source| source.client())
                    .map(|src_client| src_client.id() == surface_client.id())
            })
        }) == Some(true);
        let validated = if same_client {
            false
        } else {
            self.offer_data.as_ref().is_some_and(|data| data.validated())
        };

        if let Some(ref focus) = self.current_focus {
            <PointerFocus as DndFocus<State>>::drop(
                focus,
                data,
                self.offer_data.as_mut(),
                &self.seat,
            );
        }

        if let Some(ref offer_data) = self.offer_data {
            if validated {
                offer_data.drop();
            } else {
                offer_data.disable();
            }
        }

        if !validated {
            self.data_source.cancel();
        } else {
            self.data_source.drop_performed();
        }

        <State as smithay::input::dnd::DndGrabHandler>::dropped(
            data,
            self.current_focus.as_ref().map(smithay::input::dnd::DndTarget::Pointer),
            validated,
            self.seat.clone(),
            self.last_position,
        );

        if let Some(ref focus) = self.current_focus {
            <PointerFocus as DndFocus<State>>::leave(focus, data, self.offer_data.as_mut(), &self.seat);
        }
    }
}

impl<S: Source> PointerGrab<State> for WorkaroundDndGrab<S> {
    fn motion(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        focus: Option<(PointerFocus, Point<f64, Logical>)>,
        event: &PointerMotionEvent,
    ) {
        // Use smithay's default non-xwayland behavior (no pointer focus during DnD).
        handle.motion(data, None, event);

        self.last_position = event.location;

        self.update_focus(data, focus, event.location, event.serial, event.time);
    }

    fn relative_motion(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        _focus: Option<(PointerFocus, Point<f64, Logical>)>,
        event: &RelativeMotionEvent,
    ) {
        handle.relative_motion(data, None, event);
    }

    fn button(&mut self, data: &mut State, handle: &mut PointerInnerHandle<'_, State>, event: &ButtonEvent) {
        handle.button(data, event);

        if handle.current_pressed().is_empty() {
            handle.unset_grab(self, data, event.serial, event.time, true);
        }
    }

    fn axis(&mut self, data: &mut State, handle: &mut PointerInnerHandle<'_, State>, details: AxisFrame) {
        handle.axis(data, details);
    }

    fn frame(&mut self, data: &mut State, handle: &mut PointerInnerHandle<'_, State>) {
        handle.frame(data);
    }

    fn gesture_swipe_begin(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        event: &GestureSwipeBeginEvent,
    ) {
        handle.gesture_swipe_begin(data, event);
    }

    fn gesture_swipe_update(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        event: &GestureSwipeUpdateEvent,
    ) {
        handle.gesture_swipe_update(data, event);
    }

    fn gesture_swipe_end(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        event: &GestureSwipeEndEvent,
    ) {
        handle.gesture_swipe_end(data, event);
    }

    fn gesture_pinch_begin(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        event: &GesturePinchBeginEvent,
    ) {
        handle.gesture_pinch_begin(data, event);
    }

    fn gesture_pinch_update(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        event: &GesturePinchUpdateEvent,
    ) {
        handle.gesture_pinch_update(data, event);
    }

    fn gesture_pinch_end(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        event: &GesturePinchEndEvent,
    ) {
        handle.gesture_pinch_end(data, event);
    }

    fn gesture_hold_begin(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        event: &GestureHoldBeginEvent,
    ) {
        handle.gesture_hold_begin(data, event);
    }

    fn gesture_hold_end(
        &mut self,
        data: &mut State,
        handle: &mut PointerInnerHandle<'_, State>,
        event: &GestureHoldEndEvent,
    ) {
        handle.gesture_hold_end(data, event);
    }

    fn start_data(&self) -> &PointerGrabStartData<State> {
        &self.pointer_start_data
    }

    fn unset(&mut self, data: &mut State) {
        self.finish_drop(data);
    }
}
