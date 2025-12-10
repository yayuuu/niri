# niri (fork)

This repo houses a fork of niri, a scrollable tiling Wayland compositor. I mostly created it for my personal use, to bring few changes that are not yet upstream. This readme outlines the differences between this fork and upstream niri. For more info on upstream's version, check out
the original repository: https://github.com/YaLTeR/niri.
<br><br>

## Performance
This fork fixes the performance issues with native wayland apps and PROTON_USE_WAYLAND=1 on a hardware which uses Intel GPU to output video and Nvidia GPU to render, so most of the laptops with hybrid graphics.

![Performance](assets/screenshots/perf.jpg)
<br><br>

## Blur behind windows and window groups
Brings blur behind windows and window groups (Naxdy's implementation https://github.com/Naxdy/niri)

![Blur](assets/screenshots/groups-blur.png)
<br><br>

## Center multiple columns
Improves always-center-single-column option to center any number of columns as long as they take less than a full screen width. Especially useful on ultrawide screens.

Video preview:

[![Center columns](https://img.youtube.com/vi/DDytn7EgzjY/0.jpg)](https://www.youtube.com/watch?v=DDytn7EgzjY)
<br><br>

## Release and modifier only keybinds
Merges a working implementation of release keybinds (https://github.com/YaLTeR/niri/pull/2456), so you can run app launcher by only pressing Super key. Allows muting microphone in push-to-talk like way, and many more. 

Example:
```
Mod release=true { spawn "dms" "ipc" "spotlight" "toggle"; }
KP_Insert { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0"; }
KP_Insert release=true allow-invalidation=false  { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1"; }
```
<br>

## Backward compatibility
This fork works with standard niri config out of the box. You can also create separate config file that features only changes available in this fork and include it in config.kdl, so any time you decide to return to upstream niri, just comment out the include.

For the maximum feature set, create a config file: `.config/niri/unofficial.kdl` and include it in your config.kdl:
```
layout {
  always-center-single-column

  blur {
    on
    noise 0.1
    passes 2
    radius 5
  }
}

window-rule {
  blur {
    on
  }
}

layer-rule {
  match namespace="dms:bar"
  blur {
    on
    noise 0.0
  }
}

binds {
  Mod release=true { spawn "dms" "ipc" "spotlight" "toggle"; }

  Alt+G {
    toggle-group
  }
  Alt+Shift_L release=true {
    focus-next-window
  }
  //Mod+Shift+H {
  //  move-window-into-or-out-of-group "left"
  //}
  //Mod+Shift+L {
  //  move-window-into-or-out-of-group "right"
  //}
  Alt+Shift+Up {
    move-window-into-or-out-of-group "up"
  }
  Alt+Shift+Down {
    move-window-into-or-out-of-group "down"
  }
}

```
<br>

## Disclaimer
These changes are not well tested, they work on my PC. It might result in worse performance with other hardware configurations and it might break with different monitor layouts / scaling. I am not a rust programmer, so if it doesn't work for you then don't use it or fix it yourself. Most of the changes made here are other people's work that I just pulled together. I am not responsible for any damage caused by this fork, so use at your own risk.
