{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  pkg-config,
  makeWrapper,
  addDriverRunpath,
  fontconfig,
  freetype,
  gtk3,
  libayatana-appindicator,
  libGL,
  libxkbcommon,
  wayland,
  libdecor,
  vulkan-loader,
  libx11,
  libxcursor,
  libxext,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libxxf86vm,
  glfw3-minecraft,
  openal,
  alsa-lib,
  libjack2,
  libpulseaudio,
  pipewire,
  udev,
  flite,
  pciutils,
  xrandr,
  jdk8,
  jdk17,
  jdk21,
  jdk25,
  jdks ? [
    jdk25
    jdk21
    jdk17
    jdk8
  ],
}:

let
  # Libraries winit and Skia dlopen for the launcher window itself.
  appLibs = [
    libGL
    libxkbcommon
    wayland
    vulkan-loader
    libx11
    libxcursor
    libxi
    libxrandr
    # 2.9.0's tray icon dlopens this.
    libayatana-appindicator
  ];

  # Same set nixpkgs' prismlauncher puts on LD_LIBRARY_PATH for the game.
  gameLibs = [
    (lib.getLib stdenv.cc.cc)
    glfw3-minecraft
    openal
    alsa-lib
    libjack2
    libpulseaudio
    pipewire
    libGL
    libx11
    libxcursor
    libxext
    libxrandr
    libxxf86vm
    # AWT in JDKs the launcher downloads (Nix JDKs carry their own rpath).
    libxi
    libxrender
    libxtst
    wayland
    libdecor
    libxkbcommon
    udev
    vulkan-loader
    flite
  ];

  # freya-skia-bindings downloads this at build time. The tag is the bindings
  # crate version in Cargo.lock; the key is printed by its build script as
  # "TRYING TO DOWNLOAD AND INSTALL SKIA BINARIES: <tag>/<key>".
  skiaTag = "0.103.2";
  skiaKey = "54a7d172bc995dfdc3e7-x86_64-unknown-linux-gnu-egl-ganesh-gl-jpegd-jpege-svg-textlayout-vulkan-wayland-webpd-webpe-x11";
  skiaBinaries = fetchurl {
    url = "https://github.com/marc2332/rust-skia/releases/download/${skiaTag}/skia-binaries-${skiaKey}.tar.gz";
    hash = "sha256-8HifMlB8eKptId0L9UFpsw8AD0rlVtBGXwu2KxY604U=";
  };

  gamePrograms = [
    pciutils
    xrandr
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "oneclient";
  version = "2.9.0";

  src = fetchFromGitHub {
    owner = "Polyfrost";
    repo = "OneLauncher";
    tag = "oneclient-${finalAttrs.version}";
    hash = "sha256-pIAnp5D4zQz2+JvdS9Bd3x+0TL5iTtH17u60QRL2BUE=";
  };

  cargoHash = "sha256-Tuk7g/6Ip++LZRgWWnhXIWvby6NRPgvbXqEohTO8h2k=";

  cargoBuildFlags = [
    "-p"
    "oneclient_app"
  ];

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    fontconfig
    freetype
    gtk3
  ]
  ++ appLibs;

  env = {
    SQLX_OFFLINE = "true";
    # An empty DSN leaves the Sentry client disabled.
    ONECLIENT_SENTRY_DSN = "";
    SKIA_BINARIES_URL = "file://${skiaBinaries}";
  };

  # Tests need a display and network access.
  doCheck = false;

  postInstall = ''
    app=packages/oneclient_app

    install -Dm644 $app/icons/32x32.png $out/share/icons/hicolor/32x32/apps/oneclient_app.png
    install -Dm644 $app/icons/64x64.png $out/share/icons/hicolor/64x64/apps/oneclient_app.png
    install -Dm644 $app/icons/128x128.png $out/share/icons/hicolor/128x128/apps/oneclient_app.png
    install -Dm644 $app/icons/128x128@2x.png $out/share/icons/hicolor/256x256/apps/oneclient_app.png
    install -Dm644 $app/icons/512x512.png $out/share/icons/hicolor/512x512/apps/oneclient_app.png

    mkdir -p $out/share/applications
    sed -e 's|{{exec}}|oneclient %u|' \
        -e 's|{{icon}}|oneclient_app|' \
        -e 's|^StartupWMClass=.*|StartupWMClass=oneclient_app|' \
        $app/distribution/linux/org.polyfrost.oneclient.template \
        > $out/share/applications/org.polyfrost.OneClient.desktop
    echo 'MimeType=x-scheme-handler/oneclient;' >> $out/share/applications/org.polyfrost.OneClient.desktop
  '';

  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath appLibs} $out/bin/oneclient_app

    wrapProgram $out/bin/oneclient_app \
      --prefix PATH : ${lib.makeBinPath (jdks ++ gamePrograms)} \
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib:${lib.makeLibraryPath gameLibs} \
      --set ONECLIENT_LAUNCHER_EXE $out/bin/oneclient \
      --set ONECLIENT_DISABLE_JAVA_AUTOINSTALL 1 \
      --set ONECLIENT_DISABLE_AUTOUPDATE 1

    ln -s oneclient_app $out/bin/oneclient
  '';

  passthru.updateScript = [
    "nix-update"
    "--flake"
    "oneclient"
    "--version-regex"
    "oneclient-(.*)"
  ];

  meta = {
    description = "Open source Minecraft launcher by Polyfrost";
    homepage = "https://polyfrost.org/projects/oneclient";
    changelog = "https://github.com/Polyfrost/OneLauncher/blob/oneclient-${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.gpl3Only;
    mainProgram = "oneclient";
    platforms = [ "x86_64-linux" ];
  };
})
