# SPDX-License-Identifier: MIT
{
  pkgs,
  impurifier,
  coreSrc,
}:
let
  fixture = import (coreSrc + "/tests/hardware-fixture.nix") { inherit pkgs; };
  consumer = pkgs.writeText "consumer-flake.nix" ''
    {
      inputs.nixpkgs.url = "path:${pkgs.path}";
      outputs = {self, nixpkgs}: let
        pkgs = import nixpkgs {system="x86_64-linux";};
        impurifier = import ./lib {inherit pkgs;};
        fixture = import ./fixture.nix {inherit pkgs;};
      in {
        packages.x86_64-linux.default = impurifier.makePackage {
          pkg = fixture.tool;
          libraries."libimpurifier-driver.so.1" = "/usr/lib/libimpurifier-driver.so.1";
          programs = ["hardware-tool"];
        };
      };
    }
  '';
in
{
  vm = pkgs.testers.runNixOSTest {
    name = "nix-impurifier";
    requiredFeatures = {
      kvm = false;
      devnet = false;
    };
    nodes.machine = { lib, ... }: {
      virtualisation.memorySize = 3072;
      virtualisation.diskSize = 6144;
      virtualisation.useNixStoreImage = true;
      virtualisation.writableStore = true;
      virtualisation.qemu.package = lib.mkForce pkgs.qemu;
      virtualisation.qemu.forceAccel = false;
      environment.systemPackages = [
        pkgs.nix
        pkgs.su
      ];
      system.extraDependencies = [
        pkgs.path
        pkgs.stdenvNoCC
        pkgs.makeWrapper
        pkgs.xorg.lndir
        fixture.tool
        (fixture.driver "1")
        (fixture.driver "2")
      ];
      users.users.consumer = {
        isNormalUser = true;
      };
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nix.settings.substituters = lib.mkForce [ ];
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl stop dhcpcd; ip link set eth0 down")
      machine.succeed("mkdir -p /usr/lib /home/consumer/project; cp -r ${../nix} /home/consumer/project/lib; cp ${consumer} /home/consumer/project/flake.nix; cp ${
        coreSrc + "/tests/hardware-fixture.nix"
      } /home/consumer/project/fixture.nix; chown -R consumer:users /home/consumer/project; chmod -R u+w /home/consumer/project")
      machine.succeed("cp ${fixture.driver "1"}/usr/lib/libimpurifier-driver.so.1 /usr/lib/libimpurifier-driver.so.1.1; ln -s libimpurifier-driver.so.1.1 /usr/lib/libimpurifier-driver.so.1")
      import shlex
      def user(command):
          return "su - consumer -c " + shlex.quote(command)
      profile = "/home/consumer/test-profile"
      with subtest("pure evaluation rejects capture of mutable host libraries"):
          code, output = machine.execute(user("nix build path:/home/consumer/project --no-link") + " 2>&1")
          assert code != 0 and "pure evaluation" in output, output
      with subtest("unprivileged native Nix profile installs captured host library"):
          machine.succeed(user("nix profile install --profile " + profile + " --impure path:/home/consumer/project"))
          machine.succeed(user(profile + "/bin/hardware-tool | grep '^1$'"))
          machine.succeed("nix-store --gc")
          machine.succeed(user(profile + "/bin/hardware-tool | grep '^1$'"))
      with subtest("native profile upgrade recaptures changed host library"):
          machine.succeed("cp ${fixture.driver "2"}/usr/lib/libimpurifier-driver.so.1 /usr/lib/libimpurifier-driver.so.1.1")
          machine.succeed(user(profile + "/bin/hardware-tool | grep '^1$'"))
          machine.succeed(user("nix profile upgrade --profile " + profile + " --all --impure"))
          machine.succeed(user(profile + "/bin/hardware-tool | grep '^2$'"))
          machine.succeed("rm /usr/lib/libimpurifier-driver.so.1 /usr/lib/libimpurifier-driver.so.1.1; nix-store --gc")
          machine.succeed(user(profile + "/bin/hardware-tool | grep '^2$'"))
      with subtest("native rollback retains the previous immutable driver snapshot"):
          machine.succeed(user("nix profile rollback --profile " + profile))
          machine.succeed(user(profile + "/bin/hardware-tool | grep '^1$'"))
      with subtest("native profile removal releases the application entry"):
          machine.succeed(user("nix profile remove --profile " + profile + " --all"))
          machine.fail(user("test -e " + profile + "/bin/hardware-tool"))
    '';
  };
}
