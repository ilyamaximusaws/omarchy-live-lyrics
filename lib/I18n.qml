pragma Singleton
import QtQuick
import Quickshell
import qs.Commons as Commons

// Two-string helper: the engine's strings were written as I18n.t(ru, en) in
// angelOS. The language comes from the same Commons.I18n Omarchy's own widgets
// read, so a line follows the system language instead of a second setting.
Singleton {
    id: root

    function t(ru, en) {
        try {
            return (Commons.I18n.language || "ru") === "ru" ? ru : en
        } catch (e) {
            return ru
        }
    }
}
