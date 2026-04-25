{
  description = "Niri: A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    fenix.url = "github:nix-community/fenix";

    treefmt-nix.url = "github:numtide/treefmt-nix";

    crane.url = "github:ipetkov/crane";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      revision = self.shortRev or self.dirtyShortRev or "unknown";
      niri-package =
        {
          lib,
          cairo,
          dbus,
          libGL,
          libdisplay-info,
          libinput,
          seatd,
          libxkbcommon,
          libgbm,
          pango,
          pipewire,
          pkg-config,
          rustPlatform,
          systemd,
          wayland,
          installShellFiles,
          withDbus ? true,
          withSystemd ? true,
          withScreencastSupport ? true,
          withDinit ? false,
        }:

        rustPlatform.buildRustPackage {
          pname = "niri";
          version = revision;

        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./niri-config
            ./niri-ipc
            ./niri-visual-tests
            ./resources
            ./src
            ./Cargo.toml
            ./Cargo.lock
          ];
        };

        postPatch = ''
          patchShebangs resources/niri-session
          substituteInPlace resources/niri.service \
            --replace-fail 'ExecStart=niri' "ExecStart=$out/bin/niri"
        '';

        cargoLock = {
          # NOTE: This is only used for Git dependencies
          allowBuiltinFetchGit = true;
          lockFile = ./Cargo.lock;
        };

        strictDeps = true;

        nativeBuildInputs = [
          rustPlatform.bindgenHook
          pkg-config
          installShellFiles
        ];

        buildInputs =
          [
            cairo
            dbus
            libGL
            libdisplay-info
            libinput
            seatd
            libxkbcommon
            libgbm
            pango
            wayland
          ]
          ++ lib.optional (withDbus || withScreencastSupport || withSystemd) dbus
          ++ lib.optional withScreencastSupport pipewire
          # Also includes libudev
          ++ lib.optional withSystemd systemd;

        buildFeatures =
          lib.optional withDbus "dbus"
          ++ lib.optional withDinit "dinit"
          ++ lib.optional withScreencastSupport "xdp-gnome-screencast"
          ++ lib.optional withSystemd "systemd";
        buildNoDefaultFeatures = true;

          # ever since this commit:
          # https://github.com/niri-wm/niri/commit/771ea1e81557ffe7af9cbdbec161601575b64d81
          # niri now runs an actual instance of the real compositor (with a mock backend) during tests
          # and thus creates a real socket file in the runtime dir.
          # this is fine for our build, we just need to make sure it has a directory to write to.
          preCheck = ''
            export XDG_RUNTIME_DIR="$(mktemp -d)"
          '';

        checkFlags = [
          # These tests require the ability to access a "valid EGL Display", but that won't work
          # inside the Nix sandbox
          "--skip=::egl"
        ];

        postInstall =
          ''
            installShellCompletion --cmd niri \
              --bash <($out/bin/niri completions bash) \
              --fish <($out/bin/niri completions fish) \
              --nushell <($out/bin/niri completions nushell) \
              --zsh <($out/bin/niri completions zsh)

            install -Dm644 resources/niri.desktop -t $out/share/wayland-sessions
            install -Dm644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
          ''
          + lib.optionalString withSystemd ''
            install -Dm755 resources/niri-session $out/bin/niri-session
            install -Dm644 resources/niri{.service,-shutdown.target} -t $out/share/systemd/user
          '';

          env = {
            # Force linking with libEGL and libwayland-client
            # so they can be discovered by `dlopen()`
            RUSTFLAGS = toString (
              map (arg: "-C link-arg=" + arg) [
                "-Wl,--push-state,--no-as-needed"
                "-lEGL"
                "-lwayland-client"
                "-Wl,--pop-state"
              ]
            );
            NIRI_BUILD_COMMIT = revision;
          };

        passthru = {
          providedSessions = ["niri"];
        };

          meta = {
            description = "Scrollable-tiling Wayland compositor";
            homepage = "https://github.com/niri-wm/niri";
            license = lib.licenses.gpl3Only;
            mainProgram = "niri";
            platforms = lib.platforms.linux;
          };
        };

      inherit (nixpkgs) lib;
      # Support all Linux systems that the nixpkgs flake exposes
      systems = lib.intersectLists lib.systems.flakeExposed lib.platforms.linux;

      forAllSystems = lib.genAttrs systems;
      nixpkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});
    in
    {
      checks = forAllSystems (system: {
        # We use the debug build here to save a bit of time
        inherit (self.packages.${system}) niri-debug;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
          rust-bin = rust-overlay.lib.mkRustBin { } pkgs;
          inherit (self.packages.${system}) niri;
        in
        {
          default = pkgs.mkShell {
            packages = [
              # We don't use the toolchain from nixpkgs
              # because we prefer a nightly toolchain
              # and we *require* a nightly rustfmt
              (rust-bin.selectLatestNightlyWith (
                toolchain:
                toolchain.default.override {
                  extensions = [
                    # includes already:
                    # rustc
                    # cargo
                    # rust-std
                    # rust-docs
                    # rustfmt-preview
                    # clippy-preview
                    "rust-analyzer"
                    "rust-src"
                  ];
                }
              ))
              pkgs.cargo-insta
            ];

            nativeBuildInputs = [
              pkgs.rustPlatform.bindgenHook
              pkgs.pkg-config
              pkgs.wrapGAppsHook4 # For `niri-visual-tests`
            ];

          buildInputs = [
            pkgs.libadwaita # For `niri-visual-tests`
          ];

          env = {
            LD_LIBRARY_PATH = builtins.concatStringsSep ":" (
              map (e: "${e.lib or e.out}/lib") (
                ourBuildInputs
                ++ [
                  pkgs.glib
                  pkgs.pixman

                  # for `niri-visual-tests`
                  pkgs.libadwaita
                  pkgs.gtk4
                ]
              )
            );
          };
        };
      }
    );

    packages = forEachSupportedSystem ({ourPackages, ...}: ourPackages);

    nixosModules.default = import ./nix/modules/niri-nixos.nix {overlay = self.overlays.default;};

    homeManagerModules.default = import ./nix/modules/niri-home-manager.nix;

    overlays.default = final: _: {
      niriPackages = final.callPackage ./scope.nix {
        inherit
          advisory-db
          crane
          fenix
          self
          ;
      };
    };
  };
}
