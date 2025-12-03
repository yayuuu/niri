# Contributing to niri (fork)

Greetings, and first of all thank you for reading this and deciding you want to contribute to this fork of niri!

Although this fork was born out of the desire to add features that don't align with upstream's vision for the project, I
still strive to be as close to upstream in functionality as possible wherever it makes sense. As such, I'll try my best
to write down contributing guidelines I think make sense in order to achieve this goal.

## The Vision

My vision for this fork is to bring it closer into the KDE ecosystem, by implementing a variety of KDE Wayland
protocols, and removing most if not all of the Gnome / Mutter compatibilities. There are two main reasons for this:

1. I started my Linux journey with KDE, and am therefore much more familiar with it than I am with Gnome. I've even
   contributed a few trivial and a few non-trivial things to the project in the past, and am therefore also familiar
   with it from a development perspective.
2. I want this compositor to ultimately become a "near-drop-in replacement" for KWin, that is to say an end user should
   be able to boot into a Plasma session and have everything "just work", with the only exception being that instead of
   running KWin, they are running this fork of niri (by that point I'll probably have rebranded).

   This will include things like viewing (and perhaps even editing) output settings in KDE System Settings, mapping
   tablet areas, etc.

The biggest hurdles in introducing new users to tiling wayland compositors that I see nowadays are:

1. Having to configure the entire thing yourself from scratch (niri helps with this by providing a very good, sensible
   default config).
2. Having to source all sorts of auxiliary applications yourself (secret service, idle daemon, lockscreen, you name it).
   Most users don't even know what the hell these are!

My idea is to accomplish this is with a NixOS module that sets up everything for a decent out-of-the-box experience for
a "regular user", such that you only need to add 1 line to your config in order to give this compositor a shot, without
having to commit many hours to configuring it, just to see if you'd be into it.

### Unix Philosophy

I am a firm believer in the Unix philosophy, in that a thing should do _one_ thing and be really good at it. In reality
this means I don't want to bloat niri with too many (unrelated) features. This includes "joke" features like
`baba-is-float` for example, but also things like niri's built-in screenshot UI.

The thing is, screenshotting has already been done many times by applications that do it _really_ well, like Spectacle
or flameshot, and while having a screenshot solution baked in is nice to have when starting out from scratch, with a
more complete desktop environment it doesn't really make sense anymore imo, at least not when there are more fleshed-out
solutions.

## Raising Issues

### Bugs

If you experience a bug, before raising an issue, please ensure that it is _either_ exclusive to this fork of niri, i.e.
that the wrong behavior doesn't occur in upstream's version of niri, _or_ it is a bug that exists in both versions, but
upstream either can't or won't fix it (for whatever reason).

I have different thresholds as for when I'm fine with a "dirty / quick fix" in order to get rid of buggy behavior
compared to upstream. One example includes [this bug](https://github.com/YaLTeR/niri/issues/454) which I have "fixed" by
applying [this suggestion](https://github.com/YaLTeR/niri/issues/454#issuecomment-3561738404), but as
[upstream's maintainer noted](https://github.com/YaLTeR/niri/issues/454#issuecomment-3562080633), this may cause issues
elsewhere in the compositor.

I have yet to encounter any, but I have more of a "fuck it, let's just do it and see what breaks" attitude, which may or
may not be your cup of tea :)

### Features

If you want to request a new feature, it's always a good idea to open an issue first, especially if it's a big request
(like blur), even if you plan to develop it yourself. This gives us the opportunity to first assess whether it makes
sense for this fork, as well as discuss potential implementation options. Sometimes a feature requires an upstream
change e.g. in Smithay, and raising an issue before opening a PR would make things like this easier to spot.

### Discussions

For any other inquiries like "how do I make X work", please use discussions instead of issues.

## _What_ to contribute

The first and most obvious question is that of what kind of PRs I would want to see / would actually consider merging.

### Feature PRs

In terms of feature PRs, if it aligns well with upstream's design, I think it makes the most sense to submit a PR there.
If you're unsure, ask in their matrix chat if they'd merge your feature before starting to work on something big.

I cherrypick most commits from upstream anyway (as long as they're not doc / wiki changes) so chances are very high that
if you work on something there, it will end up here.

As for features that definitely won't make it into upstream, one that comes to mind is implementing KDE Wayland
protocols. Ultimately, I'll probably want most if not all of them implemented in _some_ way, but the most important one
(for now) is [KDE screencast](https://wayland.app/protocols/kde-zkde-screencast-unstable-v1) and everything that is
needed for this to function properly, e.g.
[KDE plasma window management](https://wayland.app/protocols/kde-plasma-window-management).

For everything else, first make sure it adheres to the Unix philosophy as I mentioned above (I will not merge e.g.
built-in video recording).

### Fixes / Code Improvements

Same rule goes as for feature PRs: If you think upstream would be interested in it, please submit it there! It'll very
likely find its way into this fork eventually.

If the fix / improvement is for a feature that either doesn't exist in upstream (such as tabbed tiles or blur), or
upstream is not interested in it, feel free to submit it here.

### Feature Removal

If you spot something that you think makes no sense to have in the project considering everything I said before in this
document, feel free to open a PR removing a feature in question, or raise an issue discussing its potential removal.

## _How_ to contribute

For small / medium features, fixes, or improvements, just open a PR directly. It'd be nice if you added a description to
your PR explaining what you're doing and why you're doing it, especially for medium-big-ish changes, although this is
not required if your change is self-evident (e.g. fixing some typos), or if it's already well documented within the code
itself.

> [!NOTE]
>
> When updating your branch, please _rebase_ instead of merge, to ensure a linear history is kept. Merge commits make
> reviewing PRs quite painful.

### Nix

This project is developed on [NixOS](https://nixos.org/), built & tested using [crane](https://crane.dev/), and uses
[treefmt-nix](https://github.com/numtide/treefmt-nix) for treewide formatting.

While you don't _have_ to use Nix to work on this fork, it will make your life significantly easier, since it

- provides a dev shell with all of the tools needed to work on this fork, even ensuring the exact correct version (you
  don't need `rustup`)
- allows you to format everything easily by running `nix fmt`
- provides easy access to the entire test suite as it is being run in CI, using `nix flake check`, which includes
  `cargo test` but also other checks, such as `cargo clippy`, formatting, spelling, and more

You don't need NixOS to run Nix, as it's a distro-agnostic package manager that even works on macOS and WSL. You can
either get the [official version](https://nixos.org/download/), or the one maintained by
[Determinate Systems](https://docs.determinate.systems/). On Linux, it doesn't really matter, but on macOS I would
_highly_ suggest using Determinate Nix, as "vanilla" Nix has a tendency to break after macOS system updates.

If you use "vanilla" Nix, you will additionally need to [enable Flakes](https://nixos.wiki/wiki/flakes) (Determinate Nix
does not require this step).

To enter this project's dev shell, run `nix develop .` while in the root of this project. It may take a while to fetch
all dependencies, but afterwards you should be dropped into a bash shell with all required tools to build this project.
Run `cargo build` to verify!

To enter the dev shell with a different command, e.g. `zsh` instead of `bash`, you can run
`nix develop . --command zsh`.

To automatically enter the dev shell whenever you navigate to this directory, you can use [direnv](https://direnv.net/).
There also exists an [extension for VSCode](https://marketplace.visualstudio.com/items?itemName=mkhl.direnv) that loads
the dev environment whenever you open this project in your editor. For terminal editors like Neovim, it is already
enough to just have direnv's regular shell integration and open your editor from within the project directory.

### Commits

When making changes, please keep each _logical_ change in a separate commit. That's not to say commit after everything
you do, but just separate the "things" you do from each other.

For example, if you open a PR that 1) fixes a bug in how blur is rendered, and 2) optimizes blur performance in a way
that has nothing to do with your fix and _could_ be done separately, then these two changes should be done in separate
commits.

As a good rule of thumb, make sure that each of your commits _individually_ passes the test suite, which you can run
via:

```shell
nix flake check . --print-build-logs -j auto
```

This means that if your commit causes tests to change (in an expected manner), adjusting these tests should be done in
the same commit.

Name your commits according to [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/). Specifically, use
the breaking change indicator `!` if your change

- has the potential to break users' existing configs (e.g. because it removes / renames a config option that exists in a
  stable release)
- causes niri's behavior to change in ways that would require users to amend their configs in order to restore the
  previous behavior (e.g. if you introduce a new keyboard shortcut that is active by default, or change the default
  value of an option that would cause user's settings to change if they didn't explicitly set it in their config)
- causes niri's behavior to change in a way that is "likely to impact users' current workflow"

The last point is kept intentionally vague so as to allow for some room of discussion regarding what constitutes a
"workflow breakage".

### Tests

It goes without saying that if you do something that breaks a test, you should either fix your code, the code that
causes the breakage, or amend the test to consider the new behavior.

If you're adding a new feature that _can_ be tested, then you _should_ add a test for it. This can be done either in the
same `feat` commit, or in a separate `test` commit, depending on how big your feature is and how many tests you add for
it. Ultimately, I leave it up to you though and won't yell at you if you add a huge test suite as part of your `feat`
commit.
