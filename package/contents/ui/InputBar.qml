import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    property bool loading: false

    SystemPalette { id: sysPal; colorGroup: SystemPalette.Active }

    readonly property color ibText: sysPal.windowText
    readonly property color ibBg: Qt.lighter(sysPal.window, 1.05)
    readonly property color ibFocusBorder: sysPal.highlight
    readonly property color ibBorder: Qt.rgba(sysPal.windowText.r, sysPal.windowText.g, sysPal.windowText.b, 0.12)
    readonly property color ibRed: "#F44336"
    readonly property color ibDisabledText: Qt.darker(sysPal.windowText, 2)
    readonly property color ibBtnText: sysPal.highlightedText
    readonly property color ibSendBg: Qt.darker(sysPal.highlight, 1.5)

    signal send(string text)
    signal newChat()
    signal stopRequested()

    spacing: 4
    Layout.fillWidth: true

    function sendMessage() {
        if (root.loading) return;
        var text = inputField.text.trim();
        if (text.length > 0) {
            inputField.text = "";
            root.send(text);
        }
    }

    TextArea {
        id: inputField

        Layout.fillWidth: true
        Layout.minimumHeight: 34
        Layout.maximumHeight: 100
        enabled: root.enabled
        placeholderText: root.loading ? "Model is thinking..." : (!root.enabled ? "Server offline \u2014 open to connect" : "Type a message...")
        color: root.ibText
        placeholderTextColor: Qt.darker(sysPal.windowText, 1.8)
        font.pixelSize: 13
        wrapMode: TextArea.WordWrap

        Keys.onReturnPressed: function(event) {
            if (!(event.modifiers & Qt.ShiftModifier)) {
                event.accepted = true;
                if (!root.loading) root.sendMessage();
            }
        }

        background: Rectangle {
            color: root.ibBg
            radius: 4
            border.width: 1
            border.color: inputField.activeFocus ? root.ibFocusBorder : "transparent"
        }
    }

    Button {
        id: sendBtn

        implicitWidth: 34
        implicitHeight: 34
        visible: root.enabled
        enabled: inputField.text.trim().length > 0 && !root.loading
        text: "\u2191"
        onClicked: root.sendMessage()

        background: Rectangle {
            color: sendBtn.enabled ? (sendBtn.hovered ? root.ibFocusBorder : root.ibSendBg) : root.ibBg
            radius: 4
        }

        contentItem: Label {
            text: sendBtn.text
            color: sendBtn.enabled ? root.ibBtnText : root.ibDisabledText
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Button {
        id: stopBtn

        implicitWidth: 34
        implicitHeight: 34
        visible: root.loading
        text: "\u25A0"
        onClicked: root.stopRequested()

        background: Rectangle {
            color: stopBtn.hovered ? Qt.darker(root.ibRed, 1.1) : root.ibRed
            radius: 4
        }

        contentItem: Label {
            text: stopBtn.text
            color: root.ibBtnText
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Button {
        id: pasteBtn

        implicitWidth: 34
        implicitHeight: 34
        visible: root.enabled
        text: "\u2398"
        onClicked: inputField.paste()

        ToolTip {
            visible: pasteBtn.hovered
            text: "Paste from clipboard"
            delay: 300
        }

        background: Rectangle {
            color: pasteBtn.hovered ? Qt.lighter(root.ibBg, 1.05) : Qt.darker(root.ibBg, 1.5)
            radius: 4
        }

        contentItem: Label {
            text: pasteBtn.text
            color: Qt.darker(root.ibText, 1.3)
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
