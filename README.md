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

## Credits

- [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) — the sandbox escape
- [frs0n/GestaltEdit](https://github.com/frs0n/GestaltEdit) — architecture, MIT
- [rooootdev/mond](https://github.com/rooootdev/mond) — tweak approaches
- [leminlimez/Nugget](https://github.com/leminlimez/Nugget) — MobileGestalt keys & iPadOS `CacheData` patch
- [rooootdev/neospring](https://github.com/rooootdev/neospring) — respring (neonmodder123 / skadz108)

## License

MIT, see [LICENSE](LICENSE).
