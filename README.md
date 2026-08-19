<h1 align="center">
  <img src="https://images.weserv.nl/?url=https://raw.githubusercontent.com/Rok574/GestaltTweak/main/GestaltTweak/Assets.xcassets/AppIcon.appiconset/AppIcon.png&w=256&h=256&mask=ellipse" width="40" height="40" align="absmiddle" alt="GestaltTweak Icon">
  GestaltTweak
</h1>

<p align="center">
  <strong>Modify MobileGestalt On iOS 27 Dev Beta 1-4!</strong>
</p>

---

GestaltTweak is a native SwiftUI app for iOS that edits `com.apple.MobileGestalt.plist` directly on-device. By utilizing local sandbox escape methods (`bad_query` with a `cmg` fallback), you can toggle system features, customize device subtypes, and manage configuration backups without needing to be on computer.

## Features

- **Capability Toggles:** Quickly enable features like Dynamic Island, Always-On Display, boot chimes, and charge limits.
- **Device Identity:** Change your device subtype and model name on the fly.
- **Advanced Field Editor:** Search and modify raw MobileGestalt keys manually.
- **Backup & Restore:** Automatic backups before any changes, plus full restore management.
- **PosterBoard Support:** Import and apply custom wallpaper packs ("tendies").
- **Customization & Persistence:** Integrated respring tool, exploit method selection, and persistent toggle management.

---

> ⚠️ **Disclaimer & Warning**  
> GestaltTweak uses private APIs and modifies system cache files. Modifying incorrect keys can cause feature instability, UI glitches, or bootloops. Use this tool responsibly and at your own risk. Always ensure you have a backup saved.

---

## Compatibility

This app relies on specific kernel/sandbox vulnerabilities and supports **iOS / iPadOS 27 Developer Betas 1 through 4** only.

* **Supported Builds:** `24A5355q`, `24A5370h`, `24A5380h`, `24A5380i`, `24A5380l`, `24A5390f`

*Note: Running GestaltTweak on unsupported iOS versions will result in an "Unsupported OS Version" warning, and exploit execution will be blocked.*

---

## Troubleshooting

- **"Unsupported OS Version"**  
  Your device is running an iOS build outside the supported beta range listed above.
- **"Unable to Read MobileGestalt"**  
  The sandbox escape failed to initialize. Try restarting your device, reinstalling the application, or verifying your build version.
- **Tweaks Revert After a Reboot**  
  This is expected behavior. The MobileGestalt cache is rebuilt by iOS upon reboot. Re-apply your tweaks or enable the persist option in app settings.

---

## Credits & Acknowledgments

GestaltTweak is made possible thanks to the work of the following developers and projects:

- [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) – Primary sandbox escape method
- [frs0n/GestaltEdit](https://github.com/frs0n/GestaltEdit) – Project architecture inspiration (MIT)
- [rooootdev/mond](https://github.com/rooootdev/mond) – Implementations for PosterBoard feature
- [leminlimez/Nugget](https://github.com/leminlimez/Nugget) – MobileGestalt key mappings and iPadOS `CacheData` patch
- [rooootdev/neospring](https://github.com/rooootdev/neospring) – Respring implementation (neonmodder123 / skadz108)
- [SerStars/Nugget-Wallpapers](https://github.com/SerStars/Nugget-Wallpapers) – PosterBoard wallpaper catalog

---

## License

This project is licensed under the [MIT License](LICENSE).
