{ pkgs }:

with pkgs; [
  # General packages for development and system management
  alacritty
  aspell
  aspellDicts.en
  bash-completion
  bat
  btop
  coreutils
  killall
  fastfetch
  openssh
  sqlite
  wget
  zip
  fish
  zsh
  neovim
  localsend
  gh
  nixpacks

  # Encryption and security tools
  age
  age-plugin-yubikey
  gnupg
  libfido2
  yubikey-manager

  # Cloud-related tools and SDKs
  docker
  docker-compose
  dive

  # Media-related packages
  emacs-all-the-icons-fonts
  dejavu_fonts
  ffmpeg
  fd
  font-awesome
  hack-font
  noto-fonts
  noto-fonts-color-emoji
  meslo-lgs-nf

  # Node.js development tools
  prettier
  yarn-berry
  pnpm
  nodejs_22

  # Go
  go

  # Text and terminal utilities
  htop
  hunspell
  iftop
  jetbrains-mono
  jq
  ripgrep
  tree
  tmux
  unrar
  unzip
  zsh-powerlevel10k
  fzf
  # Lets remote Linux hosts correctly interpret TERM=xterm-ghostty over SSH.
] ++ lib.optionals stdenv.hostPlatform.isLinux [
  ghostty.terminfo
] ++ [

  # Python packages
  python313
  python313Packages.virtualenv # globally install virtualenv
  python313Packages.pip
  python313Packages.uv

  # Zig packages
  zig
  
  # Keyboards
  goku

  # Kubernetes
  # minikube now ships kubectl; avoid colliding kubectl binaries in the
  # Home Manager profile.
  kubernetes-helm
  helmfile
  k9s
  kcl
  clusterctl
  cilium-cli
  kind
  (minikube.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      rm $out/bin/kubectl
    '';
  }))
  kubectl
  kubectx
  kubie
  upbound
  eksctl
  kubebuilder
  krew
  stern
  kyverno
  fluxcd
  tilt
  kyverno-chainsaw
  porter

  flyctl

  # AWS (v2 is the maintained line; nixpkgs' v1 build is broken on this rev)
  awscli2
  # Google Cloud
  google-cloud-sdk

  # LLM
  ollama

  # Rust things
  rustup
]
