# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: rec {
  libfprint-canvasbio-cb2000 = pkgs.callPackage ./libfprint-canvasbio-cb2000 { };

  # Cross-compiled BSP kernel for ASUS RT-AX88U (BCM4908)
  # Builds from Merlin source tree using aarch64 cross-compiler
  rt-ax88u-bsp-kernel =
    if pkgs ? pkgsCross.aarch64-multiplatform then
      pkgs.pkgsCross.aarch64-multiplatform.callPackage ./rt-ax88u-bsp-kernel { }
    else
      builtins.throw "aarch64 cross-compilation not available in this nixpkgs version";
}
