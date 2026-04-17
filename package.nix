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
}:

let
  version = "262.2310.0";

  platforms = {
    "x86_64-linux" = {
      suffix = "linux-x64";
      hash = "sha256:c004242158f4b5e1d917ddd848e6f6a279484fa58a3e2bce8846b807d1ad16b1";
    };
    "aarch64-linux" = {
      suffix = "linux-aarch64";
      hash = "sha256:1f8c814dfa9d64a9fba32b83a6fa0279cbc48e7240ef0ce922c7db2f39f0d35c";
    };
    "x86_64-darwin" = {
      suffix = "mac-x64";
      hash = "sha256:a4ccf591664cfef6a12f21a690d23bad26b92de62ed34674491b915f25f95bf5";
    };
    "aarch64-darwin" = {
      suffix = "mac-aarch64";
      hash = "sha256:11560eb4ecd766204363848cc5ee84b51c0fd03fbfd4bbedaba0f00af74309c7";
    };
  };

  platform = platforms.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
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
    cp -r unpacked/* $out/lib/kotlin-lsp/

    chmod +x $out/lib/kotlin-lsp/kotlin-lsp.sh
  '' + (if stdenv.hostPlatform.isDarwin then ''
    chmod +x $out/lib/kotlin-lsp/jre/Contents/Home/bin/java
  '' else ''
    chmod +x $out/lib/kotlin-lsp/jre/bin/java
  '') + ''

    ln -s $out/lib/kotlin-lsp/kotlin-lsp.sh $out/bin/kotlin-lsp

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
    platforms = builtins.attrNames platforms;
    mainProgram = "kotlin-lsp";
  };
}
