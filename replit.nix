{ pkgs }: {
  deps = [
    pkgs.sqlite-interactive
    pkgs.bashInteractive
    pkgs.nodePackages.bash-language-server
    pkgs.man
  ];
}