# SPDX-License-Identifier: MIT
{ pkgs }:
let
  inherit (pkgs) lib;
  atom =
    value:
    builtins.isString value
    && builtins.match "[A-Za-z0-9_.+-]+" value != null
    && !(lib.elem value [
      "."
      ".."
    ]);
  makePackage =
    {
      pkg,
      libraries,
      programs,
      preload ? [ ],
    }:
    assert lib.assertMsg (
      libraries != { } && lib.all atom (builtins.attrNames libraries)
    ) "declare native libraries by soname";
    assert lib.assertMsg (programs != [ ] && lib.all atom programs) "declare wrapped bin programs";
    assert lib.assertMsg (lib.all (
      name: builtins.hasAttr name libraries
    ) preload) "preload must select declared libraries";
    let
      captured = lib.mapAttrs (
        name: source:
        assert lib.assertMsg (
          builtins.isString source && lib.hasPrefix "/" source
        ) "native library source must be an absolute path string";
        builtins.path {
          path = source;
          inherit name;
          recursive = false;
        }
      ) libraries;
      snapshot = pkgs.linkFarm "${pkg.pname}-native-libraries" (
        lib.mapAttrsToList (name: path: { inherit name path; }) captured
      );
    in
    pkgs.symlinkJoin {
      name = "${pkg.pname}-impurified-${pkg.version}";
      inherit (pkg) pname version;
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      passthru = { inherit snapshot captured; };
      meta = pkg.meta or { };
      postBuild = lib.concatMapStringsSep "\n" (program: ''
        test -x "$out/bin/${program}"
        rm "$out/bin/${program}"
        makeWrapper ${lib.escapeShellArg "${pkg}/bin/${program}"} "$out/bin/${program}" \
          --prefix LD_LIBRARY_PATH : ${snapshot} \
          ${lib.optionalString (preload != [ ])
            "--prefix LD_PRELOAD : ${lib.concatMapStringsSep ":" (name: "${snapshot}/${name}") preload}"
          }
      '') programs;
    };
in
{
  inherit makePackage;
}
