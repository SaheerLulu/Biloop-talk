# Biloop Talk — Desktop build

Build infrastructure for the **[Nextcloud Talk Desktop](https://github.com/nextcloud/talk_desktop)**
client (the Electron-based desktop app for Nextcloud Talk), producing
installers for **Windows** and **macOS**.

The upstream source is **not vendored** into this repo. Instead it is cloned
and built on demand on a machine/runner that matches the target OS. This is the
same model the upstream project uses, and it is required because:

- **macOS** installers (`.dmg`) can only be produced on macOS — they need
  `hdiutil` / `codesign`, which do not exist on Linux or Windows.
- **Windows** installers (`.exe`, NSIS) build natively on Windows without Wine.

## Build via GitHub Actions (recommended)

The workflow [`.github/workflows/build-desktop.yml`](.github/workflows/build-desktop.yml)
builds both platforms on GitHub-hosted runners (`windows-latest`,
`macos-latest`), which have full internet access and the native toolchains.

How to run it:

1. Go to the repo's **Actions** tab → **Build Talk Desktop (Windows & macOS)**.
2. Click **Run workflow**. Optionally choose:
   - **ref** — the upstream branch or tag of `nextcloud/talk_desktop` to build
     (default `main`).
   - **platforms** — `windows,macos`, `windows`, or `macos`.
3. When the run finishes, download the installers from the run's **Artifacts**:
   - `talk-desktop-windows` → `.exe`
   - `talk-desktop-macos` → `.dmg`

The workflow also runs automatically when the build script or the workflow
itself changes on the `claude/nextcloud-talk-desktop-app-T3xzi` branch.

> Builds are **unsigned** by default (`CSC_IDENTITY_AUTO_DISCOVERY=false`).
> Unsigned apps will show Gatekeeper / SmartScreen warnings on first launch.
> To ship signed builds, add your signing certificates as repository secrets
> and wire them into the build step (see comments in the workflow and the
> [electron-builder code signing docs](https://www.electron.build/code-signing)).

## Build locally

Run on a machine that matches the OS you want to build for:

```bash
# macOS .dmg   (run on a Mac)
scripts/build.sh mac

# Windows .exe (run on Windows, e.g. via Git Bash)
scripts/build.sh win

# Linux AppImage/deb (run on Linux)
scripts/build.sh linux
```

The script will:

1. Clone `nextcloud/talk_desktop` into `./upstream` (override with
   `TALK_DESKTOP_REPO` / `TALK_DESKTOP_REF`).
2. Install dependencies (`npm ci`).
3. Run upstream's `package:<platform>` script, falling back to
   `npm run build` + `electron-builder`.
4. Print where the resulting installers were written (`upstream/dist/` by
   default).

### Requirements

- **Node.js 22+** and npm.
- Git.
- For **macOS** builds: a Mac with Xcode command line tools.
- For **Windows** builds: a Windows machine (native NSIS build, no Wine needed).

## Notes on this environment

These build steps deliberately run on CI/native machines rather than inside the
Claude Code sandbox, because the sandbox runs Linux (cannot produce macOS apps)
and its network policy blocks cloning `github.com` source directly. The GitHub
Actions runners do not have those restrictions, so the build succeeds there.
