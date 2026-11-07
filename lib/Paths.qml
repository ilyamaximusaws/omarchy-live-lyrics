pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string pluginDir: {
        var url = String(Qt.resolvedUrl("."))
        if (url.indexOf("file://") === 0) {
            try { url = decodeURIComponent(url.substring(7)) } catch (e) {}
        }
        return url.replace(/\/lib\/?$/, "")
    }

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/omarchy/angelos.lyrics"
    readonly property string home: Quickshell.env("HOME")

    function script(name) {
        return pluginDir + "/scripts/" + name
    }
}
