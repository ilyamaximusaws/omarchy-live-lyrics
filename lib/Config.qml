pragma Singleton
import QtQuick
import Quickshell

// The engine's settings, as the ported code reads them: a bag on one property,
// `Config.lyrics.…`, because that is how angelOS wrote them and 43 reads in the
// engine depend on the shape.
//
// The bag exists to make one thing work: a change has to reach bindings.
//   * `lyrics` is a `var` property, so assigning it notifies;
//   * its default is frozen, so nobody can quietly mutate the singleton's own
//     object;
//   * every write goes through setLyrics(), which merges over `lyrics()` and
//     assigns a NEW object. Replacing the whole value is what re-evaluates
//     `Config.lyrics.glow !== "off"` and the rest; poking at a field of the old
//     object would notify nobody and leave the bar drawing the old mode.
Singleton {
    id: root

    // merged over this, never written through: a plain JS object's fields carry
    // no change signal, so a direct write into it would be invisible
    readonly property var defaults: Object.freeze({
        "enabled": true,
        "byWord": true,
        "onBeat": true,
        "glow": "level",            // "off" | "level"
        "glowFloor": 0.3,
        "glowLevelMin": 0.1,
        "glowLevelMax": 0.8,
        "glowRodeMin": 0.1,
        "glowRodeMax": 0.8,
        "glowTap": "main",
        "preferPlayer": "",
        // a messenger's voice message is not a song: its metadata goes to the lyrics services
        // only at the user's request (the player card's «Search lyrics»), unless this is on
        "searchInMessengers": false,
        "artwork": "cover",         // note | cover: what sits left of the line
        "offsetMs": 0,
        "wordLeadMs": 150,
        "typewriter": true,
        "screens": [],              // [] = every screen
        "sources": ["local", "player", "lrclib", "amll", "netease", "kugou", "qq", "lrccx", "musixmatch", "ovh"]
    })

    property var lyrics: defaults

    // patch one or more settings; always assigns a fresh object so bindings react
    function setLyrics(patch) {
        if (!patch)
            return
        var next = {}
        for (var k in root.lyrics)
            next[k] = root.lyrics[k]
        for (var j in patch)
            next[j] = patch[j]
        root.lyrics = next
    }

    // ---- paths and readiness -------------------------------------------------
    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: home + "/.cache/omarchy/angelos.lyrics"
    // true here, always: the ported engine has no settings file of its own to
    // wait for — the shell reads the manifest schema before the plugin loads
    readonly property bool ready: true
}
