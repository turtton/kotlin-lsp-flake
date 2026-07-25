{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  alsa-lib,
  freetype,
  libgcc,
  libx11,
  libxi,
  libxrender,
  libxtst,
  wayland,
  zlib,
  extraBinNames ? [ ],
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  platform = versionData.sources.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "kotlin-lsp";
  inherit version;

  src = fetchurl {
    url = "https://download-cdn.jetbrains.com/kotlin-lsp/${version}/kotlin-lsp-${version}-${platform.suffix}.zip";
    hash = platform.hash;
  };

  nativeBuildInputs = [
    unzip
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    alsa-lib
    freetype
    libgcc.lib
    libx11
    libxi
    libxrender
    libxtst
    wayland
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    unzip $src -d unpacked
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/kotlin-lsp $out/bin
    cp -r unpacked/. $out/lib/kotlin-lsp/

    chmod +x $out/lib/kotlin-lsp/kotlin-lsp.sh
  '' + (if stdenv.hostPlatform.isDarwin then ''
    find $out/lib/kotlin-lsp/jre/Contents/Home/bin -type f -exec chmod +x {} +
  '' else ''
    find $out/lib/kotlin-lsp/jre/bin -type f -exec chmod +x {} +
  '') + ''

    ln -s $out/lib/kotlin-lsp/kotlin-lsp.sh $out/bin/kotlin-lsp

    ${lib.concatMapStringsSep "\n" (name: ''
      ln -s $out/lib/kotlin-lsp/kotlin-lsp.sh "$out/bin"/${lib.escapeShellArg name}
    '') extraBinNames}

    runHook postInstall
  '';

  postInstall = ''
    substituteInPlace $out/lib/kotlin-lsp/kotlin-lsp.sh \
      --replace-fail 'chmod' '# chmod'
  '';

  meta = with lib; {
    description = "Kotlin Language Server by JetBrains";
    homepage = "https://github.com/Kotlin/kotlin-lsp";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ binaryBytecode binaryNativeCode ];
    platforms = builtins.attrNames versionData.sources;
    mainProgram = "kotlin-lsp";
  };
}
