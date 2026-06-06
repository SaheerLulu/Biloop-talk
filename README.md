# Biloop Talk — Desktop build

Build infrastructure for **Biloop Talk**, a branded build of the
**[Nextcloud Talk Desktop](https://github.com/nextcloud/talk-desktop)**
client (the Electron desktop app for Nextcloud Talk), producing installers for
**Windows** and **macOS**.

The upstream source is **not vendored** into this repo. Instead it is checked
out and built on demand on a runner/machine that matches the target OS, because:

- **macOS** installers (`.dmg`) can only be produced on macOS — they need Apple
  tooling (`hdiutil`, `iconutil`, `codesign`) that does not exist on Linux/Windows.
- **Windows** installers (Squirrel `Setup.exe`) build natively on Windows.

Upstream uses **electron-forge**, so builds run in two steps per platform:
`build:<platform>` (electron-forge *package*) then `package:<platform>`
(electron-forge *make*). Installers land in `upstream/out/make/`.

## Build via GitHub Actions (recommended)

The workflow [`.github/workflows/build-desktop.yml`](.github/workflows/build-desktop.yml)
builds both platforms on GitHub-hosted runners (`windows-latest`,
`macos-latest`), which have full internet access and the native toolchains.

How to run it:

1. Go to the repo's **Actions** tab → **Build Talk Desktop (Windows & macOS)**.
2. Click **Run workflow**. Optionally choose:
   - **ref** — upstream branch/tag of `nextcloud/talk-desktop` (blank = default
     branch, `main`).
   - **platforms** — `windows,macos`, `windows`, or `macos`.
3. When the run finishes, download the installers from the run's **Artifacts**:
   - `biloop-talk-windows` → Windows `Setup.exe`
   - `biloop-talk-macos` → macOS `.dmg`

The workflow also runs automatically when the build scripts, the workflow, or
the `branding/` assets change on the `claude/nextcloud-talk-desktop-app-T3xzi`
branch.

> Builds are **unsigned** by default. Unsigned apps show Gatekeeper /
> SmartScreen warnings on first launch. To ship signed builds, add your signing
> certificates as repository secrets and configure electron-forge signing
> (`packagerConfig.osxSign` / `osxNotarize`, and a Windows signing cert). See
> the [electron-forge code signing guide](https://www.electronforge.io/guides/code-signing).

## Build locally

Run on a machine that matches the OS you want to build for:

```bash
# macOS .dmg   (run on a Mac)
scripts/build.sh mac

# Windows Setup.exe (run on Windows, e.g. via Git Bash)
scripts/build.sh win

# Linux (run on Linux)
scripts/build.sh linux
```

The script will:

1. Clone `nextcloud/talk-desktop` into `./upstream` (override with
   `TALK_DESKTOP_REPO` / `TALK_DESKTOP_REF`; reuses an existing checkout).
2. Apply Biloop branding (set `APPLY_BRANDING=0` to skip).
3. Install dependencies (`npm ci`).
4. Provision the built-in **Nextcloud Talk frontend (`spreed`)**: clone it at
   the version pinned in `package.json` → `talk.<channel>` (default channel
   `stable`) and install its dependencies. Override with `TALK_PATH` (reuse an
   existing checkout), `TALK_VERSION`, or `CHANNEL`.
5. Run `npm run build:<platform>` then `npm run package:<platform>`.
6. Print where the installers were written (`upstream/out/make/`).

### Requirements

- **Node.js 22+** and npm, and Git.
- For **macOS** builds: a Mac with the Xcode command line tools.
- For **Windows** builds: a Windows machine.

## Biloop branding

The build is rebranded as **Biloop Talk** automatically via
[`scripts/apply-branding.sh`](scripts/apply-branding.sh) (called by `build.sh`;
set `APPLY_BRANDING=0` to build vanilla upstream). It uses Talk Desktop's
**first-class branding mechanism**: a `.overrides/build.config.json` file is
written into the checkout, which the upstream `build/resolveBuildConfig.js`
merges over its defaults and flips `BUILD_CONFIG.isBranded` to `true`.

What gets rebranded:

- **App name** (window title, login/help screens, About, user-agent) → `Biloop Talk`
- **Brand colors** → primary `#6C2BD9`, matching gradient and font color
- **`isBranded` behavior** → hides the upstream Nextcloud homepage / issues /
  source links and disables the GitHub release update-checker
- **App icon** → `img/icons/icon.{ico,icns,png}` used by electron-forge for the
  Windows `.ico`, the macOS `.icns` (generated from the PNG via `iconutil` on
  the macOS runner) and the app/tray icons
- **Metadata** → `productName`, description, author (`info@biloop.ai`),
  homepage (`https://biloop.ai`)

Branding assets:

| File | Purpose |
| --- | --- |
| `branding/branding.json` | Name, colors and metadata (single source of truth) |
| `branding/icon.png` | 1024×1024 master icon |
| `branding/icon.ico` | Multi-size Windows icon |
| `branding/icon.svg` | Editable vector source |
| `branding/icon-*.png` | Pre-rendered sizes (convenience) |
| `scripts/gen-icon.py` | Regenerates the PNG/ICO from code (`pip install pillow`) |

> The current logo is a **placeholder** (purple `#6C2BD9` "B" mark). To use the
> real Biloop logo, drop your own `icon.png` (1024×1024) and `icon.ico` into
> `branding/` — or edit `icon.svg` and run `python scripts/gen-icon.py` — then
> rebuild. Update names/colors in `branding/branding.json`.

## Android (Biloop Talk for Android)

Builds the **[Nextcloud Talk Android](https://github.com/nextcloud/talk-android)**
client, rebranded as **Biloop Talk**, into an installable **APK**.

- Workflow: [`.github/workflows/build-android.yml`](.github/workflows/build-android.yml)
  builds on `ubuntu-latest` (JDK 17), runs `./gradlew assembleGenericDebug`
  (the F-Droid "generic" flavor, no Google services — debug-signed so it can be
  sideloaded), and publishes the APK to the **`android-latest`** Release.
- Build script: [`scripts/build-android.sh`](scripts/build-android.sh).
- Branding: [`scripts/apply-branding-android.sh`](scripts/apply-branding-android.sh)
  sets the app name to **Biloop Talk** (`res/values/setup.xml`) and replaces the
  launcher icon (purple `#6C2BD9` background vector + white "B" foreground +
  legacy mipmaps). Icon assets live in `branding/android/` and are regenerated
  by [`scripts/gen-android-icons.py`](scripts/gen-android-icons.py).

Run it from the **Actions** tab → **Build Talk Android (APK)** → **Run
workflow**, then download `Biloop.Talk-android.apk` from the
[`android-latest` release](../../releases/tag/android-latest). On the device,
enable "Install unknown apps" to sideload.

> The APK is **debug-signed** and keeps the upstream `applicationId`
> (`com.nextcloud.talk2`). For a Play-style release build, add a signing
> keystore as secrets and switch the task to `assembleGenericRelease`.

## Notes on this environment

These build steps deliberately run on CI/native machines rather than inside the
Claude Code sandbox, because the sandbox runs Linux (cannot produce macOS apps)
and its network policy blocks cloning `github.com` source directly. The GitHub
Actions runners do not have those restrictions, so the build succeeds there.
