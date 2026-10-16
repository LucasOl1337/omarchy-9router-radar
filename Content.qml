import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import "RadarModel.js" as RadarModel

Item {
  id: root
  property var snapshot: ({routers: []})
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property string router: "all"
  property string sort: "provider"
  property string period: "today"
  property double now: Date.now()
  readonly property var view: RadarModel.buildCards(snapshot, now, {router: router, sort: sort})
  readonly property var routerTabs: [{id: "all", name: "Todas"}].concat((snapshot.routers || []).map(r => ({id: r.id, name: r.name, error: r.error})))
  readonly property var sorts: [{id: "provider", label: "Provedor"}, {id: "free", label: "Mais livre"}, {id: "expiring", label: "Expira primeiro"}]
  readonly property var periods: [{id: "today", label: "Hoje"}, {id: "7d", label: "7 dias"}, {id: "30d", label: "30 dias"}, {id: "all", label: "Total"}]
  readonly property real gap: Style.space(10)
  readonly property int columns: Math.max(1, Math.floor((width + gap) / (Style.space(330) + gap)))
  readonly property real cardWidth: (list.width - Style.space(10) - gap * (columns - 1)) / columns
  signal refreshRequested()

  function toneColor(tone) { return ({green: "#22c55e", yellow: "#eab308", red: "#ef4444"})[tone] || Qt.rgba(foreground.r, foreground.g, foreground.b, .35) }
  function faint(alpha) { return Qt.rgba(foreground.r, foreground.g, foreground.b, alpha) }
  function compact(n) { return n >= 1000000 ? (n / 1000000).toFixed(1) + "M" : n >= 1000 ? (n / 1000).toFixed(1) + "k" : String(n || 0) }
  function duration(ms) {
    if (ms <= 0) return ""
    var minutes = Math.ceil(ms / 60000)
    return minutes < 60 ? minutes + "m" : minutes < 1440 ? Math.floor(minutes / 60) + "h " + minutes % 60 + "m" : Math.floor(minutes / 1440) + "d " + Math.floor(minutes % 1440 / 60) + "h " + minutes % 60 + "m"
  }
  // Cards in the same grid row share quota and usage slots, so their bars line up.
  function rowMax(index, field) {
    var start = Math.floor(index / columns) * columns, best = 0
    for (var i = start; i < Math.min(start + columns, view.cards.length); i++) best = Math.max(best, view.cards[i][field].length)
    return best
  }
  function routerCount(id) {
    return id === root.router ? root.view.cards.length : RadarModel.buildCards(root.snapshot, root.now, {router: id}).cards.length
  }
  function usageText(m) {
    var usage = m.periods[root.period]
    return m.router + " · " + (usage ? root.compact(usage.tokens) + " tokens · " + root.compact(usage.requests) + " pedidos · US$ " + usage.cost.toFixed(2) : "uso indisponível")
  }
  function cycle(list, current, step) {
    var index = list.findIndex(x => x.id === current)
    return list[(index + step + list.length) % list.length].id
  }
  function cycleRouter(step) { router = cycle(routerTabs, router, step) }
  function cycleSort() { sort = cycle(sorts, sort, 1) }
  function cyclePeriod() { period = cycle(periods, period, 1) }
  function selectRouter(index) { if (index < routerTabs.length) router = routerTabs[index].id }
  function scrollBy(amount) { list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + amount)) }
  onRouterChanged: { list.contentY = 0; savePrefs() }
  onSortChanged: { list.contentY = 0; savePrefs() }
  onPeriodChanged: savePrefs()
  onRouterTabsChanged: if (!routerTabs.some(t => t.id === router)) router = "all"
  Timer { interval: 60000; running: true; repeat: true; onTriggered: root.now = Date.now() }

  // Remember the chosen router, order and period between openings.
  property bool prefsLoaded: false
  function savePrefs() { if (prefsLoaded) prefs.setText(JSON.stringify({router: router, sort: sort, period: period})) }
  FileView {
    id: prefs
    path: Quickshell.env("HOME") + "/.local/state/omarchy-trackers/routers/view.json"
    printErrors: false
    onLoaded: {
      try {
        var saved = JSON.parse(text())
        if (root.sorts.some(s => s.id === saved.sort)) root.sort = saved.sort
        if (root.periods.some(p => p.id === saved.period)) root.period = saved.period
        if (typeof saved.router === "string") root.router = saved.router
      } catch (e) {}
      root.prefsLoaded = true
    }
    onLoadFailed: root.prefsLoaded = true
  }

  component Chip: Rectangle {
    id: chip
    property string label: ""
    property bool selected: false
    property bool alert: false
    signal clicked()
    width: chipText.implicitWidth + Style.space(22); height: Style.space(26); radius: Style.space(6)
    color: selected ? root.faint(.14) : chipMouse.containsMouse ? root.faint(.07) : "transparent"
    border.width: 1; border.color: root.faint(selected ? .22 : .1)
    Row {
      anchors.centerIn: parent; spacing: Style.space(6)
      Rectangle { visible: chip.alert; anchors.verticalCenter: parent.verticalCenter; width: Style.space(6); height: width; radius: width / 2; color: "#ef4444" }
      Text { id: chipText; text: chip.label; color: root.foreground; opacity: chip.selected ? 1 : .65; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: chip.selected }
    }
    MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
  }

  Column {
    id: header
    width: parent.width; spacing: Style.space(10)
    Item {
      width: parent.width; height: Style.space(28)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "9Router · cotas"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.bold: true
      }
      Row {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(10)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.view.cards.length + " contas · " + (root.snapshot.updatedAt ? "atualizado " + Qt.formatDateTime(new Date(root.snapshot.updatedAt * 1000), "HH:mm") : "aguardando leitura")
          color: root.foreground; opacity: .5; font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
        Chip { label: root.snapshot.refreshing ? "Atualizando…" : "↻ Atualizar"; onClicked: root.refreshRequested() }
      }
    }
    Flow {
      width: parent.width; spacing: Style.space(6)
      Repeater {
        model: root.routerTabs
        delegate: Chip {
          required property var modelData
          required property int index
          label: modelData.name + "  " + root.routerCount(modelData.id)
          selected: root.router === modelData.id
          alert: !!modelData.error && modelData.error !== "Aguardando leitura"
          onClicked: root.router = modelData.id
        }
      }
    }
    Item {
      width: parent.width; height: Style.space(26)
      Row {
        spacing: Style.space(4)
        Repeater {
          model: root.sorts
          delegate: Chip { required property var modelData; label: modelData.label; selected: root.sort === modelData.id; onClicked: root.sort = modelData.id }
        }
      }
      Row {
        anchors.right: parent.right; spacing: Style.space(4)
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Uso "; color: root.foreground; opacity: .45; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        Repeater {
          model: root.periods
          delegate: Chip { required property var modelData; label: modelData.label; selected: root.period === modelData.id; onClicked: root.period = modelData.id }
        }
      }
    }
  }

  Flickable {
    id: list
    anchors.top: header.bottom; anchors.topMargin: Style.space(12)
    anchors.bottom: footer.top; anchors.bottomMargin: Style.space(8)
    anchors.left: parent.left; anchors.right: parent.right
    clip: true; contentHeight: grid.implicitHeight; contentWidth: width
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    Grid {
      id: grid
      columns: root.columns; spacing: root.gap
      Repeater {
        model: root.view.cards
        delegate: Rectangle {
          id: card
          required property var modelData
          required property int index
          width: root.cardWidth; height: body.implicitHeight + Style.space(24)
          radius: Style.space(8)
          color: root.faint(.035); border.width: 1; border.color: root.faint(.09)
          opacity: modelData.active ? 1 : .5
          Column {
            id: body
            x: Style.space(12); y: Style.space(12); width: parent.width - Style.space(24); spacing: Style.space(8)
            Item {
              width: parent.width; height: Style.space(34)
              Rectangle {
                id: iconBox
                width: Style.space(34); height: width; radius: Style.space(7); color: root.faint(.06); clip: true
                Image {
                  id: icon
                  anchors.fill: parent; anchors.margins: Style.space(3)
                  source: Qt.resolvedUrl("icons/" + card.modelData.icon + ".png")
                  sourceSize.width: 96; sourceSize.height: 96
                  fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                }
                Text { visible: icon.status !== Image.Ready; anchors.centerIn: parent; text: card.modelData.title.charAt(0); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
              }
              Column {
                anchors.left: iconBox.right; anchors.leftMargin: Style.space(10); anchors.right: routes.left; anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(2)
                Text { width: parent.width; text: card.modelData.title; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                Text { width: parent.width; text: card.modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; opacity: .6; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
              Row {
                id: routes
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(4)
                Repeater {
                  model: root.router === "all" ? card.modelData.members : []
                  delegate: Rectangle {
                    required property var modelData
                    readonly property bool preferred: card.modelData.route === modelData.router
                    width: routeText.implicitWidth + Style.space(12); height: Style.space(18); radius: height / 2
                    color: preferred ? Qt.rgba(0.13, 0.77, 0.37, .15) : root.faint(.06)
                    border.width: 1; border.color: preferred ? Qt.rgba(0.13, 0.77, 0.37, .45) : root.faint(.1)
                    Text { id: routeText; anchors.centerIn: parent; text: modelData.router; color: parent.preferred ? "#22c55e" : root.foreground; opacity: modelData.active ? 1 : .5; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }
                }
              }
            }
            Text {
              width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
              text: card.modelData.quotas.length + (card.modelData.quotas.length === 1 ? " quota" : " quotas")
                + (card.modelData.note ? " · " + card.modelData.note : "")
                + (card.modelData.stale ? " · leitura de " + root.duration(card.modelData.updatedAgoMs) + " atrás" : "")
              color: card.modelData.band === 3 ? "#ef4444" : root.foreground; opacity: card.modelData.band === 3 ? .9 : .45
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
            Column {
              width: parent.width; height: root.rowMax(card.index, "quotas") * Style.space(30)
            Repeater {
              model: card.modelData.quotas
              delegate: Item {
                id: quota
                required property var modelData
                width: body.width; height: Style.space(30)
                Rectangle { id: dot; anchors.verticalCenter: parent.verticalCenter; width: Style.space(8); height: width; radius: width / 2; color: root.toneColor(quota.modelData.tone) }
                Text {
                  id: quotaLabel
                  anchors.left: dot.right; anchors.leftMargin: Style.space(7); anchors.verticalCenter: parent.verticalCenter
                  width: body.width * .3; elide: Text.ElideRight; textFormat: Text.PlainText
                  text: quota.modelData.label; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                }
                Text {
                  id: resetLabel
                  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(92); horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                  text: quota.modelData.expired ? "renovou" : quota.modelData.resetMs > 0 ? "em " + root.duration(quota.modelData.resetMs) : "N/A"
                  color: root.foreground; opacity: quota.modelData.resetMs > 0 ? .85 : .45; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: quota.modelData.resetMs > 0
                }
                Item {
                  anchors.left: quotaLabel.right; anchors.leftMargin: Style.space(8)
                  anchors.right: resetLabel.left; anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter; height: Style.space(24)
                  Rectangle {
                    id: track
                    width: parent.width; height: Style.space(4); radius: height / 2
                    color: quota.modelData.tone === "none" ? root.faint(.08) : Qt.rgba(root.toneColor(quota.modelData.tone).r, root.toneColor(quota.modelData.tone).g, root.toneColor(quota.modelData.tone).b, .15)
                    Rectangle {
                      width: parent.width * (quota.modelData.unlimited ? 100 : quota.modelData.remaining || 0) / 100
                      height: parent.height; radius: height / 2; color: root.toneColor(quota.modelData.tone)
                    }
                  }
                  Text {
                    anchors.left: parent.left; anchors.bottom: parent.bottom
                    text: quota.modelData.usage; color: root.foreground; opacity: .5; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  }
                  Text {
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    text: quota.modelData.unlimited ? "ilimitado" : quota.modelData.remaining === null ? "—" : quota.modelData.remaining + "%"
                    color: root.toneColor(quota.modelData.tone); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                  }
                }
              }
            }
            }
            Rectangle { width: parent.width; height: 1; color: root.faint(.08) }
            Column {
              width: parent.width; spacing: Style.space(3)
            Repeater {
              model: card.modelData.members
              delegate: Text {
                required property var modelData
                width: body.width; elide: Text.ElideRight; textFormat: Text.PlainText
                text: root.usageText(modelData)
                color: root.foreground; opacity: .5; font.family: root.fontFamily; font.pixelSize: Style.font.caption
              }
            }
            Item { width: 1; height: Math.max(0, root.rowMax(card.index, "members") - card.modelData.members.length) * (Style.font.caption + Style.space(6)) }
            }
          }
        }
      }
    }
    Text {
      visible: !root.view.cards.length
      text: root.snapshot.refreshing ? "Buscando contas…" : "Nenhuma conta neste router."
      color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body
    }
  }

  Text {
    id: footer
    anchors.bottom: parent.bottom; width: parent.width; elide: Text.ElideRight
    text: "← → router · 0–9 escolhe · S ordem · P período · R atualiza · leitura a cada 5 min" + (root.view.hidden ? " · " + root.view.hidden + " removidas ocultas" : "")
    color: root.foreground; opacity: .4; font.family: root.fontFamily; font.pixelSize: Style.font.caption
  }
}
