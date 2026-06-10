import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    property bool enabled: true
    property bool loading: false

    signal send(string text)
    signal newChat()

    spacing: 4
    Layout.fillWidth: true

    TextArea {
        id: inputField
        Layout.fillWidth: true
        Layout.minimumHeight: 36
        Layout.maximumHeight: 100
        enabled: root.enabled && !root.loading
        placeholderText: root.loading ? "Waiting for response..." : "Type a message..."
        color: "#e0e0e0"
        placeholderTextColor: "#666666"
        font.pixelSize: 13
        wrapMode: TextArea.WordWrap

        background: Rectangle {
            color: "#1e1e1e"
            radius: 6
            border.width: 1
            border.color: inputField.activeFocus ? "#3a7bd5" : "#333333"
        }

        Keys.onReturnPressed: function(event) {
            if (!(event.modifiers & Qt.ShiftModifier)) {
                event.accepted = true
                sendMessage()
            }
        }
    }

    Button {
        id: sendBtn
        enabled: inputField.text.trim().length > 0 && !root.loading
        implicitWidth: 36
        implicitHeight: 36
        text: "➤"
        onClicked: sendMessage()

        background: Rectangle {
            color: sendBtn.enabled ? "#3a7bd5" : "#333333"
            radius: 6
        }
        contentItem: Label {
            text: sendBtn.text
            color: "white"
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Button {
        id: newChatBtn
        enabled: !root.loading
        implicitWidth: 36
        implicitHeight: 36
        text: "↺"
        onClicked: root.newChat()

        background: Rectangle {
            color: newChatBtn.enabled ? "#444444" : "#333333"
            radius: 6
        }
        contentItem: Label {
            text: newChatBtn.text
            color: "white"
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    function sendMessage() {
        var text = inputField.text.trim()
        if (text.length > 0) {
            inputField.text = ""
            root.send(text)
        }
    }
}
