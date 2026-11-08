{
    pkgs ? import <nixpkgs> { },
    lib ? pkgs.lib,
    # "light" and "dark" follow X-Login's Halon schemes; "classic" is the original black and white
    variant ? "light",
}:
let
    # Halon tokens, from X-Themes/halon/tokens.json
    palettes = {
        light = {
            SURFACE_ROOT = "f1f5f9";
            SURFACE_DEFAULT = "ffffff";
            BORDER_DEFAULT = "e2e8f0";
            BORDER_CONTROL = "8792a3";
            ACCENT = "2563eb";
            TEXT_HEADING = "0f172a";
            TEXT_SECONDARY = "475569";
            TEXT_TERTIARY = "64748b";
            STATUS_WARNING = "c2410c";
        };
        dark = {
            SURFACE_ROOT = "060b14";
            SURFACE_DEFAULT = "16213a";
            BORDER_DEFAULT = "334155";
            BORDER_CONTROL = "64748b";
            ACCENT = "60a5fa";
            TEXT_HEADING = "f8fafc";
            TEXT_SECONDARY = "cbd5e1";
            TEXT_TERTIARY = "94a3b8";
            STATUS_WARNING = "f59e0b";
        };
    };
    palette = palettes.${variant};

    # "f1f5f9" -> "0.945098, 0.960784, 0.976471", the form Plymouth's script functions take
    channels =
        hex:
        lib.concatMapStringsSep ", " (
            i: toString (lib.fromHexString (builtins.substring i 2 hex) / 255.0)
        ) [ 0 2 4 ];

    # Each file uses only some of the colours, so every one is offered and the result checked after
    substituteFlags =
        format: lib.concatStringsSep " " (lib.mapAttrsToList (name: hex: "--replace-quiet @${name}@ '${format hex}'") palette);
in
assert lib.assertOneOf "variant" variant [ "light" "dark" "classic" ];
pkgs.stdenv.mkDerivation {
    pname = "x-plymouth";
    version = "master";

    src = ./src;

    nativeBuildInputs = lib.optionals (variant != "classic") [
        pkgs.librsvg
        pkgs.imagemagick
    ];

    installPhase =
        if variant == "classic" then
            ''
                # Copy files
                INSTALL_PATH="$out/share/plymouth/themes/x-plymouth"
                mkdir -p $INSTALL_PATH
                cp -v x-plymouth.plymouth $INSTALL_PATH
                cp -Rv resources $INSTALL_PATH

                # Fix path
                sed -i "s@\/usr\/@$out\/@" $INSTALL_PATH/x-plymouth.plymouth
            ''
        else
            ''
                INSTALL_PATH="$out/share/plymouth/themes/x-plymouth"
                mkdir -p $INSTALL_PATH

                substitute halon/x-plymouth.plymouth $INSTALL_PATH/x-plymouth.plymouth \
                    --replace-fail @THEME_DIR@ $INSTALL_PATH --replace-fail @VARIANT@ ${variant}
                substitute halon/x-plymouth.script $INSTALL_PATH/x-plymouth.script ${substituteFlags channels}

                # The frames are a white logo with a white glow. Recolour the glow to the accent, then lay
                # the logo over it in the heading colour, raising alpha to a power so only the opaque logo
                # pixels and not the glow's soft edge take that colour
                for frame in resources/throbber-*.png; do
                    magick \( "$frame" -fill '#${palette.ACCENT}' -colorize 100 \) \
                        \( "$frame" -fill '#${palette.TEXT_HEADING}' -colorize 100 -channel A -evaluate pow 6 +channel \) \
                        -composite "$INSTALL_PATH/$(basename "$frame")"
                done

                for icon in entry bullet lock capslock; do
                    substitute halon/$icon.svg $icon.svg ${substituteFlags (hex: "#${hex}")}
                    rsvg-convert $icon.svg -o $INSTALL_PATH/$icon.png
                done

                magick -size 1x1 'xc:#${palette.BORDER_DEFAULT}' $INSTALL_PATH/progress-trough.png
                magick -size 1x1 'xc:#${palette.ACCENT}' $INSTALL_PATH/progress-fill.png

                if grep -n '@[A-Z_]*@' $INSTALL_PATH/x-plymouth.script *.svg; then
                    echo "unfilled colour placeholder" >&2
                    exit 1
                fi
            '';
}
