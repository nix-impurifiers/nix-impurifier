# nix-impurifier

Capture explicitly selected host libraries into immutable Nix store objects and
wrap selected Nix application programs to use them. Native Nix profiles own the
application, snapshot, generations, rollback and GC roots. This is meaningful
host interoperability for Nix itself; a native impure Nix installer remains
explicitly deferred. Original library/test code is MIT. Application licenses
remain their own.

```nix
let
  impurifier = inputs.nix-impurifier.lib.nix-impurifier {inherit pkgs;};
in impurifier.makePackage {
  pkg = myApplication;
  libraries."libdriver.so.1" = "/usr/lib/libdriver.so.1";
  programs = ["my-program"];
}
```

Library sources are absolute path **strings**, deliberately evaluated from the
host rather than copied into the consumer flake as source literals. Keys are the
library filenames expected by the loader. Each selected file is imported with
flat content addressing, so a native symlink is followed and its bytes captured.
The wrapper's LD_LIBRARY_PATH points at the immutable snapshot. Optional
`preload` selects declared library names for LD_PRELOAD. Programs outside the
selected `bin` list remain the original package's files; other package contents
are linked into the result. `snapshot` and `captured` are exposed as passthru.

Use the resulting package in your flake's normal package output:

```sh
nix profile install --impure .#my-package
nix profile upgrade --all --impure
nix profile rollback
nix profile list
nix profile remove ENTRY_NAME
```

Pure evaluation rejects access to mutable host paths. `--impure` is required at
install and upgrade so a changed driver is captured during evaluation. An
already-installed package continues using its old snapshot until explicitly
upgraded; changing or deleting the original host library cannot mutate it.
Rollback returns the previous native profile and its captured libraries.
Snapshots are ordinary Nix store dependencies rooted by native profile
generations; normal native history pruning/GC applies. No global trust setting,
privileged helper or second profile-generation database is added.

The consumer chooses native paths, programs and preload policy. This does not
make arbitrary host libraries ABI-compatible with arbitrary applications or
kernel drivers. It snapshots declared user-space files; load-time-discovered
plugins and indirect native library dependencies must also be declared when
needed. It does not traverse the host filesystem to guess a complete driver
installation. Nix profiles do not own /etc configuration or system services;
configure those through the host's service/configuration tools.

`nix flake check -L` runs a network-disabled QEMU VM with the real Nix daemon and
an unprivileged user. It tests rejection of pure host capture, native profile
install and upgrade, symlinked library capture, immutable behavior after the host
library changes/disappears, rollback, GC and removal. Native Nix itself and the
fixture application are preinstalled; this is not an installer test.
