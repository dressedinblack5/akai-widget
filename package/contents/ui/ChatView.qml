import QtQuick
import QtQuick.Controls

ScrollView {
    id: root

    property var messages: []
    property bool loading: false
    property string loadingText: "Thinking..."

    clip: true

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: 4
        model: root.messages
        spacing: 4

        delegate: MessageBubble {
            width: listView.width - 8
            role: model.role
            text: model.text
            time: model.time
        }

        header: Item {
            height: 4
            width: parent.width
        }

        footer: Item {
            height: root.loading ? 40 : 4
            width: parent.width

            Label {
                visible: root.loading
                anchors.centerIn: parent
                text: root.loadingText
                color: "#888888"
                font.pixelSize: 12
                opacity: 0.7
            }
        }

        onCountChanged: {
            if (count > 0) positionViewAtEnd()
        }
    }
}
