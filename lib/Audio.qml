pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var sources: Pipewire.sources ? Pipewire.sources.values : []
    readonly property var appStreams: {
        var list = []
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && n.isStream && n.audio) list.push(n)
        }
        return list
    }
}
