import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Orivo pomodoro session + countdown for the Omarchy bar.
// Polls scripts/orivo-status.sh once a second, which prefers orivo's live
// IPC socket (~/.local/state/orivo/orivo.sock) and falls back to its last
// saved ~/.local/state/orivo/store.json snapshot when orivo isn't open.
BarWidget {
  id: root
  moduleName: "omarchy-orivo-plugin"

  property string code: "W"
  property string label: "Work Session"
  property string time: "00:00"
  property bool dataVisible: false
  property bool running: false
  property bool live: false

  readonly property string scriptPath: Qt.resolvedUrl("scripts/orivo-status.sh").toString().replace("file://", "")

  readonly property string tooltip: !root.live
    ? root.label + " · orivo closed"
    : (root.running ? root.label : root.label + " · Paused")

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
          root.running = !!data.running
          root.live = !!data.live
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
