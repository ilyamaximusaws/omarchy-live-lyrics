import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "lib" as Lib

// The lyric engine has to be alive before any bar shows a line: it fetches the
// text, keeps the position ticker running and hears the player's stream. The
// bar widget only draws what this holds, so the service is what has to survive
// the widget being hidden — `keepLoaded` in the manifest is the promise.
Item {
    id: root

    readonly property var lyrics: Lib.Lyrics
    readonly property var glow: Lib.LyricsGlow
    readonly property var beat: Lib.LyricsBeat

    // Settings live on the bar widget's instance (the shell builds them from
    // the manifest schema); the widget hands them here, because one component
    // cannot read another's `settings`.
    function updateConfig(settings) {
        if (!settings)
            return
        var patch = {}
        if (settings.byWord !== undefined) patch.byWord = settings.byWord
        if (settings.onBeat !== undefined) patch.onBeat = settings.onBeat
        if (settings.glow !== undefined) patch.glow = settings.glow
        if (settings.preferPlayer !== undefined) patch.preferPlayer = settings.preferPlayer
        if (settings.searchInMessengers !== undefined) patch.searchInMessengers = settings.searchInMessengers
        Lib.Config.setLyrics(patch)
    }

    ShellIpc {
        id: ipcHandler
        target: "angelos.lyrics"

        function status(): string {
            return JSON.stringify({
                "playing": Lib.Lyrics.playing,
                "artist": Lib.Lyrics.artist,
                "title": Lib.Lyrics.title,
                "current": Lib.Lyrics.current,
                "status": Lib.Lyrics.status,
                "hasLyrics": Lib.Lyrics.hasLyrics,
                "source": Lib.Lyrics.source || "",
                // diagnostics for the reveal: a line that arrives mid-song has to
                // be distinguishable from one that starts from its own zero
                "position": Math.round(Lib.Lyrics.position * 100) / 100,
                "index": Lib.Lyrics.index,
                "wordTimed": Lib.Lyrics.wordTimed,
                "wordChars": Lib.Lyrics.wordChars,
                "lineStart": Lib.Lyrics.lineStart,
                "lineEnd": Lib.Lyrics.lineEnd,
                "lines": Lib.Lyrics.lines.length
            })
        }

        function toggle(): string {
            if (Lib.Lyrics.player && Lib.Lyrics.player.canTogglePlaying) {
                Lib.Lyrics.player.togglePlaying();
                return "ok";
            }
            return "no_player";
        }

        function ping(): string {
            return "pong";
        }

        // the user asking for the network on a track that does not get it by itself
        function search(): string {
            Lib.Lyrics.refetch();
            return Lib.Lyrics.status;
        }
    }
}
