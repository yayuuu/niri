{
  craneLib,
  dbus,
  lib,
  mkNiriDerivation,
  pipewire,
  rustToolchain,
  systemd,
  withDbus ? true,
  withDinit ? false,
  withScreencastSupport ? true,
  withSystemd ? true,
}: let
  cargoToml = builtins.fromTOML (builtins.readFile ../../../Cargo.toml);
in
  mkNiriDerivation {
    pname = cargoToml.package.name;
    version = cargoToml.workspace.package.version;

    # Source filtering
    src = let
      niriFilter = path: type: builtins.match ".*niri-source/(resources|src).*" path != null;
      srcFilter = path: type: (niriFilter path type) || (craneLib.filterCargoSources path type);
    in
      lib.cleanSourceWith {
        src = builtins.path {
          path = ../../../.;
          name = "niri-source";
        };
        filter = srcFilter;
        name = "source";
      };

    # Build inputs
    buildInputs =
      lib.optional (withDbus || withScreencastSupport || withSystemd) dbus
      ++ lib.optional withScreencastSupport pipewire
      ++ lib.optional withSystemd systemd;

    buildFeatures = builtins.concatStringsSep "," (
      lib.optional withDbus "dbus"
      ++ lib.optional withDinit "dinit"
      ++ lib.optional withScreencastSupport "xdp-gnome-screencast"
      ++ lib.optional withSystemd "systemd"
    );

    # Disable tests to avoid Rust compilation errors
    doCheck = false;

    postPatch = ''
      # Fix shebangs for scripts
      patchShebangs resources/niri-session

      # Do not fail if /usr/bin is missing in systemd service
      substituteInPlace resources/niri.service --replace-warn "/usr/bin" "$out/bin"
    '';

    postInstall =
      ''
        install -Dm644 resources/niri.desktop -t $out/share/wayland-sessions
        install -Dm644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
      ''
      + lib.optionalString withSystemd ''
        install -Dm755 resources/niri-session $out/bin/niri-session
        install -Dm644 resources/niri{.service,-shutdown.target} -t $out/share/systemd/user
      '';

    postFixup = ''
      autoPatchelf $out/bin

      installShellCompletion --cmd niri \
        --bash <($out/bin/niri completions bash) \
        --fish <($out/bin/niri completions fish) \
        --nushell <($out/bin/niri completions nushell) \
        --zsh <($out/bin/niri completions zsh)
    '';

    passthru = {
      inherit rustToolchain;
      providedSessions = ["niri"];
    };

    meta = {
      description = "Scrollable-tiling Wayland compositor";
      homepage = "https://github.com/YaLTeR/niri";
      license = lib.licenses.gpl3Only;
      mainProgram = "niri";
      platforms = lib.platforms.linux;
      maintainers = [
        lib.maintainers.naxdy
      ];
    };
  }
