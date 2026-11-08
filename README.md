# Live Lyrics

Live synchronized lyrics in the Omarchy bar: the current line arrives
character by character while it is sung, and switches to a word-by-word karaoke
hand-off when the source carries word timings. The album cover sits to its left;
a click on the line opens a small player card with transport and an opacity
setting.

A port of the angelOS lyrics bar and engine by
[MixaDoDs](https://github.com/MixaDoDs/AngelOS-Dotfiles) (MIT) to the Omarchy
shell plugin system. See [`THIRD-PARTY.md`](THIRD-PARTY.md) for what was ported,
what was changed, and what is not bundled.

## What it does

- **Synced lines in the bar** — the current line, as wide as it needs (up to a
  configurable maximum) and rising into place on every line change. A line that
  still does not fit glides sideways instead of being cut off.
- **Word-by-word karaoke** — with sources that carry word timings the settled
  part of the line stays put and each new word hops in.
- **Beat grid** — word timings are aligned to the track's own beats, detected
  from the player's audio stream.
- **Loudness glow** — the line breathes with the music's level.
- **Album cover** — the current track's art, or a note glyph when the player
  publishes none.
- **Player card** — click the line: cover, title, artist, previous / play-pause /
  next, and an opacity slider with live preview while you drag.

## Requirements

- Omarchy (the `quickshell` shell with the plugin system in `omarchy plugin`).
- An MPRIS-capable player (any browser tab playing YouTube Music counts).
- Network access to `lrclib.net` for fetching lyrics.
- Optional: `python3` + `python-numpy` for the beat grid, and `cava`,
  `pw-record`, `pw-dump`, `pactl` for the loudness glow, plus `curl` for remote
  cover art. Without them the plugin still shows synced lyrics line by line.
  See [`THIRD-PARTY.md`](THIRD-PARTY.md#runtime-dependencies-not-bundled).

On Arch the optional pieces come from the `extra` repository: `python-numpy`,
`cava`, `pipewire` and `curl`. Install them with your usual package manager —
the plugin never runs package management itself.

## Install

```bash
omarchy plugin add https://github.com/ilyamaximusaws/omarchy-live-lyrics.git --enable
```

Then place the widget: `omarchy plugin enable angelos.lyrics center` (or move it
in the bar settings). Nothing else to configure — with lyrics available for the
current track the line appears on its own.

## Remove

```bash
omarchy plugin remove angelos.lyrics
```

To keep the plugin but hide the line, disable it:

```bash
omarchy plugin disable angelos.lyrics
```

## Settings

Set through the shell's plugin settings (they live in your
`~/.config/omarchy/shell.json` entry for this widget):

| Key | Default | What it does |
|---|---|---|
| `byWord` | `true` | word-by-word karaoke when the source has word timings |
| `onBeat` | `true` | align word timings to the track's beat grid |
| `glow` | `level` | `level` — the line breathes with the music; `off` — steady |
| `artwork` | `cover` | `cover` — the album art; `note` — the note glyph |
| `opacity` | `100` | how solid the line sits in the bar, 20–100 |
| `maxWidth` | `500` | widest a line may get before it glides |
| `preferPlayer` | — | substring of the player to prefer when several are running |

`opacity` also has a slider in the player card (the gear in its transport row);
the drag previews live and only the release is saved.

## Click actions on the line

- **Left click** — open or close the player card.
- **Middle click** — play/pause without opening anything.
- **Right click** — cycle the glow off and back to level.

## Development

The plugin lives in `~/.config/omarchy/plugins/<id>`. This repository *is* the
plugin directory, so a checkout can be symlinked or copied in place.

The engine and the widget are covered by a test harness that runs its own
`quickshell` against real LRC text, a real lrclib reply and real text
measurement:

```bash
mkdir -p /tmp/qsimp/qs
cp -r /usr/share/omarchy/shell/Commons /usr/share/omarchy/shell/Ui /tmp/qsimp/qs/
QML_IMPORT_PATH=/tmp/qsimp:/usr/lib/qt6/qml quickshell -p tests
```

Every line it prints starts with `PORTTEST`; `... | grep PORTTEST` shows the
assertions and a final `PORTTEST SUMMARY <passed>/<total>`. See
[`tests/README.md`](tests/README.md) for what each section drives.

Validate the manifest before publishing:

```bash
omarchy plugin validate .
```

## License

MIT, © 2026 MixaDoDs (the original angelOS lyrics bar and engine) and
© 2026 Iliya Brook (the Omarchy port). Full text in [`LICENSE`](LICENSE).
