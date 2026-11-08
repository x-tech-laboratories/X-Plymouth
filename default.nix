{ config, lib, pkgs, ... }:
{
    options.x-plymouth.variant = lib.mkOption {
        type = lib.types.enum [ "light" "dark" "classic" ];
        default = "light";
        description = ''
            Colour scheme of the splash. "light" and "dark" use X-Login's Halon schemes;
            "classic" is the original black and white theme. Plymouth runs before any
            desktop session, so the scheme cannot follow the system's and is fixed here.
        '';
    };

    config.boot.plymouth = {
        enable = true;
        themePackages = [ (pkgs.callPackage ./x-plymouth.nix { inherit (config.x-plymouth) variant; }) ];
        theme = "x-plymouth";
    };
}
