{ agenix, config, pkgs, ... }:

let
  user = "reoring";
  # macOS Tahoe (26.x) ships a libgccjit that fails Emacs's configure-time
  # test program, and the current emacs-overlay master fails to build
  # against the new tree-sitter ABI. Fall back to stable pkgs.emacs with
  # native compilation off until upstream catches up.
  emacsBuild = pkgs.emacs.override { withNativeCompilation = false; };
in

{

  imports = [
    ../../modules/darwin/secrets.nix
    ../../modules/darwin/home-manager.nix
    ../../modules/shared
     agenix.darwinModules.default
  ];

  # nix-darwin now manages the daemon unconditionally when nix.enable is on,
  # and gc runs as root, so services.nix-daemon.enable / nix.gc.user are
  # no longer settable.
  system.primaryUser = user;

  # Existing Nix install was set up before nix-darwin's default nixbld GID
  # changed from 30000 to 350; tell nix-darwin to use the actual GID.
  ids.gids.nixbld = 350;

  # Determinate manages the Nix daemon and Nix installation on this host.
  # Keep nix-darwin from trying to manage the same files/services.
  nix.enable = false;

  # Turn off NIX_PATH warnings now that we're using flakes
  system.checks.verifyNixPath = false;

  # Load configuration that is shared across systems
  environment.systemPackages = with pkgs; [
    emacsBuild
    agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
    devbox
  ] ++ (import ../../modules/shared/packages.nix { inherit pkgs; });

  launchd.user.agents.emacs.path = [ config.environment.systemPath ];
  launchd.user.agents.emacs.serviceConfig = {
    KeepAlive = true;
    ProgramArguments = [
      "/bin/sh"
      "-c"
      "/bin/wait4path ${pkgs.emacs}/bin/emacs && exec ${pkgs.emacs}/bin/emacs --fg-daemon"
    ];
    StandardErrorPath = "/tmp/emacs.err.log";
    StandardOutPath = "/tmp/emacs.out.log";
  };

  launchd.user.agents.karabiner-elements.serviceConfig = {
    RunAtLoad = true;
    ProgramArguments = [
      "/usr/bin/open"
      "-g"
      "-j"
      "-a"
      "Karabiner-Elements"
    ];
  };

  # AeroSpace is managed by Nix; start the app bundle from the active store
  # generation instead of the Homebrew Cask location in /Applications.
  launchd.user.agents."bobko.aerospace".serviceConfig = {
    ProgramArguments = [
      "${pkgs.aerospace}/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"
    ];
    RunAtLoad = true;
  };

  system = {
    stateVersion = 4;

    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;

        # 120, 90, 60, 30, 12, 6, 2
        KeyRepeat = 2;

        # 120, 94, 68, 35, 25, 15
        InitialKeyRepeat = 15;

        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };

      dock = {
        autohide = false;
        show-recents = false;
        launchanim = true;
        orientation = "bottom";
        tilesize = 48;
      };

      finder = {
        _FXShowPosixPathInTitle = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };
}
