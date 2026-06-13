import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property string role: "user"
    property string text: ""
    property string time: ""

    property color bubbleUserBg: "#2b5278"
    property color bubbleUserBorder: "#3a7bd5"
    property color bubbleAsstBg: "#2d2d2d"
    property color bubbleAsstBorder: "#404040"
    property color bubbleText: "#e0e0e0"
    property color bubbleTime: "#888888"

    implicitHeight: bubbleArea.height + (timeLabel.visible ? timeLabel.height + 10 : 4)
    color: "transparent"

    Rectangle {
        id: bubbleArea

        anchors.right: role === "user" ? parent.right : undefined
        anchors.left: role === "user" ? undefined : parent.left
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        width: Math.min(contentText.implicitWidth + 24, parent.width * 0.88)
        height: contentText.implicitHeight + 14
        radius: 6
        color: role === "user" ? root.bubbleUserBg : root.bubbleAsstBg
        border.width: 1
        border.color: role === "user" ? root.bubbleUserBorder : root.bubbleAsstBorder
        clip: false

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.margins: 8
            contentWidth: contentText.implicitWidth
            contentHeight: contentText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: contentText

                textFormat: TextEdit.MarkdownText
                text: root.text
                color: root.bubbleText
                font.pixelSize: 13
                wrapMode: TextEdit.WordWrap
                readOnly: true
                selectByMouse: true
                width: flick.width

                onLinkActivated: function(link) {
                    if (link.indexOf("http://") === 0 || link.indexOf("https://") === 0)
                        Qt.openUrlExternally(link);
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 4
                background: null
            }
        }
    }

    Label {
        id: timeLabel

        anchors.top: bubbleArea.bottom
        anchors.topMargin: 2
        anchors.right: role === "user" ? bubbleArea.right : undefined
        anchors.left: role === "user" ? undefined : bubbleArea.left
        text: root.time
        visible: root.time.length > 0
        color: root.bubbleTime
        font.pixelSize: 10
    }
}
