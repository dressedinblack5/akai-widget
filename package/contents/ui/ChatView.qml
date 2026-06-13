import QtQuick
import QtQuick.Controls

ScrollView {
    id: root

    property var messages: []
    property bool loading: false
    property string loadingText: "Thinking..."

    SystemPalette { id: sysPal; colorGroup: SystemPalette.Active }

    readonly property color dimText: Qt.darker(sysPal.windowText, 1.5)
    readonly property color bubbleUserBg: Qt.darker(sysPal.highlight, 1.5)
    readonly property color bubbleUserBorder: sysPal.highlight
    readonly property color bubbleAsstBg: Qt.lighter(sysPal.window, 1.08)
    readonly property color bubbleAsstBorder: Qt.rgba(sysPal.windowText.r, sysPal.windowText.g, sysPal.windowText.b, 0.12)
    readonly property color bubbleText: sysPal.windowText
    readonly property color bubbleTime: dimText

    clip: true
    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

    ListView {
        id: listView

        anchors.fill: parent
        anchors.margins: 2
        model: root.messages
        spacing: 2
        property bool _userScrolledUp: false

        onContentYChanged: {
            if (contentHeight <= height) return;
            var atBottom = contentY >= contentHeight - height - 30;
            if (atBottom)
                _userScrolledUp = false;
            else
                _userScrolledUp = true;
        }

        onContentHeightChanged: {
            if (root.loading && !_userScrolledUp)
                Qt.callLater(positionViewAtEnd);
        }

        onCountChanged: {
            if (count > 0 && !_userScrolledUp)
                Qt.callLater(positionViewAtEnd);
        }

        delegate: MessageBubble {
            width: listView.width - 8
            role: model.role
            text: model.text
            time: model.time
            bubbleUserBg: root.bubbleUserBg
            bubbleUserBorder: root.bubbleUserBorder
            bubbleAsstBg: root.bubbleAsstBg
            bubbleAsstBorder: root.bubbleAsstBorder
            bubbleText: root.bubbleText
            bubbleTime: root.bubbleTime
        }

        header: Item {
            height: 4
            width: parent.width
        }

        footer: Item {
            height: root.loading ? 40 : 4
            width: parent.width

            Row {
                visible: root.loading
                anchors.centerIn: parent
                spacing: 2

                Label {
                    text: root.loadingText
                    color: root.dimText
                    font.pixelSize: 12
                }

                Label {
                    id: dots
                    text: "..."
                    color: root.dimText
                    font.pixelSize: 12

                    PropertyAnimation on opacity {
                        running: root.loading
                        loops: Animation.Infinite
                        from: 0.3
                        to: 1.0
                        duration: 600
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    Rectangle {
        id: scrollDownBtn
        width: 28
        height: 28
        radius: 14
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        visible: listView._userScrolledUp
        color: scrollHover.containsMouse ? Qt.darker(sysPal.highlight, 1.1) : sysPal.highlight
        opacity: 0.9

        Label {
            anchors.centerIn: parent
            text: "\u25BC"
            color: sysPal.highlightedText
            font.pixelSize: 12
        }

        MouseArea {
            id: scrollHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                listView._userScrolledUp = false;
                listView.positionViewAtEnd();
            }
        }

        ToolTip {
            visible: scrollHover.containsMouse
            text: "Scroll to bottom"
            delay: 300
        }
    }
}
