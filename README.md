# OneLauncher-nix

Nix flake for [OneClient](https://polyfrost.org/projects/oneclient), the Minecraft launcher from Polyfrost's
[OneLauncher](https://github.com/Polyfrost/OneLauncher) monorepo. Built from source for x86_64-linux.

This flake is unofficial and not affiliated with Polyfrost. Report problems with the package here, not upstream.
I maintain it for my own machines. It may lag behind releases or stop being updated, and there is no support guarantee.

The packaging was written by AI.

## Usage

Run it once:

```sh
nix run github:<owner>/OneLauncher-nix
```

Install on NixOS through the overlay:

```nix
{
  inputs.oneclient.url = "github:<owner>/OneLauncher-nix";
  inputs.oneclient.inputs.nixpkgs.follows = "nixpkgs";

  # in a module
  nixpkgs.overlays = [ inputs.oneclient.overlays.default ];
  environment.systemPackages = [ pkgs.oneclient ];
}
```

## What the wrapper does

- Puts JDK 25, 21, 17 and 8 from nixpkgs on `PATH`, where OneClient's Java scan finds them.
  The JDKs it would download itself do not run on NixOS, so `ONECLIENT_DISABLE_JAVA_AUTOINSTALL=1` is set.
  If you download one anyway, it needs `programs.nix-ld.enable`; the wrapper supplies the X libraries AWT loads.
- Puts the libraries Minecraft and LWJGL load (OpenAL, PulseAudio, GLFW, X11, Wayland, udev, Vulkan)
  on `LD_LIBRARY_PATH`, plus `xrandr` and `lspci` on `PATH`. This is the same set nixpkgs' prismlauncher uses.
- Sets `ONECLIENT_LAUNCHER_EXE` to the wrapper, so the `oneclient://` handler and instance shortcuts
  that OneClient writes to `~/.local/share/applications` keep this environment.
  Shortcuts point at a store path, so recreate them after an upgrade and garbage collection.
- Sets `ONECLIENT_DISABLE_AUTOUPDATE=1`. The app still shows a toast when a new release exists.
- Builds with an empty Sentry DSN, which turns off crash reporting.

Pick different JDKs:

```nix
pkgs.oneclient.override { jdks = [ pkgs.jdk21 pkgs.jdk25 ]; }
```

## Updating

The `update` workflow runs nix-update weekly and opens a PR. By hand:

```sh
nix run nixpkgs#nix-update -- --flake oneclient --version-regex 'oneclient-(.*)'
```

nix-update bumps `src` and `cargoHash` only. Skia comes as a prebuilt tarball that
`freya-skia-bindings` would otherwise download during the build. When a bump changes that crate,
the build fails in its build script. To fix it:

1. Run `nix build -L` and find the line `TRYING TO DOWNLOAD AND INSTALL SKIA BINARIES: <tag>/<key>`.
2. Set `skiaTag` and `skiaKey` in `package.nix` to those values.
3. Set the hash from `nix store prefetch-file https://github.com/marc2332/rust-skia/releases/download/<tag>/skia-binaries-<key>.tar.gz`.

Upstream dropped GTK and libappindicator after 2.9.0. Once a release no longer has `gtk-sys` in its
`Cargo.lock`, remove `gtk3` and `libayatana-appindicator` from `package.nix`.
