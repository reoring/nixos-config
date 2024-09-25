{ pkgs, config, ... }:

{
  # Initializes Emacs with org-mode so we can tangle the main config
  ".emacs.d/init.el" = {
    text = builtins.readFile ../shared/config/emacs/init.el;
  };

  # Initializes karabiner-elements
  # ".config/karabiner/karabiner.json" = {
    # text = builtins.readFile ../shared/config/karabiner/karabiner.json;
  # };

  # Setup goku
  ".config/karabiner.edn" = {
    text = builtins.readFile ../shared/config/karabiner/karabiner.edn;
  };

  # Setup wezterm
  ".wezterm.lua" = {
    text = builtins.readFile ../shared/config/wezterm/.wezterm.lua;
  };
  
  # Setup tabby
  "Library/Application Support/tabby/config.yaml" = {
    text = builtins.readFile ../shared/config/tabby/config.yaml;
  };

  # Setup aquaskk
  "Library/Application Support/AquaSKK/keymap.conf" = {
    text = builtins.readFile ../shared/config/aquaskk/keymap.conf;
  };

  # Setup GPG agent
  ".gnupg/gpg-agent.conf" = {
    text = builtins.readFile ../shared/config/gnupg/gpg-agent.conf;
  };
  ".gnupg/gpg.conf" = {
    text = builtins.readFile ../shared/config/gnupg/gpg.conf;
  };
}
