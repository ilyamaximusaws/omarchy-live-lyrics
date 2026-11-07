# Tests

Isolated quickshell run of the engine and the bar widget — the live shell's
cache and state are not in the picture.

    # stage the shell's own modules the plugin imports (qs.Commons, qs.Ui)
    mkdir -p /tmp/qsimp/qs
    cp -r /usr/share/omarchy/shell/Commons /tmp/qsimp/qs/
    cp -r /usr/share/omarchy/shell/Ui /tmp/qsimp/qs/

    QML_IMPORT_PATH=/tmp/qsimp:/usr/lib/qt6/qml \
      quickshell -p ~/.config/omarchy/plugins/angelos.lyrics/tests

Every line printed starts with PORTTEST; the last line is the summary:

    ... | grep PORTTEST | grep -c PASS      # pass count
    ... | grep PORTTEST SUMMARY             # "39/39"

Notes:

* The glide timing assertions (mid-glide, end-of-glide) are skipped, not
  failed, when the live engine sings a new line inside the 2.6 s window —
  that reset is the widget's real behaviour, not a bug.
* The network assertions hit lrclib.net for real; offline, those fail.
* Do not import the plugin's `lib` from outside its directory in a test
  (`import "../lib" as Lib` resolves to the types, not the singleton
  instances). Exercise the singletons through the engine's own functions,
  as shell.qml does.
