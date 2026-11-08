{
    pkgs ? import <nixpkgs> { },
}:
pkgs.stdenv.mkDerivation {
    pname = "x-plymouth";
    version = "master";

    src = ./src;

    installPhase = ''
        # Copy files
        INSTALL_PATH="$out/share/plymouth/themes/x-plymouth"
        mkdir -p $INSTALL_PATH
        cp -v x-plymouth.plymouth $INSTALL_PATH
        cp -Rv resources $INSTALL_PATH

        # Fix path
        sed -i "s@\/usr\/@$out\/@" $INSTALL_PATH/x-plymouth.plymouth
    '';
}
