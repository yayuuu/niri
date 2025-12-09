# niri (fork)

<p align="center">
  <img height="600px" src="assets/screenshots/groups-blur.png" />
</p>

This repo houses a fork of Naxdy's fork of [niri](https://github.com/Naxdy/niri), a scrollable tiling Wayland compositor.

This fork fixes the performance issues on a hardware which uses Intel GPU to output video and Nvidia GPU to render, so most of the laptops with hybrid graphics.

Improves always-center-single-column option to center any number of columns as long as they take less than a full screen width. 
https://www.youtube.com/watch?v=DDytn7EgzjY

Implements release and modifier only keybinds (pull request: https://github.com/YaLTeR/niri/pull/2456)
Example:
```
Mod release=true { spawn "dms" "ipc" "spotlight" "toggle"; }
KP_Insert { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0"; }
KP_Insert release=true allow-invalidation=false  { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1"; }
```

These changes are not well tested, they work on my PC. It might result in worse performance with other hardware configurations and it might break with different monitor layouts / scaling. I am not a rust programmer, so if it doesn't work for you then don't use it or fix it yourself.

Before you try it out, make sure to comment out this line in your keybinds, otherwise it will not start:
```
Mod+W { toggle-column-tabbed-display; }
```

This readme outlines the differences between this fork and upstream niri. For more info on upstream's version, check out
the [original readme](./README_orig.md).
