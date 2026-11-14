import QtQuick
import QtQuick.Controls
import qs.Commons

Rectangle {
  id: root
  required property var total
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  readonly property color tone: ({green: "#22c55e", yellow: "#eab308", red: "#ef4444"})[total.tone] || foreground
  function faint(alpha) { return Qt.rgba(foreground.r, foreground.g, foreground.b, alpha) }
  function percent(value) { return String(value).replace(".", ",") + "%" }
  function duration(ms) {
    var minutes = Math.max(1, Math.ceil(ms / 60000))
    if (minutes < 60) return minutes + " min"
    if (minutes < 1440) return Math.floor(minutes / 60) + "h" + (minutes % 60 ? " " + minutes % 60 + "min" : "")
    return Math.floor(minutes / 1440) + "d " + Math.floor(minutes % 1440 / 60) + "h"
  }
  readonly property string readinessDetails: "Ativas, com cota recente e sem erro conhecido na rota."
    + (total.exhausted ? "\nCota esgotada: " + total.exhausted : "")
    + (total.unavailable ? "\nRota indisponível: " + total.unavailable : "")
    + (total.unread ? "\nSem leitura atual: " + total.unread : "")
    + (total.paused ? "\nPausadas: " + total.paused : "")
  width: parent.width; height: body.implicitHeight + Style.space(32)
  color: faint(.035); border.width: 1; border.color: faint(.1); radius: Style.space(8)
  Column {
    id: body
    x: Style.space(16); y: Style.space(16); width: parent.width - Style.space(32); spacing: Style.space(12)
    Item {
      width: parent.width; height: Style.space(28)
      Image { id: icon; width: Style.space(28); height: width; source: Qt.resolvedUrl("icons/" + root.total.icon + ".png"); fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
      Text { anchors.left: icon.right; anchors.leftMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: root.total.title; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.bold: true }
      Text {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: !root.total.accounts ? "" : root.total.unknownPlans ? "total incompleto" : !root.total.known ? "sem leitura" : (root.total.partial ? "≥ " : "") + (root.total.partial ? Math.floor(root.total.ratio * 100) : Math.round(root.total.ratio * 100)) + "% restantes"
        color: root.foreground; opacity: .6; font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
    }
    Row {
      spacing: Style.space(10)
      Text {
        text: !root.total.accounts || !root.total.known ? "—" : (root.total.partial ? "≥ " : "") + root.percent(root.total.remaining)
        color: root.tone; font.family: root.fontFamily; font.pixelSize: Style.font.heading * 1.75; font.bold: true
      }
      Text {
        anchors.baseline: parent.children[0].baseline
        text: "/ " + root.percent(root.total.maximum) + (root.total.unknownPlans ? " + ?" : "")
        color: root.foreground; opacity: .6; font.family: root.fontFamily; font.pixelSize: Style.font.heading
      }
    }
    Text { text: "saldo restante / potencial máximo"; color: root.foreground; opacity: .55; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
    Rectangle {
      width: parent.width; height: Style.space(6); radius: height / 2; color: root.faint(.1)
      Rectangle { width: parent.width * root.total.ratio; height: parent.height; radius: height / 2; color: root.tone }
    }
    Item {
      visible: root.total.accounts > 0
      width: parent.width; height: Style.font.caption + Style.space(4)
      Text {
        text: root.total.ready + "/" + root.total.accounts + " prontas agora"
        color: root.foreground; opacity: .8; font.family: root.fontFamily; font.pixelSize: Style.font.caption
        HoverHandler { id: readyHover }
        ToolTip.visible: readyHover.hovered
        ToolTip.delay: 350
        ToolTip.text: root.readinessDetails
      }
      Text {
        anchors.right: parent.right
        text: root.total.nextResetMs > 0 ? (root.total.partial ? "Próx. conhecida em " : "1ª renovação em ") + root.duration(root.total.nextResetMs) : "Renovação sem leitura"
        color: root.foreground; opacity: .7; font.family: root.fontFamily; font.pixelSize: Style.font.caption
        HoverHandler { id: resetHover }
        ToolTip.visible: resetHover.hovered
        ToolTip.delay: 350
        ToolTip.text: "Primeira renovação da janela usada na soma. Cada conta tem seu horário; inclui pausadas."
      }
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap
      text: !root.total.accounts ? "Nenhuma conta cadastrada" : root.total.accounts + " contas"
        + (root.total.provider === "claude" ? " · " + root.total.twenty + " de 20x · " + root.total.five + " de 5x" : " · cada conta cheia vale 100%")
        + (root.total.paused ? " · " + root.total.paused + (root.total.paused === 1 ? " pausada" : " pausadas") : "")
      color: root.foreground; opacity: .65; font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }
    Text {
      visible: root.total.partial; width: parent.width; wrapMode: Text.WordWrap
      text: [root.total.missing ? root.total.missing + " sem leitura atual" : "", root.total.unknownPlans ? root.total.unknownPlans + " sem plano identificado" : ""].filter(x => x).join(" · ")
      color: "#eab308"; font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }
  }
}
