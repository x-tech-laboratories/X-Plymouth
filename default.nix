{ config, lib, pkgs, ... }:
let
    cfg = config.x-plymouth;
in
{
    options.x-plymouth = {
        variant = lib.mkOption {
            type = lib.types.enum [ "light" "dark" "classic" ];
            default = "light";
            description = ''
                Colour scheme of the splash. "light" and "dark" use X-Login's Halon schemes;
                "classic" is the original black and white theme. Plymouth runs before any
                desktop session, so the scheme cannot follow the system's and is fixed here.
            '';
        };

        logo = lib.mkOption {
            type = lib.types.path;
            default = ./src/nixos-logo.svg;
            description = ''
                Logo shown in the middle of the splash, as an SVG or any image ImageMagick reads.
                Its shape is given a pulsing glow.
            '';
        };

        logoRecolor = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
                Paint the logo in the scheme's text colour, which suits a single-colour logo.
                Set to false to keep a multi-colour logo's own colours.
            '';
        };

        logoWidth = lib.mkOption {
            type = lib.types.ints.positive;
            default = 614;
            description = "Width of the logo on screen in pixels, glow excluded.";
        };

        glowColor = lib.mkOption {
            type = lib.types.nullOr (lib.types.strMatching "#?[0-9a-fA-F]{6}");
            default = null;
            example = "#60a5fa";
            description = "Colour of the pulsing glow. Null uses the scheme's accent colour.";
        };

        statusLines = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 5;
            description = ''
                How many boot statuses to list under the progress bar, newest first. systemd
                reports the name of each unit it starts; 0 hides the list.
            '';
        };
    };

    config.boot.plymouth = {
        enable = true;
        themePackages = [ (pkgs.callPackage ./x-plymouth.nix { inherit (cfg) variant logo logoRecolor logoWidth glowColor statusLines; }) ];
        theme = "x-plymouth";
    };
}
