{
    pkgs ? import <nixpkgs> { },
    lib ? pkgs.lib,
    # "light" and "dark" follow X-Login's Halon schemes; "classic" is the original black and white
    variant ? "light",
    # Any SVG or raster image
    logo ? ./src/nixos-logo.svg,
    # Paint the logo in the scheme's heading colour; false keeps its own colours
    logoRecolor ? true,
    # Width of the logo on screen in pixels, glow excluded
    logoWidth ? 614,
    # Colour of the pulsing glow as "rrggbb" or "#rrggbb"; null uses the scheme's accent
    glowColor ? null,
    # How many boot statuses to list under the progress bar; 0 hides them
    statusLines ? 5,
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
        classic = {
            SURFACE_ROOT = "000000";
            SURFACE_DEFAULT = "000000";
            BORDER_DEFAULT = "606060";
            BORDER_CONTROL = "ffffff";
            ACCENT = "ffffff";
            TEXT_HEADING = "ffffff";
            TEXT_SECONDARY = "ffffff";
            TEXT_TERTIARY = "c0c0c0";
            STATUS_WARNING = "ffffff";
        };
    };
    palette = palettes.${variant};
    glow = if glowColor == null then palette.ACCENT else lib.removePrefix "#" glowColor;

    # The glow is the logo blurred twice and screened together, fitted to the hand-made glow of the
    # NixOS logo at 614px and scaled with the width; the padding leaves room for its falloff
    scaled = factor: toString (logoWidth * factor / 614.0);
    padding = toString (logoWidth * 42 / 614);

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
assert lib.assertMsg (builtins.match "[0-9a-fA-F]{6}" glow != null) "glowColor must be a hex colour like \"#60a5fa\"";
assert lib.assertMsg (builtins.isInt statusLines && statusLines >= 0) "statusLines must be a whole number, 0 or more";
pkgs.stdenv.mkDerivation {
    pname = "x-plymouth";
    version = "master";

    src = ./src;

    nativeBuildInputs = [
        pkgs.librsvg
        pkgs.imagemagick
    ];

    installPhase = ''
        INSTALL_PATH="$out/share/plymouth/themes/x-plymouth"
        mkdir -p $INSTALL_PATH

        substitute x-plymouth.plymouth $INSTALL_PATH/x-plymouth.plymouth \
            --replace-fail @THEME_DIR@ $INSTALL_PATH --replace-fail @VARIANT@ ${variant}
        substitute x-plymouth.script $INSTALL_PATH/x-plymouth.script ${substituteFlags channels} \
            --replace-fail @STATUS_LINES@ ${toString statusLines}

        # Trim the logo to its shape and size it, rendering an SVG at twice the width so it is not upscaled
        ${
            if lib.hasSuffix ".svg" (toString logo) then
                "rsvg-convert -w ${toString (logoWidth * 2)} ${logo} -o logo-source.png"
            else
                "cp ${logo} logo-source.png"
        }
        magick logo-source.png -trim +repage -resize ${toString logoWidth}x \
            -background none -gravity center -extent "%[fx:w+2*${padding}]x%[fx:h+2*${padding}]" shape.png

        ${
            if logoRecolor then
                "magick shape.png -fill '#${palette.TEXT_HEADING}' -colorize 100 $INSTALL_PATH/logo.png"
            else
                "cp shape.png $INSTALL_PATH/logo.png"
        }
        magick \( shape.png -alpha extract -blur 0x${scaled 2} \) \( shape.png -alpha extract -blur 0x${scaled 15} \) \
            -compose screen -composite -evaluate multiply 1.2 glow-alpha.png
        magick shape.png -fill '#${glow}' -colorize 100 glow-alpha.png -alpha off -compose copy-opacity -composite \
            $INSTALL_PATH/glow.png

        for icon in entry bullet lock capslock; do
            substitute icons/$icon.svg $icon.svg ${substituteFlags (hex: "#${hex}")}
            rsvg-convert $icon.svg -o $INSTALL_PATH/$icon.png
        done

        magick -size 1x1 'xc:#${palette.BORDER_DEFAULT}' $INSTALL_PATH/progress-trough.png
        magick -size 1x1 'xc:#${palette.ACCENT}' $INSTALL_PATH/progress-fill.png

        if grep -n '@[A-Z_]*@' $INSTALL_PATH/x-plymouth.script $INSTALL_PATH/x-plymouth.plymouth *.svg; then
            echo "unfilled colour placeholder" >&2
            exit 1
        fi
    '';
}
