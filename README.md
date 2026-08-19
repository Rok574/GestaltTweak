# GestaltTweak

<p align="center">
  <img src="GestaltTweak/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" alt="GestaltTweak icon">
</p>

A native SwiftUI iPhone app that uses the **bad_query** sandbox escape
([forcequitOS/bad_query](https://github.com/forcequitOS/bad_query)) - or the
**cmg** container-manager method as a fallback - to edit
`com.apple.MobileGestalt.plist` **on your own device** - no Mac, no tethering.

It reads your live MobileGestalt file, lets you toggle capability tweaks
(Dynamic Island, Always-On Display, boot chime, charge limit, etc.), change
the device subtype / model name, edit any raw field, back up / restore, and
import PosterBoard wallpaper packs (tendies).

UI is a custom card-based home screen: a gradient hero header, a device status
card, and a grid of feature cards leading into the tweak lists, an Advanced
field editor, a Backups & Restore screen, a PosterBoard screen, and a Settings
sheet with the exploit method picker, **Persist after reboot** toggle,
respring tool, and credits.

> **WARNING - use at your own risk.**
> This uses private APIs and modifies a system cache file. Incorrect values can
> break system features, soft-brick the UI, or bootloop the device. Only use it
> on a device you own. A backup is always created before a write, and the
> Backups & Restore screen can bring the original file back.

## Supported versions

Only **iOS / iPadOS 27 developer beta 1 - 4** (builds `24A5355q`, `24A5370h`,
`24A5380h`, `24A5380i`, `24A5380l`, `24A5390f`). This is a hard limit of the
`bad_query` exploit - on any other version the app just shows "Unsupported OS
Version".

## Troublesooting

- **"Unsupported OS Version"** - your build isn't in the supported list above.
- **"Unable to read MobileGestalt"** - the sandbox escape didn't fire. Check
  the iOS version, reinstall, or ask the community (see credits).
- **Tweaks disappear after reboot** - expected; the cache is rebuilt at boot.
  This is normal for these tools.
- **Bundle id clash on install** - change `PRODUCT_BUNDLE_IDENTIFIER` in
  `GestaltTweak.xcodeproj/project.pbxproj` to something else and rebuild.

## Credits

- [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) - the sandbox escape
- [frs0n/GestaltEdit](https://github.com/frs0n/GestaltEdit) - architecture, MIT
- [rooootdev/mond](https://github.com/rooootdev/mond) - tweak approaches and PosterBoard (tendies) feature
- [leminlimez/Nugget](https://github.com/leminlimez/Nugget) - MobileGestalt keys & iPadOS `CacheData` patch
- [rooootdev/neospring](https://github.com/rooootdev/neospring) - respring (neonmodder123 / skadz108)
- [SerStars/Nugget-Wallpapers](https://github.com/SerStars/Nugget-Wallpapers) - tendies wallpaper catalog

## License

MIT, see [LICENSE](LICENSE).
