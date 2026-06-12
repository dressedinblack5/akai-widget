import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: ""
    property int columns: 1
    property int headerHeight: 28
    property color headerColor: "#2a2a2a"
    property color bodyColor: "#1a1a1a"
    property color borderColor: "#404040"
    property color titleColor: "#e0e0e0"
    property int childSpacing: 8

    default property alias data: contentArea.data

    implicitWidth: 280
    implicitHeight: headerHeight + (contentArea.implicitHeight > 0 ? contentArea.implicitHeight + 10 : 40)
    color: root.bodyColor
    radius: 6
    border.width: 1
    border.color: root.borderColor

    clip: true

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight
        color: root.headerColor

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.titleColor
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }
    }

    GridLayout {
        id: contentArea
        anchors.top: root.headerHeight > 0 ? parent.top + root.headerHeight + 4 : parent.top + 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        columns: root.columns
        columnSpacing: root.childSpacing
        rowSpacing: root.childSpacing
    }
}
