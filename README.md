# GestaltTweak

A native SwiftUI iPhone app that uses the **bad_query** sandbox escape
([forcequitOS/bad_query](https://github.com/forcequitOS/bad_query)) to edit
`com.apple.MobileGestalt.plist` **on your own device** — no Mac, no tethering.

It reads your live MobileGestalt file, lets you toggle capability tweaks
(Dynamic Island, Always-On Display, boot chime, charge limit, etc.), change
the device subtype / model name, edit any raw field, and back up / restore.

> **WARNING — use at your own risk.**
> This uses private APIs and modifies a system cache file. Incorrect values can
> break system features, soft-brick the UI, or bootloop the device. Only use it
> on a device you own. A backup is always created before a write, and the
> Restore tab can bring the original file back.

## Supported versions

Only **iOS / iPadOS 27 developer beta 1 – 4** (builds `24A5355q`, `24A5370h`,
`24A5380h`, `24A5380i`, `24A5380l`, `24A5390f`). This is a hard limit of the
`bad_query` exploit — on any other version the app just shows "Unsupported OS
Version".

## How to get the IPA (no Mac required)

You build it for free in the cloud with GitHub Actions. There is no local
compiling needed.

### 1. Put the project on GitHub

The folder you have contains a ready-made Xcode project
(`GestaltTweak.xcodeproj`) plus a workflow in `.github/workflows/build-ipa.yml`.

Push it to a **public or private GitHub repo**. No git installed? Either:

- Install [Git for Windows](https://git-scm.com/download/win) and run:
  ```
  git init
  git add .
  git commit -m "GestaltTweak"
  git branch -M main
  git remote add origin https://github.com/YOURNAME/gestalttweak.git
  git push -u origin main
  ```
- or drag-and-drop the whole folder into a new repo using GitHub's **web
  upload** at https://github.com/new (make sure `.github/workflows` is included).

### 2. Let GitHub Actions build it

Pushing to `main` triggers the `build ipa` workflow automatically. You can also
run it manually: repo → **Actions** → **build ipa** → **Run workflow**.

Wait ~5 minutes for the macOS runner to finish.

### 3. Download the IPA

Open the green run, scroll to **Artifacts**, and download
`GestaltTweak-ipa`. It contains `GestaltTweak.ipa`.

### 4. Sign and install with iLoader (Windows)

1. Download [iLoader](https://github.com/nab138/iloader/releases) (Windows
   build) or from https://iloader.app/.
2. Connect your iPhone with a cable. Enable **Developer Mode** on the device
   (Settings → Privacy & Security → Developer Mode) if prompted.
3. Open iLoader, sign in with your **free Apple ID** (used only for local code
   signing).
4. Import `GestaltTweak.ipa`, let it sign and install.
5. On the phone: Settings → General → VPN & Device Management → trust your
   developer certificate.

### 5. Run it

Open GestaltTweak. If your iOS is supported it connects automatically (you'll
see "Connected"), then:

- **Tools** tab — toggle tweaks / Dynamic Island subtype / model name, then
  tap **Apply**. The app backs up first, writes, verifies, and resprings.
- **Fields** tab — inspect or edit any key in `CacheExtra` or top level.
- **Restore** tab — export, import, restore, or delete backups.

Some tweaks need a full reboot to take effect; the app tells you which.

## Troubleshooting

- **"Unsupported OS Version"** — your build isn't in the supported list above.
- **"Unable to read MobileGestalt"** — the sandbox escape didn't fire. Check
  the iOS version, reinstall, or ask the community (see credits).
- **Tweaks disappear after reboot** — expected; the cache is rebuilt at boot.
  This is normal for these tools.
- **Bundle id clash on install** — change `PRODUCT_BUNDLE_IDENTIFIER` in
  `GestaltTweak.xcodeproj/project.pbxproj` to something else and rebuild.

## Project layout

```
GestaltTweak/
  BadQueryBridge.h/.m     bad_query integration (class 13, MobileGestalt
                          SystemGroup, path traversal) — derived from
                          forcequitOS/bad_query
  GestaltAccess.h/.m      connect / read / write / verify the plist
  GestaltModels.swift     plist model + value editor helpers
  GestaltTweaks.swift     tweak catalog (keys from Nugget)
  GestaltViewModel.swift  app state
  GestaltBackupStore.swift backups
  NeoSpringView.swift     WebKit respring (neospring)
  ContentView.swift       UI
GestaltTweak.xcodeproj    Xcode project (build config mirroring GestaltEdit)
.github/workflows/        builds the unsigned IPA on GitHub macOS runners
```

## Credits

- [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) — the sandbox escape
- [frs0n/GestaltEdit](https://github.com/frs0n/GestaltEdit) — architecture, MIT
- [rooootdev/mond](https://github.com/rooootdev/mond) — tweak approaches
- [leminlimez/Nugget](https://github.com/leminlimez/Nugget) — MobileGestalt keys & iPadOS `CacheData` patch
- [rooootdev/neospring](https://github.com/rooootdev/neospring) — respring (neonmodder123 / skadz108)

## License

MIT, see [LICENSE](LICENSE).