{
  description = "A Rust web server including a NixOS module";

  # Nixpkgs / NixOS version to use.
  inputs = {
    # Nix Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  inputs.import-cargo.url = "github:edolstra/import-cargo";

  outputs = { self, nixpkgs, import-cargo }:
    let

      # to work with older version of flakes
      lastModifiedDate =
        self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = "${builtins.substring 0 8 lastModifiedDate}-${
          self.shortRev or "dirty"
        }";

      # System types to support.
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        });

    in {

      # A Nixpkgs overlay.
      overlays.default = final: prev: {

        rustynixspike = with final;
          final.callPackage ({ inShell ? false }:
            final.rustPlatform.buildRustPackage rec {
              pname = "rustynixspike-${version}";
              version = "0.1.0";

              # In 'nix develop', we don't need a copy of the source tree
              # in the Nix store.
              # src = if inShell then null else ./.;
              src = ./.;

              cargoSha256 =
                "sha256-odcOQu12jzHrMit2nnQubAhg7pb50jNGtcw0/Iyda0s=";
            }) { };

      };

      legacyPackages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) rustynixspike;
      });

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) rustynixspike;

        # The default package for 'nix build'. This makes sense if the
        # flake provides only one package or there is a clear "main"
        # package.
        default = self.packages.${system}.rustynixspike;
      });

      # Provide a 'nix develop' environment for interactive hacking.
      devShells = forAllSystems (system: {
        default =
          self.packages.${system}.rustynixspike.override { inShell = true; };
      });

      # A NixOS module.
      nixosModules.rustynixspike = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlays.default ];

        systemd.services.rustynixspike = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.ExecStart = "${pkgs.rustynixspike}/bin/rustynixspike";
        };
      };

      # Tests run by 'nix flake check' and by Hydra.
      #checks = forAllSystems
      #  (system:
      #    with nixpkgsFor.${system};

      #    {
      #      inherit (self.packages.${system}) rustynixspike;

      #      # A VM test of the NixOS module.
      #      vmTest =
      #        with import (nixpkgs + "/nixos/lib/testing-python.nix") {
      #          inherit system;
      #        };

      #        makeTest {
      #          nodes = {
      #            client = { ... }: {
      #              imports = [ self.nixosModules.rustynixspike ];
      #            };
      #          };

      #        testScript =
      #          ''
      #            start_all()
      #            client.wait_for_unit("multi-user.target")
      #            assert "Hello Nixers" in client.wait_until_succeeds("curl --fail http://localhost:8080/")
      #          '';
      #        };
      #    }
      #  );
    };
}
