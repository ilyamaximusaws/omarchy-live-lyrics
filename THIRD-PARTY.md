# Third-party parts

This plugin is a port. Its lyrics bar, the lyrics engine, the beat grid, the
loudness glow and the helper scripts come from **angelOS** by MixaDoDs, under
the MIT license. The port to the Omarchy shell plugin system — the manifest, the
bar widget, the service entry point, the MPRIS player popup and the inline
settings — is Iliya Brook's.

Both are covered by MIT; the full text with both copyright lines is in
[`LICENSE`](LICENSE).

| What | Where | License | Source |
|---|---|---|---|
| The lyrics bar, the lyrics engine, the beat grid, the loudness glow, the helper scripts (ported) | `LyricsBarWidget.qml`, `Service.qml`, `lib/`, `scripts/` | MIT, © 2026 MixaDoDs | [MixaDoDs/AngelOS-Dotfiles](https://github.com/MixaDoDs/AngelOS-Dotfiles) |
| The Omarchy port: manifest, widget wiring, player popup, inline settings | the same files | MIT, © 2026 Iliya Brook | [ilyamaximusaws/omarchy-live-lyrics](https://github.com/ilyamaximusaws/omarchy-live-lyrics) |

## What was changed in the port

- The engine's settings bag and paths were rewired to the Omarchy shell's
  plugin host (`qs.Commons`, `qs.Ui`, the shell's `shell.json` settings).
- The bar item became an Omarchy `BarWidget`; the angelOS halo/panel surfaces,
  fonts and themes were not ported.
- The player popup (cover, title, transport, opacity setting) was added here.

## What this plugin does not ship

No fonts, no icons, no wallpapers, no sounds and no artwork are bundled. The
album cover comes from the running MPRIS player at runtime. Anything angelOS
lists as third-party (its SDDM theme, its fonts, its icon sets, LazyVim,
Spicetify, the wallpapers of unknown origin) is **not** part of this plugin and
its licenses do not apply here.

## Runtime dependencies (not bundled)

| Dependency | Needed for | Note |
|---|---|---|
| `quickshell` | everything | the shell this plugin runs in |
| `curl` | album covers, QQ Music sources | fetches remote art into `~/.cache/omarchy/angelos.lyrics/art/` |
| `python3` | beat grid, loudness glow | runs the helper scripts in `scripts/` |
| `python-numpy` | beat grid (`osu-beats.py`) | imported unconditionally by that script; without it the beat grid stays off |
| `cava`, `pw-record`, `pw-dump`, `pactl` | loudness glow | reads the player's own stream; without PipeWire tools the glow stays off |
| network access to `lrclib.net` | fetching lyrics | the primary source; the other sources are optional |

Without the optional dependencies the plugin still shows synced lyrics line by
line — the beat grid and the loudness glow are the parts that degrade.
