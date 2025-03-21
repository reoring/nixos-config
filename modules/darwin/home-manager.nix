{ config, pkgs, lib, home-manager, ... }:

let
  user = "reoring";
  # Define the content of your file as a derivation
  myEmacsLauncher = pkgs.writeScript "emacs-launcher.command" ''
    #!/bin/sh
    emacsclient -c -n &
  '';
  sharedFiles = import ../shared/files.nix { inherit config pkgs; };
  additionalFiles = import ./files.nix { inherit user config pkgs; };
in
{
  imports = [
   ./dock
  ];

  # It me
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  homebrew = {
    enable = true;
    casks = pkgs.callPackage ./casks.nix {};
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      # cleanup = "uninstall";
    };

    taps = [                                                                
      # "nikitabobko/tap"
    ];

    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    # If you have previously added these apps to your Mac App Store profile (but not installed them on this system),
    # you may receive an error message "Redownload Unavailable with This Apple ID".
    # This message is safe to ignore. (https://github.com/dustinlyons/nixos-config/issues/83)
    masApps = {
      # "1password" = 1333542190;
      # "reeder" = 2114932107;
      "reeder-classic" = 1529448980;
      "wireguard" = 1451685025;
      "amphetamine" = 937984704;
      "macdroid" = 1476545828;
    };
  };

  # Enable home-manager
  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    users.${user} = { pkgs, config, lib, ... }:{
      home = {
        enableNixpkgsReleaseCheck = false;
        packages = pkgs.callPackage ./packages.nix {};
        file = lib.mkMerge [
          sharedFiles
          additionalFiles
          { "emacs-launcher.command".source = myEmacsLauncher; }
        ];
        stateVersion = "23.11";

        activation = {
          krewPlugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
            export PATH=${lib.makeBinPath [ pkgs.git pkgs.kubectl ]}:$PATH:$HOME/.krew/bin
            if ! command -v kubectl-krew >/dev/null 2>&1; then
              $DRY_RUN_CMD ${pkgs.krew}/bin/krew install krew
            fi
            
            # Install or update specified plugins
            KREW_PLUGINS=(
              "view-secret"
              "access-matrix"
            )
            
            for plugin in "''${KREW_PLUGINS[@]}"; do
              if ! kubectl krew list | grep -q "^$plugin\$"; then
                $DRY_RUN_CMD kubectl krew install "$plugin"
              fi
            done
          '';
          
          installClaudeCode = lib.hm.dag.entryAfter ["writeBoundary"] ''
            export PATH=${lib.makeBinPath [ pkgs.nodejs_22 ]}:$PATH
            export npm_config_prefix=$HOME/.npm-packages
            mkdir -p $HOME/.npm-packages
            $DRY_RUN_CMD npm install -g @anthropic-ai/claude-code
          '';
        };
      };
      programs = {} // import ../shared/home-manager.nix { inherit config pkgs lib; };

      # Marked broken Oct 20, 2022 check later to remove this
      # https://github.com/nix-community/home-manager/issues/3344
      manual.manpages.enable = false;
    };
  };

  # Fully declarative dock using the latest from Nix Store
  local.dock.enable = true;
  local.dock.autohide = true;  # Enable auto-hide for the dock
  local.dock.entries = [
    { path = "/Applications/Obsidian.app/"; }
    { path = "/Applications/Slack.app/"; }
    # { path = "/System/Applications/Messages.app/"; }
    # { path = "/System/Applications/Messages.app/"; }
    # { path = "/System/Applications/Facetime.app/"; }
    # { path = "${pkgs.alacritty}/Applications/Alacritty.app/"; }
    # { path = "/System/Applications/Music.app/"; }
    # { path = "/System/Applications/News.app/"; }
    # { path = "/System/Applications/Photos.app/"; }
    # { path = "/System/Applications/Photo Booth.app/"; }
    # { path = "/System/Applications/TV.app/"; }
    # { path = "/System/Applications/Home.app/"; }
    # {
      # path = toString myEmacsLauncher;
      # section = "others";
    # }
    {
      path = "${config.users.users.${user}.home}/.local/share/";
      section = "others";
      options = "--sort name --view grid --display folder";
    }
    {
      # path = "${config.users.users.${user}.home}/.local/share/downloads";
      path = "${config.users.users.${user}.home}/Downloads";
      section = "others";
      options = "--sort datemodified --view grid --display stack";
    }
  ];
}
