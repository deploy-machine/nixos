{
  description = "Ruby on Rails development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
        (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [ ruby libyaml pkg-config openssl zlib ];
          shellHook = ''
            export GEM_HOME="$PWD/.gems"
            export PATH="$GEM_HOME/bin:$PATH"
            echo "Ruby $(ruby --version | cut -d\  -f2) — gems install into ./.gems (gem install rails)"
          '';
        };
      });
    };
}
