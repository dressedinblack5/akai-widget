import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string role: "user"
    property string text: ""
    property string time: ""

    width: parent ? parent.width : 200
    height: bubbleColumn.implicitHeight + 16
    color: "transparent"

    ColumnLayout {
        id: bubbleColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 8
        }
        spacing: 2

        Rectangle {
            id: bubbleBg
            Layout.maximumWidth: parent ? parent.width * 0.85 : 300
            Layout.alignment: role === "user" ? Qt.AlignRight : Qt.AlignLeft
            implicitHeight: contentText.implicitHeight + 20
            radius: 8
            color: role === "user" ? "#2b5278" : "#2d2d2d"
            border.width: 1
            border.color: role === "user" ? "#3a7bd5" : "#404040"

            TextEdit {
                id: contentText
                anchors.fill: parent
                anchors.margins: 10
                textFormat: TextEdit.MarkdownText
                text: root.text
                color: "#e0e0e0"
                font.pixelSize: 13
                wrapMode: TextEdit.WordWrap
                readOnly: true
                selectByMouse: true
                onLinkActivated: function(link) {
                    Qt.openUrlExternally(link)
                }
            }
        }

        Label {
            text: root.time
            color: "#888888"
            font.pixelSize: 10
            Layout.alignment: role === "user" ? Qt.AlignRight : Qt.AlignLeft
            Layout.leftMargin: role === "user" ? 0 : 4
            Layout.rightMargin: role === "user" ? 4 : 0
        }
    }
}
