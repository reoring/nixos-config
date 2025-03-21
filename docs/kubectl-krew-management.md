# Managing kubectl-krew with Nix and Home Manager

This document explains how to manage kubectl krew and its plugins using Nix and Home Manager.

## Overview

kubectl-krew is a plugin manager for kubectl command-line tool. While it's possible to install krew plugins manually, managing them through Nix provides several benefits:

1. Declarative configuration
2. Reproducible setup
3. Automatic installation and updates
4. Version control of plugin configurations

## Implementation Details

### 1. Package Installation

The base krew package is installed through the system packages in `modules/shared/packages.nix`:

```nix
{ pkgs }:

with pkgs; [
  # ... other packages ...
  kubectl
  krew
  # ... other packages ...
]
```

### 2. PATH Configuration

The krew binary path needs to be added to the shell's PATH. This is done in the zsh configuration in `modules/shared/home-manager.nix`:

```nix
zsh = {
  enable = true;
  initExtraFirst = ''
    # ... other PATH configurations ...
    export PATH=''${KREW_ROOT:-$HOME/.krew}/bin:$PATH
  '';
};
```

Note: The `''${...}` syntax is used for proper shell variable escaping in Nix strings.

### 3. Plugin Management

Plugins are managed through home-manager's activation scripts in `modules/darwin/home-manager.nix`:

```nix
home-manager = {
  users.${user} = { pkgs, config, lib, ... }: {
    home = {
      activation = {
        krewPlugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
          export PATH=${lib.makeBinPath [ pkgs.git pkgs.kubectl ]}:$PATH:$HOME/.krew/bin
          if ! command -v kubectl-krew >/dev/null 2>&1; then
            $DRY_RUN_CMD ${pkgs.krew}/bin/krew install krew
          fi
          
          # Install or update specified plugins
          KREW_PLUGINS=(
            "view-secret"
            # Add more plugins here
          )
          
          for plugin in "''${KREW_PLUGINS[@]}"; do
            if ! kubectl krew list | grep -q "^$plugin\$"; then
              $DRY_RUN_CMD kubectl krew install "$plugin"
            fi
          done
        '';
      };
    };
  };
};
```

## Key Learnings

1. **PATH Management**:
   - Krew requires its bin directory in PATH
   - Shell variables in Nix strings need proper escaping (using `''${...}` instead of `${...}`)
   - PATH modifications should be done in shell configuration for persistence

2. **Activation Scripts**:
   - Use `home.activation` for one-time setup operations
   - Ensure required tools (git, kubectl) are available in activation script PATH
   - Use `lib.makeBinPath` to properly construct PATH with Nix packages

3. **Plugin Installation**:
   - Check if plugins are already installed before attempting installation
   - Use an array to manage multiple plugins
   - Consider plugin dependencies (some plugins might require others)

4. **Error Handling**:
   - Check for command existence before running installation
   - Use proper error checking in activation scripts
   - Consider network connectivity for plugin installation

## Adding New Plugins

To add new kubectl plugins:

1. Add the plugin name to the `KREW_PLUGINS` array in the activation script
2. Run `nix run .#build-switch` to apply the changes

Example:
```nix
KREW_PLUGINS=(
  "view-secret"
  "ctx"      # Add new plugin
  "ns"       # Add new plugin
)
```

## Troubleshooting

1. If plugins are not found after installation:
   - Verify that the krew PATH is correctly set in your shell
   - Try starting a new shell session
   - Check if the plugin was installed correctly with `kubectl krew list`

2. If installation fails:
   - Check network connectivity
   - Verify that git is available during activation
   - Check plugin compatibility with your kubectl version

## References

- [Krew Documentation](https://krew.sigs.k8s.io/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Manual](https://nixos.org/manual/nix/stable/)
