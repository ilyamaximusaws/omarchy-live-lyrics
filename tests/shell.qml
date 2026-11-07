import QtQuick
import Quickshell

// The ported engine and the bar widget, exercised against real LRC text, a real
// lrclib reply and real text measurement.
//
// Run it on its own quickshell so the running shell's cache and state are not in
// the picture:
//
//   QML_IMPORT_PATH=/tmp/qsimp:/usr/lib/qt6/qml \
//     quickshell -p ~/.config/omarchy/plugins/angelos.lyrics/tests
//
// where /tmp/qsimp holds the shell's own modules (qs.Commons, qs.Ui) copied out
// of /usr/share/omarchy/shell. Every line it prints starts with PORTTEST, so
// `... | grep PORTTEST | grep -c PASS` is the pass count.
//
// The summary prints from a timer (6 s), not from the last assertion: the glide
// assertions need real animation time, and the network ones are asynchronous.
ShellRoot {
    id: root

    // the plugin directory, whether or not the config is passed in place
    readonly property string home: Quickshell.env("HOME")
    readonly property string plugin: home + "/.config/omarchy/plugins/angelos.lyrics"

    property int passed: 0
    property int total: 0
    function ok(name, cond, detail) {
        total++
        if (cond)
            passed++
        console.log("PORTTEST " + (cond ? "PASS" : "FAIL") + "  " + name + (detail ? "  — " + detail : ""))
    }
    function done() {
        console.log("PORTTEST SUMMARY " + passed + "/" + total)
        Qt.callLater(Qt.quit)
    }

    Timer {
        interval: 6000
        running: true
        onTriggered: root.done()
    }

    Loader {
        id: engine
        source: root.plugin + "/lib/Lyrics.qml"
        asynchronous: false
        onLoaded: root.testEngine(item)
        onStatusChanged: if (status === Loader.Error) {
            console.log("PORTTEST FAIL  engine did not load")
            Qt.callLater(Qt.quit)
        }
    }

    Loader {
        id: widget
        source: root.plugin + "/LyricsBarWidget.qml"
        asynchronous: false
        onLoaded: root.testWidget(item)
        onStatusChanged: if (status === Loader.Error && !widgetError) {
            widgetError = true
            console.log("PORTTEST FAIL  bar widget did not load")
        }
    }
    property bool widgetError: false
    // a stand-in bar whose shell records what the real one would write to
    // shell.json (the harness loads the widget with no bar at all)
    Item {
        id: fakeBar
        property color foreground: "#ffffff"
        property color barForeground: "#ffffff"
        property color background: "#000000"
        property real barSize: 30
        property var writes: []
        property QtObject shell: QtObject {
            function updateEntryInline(id, entry) {
                fakeBar.writes.push({ "id": id, "entry": entry })
            }
        }
    }
    // an 8x8 PNG, embedded so the test needs no files on disk
    readonly property string artData: "data:image/png;base64," + "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGM4YROFFTEMLQkATEZXgWfmY7oAAAAASUVORK5CYII="

    // ---------------------------------------------------------------- engine
    function testEngine(lyr) {
        // ---- parsing ----
        var p = lyr.parseLrc("[00:12.34]Первый раз\n[00:15.00]Второй раз\n[00:18.50]Третий раз\n")
        ok("parseLrc count", p.length === 3, "n=" + p.length)
        ok("parseLrc time", p.length > 0 && Math.abs(p[0].t - 12.34) < 0.01, "t=" + (p[0] && p[0].t))
        ok("parseLrc text", p.length > 1 && p[1].text === "Второй раз", p.length > 1 ? JSON.stringify(p[1].text) : "")

        var e = lyr.parseLrc("[00:01.00]<00:01.00>one <00:01.50>two <00:02.00>three\n")
        // s[0] is documented as "what comes before the first word", so the words
        // themselves are s.length - 1
        ok("enhanced LRC keeps words", e.length === 1 && e[0].s && e[0].s.length === 4,
           "entries=" + (e[0].s ? e[0].s.length : 0))
        ok("enhanced LRC word times", e[0].w && e[0].w.length === 3 && e[0].w[0] < e[0].w[1], JSON.stringify(e[0].w))

        // ---- matching ----
        ok("sameArtist exact", lyr.sameArtist("Скриптонит", "Скриптонит") === true)
        ok("key normalises case", lyr.key("Скриптонит — Полюби") === lyr.key("скриптонит — полюби"))
        ok("artistsOf splits feat/&", lyr.artistsOf("Скриптонит feat. T-Fest & 104").length >= 3,
           JSON.stringify(lyr.artistsOf("Скриптонит feat. T-Fest & 104")))

        var a = lyr.clean("Radiohead - Creep (Official Music Video)", "Radiohead")
        ok("clean video title", a.title === "Creep", JSON.stringify(a))
        var b = lyr.clean("Скриптонит - Полюби меня (премьера клипа, 2024)", "")
        ok("clean cyrillic", b.title === "Полюби меня" && b.artist === "Скриптонит", JSON.stringify(b))

        // ---- the port's own invariants ----
        ok("no angelOS settings migration", lyr.migrateSources === undefined)
        ok("source list is the plugin's", JSON.stringify(lyr.sources).indexOf("lrclib") > 0,
           JSON.stringify(lyr.sources).slice(0, 70))
        // these two call the ported singletons from *inside* the module
        // (Lib.Paths.cacheDir, Lib.I18n.t): an import from outside the module
        // directory resolves to the type, not the instance
        ok("the cache path is inside the plugin's cache",
           lyr.cacheFile("Artist\u0001Title").indexOf("angelos.lyrics/lyrics/") > 0,
           lyr.cacheFile("Artist\u0001Title"))
        var menu = lyr.playerMenu()
        ok("the player menu is built (Lib.I18n.t resolves)",
           Array.isArray(menu) && menu.length === 3 && menu[0].label.length > 0,
           JSON.stringify(menu.map(function (m) { return m.label })))

        // ---- a real source: lrclib over the network ----
        lyr.http("https://lrclib.net/api/search?q=radiohead+creep", function (code, body) {
            ok("lrclib status 200", code === 200 && Array.isArray(body), "hits=" + (body ? body.length : 0))
            if (!Array.isArray(body) || !body.length)
                return
            // what the lrclib branch does: run every hit through matches()
            var song = { "title": "Creep", "artist": "Radiohead" }
            var candidates = body.filter(function (r) {
                return lyr.matches({ "title": r.trackName || r.name, "artist": r.artistName, "duration": r.duration }, song, 236)
            })
            ok("matches() accepts real hits", candidates.length > 0, "kept " + candidates.length + "/" + body.length)
            // a candidate with no duration at all is accepted on purpose: it
            // cannot be compared, and rejecting it would throw away good lyrics.
            // Where a duration IS known, a 400 s player must not match a 236 s
            // recording.
            var timed = candidates.filter(function (r) { return (Number(r.duration) || 0) > 0 })
            ok("matches() rejects a wrong duration", timed.length > 0 && timed.every(function (r) {
                return !lyr.matches({ "title": r.trackName || r.name, "artist": r.artistName, "duration": r.duration }, song, 400)
            }), timed.length + " timed candidates checked")
            var best = candidates.filter(function (r) { return r.syncedLyrics })
                .sort(function (x, y) { return Math.abs(x.duration - 236) - Math.abs(y.duration - 236) })[0]
            ok("a synced hit survives", !!best, best ? best.trackName + " @ " + best.duration : "none")
            if (best) {
                ok("goodLrc on it", lyr.goodLrc(best.syncedLyrics) === true)
                var lines = lyr.parseLrc(best.syncedLyrics)
                ok("its lines parse", lines.length > 20, "n=" + lines.length)
                ok("its line times ascend", lines.length > 1 && lines[1].t > lines[0].t)
            }
            lyr.http("https://lrclib.net/api/search?q=zzz+this+song+does+not+exist+2026", function (c2, b2) {
                ok("an impossible search finds nothing", Array.isArray(b2) && b2.length === 0, "hits=" + (b2 ? b2.length : "null"))
            })

            // a player that rewrites one art file in place (Chromium) must still
            // give a fresh URL per track, or the bar keeps the previous cover
            lyr.artVersion = 1
            lyr._resolveArt("file:///tmp/cover-a.png")
            var artA = lyr.artUrl
            ok("file art passes through with a version tag",
               artA.indexOf("file:///tmp/cover-a.png#a") === 0, artA)
            lyr.artVersion = 2
            lyr._resolveArt("file:///tmp/cover-b.png")
            ok("a new track busts the Image cache",
               lyr.artUrl !== artA && lyr.artUrl.indexOf("file:///tmp/cover-b.png#a") === 0, lyr.artUrl)
            lyr._resolveArt("")
            ok("no art gives no source", lyr.artUrl === "")
        })
    }

    // ---------------------------------------------------------------- widget
    function testWidget(w) {
        ok("widget is a BarWidget", w.vertical !== undefined, "vertical=" + w.vertical)
        ok("reads the manifest defaults", w.byWord === true && w.glowMode === "level",
           "byWord=" + w.byWord + " glow=" + w.glowMode)
        ok("falls back to the engine directly", w.lyr !== null && w.lyr !== undefined)
        ok("pushes its settings into the engine", w.glow.mode === "level", "engine glow=" + w.glow.mode)
        ok("placeholder line before any song", w.line === "\u266a ~ \u266a", JSON.stringify(w.line))
        ok("inactive with no lyrics", w.active === false)
        ok("takes no width while inactive", w.implicitWidth === 0, "w=" + w.implicitWidth)

        w.settings = { "byWord": false, "glow": "off", "preferPlayer": "spotify" }
        ok("a settings override is read", w.byWord === false && w.glowMode === "off" && w.prefer === "spotify",
           "glow=" + w.glowMode)
        // read the engine through the widget's own object: an import by a
        // different URL is a separate module instance with its own singletons
        ok("the override reaches the engine", w.glow.mode === "off", "engine glow=" + w.glow.mode)
        w.settings = { "glow": "level" }
        ok("and back", w.glow.mode === "level", "engine glow=" + w.glow.mode)

        // ---- long lines: the box caps at maxWidth and glides, never sits cut ----
        w.shown = "Это очень длинная строка песни, которая точно не влезает в бар целиком — она должна плыть вбок, а не обрезаться навсегда"
        w.typed = w.shown.length
        ok("a long line is measured whole", w.fullW > w.maxWidth,
           "fullW=" + Math.round(w.fullW) + " > maxWidth=" + w.maxWidth)
        // the widget is invisible here, so implicitWidth is 0 by design; the box
        // itself is fullW - overflowW
        ok("the box caps at maxWidth, not narrower", w.fullW - w.overflowW === w.maxWidth,
           "box=" + Math.round(w.fullW - w.overflowW) + " = maxWidth " + w.maxWidth)
        ok("the long line overflows its box", w.overflowW > 0, "overflow=" + Math.round(w.overflowW))
        ok("the glide starts for a long line", w.startGlide() === true)
        // 700 ms pause, then the move: mid-glide it must be under way; the shown
        // line stays until the glide has finished, or overflowW would reset.
        // The live engine may sing a new line mid-window — that resets the glide
        // by design, so those runs are skipped rather than failed.
        root.interfered = false
        glideMid.restart()
        glideEnd.restart()
    }

    Connections {
        target: widget.item
        function onLineChanged() { root.interfered = true }
    }
    property bool interfered: false

    Timer {
        id: glideMid
        interval: 1200
        onTriggered: {
            if (root.interfered) {
                console.log("PORTTEST SKIP  the glide is under way (the engine sang a new line mid-glide)")
                return
            }
            var w = widget.item
            root.ok("the glide is under way", w.scrollX > 0 && w.scrollX < w.overflowW,
                    "scrollX=" + Math.round(w.scrollX) + " of " + Math.round(w.overflowW))
        }
    }
    Timer {
        id: glideEnd
        interval: 2600
        onTriggered: {
            var w = widget.item
            if (!root.interfered) {
                root.ok("the glide reaches the line's end", Math.abs(w.scrollX - w.overflowW) < 0.5,
                        "scrollX=" + Math.round(w.scrollX) + " of " + Math.round(w.overflowW))
            } else {
                console.log("PORTTEST SKIP  the glide reaches the line's end (the engine sang a new line mid-glide)")
            }
            // a short line fits: no overflow, and the box hugs it
            w.shown = "короткая"
            w.typed = w.shown.length
            root.ok("a short line does not overflow", w.overflowW === 0 && w.fullW > 0,
                    "fullW=" + Math.round(w.fullW))
            root.ok("the box hugs a short line", w.fullW - w.overflowW === w.fullW,
                    "box=" + Math.round(w.fullW - w.overflowW))
            root.ok("no glide for a short line", w.startGlide() === false)

            // ---- the first line of a song rises like any other ----
            // driven through the widget's own engine, so the real onLineChanged
            // path runs: the placeholder is current, then the first line becomes
            // current with nothing sung yet
            var e = w.lyr
            e.anyScreenVisible = false       // stop the engine's 80 ms tick
            e.status = "ok"
            e.lines = [{ "t": 3.2, "text": "первая строка песни",
                         "s": ["", "первая", " строка", " песни"], "ws": [3.2, 4.0, 4.8] }]
            // walk to the placeholder through a real line first: the live engine
            // may already sit on index -1, and a write that changes nothing fires
            // no lineChanged
            e.index = 0
            e.index = -1
            e.wordChars = 0
            root.ok("the placeholder is showing before the first line",
                    w.shown === "\u266a ~ \u266a" && w.byWordNow === false, JSON.stringify(w.shown))
            // in the live flow the placeholder has been typed out by now, so
            // settled holds its length; the regression this guards is that stale
            // value leaking into the first line's state
            w.settled = w.shown.length
            e.index = 0                      // the song's first line becomes current
            root.ok("the first line takes the word path, not the typewriter",
                    w.settled === 0 && w.typed === 0,
                    "settled=" + w.settled + " typed=" + w.typed)
            root.ok("the first line arrives with nothing sung",
                    w.shown === "первая строка песни" && w.typed === 0,
                    "shown=" + JSON.stringify(w.shown) + " typed=" + w.typed)
            root.ok("no full-line flash, no lone caret at the start",
                    w.typed === 0 && w.caretShown === false,
                    "typed=" + w.typed + " caret=" + w.caretShown)
            root.ok("the first line rises into place", w.sliding === true, "sliding=" + w.sliding)
            slideEnd.restart()
        }
    }

    Timer {
        id: slideEnd
        interval: 400
        onTriggered: {
            var w = widget.item
            root.ok("the rise finishes", w.sliding === false, "sliding=" + w.sliding)
            w.lyr.wordChars = 6              // the first word is sung
            root.ok("the first word shows, and the caret comes with it",
                    w.typed === 6 && w.caretShown === true,
                    "typed=" + w.typed + " caret=" + w.caretShown)
            w.shown = ""
            w.typed = 0
            w.settled = 0

            // ---- the player popup ----
            ok("the popup starts closed", w.popupOpen === false)
            w.togglePopup()
            ok("a click on the line opens the popup", w.popupOpen === true)
            w.togglePopup()
            ok("a second click closes it", w.popupOpen === false)
            w.togglePopup()
            w.close()
            ok("the bar's hide closes it too", w.popupOpen === false)
            ok("the transport buttons report booleans",
               typeof w.canPrev === "boolean" && typeof w.canPlay === "boolean" && typeof w.canNext === "boolean",
               "prev=" + w.canPrev + " play=" + w.canPlay + " next=" + w.canNext)

            // ---- the popup's settings row: opacity ----
            ok("opacity defaults to fully solid", w.opacityPct === 100, "opacityPct=" + w.opacityPct)
            ok("the preview factor follows the setting", w.previewOpacity === 1, "preview=" + w.previewOpacity)
            ok("the settings row starts collapsed", w.settingsOpen === false)
            w.settingsOpen = true
            ok("the gear opens the settings row", w.settingsOpen === true)
            // the drag dims the line before anything is saved
            w.previewOpacity = 0.4
            ok("a drag dims the line without touching the setting",
               w.previewOpacity === 0.4 && w.opacityPct === 100,
               "preview=" + w.previewOpacity + " pct=" + w.opacityPct)
            // the release writes it; the harness has no shell to persist to, so
            // only the local apply is observable here
            w.previewOpacity = 0.9
            w.saveSetting("opacity", 40)
            ok("saving applies the opacity locally", w.settings.opacity === 40,
               JSON.stringify(w.settings))
            ok("the saved value feeds the line's opacity", w.opacityPct === 40, "pct=" + w.opacityPct)
            ok("a saved setting replaces a stale preview", w.previewOpacity === 0.4,
               "preview=" + w.previewOpacity)
            // out-of-range values are clamped, not trusted
            w.saveSetting("opacity", 500)
            ok("opacity is clamped to 100", w.opacityPct === 100, "pct=" + w.opacityPct)
            w.saveSetting("opacity", -20)
            ok("opacity is clamped to 0", w.opacityPct === 0, "pct=" + w.opacityPct)

            // ---- the persistence handoff ----
            // the harness has no shell, so hand the widget a stand-in that
            // records what the real one would write to shell.json
            fakeBar.writes = []
            w.bar = fakeBar
            w.saveSetting("opacity", 60)
            ok("the save reaches the shell's shell.json writer", fakeBar.writes.length === 1,
               "writes=" + fakeBar.writes.length)
            if (fakeBar.writes.length > 0) {
                ok("it writes under this widget's id", fakeBar.writes[0].id === "angelos.lyrics",
                   fakeBar.writes[0].id)
                ok("it carries the opacity", fakeBar.writes[0].entry.opacity === 60,
                   JSON.stringify(fakeBar.writes[0].entry))
                ok("it keeps the widget id in the entry", fakeBar.writes[0].entry.id === "angelos.lyrics",
                   JSON.stringify(fakeBar.writes[0].entry))
            }
            w.bar = null
            w.saveSetting("opacity", 100)
            w.settingsOpen = false

            // ---- the cover on the left ----
            ok("artwork defaults to the cover", w.artwork === "cover", w.artwork)
            ok("the note slot is cover-sized", w.noteSize >= 16, "noteSize=" + Math.round(w.noteSize))
            // the live engine may already hold the real player's cover: clear it
            // and let the Image unload before asserting the fallback
            w.lyr.artUrl = ""
            artClear.restart()
        }
    }

    Timer {
        id: artClear
        interval: 500
        onTriggered: {
            var w = widget.item
            if (w.lyr.artUrl !== "") {
                console.log("PORTTEST SKIP  the note glyph fallback (the live player re-set its cover mid-test)")
            } else {
                root.ok("the note glyph shows while there is no cover",
                        w.noteGlyphShown === true && w.coverShown === false,
                        "cover=" + w.coverShown + " glyph=" + w.noteGlyphShown)
            }
            w.lyr.artUrl = root.artData
            coverUp.restart()
        }
    }

    Timer {
        id: coverUp
        interval: 600
        onTriggered: {
            var w = widget.item
            root.ok("the cover shows once the art is ready",
                    w.coverShown === true && w.noteGlyphShown === false,
                    "cover=" + w.coverShown + " glyph=" + w.noteGlyphShown)
            w.settings = { "artwork": "note" }
            noteMode.restart()
        }
    }
    Timer {
        id: noteMode
        interval: 400
        onTriggered: {
            var w = widget.item
            root.ok("artwork=note hides the cover even with art ready",
                    w.coverShown === false && w.noteGlyphShown === true,
                    "cover=" + w.coverShown + " glyph=" + w.noteGlyphShown)
            w.settings = { }
            w.lyr.artUrl = ""
        }
    }
}
