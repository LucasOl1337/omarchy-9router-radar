import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "lol.routers"
  ipcTarget: "lol.routers"
  manageIpc: false
  IpcHandler {
    enabled: root.ipcTarget !== ""
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function router(id: string): void { content.router = id }
    function diagnostics(): string {
      return JSON.stringify({version: "1.2.0", sourceUrl: Qt.resolvedUrl("Panel.qml").toString(), icon: button.text, layout: "quota-cards", router: content.router, sort: content.sort, columns: content.columns, cards: content.view.cards.length, connections: content.view.connections, gateways: root.snapshot.routers.length})
    }
  }
  property var snapshot: ({routers: []})
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property int accountCount: content.view.cards.length
  readonly property bool hasError: snapshot.routers.some(r => r.error !== "" && r.error !== "Aguardando leitura")
  function refresh() { if (!refreshProcess.running) refreshProcess.running = true }
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy-trackers/routers/status.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.snapshot = JSON.parse(text()) } catch (e) { console.warn("9Router: JSON inválido") }
    }
  }
  Process { id: refreshProcess; command: ["systemctl", "--user", "start", "--no-block", "omarchy-routers.service"] }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "9R"
    iconComponent: Text {
      text: "9R"
      color: button.active ? button.activeColor : button.foreground
      font.family: button.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
    active: root.hasError
    tooltipText: "9Router · " + root.accountCount + " contas · " + root.snapshot.routers.map(r => r.name).join(" / ")
    onPressed: function(b) { if (b === Qt.MiddleButton) root.refresh(); else root.toggle() }
  }
  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: popup.fittedContentWidth(Style.space(1560))
    contentHeight: popup.fittedContentHeight(Style.space(980))
    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dy) content.scrollBy(dy * Style.space(120))
        if (dx) content.cycleRouter(dx)
      }
      onTextKey: function(t) {
        var key = t.toLowerCase()
        if (key === "r") root.refresh()
        else if (key === "s") content.cycleSort()
        else if (key === "p") content.cyclePeriod()
        else if (/^[0-9]$/.test(key)) content.selectRouter(Number(key))
      }
      Content {
        id: content
        anchors.fill: parent
        snapshot: root.snapshot
        foreground: root.bar ? root.bar.foreground : Color.foreground
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        onRefreshRequested: root.refresh()
      }
    }
  }
}
