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

  outputs = {
    self,
    nixpkgs,
    treefmt-nix,
    fenix,
    crane,
    advisory-db,
  }: let
    niri-package = {
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
        version = self.shortRev or self.dirtyShortRev or "unknown";

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
        # https://github.com/YaLTeR/niri/commit/771ea1e81557ffe7af9cbdbec161601575b64d81
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
        };

        passthru = {
          providedSessions = ["niri"];
        };

        meta = {
          description = "Scrollable-tiling Wayland compositor";
          homepage = "https://github.com/YaLTeR/niri";
          license = lib.licenses.gpl3Only;
          mainProgram = "niri";
          platforms = lib.platforms.linux;
        };
      };
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    inherit (nixpkgs) lib;

    forEachSupportedSystem = f:
      lib.genAttrs supportedSystems (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
          };

          ourPackages = lib.filterAttrs (_: v: (v ? niriPackage)) pkgs.niriPackages;

          treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

          treefmt = treefmtEval.config.build.wrapper;
        in
          f {
            inherit
              crane
              fenix
              ourPackages
              pkgs
              system
              treefmt
              treefmtEval
              ;
          }
      );
  in {
    formatter = forEachSupportedSystem ({treefmt, ...}: treefmt);

    checks = forEachSupportedSystem (
      {
        pkgs,
        treefmtEval,
        ourPackages,
        ...
      }: let
        testsFrom = pkg:
          pkgs.lib.mapAttrs' (name: value: {
            name = "${pkg.pname}-${name}";
            inherit value;
          }) (pkg.passthru.tests or {});

        ourTests =
          pkgs.lib.foldlAttrs (
            acc: name: value:
              acc // (testsFrom value)
          ) {}
          ourPackages;
      in
        ourTests
        // {
          treefmt = treefmtEval.config.build.check self;
        }
    );

    devShells = forEachSupportedSystem (
      {
        pkgs,
        ourPackages,
        treefmt,
        ...
      }: let
        ourBuildInputs = lib.unique (
          lib.foldlAttrs (
            acc: _: v:
              acc ++ (v.buildInputs or []) ++ (v.nativeBuildInputs or [])
          ) []
          ourPackages
        );
      in {
        default = pkgs.mkShell {
          inputsFrom = builtins.attrValues ourPackages;

          packages = let
            perf = pkgs.perf.override {
              binutils-unwrapped = pkgs.llvmPackages.bintools-unwrapped;
            };

            cargo-flamegraph = pkgs.cargo-flamegraph.override {
              inherit perf;
            };
          in [
            pkgs.cargo-insta
            pkgs.flamegraph
            pkgs.pkg-config
            pkgs.rustPlatform.bindgenHook
            pkgs.wrapGAppsHook4 # For `niri-visual-tests`

            cargo-flamegraph
            perf
            treefmt
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
