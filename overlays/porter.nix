final: prev: {
  porter = prev.stdenv.mkDerivation rec {
    pname = "porter";
    version = "v1.2.1"; # Current version from the installer script
    
    # No src needed as we'll download binaries directly
    
    nativeBuildInputs = [ prev.makeWrapper ];
    
    # We don't need to unpack anything
    dontUnpack = true;
    
    # No build phase needed
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin $out/share/porter/runtimes
      
      # Download platform-specific binaries
      ${if prev.stdenv.isDarwin then ''
        # macOS
        curl -fsSLo $out/bin/porter ${prev.lib.escapeShellArg "https://cdn.porter.sh/${version}/porter-darwin-amd64"}
        curl -fsSLo $out/share/porter/runtimes/porter-runtime ${prev.lib.escapeShellArg "https://cdn.porter.sh/${version}/porter-linux-amd64"}
      '' else ''
        # Linux
        curl -fsSLo $out/bin/porter ${prev.lib.escapeShellArg "https://cdn.porter.sh/${version}/porter-linux-amd64"}
        cp $out/bin/porter $out/share/porter/runtimes/porter-runtime
      ''}
      
      chmod +x $out/bin/porter
      chmod +x $out/share/porter/runtimes/porter-runtime
      
      # Wrap the binary to set PORTER_HOME to the share directory
      wrapProgram $out/bin/porter \
        --set PORTER_HOME $out/share/porter
      
      # Install the exec mixin
      $out/bin/porter mixin install exec --version ${version}
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
