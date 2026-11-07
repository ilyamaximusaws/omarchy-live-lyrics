import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "lib" as Lib

// The current lyric line in the bar: a typewriter reveal while a synced line is
// being sung, and a karaoke hand-off (the settled part stays, the new word hops
// in) when the source carries word timings. The box is as wide as the current
// line (up to maxWidth), so it stays put during a line; a line that still
// doesn't fit glides sideways instead of being cut.
//
// The engine lives in lib/ and is kept alive by this plugin's Service.qml — the
// fetch and the position ticker must run with the widget hidden, so they are not
// the widget's to own. What is here is drawing, the settings handoff and clicks.
BarWidget {
    id: root
    moduleName: "angelos.lyrics"

    // ---- the service, or the singletons directly ----------------------------
    // Through the shell when this plugin's service is up (the normal case: it
    // owns the engine and the IPC target), the module singletons otherwise, so
    // the widget still draws if it is ever opened on its own.
    readonly property var svc: bar && bar.shell && typeof bar.shell.serviceFor === "function"
        ? bar.shell.serviceFor(moduleName) : null
    readonly property var lyr: svc ? svc.lyrics : Lib.Lyrics
    readonly property var glow: svc ? svc.glow : Lib.LyricsGlow

    // ---- settings ------------------------------------------------------------
    // The manifest schema is where these come from; its `defaults` is what they
    // read as before anything is set. Pushed into the engine too, because one
    // QML component cannot read another's `settings`.
    readonly property bool byWord: setting("byWord", true)
    readonly property bool onBeat: setting("onBeat", true)
    readonly property string glowMode: setting("glow", "level")
    readonly property string prefer: setting("preferPlayer", "")
    // how wide the line may get before it has to glide (angelOS: Theme.u * 250,
    // one art pixel = 2 screen px)
    readonly property int maxWidth: setting("maxWidth", 500)

    function pushSettings() {
        // setLyrics assigns a fresh object: that assignment is what re-evaluates
        // the engine's bindings on these settings
        Lib.Config.setLyrics({
            "byWord": byWord,
            "onBeat": onBeat,
            "glow": glowMode,
            "preferPlayer": prefer
        })
        if (svc && typeof svc.updateConfig === "function")
            svc.updateConfig({ "byWord": byWord, "onBeat": onBeat, "glow": glowMode, "preferPlayer": prefer })
    }
    onByWordChanged: pushSettings()
    onOnBeatChanged: pushSettings()
    onGlowModeChanged: pushSettings()
    onPreferChanged: pushSettings()
    Component.onCompleted: {
        pushSettings()
        shown = line
        typed = shown.length
        settled = typed
    }

    // ---- what to show --------------------------------------------------------
    readonly property bool active: Lib.Config.lyrics.enabled && lyr.hasLyrics && lyr.visibleToggle
    readonly property string line: lyr.current !== "" ? lyr.current : "\u266a ~ \u266a"
    readonly property bool singing: lyr.current !== "" && lyr.playing

    // ---- settings ------------------------------------------------------------
    readonly property string artwork: setting("artwork", "cover")   // "cover" | "note"
    // how opaque the widget is, 0-100 (the popup's own settings row writes it)
    readonly property int opacityPct: Math.max(0, Math.min(100, Number(setting("opacity", 100))))

    // merge one setting into the entry shell.json keeps for this widget: applied
    // locally first so the change shows on the click itself, then persisted, and
    // the shell hands the same value back through `settings`
    function saveSetting(key, value) {
        var entry = { "id": moduleName }
        for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
        entry[key] = value
        root.settings = entry
        if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
            bar.shell.updateEntryInline(moduleName, entry)
    }

    // ---- the player popup ----------------------------------------------------
    // a small transport card anchored to this widget: cover, title, pause/next/previous
    property bool popupOpen: false
    // the popup's own settings row (opacity), collapsed until the gear is hit
    property bool settingsOpen: false
    function togglePopup() { popupOpen = !popupOpen }
    // the bar calls this when it hides; a popup anchored to a hidden bar must not stay
    function close() { popupOpen = false }

    // the player the lyrics follow is the player the popup controls
    readonly property var popupPlayer: lyr.player
    readonly property bool canPrev: !!popupPlayer && popupPlayer.canGoPrevious === true
    readonly property bool canPlay: !!popupPlayer && (popupPlayer.canTogglePlaying === true
        || popupPlayer.canPlay === true || popupPlayer.canPause === true)
    readonly property bool canNext: !!popupPlayer && popupPlayer.canGoNext === true

    readonly property color tint: bar ? bar.barForeground : "#cacccc"
    readonly property color accent: Commons.Color.accent
    readonly property string fontFamily: Style.fontFamily
    readonly property int fontPx: Style.fontPx(1.0)
    // the engine's wordTimed already folds the byWord setting in (as angelOS's
    // Lyrics.wordTimed does), so this is purely "the source carries word times"
    readonly property bool byWordNow: lyr.wordTimed && lyr.current !== ""

    // ---- geometry ------------------------------------------------------------
    readonly property real gap: Math.round(barSize * 0.18)
    readonly property real pad: 6
    readonly property real chrome: note.width + gap
    // the current line, laid out whole
    readonly property real fullW: fullProbe.implicitWidth
    readonly property real typedW: typed >= shown.length ? fullW : typedProbe.implicitWidth
    readonly property int clipChars: byWordNow ? settled : typed
    readonly property real clipW: clipChars >= shown.length ? fullW : clipChars === typed ? typedW : clipProbe.implicitWidth
    readonly property real overflowW: Math.max(0, fullW - textBox.width)
    property real scrollX: 0
    // the line's rise into place is running (the first line of a song rises like any other)
    readonly property bool sliding: slide.running
    // whether the caret is on screen (hidden until there is something to sit after)
    readonly property alias caretShown: caret.visible
    // what is on the left of the line
    readonly property alias coverShown: cover.visible
    readonly property alias noteGlyphShown: noteGlyph.visible
    readonly property alias noteSize: note.width

    implicitWidth: visible ? Math.min(maxWidth, fullW) + chrome : 0
    implicitHeight: barSize
    visible: active
    // the loudness glow and the opacity setting multiply: a dimmed line still
    // breathes with the music, it just breathes quieter
    opacity: (glowMode !== "off" && glow ? glow.opacity : 1.0) * previewOpacity
    Behavior on opacity {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    // ---- opacity, live while the slider is dragged ---------------------------
    // the setting is the truth; this is the same value as a 0..1 factor so the
    // drag shows before it is saved (and stays right if the setting changes
    // from anywhere else)
    property real previewOpacity: opacityPct / 100
    onOpacityPctChanged: previewOpacity = opacityPct / 100

    // ---- the reveal ----------------------------------------------------------
    property string previous: ""
    property int typed: 0
    property int settled: 0
    property string shown: ""

    // laid out against the same font as the visible line, so x offsets line up
    Text {
        id: fullProbe
        visible: false
        font.family: root.fontFamily
        font.pixelSize: root.fontPx
        text: root.shown
    }
    Text {
        id: typedProbe
        visible: false
        font.family: root.fontFamily
        font.pixelSize: root.fontPx
        text: root.shown.slice(0, Math.max(0, Math.min(root.shown.length, root.typed)))
    }
    Text {
        id: clipProbe
        visible: false
        font.family: root.fontFamily
        font.pixelSize: root.fontPx
        text: root.clipChars < root.typed ? root.shown.slice(0, root.clipChars) : ""
    }
    Text {
        id: freshProbe
        visible: false
        font.family: root.fontFamily
        font.pixelSize: root.fontPx
        text: root.shown.slice(0, Math.max(0, Math.min(root.shown.length, root.settled)))
    }

    function startGlide() {
        if (!(overflowW > 0))
            return false
        const dur = Math.max(1.2, (lyr.lineEnd || 0) - (lyr.lineStart || 0))
        glideMove.to = overflowW
        glideMove.duration = Math.max(900, Math.min(8000, dur * 1000 * 0.55))
        glide.restart()
        return true
    }

    onLineChanged: {
        previous = shown
        shown = line
        glide.stop()
        scrollX = 0
        // byWordNow's binding lags a beat behind the engine: on the song's first
        // line (index -1 -> 0) it still reads the placeholder's false, and the
        // line would be typed left-to-right instead of revealed word by word.
        // The engine updates wordChars before index on purpose, so branch on the
        // engine's raw state here, not on the widget's bindings.
        const i = lyr.index
        const wordNow = i >= 0 && i < lyr.lines.length && !!lyr.lines[i].s
            && Lib.Config.lyrics.byWord !== false
        if (wordNow) {
            typer.stop()
            freshIn.stop()
            // wordChars reflects the exact number of characters sung up to position,
            // whether the line just started or lyrics loaded mid-song
            typed = Math.max(0, Math.min(shown.length, lyr.wordChars))
            settled = typed
            if (visible)
                slide.restart()
            if (typed >= shown.length)
                startGlide()
            return
        }
        if (!visible) {
            typed = shown.length
            startGlide()
            return
        }
        typed = 0
        const dur = Math.max(0.3, (lyr.lineEnd || 0) - (lyr.lineStart || 0))
        typer.interval = Math.max(12, Math.min(40, dur * 1000 * 0.45 / Math.max(1, shown.length)))
        typer.restart()
        slide.restart()
    }

    // word by word: the engine says how many characters of the line are sung
    Connections {
        target: lyr
        enabled: root.byWordNow
        function onWordCharsChanged() {
            const n = Math.min(root.shown.length, lyr.wordChars)
            if (n > root.typed && root.visible) {
                root.settled = root.typed
                root.typed = n
                freshIn.restart()
            } else {
                freshIn.stop()
                root.typed = n
                root.settled = n
            }
            // sung to its end: it stays where the caret pulled it (as the typewriter's line does)
            if (root.typed >= root.shown.length)
                root.scrollX = root.overflowW
        }
    }

    Timer {
        id: typer
        repeat: true
        onTriggered: {
            let n = Math.min(root.shown.length, root.typed + 1)
            // never cut a surrogate pair (emoji) in the middle
            const c = root.shown.charCodeAt(n - 1)
            if (n < root.shown.length && c >= 0xD800 && c <= 0xDBFF)
                n++
            root.typed = n
            if (root.typed >= root.shown.length) {
                stop()
                // the caret already pulled the text to its end
                root.scrollX = root.overflowW
            }
        }
    }

    SequentialAnimation {
        id: glide
        PauseAnimation { duration: 700 }
        NumberAnimation {
            id: glideMove
            target: root
            property: "scrollX"
            easing.type: Easing.InOutSine
        }
    }

    // ---- the bar item --------------------------------------------------------
    Row {
        anchors.fill: parent
        spacing: root.gap

        // the cover, or the note glyph while there is no cover to show
        Item {
            id: note
            readonly property real artSize: Math.max(16, Math.round(root.barSize * 0.6))
            width: root.artwork === "cover" ? artSize : Math.round(artSize * 2 / 3)
            height: artSize
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.singing ? 1 : 0.6
            Behavior on opacity {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            Image {
                id: cover
                anchors.fill: parent
                source: root.artwork === "cover" ? root.lyr.artUrl : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                smooth: true
                clip: true
            }

            Text {
                id: noteGlyph
                anchors.centerIn: parent
                visible: !cover.visible
                text: root.singing ? "\u266a" : "\u266b"
                color: root.tint
                font.family: root.fontFamily
                font.pixelSize: root.fontPx
            }
        }

        Item {
            id: textBox
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(root.maxWidth, root.fullW)
            height: parent.height
            clip: true

            Text {
                id: cur
                anchors.verticalCenter: parent.verticalCenter
                // typing: the line is laid out whole and a clip uncovers it,
                // instead of rebuilding the text on every character
                readonly property bool typing: root.clipChars < root.shown.length
                width: typing ? root.clipW + root.pad : Math.max(parent.width, root.fullW + root.pad * 2)
                clip: typing
                // while typing (or the words coming), the caret pulls a long line
                // along; afterwards scrollX holds / glides
                x: typer.running || (root.byWordNow && typing)
                    ? -Math.min(Math.max(0, root.typedW + root.pad - textBox.width), root.byWordNow ? root.overflowW : Infinity)
                    : -Math.min(root.scrollX, root.overflowW)
                text: root.shown
                color: root.singing ? root.tint : Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.6)
                font.family: root.fontFamily
                font.pixelSize: root.fontPx

                Text {
                    id: caret
                    visible: cur.typing && (!root.byWordNow || root.typed > 0)
                    x: root.typedW
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accent
                    font.family: cur.font.family
                    font.pixelSize: cur.font.pixelSize
                    text: "\u258c"
                }
            }

            // the word that just arrived, coming in over the settled part
            Text {
                id: fresh
                visible: root.byWordNow && root.settled < root.typed
                x: cur.x + root.clipW
                anchors.verticalCenter: parent.verticalCenter
                property real hop: 0
                property real fade: 1
                anchors.verticalCenterOffset: hop
                opacity: fade
                text: root.shown.slice(Math.max(0, root.settled), Math.max(0, root.typed))
                color: cur.color
                font.family: root.fontFamily
                font.pixelSize: root.fontPx
            }

            ParallelAnimation {
                id: freshIn
                NumberAnimation { target: fresh; property: "fade"; from: 0.25; to: 1; duration: 90 }
                NumberAnimation { target: fresh; property: "hop"; from: 3; to: 0; duration: 200; easing.type: Easing.OutBack }
                onFinished: root.settled = root.typed
            }

            // a new line: the new one rises into place
            NumberAnimation {
                id: slide
                target: cur
                property: "anchors.verticalCenterOffset"
                from: 5
                to: 0
                duration: 190
                easing.type: Easing.OutBack
            }
        }
    }

    // ---- clicks --------------------------------------------------------------
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePopup()
            } else if (mouse.button === Qt.MiddleButton) {
                // the quick action without opening anything
                if (root.lyr.player && root.lyr.player.canTogglePlaying)
                    root.lyr.player.togglePlaying()
            } else {
                // the glow is the only setting whose effect is visible in the bar
                root.glowMode = root.glowMode === "off" ? "level" : "off"
            }
        }
    }

    // ---- the player popup ----------------------------------------------------
    // A small transport card that grows out of the bar under the widget. Outside
    // clicks close it (the card's focus grab), as does another click on the line.
    PopupCard {
        id: popup
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        contentWidth: popup.fittedContentWidth(Style.space(300))
        contentHeight: popup.fittedContentHeight(column.implicitHeight)

        Column {
            id: column
            anchors.fill: parent
            spacing: Style.space(10)

            Row {
                spacing: Style.space(10)
                width: parent.width

                BorderSurface {
                    width: Style.space(64)
                    height: Style.space(64)
                    radius: Style.spacing.labelGap
                    color: Style.normalFillFor(root.tint, Commons.Color.accent)
                    borderSpec: Border.controlSpec("normal", root.tint, Commons.Color.accent)

                    SizedImage {
                        anchors.fill: parent
                        anchors.margins: Style.space(2)
                        crop: true
                        url: root.lyr.artUrl
                        visible: url != ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.lyr.artUrl === ""
                        text: "󰝚"
                        color: root.tint
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.displayLarge
                    }
                }

                Column {
                    spacing: Style.space(4)
                    width: parent.width - Style.space(74)

                    Text {
                        textFormat: Text.PlainText
                        text: root.popupPlayer ? (root.popupPlayer.trackTitle || "") : ""
                        color: root.tint
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                        visible: text !== ""
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: root.popupPlayer ? (root.popupPlayer.trackArtist || "") : ""
                        color: Qt.darker(root.tint, 1.3)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        width: parent.width
                        visible: text !== ""
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(6)
                // Transport controls keep previous, play, next in every language,
                // matching their glyphs; media controls are not mirrored.
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: true

                Button {
                    iconText: "󰒮"
                    foreground: root.tint
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    enabled: root.canPrev
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: if (root.lyr.player) root.lyr.player.previous()
                }

                Button {
                    iconText: root.popupPlayer && root.popupPlayer.isPlaying ? "󰏤" : "󰐊"
                    foreground: root.tint
                    horizontalPadding: Style.spacing.panelGap
                    verticalPadding: Style.spacing.controlPaddingY
                    iconSize: Style.font.iconLarge
                    enabled: root.canPlay
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: if (root.lyr.player) root.lyr.player.togglePlaying()
                }

                Button {
                    iconText: "󰒭"
                    foreground: root.tint
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    enabled: root.canNext
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: if (root.lyr.player) root.lyr.player.next()
                }

                // the settings row is the popup's own; the gear stays in the
                // transport row so the card does not change height on the toggle
                Button {
                    iconText: "󰒓"
                    foreground: root.tint
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    selected: root.settingsOpen
                    onClicked: root.settingsOpen = !root.settingsOpen
                }
            }

            // ---- settings: the opacity of the line ----
            Column {
                width: parent.width
                spacing: Style.space(4)
                visible: root.settingsOpen

                Item {
                    width: parent.width
                    height: opacityLabel.implicitHeight

                    Text {
                        id: opacityLabel
                        textFormat: Text.PlainText
                        text: "Opacity"
                        color: root.tint
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: Math.round(root.previewOpacity * 100) + "%"
                        color: Qt.darker(root.tint, 1.3)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                PanelSlider {
                    width: parent.width
                    bar: root.bar
                    minimum: 20
                    maximum: 100
                    step: 5
                    integer: true
                    value: Math.round(root.previewOpacity * 100)
                    // the line dims as the knob moves, and only the release
                    // writes shell.json (a drag is not a setting)
                    onMoved: function (v) { root.previewOpacity = v / 100 }
                    onReleased: function (v) {
                        root.previewOpacity = v / 100
                        root.saveSetting("opacity", Math.round(v))
                    }
                }
            }
        }
    }
}
