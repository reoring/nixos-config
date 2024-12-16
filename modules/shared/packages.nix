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
  uv

  # Encryption and security tools
  age
  age-plugin-yubikey
  gnupg
  libfido2

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
  nodePackages.npm # globally install npm
  nodePackages.prettier
  nodejs

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

  # Python packages
  python311
  python311Packages.virtualenv # globally install virtualenv
  python311Packages.pip
  python311Packages.uv

  # Keyboards
  goku

  # Kubernetes
  kubernetes
  kubernetes-helm
  k9s
  clusterctl
  cilium-cli
  kind
  minikube
  kubectl
  kubectx
  upbound
  eksctl
  kubebuilder
  krew
  stern
  kyverno

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
