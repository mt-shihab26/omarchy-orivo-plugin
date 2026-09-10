import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Orivo pomodoro session + countdown for the Omarchy bar.
// Polls scripts/orivo-status.sh once a second, which reads orivo's live
// IPC socket (~/.local/state/orivo/orivo.sock). The widget stays hidden
// whenever that socket isn't reachable, i.e. whenever orivo isn't open.
BarWidget {
  id: root
  moduleName: "omarchy-orivo-plugin"

  property string code: "W"
  property string label: "Work Session"
  property string time: "00:00"
  property string todo: ""
  property bool dataVisible: false
  property bool running: false

  // decodeURIComponent matters: the resolved URL percent-encodes spaces and
  // non-ASCII, so a plugin checked out under e.g. "~/my projects/" would
  // otherwise yield a path that does not exist and the widget would go dark.
  readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("scripts/orivo-status.sh").toString().replace("file://", ""))

  readonly property string tooltip: {
    var text = root.label
    if (!root.running) text += " · Paused"
    if (root.todo !== "") text += " — " + root.todo
    return text
  }

  visible: dataVisible
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  Process {
    id: statusProc
    command: ["bash", root.scriptPath]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.dataVisible = !!data.visible
          if (data.code) root.code = data.code
          if (data.label) root.label = data.label
          if (data.time) root.time = data.time
          root.todo = data.todo || ""
          root.running = !!data.running
        } catch (e) {
          root.dataVisible = false
        }
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.code + " " + root.time
    tooltipText: root.tooltip
  }
}
