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
  neofetch
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
  noto-fonts-emoji
  meslo-lgs-nf

  # Node.js development tools
  nodePackages.prettier
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

  # Python packages
  python311
  python311Packages.virtualenv # globally install virtualenv
  python311Packages.pip
  python311Packages.uv

  # Zig packages
  zig
  
  # Keyboards
  goku

  # Kubernetes
  kubernetes
  kubernetes-helm
  helmfile
  k9s
  kcl
  clusterctl
  cilium-cli
  kind
  minikube
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

  # AWS
  awscli
  # Google Cloud
  google-cloud-sdk

  # LLM
  ollama
  aider-chat

  # Rust things
  rustup
]
