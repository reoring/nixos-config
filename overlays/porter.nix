final: prev: {
  porter = prev.stdenv.mkDerivation rec {
    pname = "porter";
    version = "v1.2.1"; # Current version from the installer script
    
    # Pre-fetch Porter binaries
    porterDarwin = prev.fetchurl {
      url = "https://cdn.porter.sh/${version}/porter-darwin-amd64";
      sha256 = "caa17786bea4c545f463a7d9c4ea8347c79abb3692ef2bf83e66c6a99c60dc87";
    };
    
    porterLinux = prev.fetchurl {
      url = "https://cdn.porter.sh/${version}/porter-linux-amd64";
      sha256 = "85ee9eb88c62620e277ec35f63f3c73ba908a0e569f1fbbc0ddc5f54c9d14052";
    };
    
    nativeBuildInputs = [ prev.makeWrapper ];
    
    # We don't need to unpack anything
    dontUnpack = true;
    
    # No build phase needed
    dontBuild = true;

    installPhase = ''
      # Create directory structure
      mkdir -p $out/bin $out/libexec/porter
      mkdir -p $out/share/porter/runtimes
      
      # Install porter binaries
      ${if prev.stdenv.isDarwin then ''
        # macOS
        # Copy the raw binary to libexec (unwrapped version for internal use)
        cp ${porterDarwin} $out/libexec/porter/porter-unwrapped
        # Copy the binary that will be wrapped to bin
        cp ${porterDarwin} $out/bin/porter
        # Copy runtime
        cp ${porterLinux} $out/share/porter/runtimes/porter-runtime
      '' else ''
        # Linux
        cp ${porterLinux} $out/libexec/porter/porter-unwrapped
        cp ${porterLinux} $out/bin/porter
        cp ${porterLinux} $out/share/porter/runtimes/porter-runtime
      ''}
      
      # Make all binaries executable
      chmod +x $out/libexec/porter/porter-unwrapped
      chmod +x $out/bin/porter
      chmod +x $out/share/porter/runtimes/porter-runtime
      
      # Create mixins directory (Porter will install mixins on first use)
      mkdir -p $out/share/porter/mixins
      
      # Create a setup script that uses the unwrapped binary
      mkdir -p $out/libexec
      cat > $out/libexec/porter-setup.sh << EOF
      #!/bin/sh
      # Create Porter home directory if it doesn't exist
      mkdir -p \$HOME/.porter/mixins
      
      # Copy runtime to user's Porter home if needed
      if [ ! -f \$HOME/.porter/runtimes/porter-runtime ]; then
        mkdir -p \$HOME/.porter/runtimes
        cp $out/share/porter/runtimes/porter-runtime \$HOME/.porter/runtimes/
        chmod +x \$HOME/.porter/runtimes/porter-runtime
      fi
      
      # Install exec mixin if not already installed - using unwrapped binary
      if [ ! -f \$HOME/.porter/mixins/exec/exec ]; then
        # Use the unwrapped binary directly with explicit PORTER_HOME
        PORTER_HOME=\$HOME/.porter $out/libexec/porter/porter-unwrapped mixin install exec --version ${version}
      fi
      
      # Create marker file to indicate setup is complete
      touch \$HOME/.porter/.setup-complete
      EOF
      
      chmod +x $out/libexec/porter-setup.sh
      
      # Create a wrapper that checks for setup completion first
      wrapProgram $out/bin/porter \
        --set PORTER_HOME "\$HOME/.porter" \
        --prefix PATH : $out/bin \
        --run "if [ ! -f \"\$HOME/.porter/.setup-complete\" ]; then $out/libexec/porter-setup.sh; fi"
    '';
    
    meta = with prev.lib; {
      description = "A package manager for CNAB bundles";
      homepage = "https://porter.sh";
      license = licenses.asl20;
      platforms = platforms.unix;
      mainProgram = "porter";
    };
  };
}
