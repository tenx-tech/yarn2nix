#
# Fairly "dumb" minimal version of `yarn2nix` which avoids the symlink farming
# that the original `mkYarnPackage` does, which breaks very often with Git
# dependencies or `"resolutions"`.
#
# The `mkYarnPackage` API behaves somewhat similar to the original, except there
# is no `yarn pack` step after the build is complete.
#

{ pkgs ? import <nixpkgs> {} }:
let
  inherit (pkgs) stdenv cacert callPackage fetchurl lib linkFarm runCommand;
  yarn2nix = (import ./. { inherit pkgs; }).yarn2nix;

  unlessNull = item: alt:
    if item == null then alt else item;

  reformatPackageName = pname:
    let
      # regex adapted from `validate-npm-package-name`
      # will produce 3 parts e.g.
      # "@someorg/somepackage" -> [ "@someorg/" "someorg" "somepackage" ]
      # "somepackage" -> [ null null "somepackage" ]
      parts = builtins.tail (builtins.match "^(@([^/]+)/)?([^/]+)$" pname);
      # if there is no organisation we need to filter out null values.
      non-null = builtins.filter (x: x != null) parts;
    in builtins.concatStringsSep "-" non-null;

  defaultYarnFlags = [
    "--offline"
    "--frozen-lockfile"
    "--ignore-engines"
    "--ignore-scripts"
  ];

  mkYarnNix = { yarnLock, flags ? [] }:
    runCommand "yarn.nix" {}
    "${yarn2nix}/bin/yarn2nix --lockfile ${yarnLock} --no-patch --builtin-fetchgit ${lib.escapeShellArgs flags} > $out";

  mkYarnPackage = {
    name ? null,
    src,
    packageJSON ? src + "/package.json",
    yarnLock ? src + "/yarn.lock",
    yarnNix ? mkYarnNix { inherit yarnLock; },
    yarnFlags ? defaultYarnFlags,
    extraBuildInputs ? [],
    preBuild ? "",
    postBuild ? "",
    ...
  }@attrs:
  let
    package = lib.importJSON packageJSON;
    pname = package.name;
    safeName = reformatPackageName pname;
    version = package.version or attrs.version;
    baseName = unlessNull name "${safeName}-${version}";

    importOfflineCache = yarnNix:
      let
        pkg = callPackage yarnNix {};
      in
        pkg.offline_cache;
  in
    stdenv.mkDerivation {
      inherit src preBuild postBuild;
      name = "${baseName}";
      buildInputs = with pkgs; [ cacert yarn nodejs git ] ++ extraBuildInputs;

      buildPhase = ''
        if [[ -d node_modules || -L node_modules ]]; then
          echo "node_modules dir present. Removing."
          rm -rf node_modules
        fi

        cp ${packageJSON} ./package.json
        cp ${yarnLock} ./yarn.lock
        chmod u+w .

        runHook preBuild

        mkdir -p .yarn
        export HOME=$PWD/.yarn
        yarn config --offline set yarn-offline-mirror ${importOfflineCache yarnNix}
        yarn install ${lib.escapeShellArgs yarnFlags}

        runHook postBuild
      '';

      installPhase = ''
        rm -rf .yarn
        mv $PWD $out
        patchShebangs $out
      '';
    };
in
  { inherit yarn2nix mkYarnPackage; }
