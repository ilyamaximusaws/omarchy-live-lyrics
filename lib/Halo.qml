pragma Singleton
import QtQuick
import Quickshell

// angelOS's Halo is a ring of lyrics on the wallpaper's edge, driven by its own
// Compositor service. This port does not carry it (v1 shows lines in the bar
// only), but Lyrics.qml asks placeOn() about it — so the name stays, answering
// "no" forever, and the ported lines that mention Halo still compile.
Singleton {
    id: root

    function on(screenName) {
        return false
    }
}
