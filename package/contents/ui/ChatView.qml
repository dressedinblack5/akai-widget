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

    ListView {
        id: listView

        anchors.fill: parent
        anchors.margins: 2
        model: root.messages
        spacing: 2
        property bool _userScrolledUp: false

        onContentYChanged: {
            if (contentHeight > height && contentY < contentHeight - height - 30)
                _userScrolledUp = true;
        }

        onContentHeightChanged: {
            if (root.loading && !_userScrolledUp)
                positionViewAtEnd();
        }

        onCountChanged: {
            _userScrolledUp = false;
            if (count > 0)
                positionViewAtEnd();
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
}
