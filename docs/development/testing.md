# Testing

`nix flake check -L` runs actual native Nix profile commands through an
unprivileged user and daemon inside QEMU, with networking disabled. Library
inputs are real compiled DSOs provided through a mutable host symlink; the
application uses dlopen and reports a different value for each driver version.

Verify pure evaluation fails, impure install captures the bytes, GC preserves
profile dependencies, profile upgrade recaptures changed bytes, host-file deletion
leaves snapshots usable, and native rollback/removal have their normal meaning.
No fake native manager or relaxed daemon trust is used. Nix is preinstalled;
installation/provisioning itself is deferred.
