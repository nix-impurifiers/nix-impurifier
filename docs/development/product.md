# Product

Nix needs a concrete impurifier contract too: explicitly capture selected host
DSOs and let native Nix profiles own their immutable snapshots. Do not emulate
Nix profile transactions through package scripts. Original code is MIT. The Nix
provider/installer remains deferred; see ../../README.md for the public API.
