import QtQuick
import QtQuick.Controls
import qs.Commons
import "RadarModel.js" as RadarModel

Item {
  id: root
  property var snapshot: ({routers: []})
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property string period: "today"
  property double now: Date.now()
  readonly property var radar: RadarModel.buildRows(snapshot, now)
  signal refreshRequested()
  function compact(n) { return n >= 1000000 ? (n / 1000000).toFixed(1) + "M" : n >= 1000 ? (n / 1000).toFixed(1) + "k" : String(n || 0) }
  function providerName(p) { return p.indexOf("compatible") >= 0 ? "API compatível" : ({codex:"Codex",claude:"Claude","grok-cli":"Grok",github:"Copilot",antigravity:"Antigravity",cursor:"Cursor","devin-cli":"Devin",gemini:"Gemini"})[p] || p }
  function duration(ms) {
    if (ms <= 0) return ""
    var minutes = Math.ceil(ms / 60000)
    return minutes < 60 ? minutes + "min" : minutes < 1440 ? Math.floor(minutes / 60) + "h " + minutes % 60 + "min" : Math.floor(minutes / 1440) + "d " + Math.floor(minutes % 1440 / 60) + "h"
  }
  function quotaLabel(q) {
    var label = q.label.replace(" (7d)", "").replace(" (5h)", "").replace("weekly", "semana").replace("session", "sessão")
    return label + " " + (q.unlimited ? "sem teto" : q.percent !== null ? q.percent + "% usado" : "sem leitura")
  }
  function memberLabel(m, preferred) {
    var usage = m.account.periods[root.period]
    return m.router.name + (preferred ? " · usar aqui" : "") + " · " + (usage ? root.compact(usage.tokens) + " tokens · " + root.compact(usage.requests) + " pedidos · US$ " + usage.cost.toFixed(2) : "uso indisponível") + (m.note ? " · " + m.note : "")
  }
  function scrollBy(amount) { list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + amount)) }
  onPeriodChanged: list.contentY = 0
  Timer { interval: 60000; running: true; repeat: true; onTriggered: root.now = Date.now() }
  Column {
    id: header
    width: parent.width; spacing: Style.space(9)
    Row {
      width: parent.width
      Text { width: parent.width - Style.space(105); text: "9Router · radar de contas"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.bold: true }
      Rectangle {
        width: Style.space(100); height: Style.space(25); radius: Style.space(5)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, refreshMouse.containsMouse ? .13 : .06)
        Text { anchors.centerIn: parent; text: root.snapshot.refreshing ? "Atualizando…" : "↻ Atualizar"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshRequested() }
      }
    }
    Row {
      width: parent.width; spacing: Style.space(12)
      Repeater {
        model: root.snapshot.routers || []
        delegate: Text {
          required property var modelData
          text: "● " + modelData.name + (modelData.error ? " · offline" : "")
          color: modelData.error ? Color.urgent : root.foreground; opacity: .65
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }
    }
    Text {
      width: parent.width
      text: root.radar.rows.length + " contas · " + root.radar.connections + " conexões · " + (root.snapshot.updatedAt ? "atualizado " + Qt.formatDateTime(new Date(root.snapshot.updatedAt * 1000), "HH:mm") : "aguardando leitura")
      color: root.foreground; opacity: .5; font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }
    Row {
      width: parent.width; spacing: Style.space(6)
      Repeater {
        model: [{id:"today",label:"Hoje"},{id:"7d",label:"7 dias"},{id:"30d",label:"30 dias"},{id:"all",label:"Total"}]
        delegate: Rectangle {
          required property var modelData
          width: (header.width - Style.space(18)) / 4; height: Style.space(26); radius: Style.space(5)
          color: root.period === modelData.id ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .12) : "transparent"
          Text { anchors.centerIn: parent; text: modelData.label; color: root.foreground; opacity: root.period === modelData.id ? 1 : .5; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.period = modelData.id }
        }
      }
    }
  }
  Flickable {
    id: list
    anchors.top: header.bottom; anchors.topMargin: Style.space(12)
    anchors.bottom: footer.top; anchors.bottomMargin: Style.space(9)
    anchors.left: parent.left; anchors.right: parent.right
    clip: true; contentHeight: rows.implicitHeight; contentWidth: width
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    Column {
      id: rows
      width: list.width - Style.space(9); spacing: Style.space(9)
      Repeater {
        model: root.radar.rows
        delegate: Column {
          id: accountRow
          required property var modelData
          width: rows.width; spacing: Style.space(4)
          Text {
            visible: accountRow.modelData.sectionStart
            width: parent.width; height: implicitHeight + Style.space(5)
            text: accountRow.modelData.section
            color: root.foreground; opacity: .45; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
          }
          Row {
            width: parent.width
            Text {
              width: parent.width * .43
              text: (accountRow.modelData.band <= 1 ? accountRow.modelData.rank + ". " : "") + root.providerName(accountRow.modelData.provider)
              color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight
            }
            Text {
              width: parent.width * .57; horizontalAlignment: Text.AlignRight
              text: accountRow.modelData.band <= 1 ? accountRow.modelData.remaining + "% livre" + (accountRow.modelData.resetMs > 0 ? " · renova em " + root.duration(accountRow.modelData.resetMs) : "") : accountRow.modelData.note
              color: accountRow.modelData.band === 3 ? Color.urgent : accountRow.modelData.band <= 1 ? Color.accent : root.foreground
              opacity: accountRow.modelData.band <= 1 ? 1 : .6
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; textFormat: Text.PlainText
            }
          }
          Text {
            width: parent.width; text: accountRow.modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight
            color: root.foreground; opacity: .75; font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
          Rectangle {
            visible: accountRow.modelData.primary !== null
            width: parent.width; height: visible ? Style.space(3) : 0; radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .1)
            Rectangle {
              width: parent.width * Math.max(0, Math.min(100, accountRow.modelData.primary ? accountRow.modelData.primary.percent : 0)) / 100
              height: parent.height; radius: height / 2
              color: accountRow.modelData.band >= 3 ? Color.urgent : Color.accent
            }
          }
          Text {
            visible: accountRow.modelData.quotas.length > 0
            width: parent.width; wrapMode: Text.WordWrap
            text: accountRow.modelData.quotas.map(q => root.quotaLabel(q)).join(" · ") + (accountRow.modelData.band === 2 ? " · leitura anterior" : "")
            color: root.foreground; opacity: .5; font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
          Repeater {
            model: accountRow.modelData.members
            delegate: Text {
              required property var modelData
              width: accountRow.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
              text: root.memberLabel(modelData, accountRow.modelData.band <= 1 && accountRow.modelData.route === modelData.router.name)
              color: root.foreground; opacity: .6; font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
          }
          Rectangle { width: parent.width; height: 1; color: root.foreground; opacity: .08 }
        }
      }
      Text { visible: !root.radar.rows.length; text: root.snapshot.refreshing ? "Buscando contas…" : "Aguardando leitura das contas."; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
    }
  }
  Text {
    id: footer
    anchors.bottom: parent.bottom; width: parent.width; wrapMode: Text.WordWrap
    text: "Prioridade pela cota livre · sessão esgotada bloqueia.\nUso por router · leitura de limites a cada 5 min."
    color: root.foreground; opacity: .45; font.family: root.fontFamily; font.pixelSize: Style.font.caption
  }
}
