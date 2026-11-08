{ pkgs, ... }:
{
    config.boot.plymouth = {
        enable = true;
        themePackages = [ (pkgs.callPackage ./x-plymouth.nix { }) ];
        theme = "x-plymouth";
    };
}
