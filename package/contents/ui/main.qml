import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "code"
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "utils.js" as Utils

PlasmoidItem {
    id: root

    property bool _flashConnected: false

    SystemPalette { id: sysPal; colorGroup: SystemPalette.Active }

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.StandardBackground
    Plasmoid.icon: "dialog-messages"

    ChatEngine {
        id: engine

        serverUrl: "http://" + (plasmoid.configuration.serverHost || "localhost") + ":" + (plasmoid.configuration.serverPort || 4096)
        messageModel: messageModel
        processManager: processManager
        savedModel: plasmoid.configuration.lastModel || ""

        onMessageAdded: saveMessages()
    }

    ProcessManager {
        id: processManager

        onServerStarted: engine.checkHealth()
        onServerError: function(error) {
            engine.addMessage("assistant", "Server error: " + error);
        }
    }

    StorageHelper {
        id: storage
    }

    ListModel {
        id: messageModel
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: engine.resetChat()
    }

    function saveMessages() {
        var arr = [];
        for (var i = 0; i < messageModel.count; i++) {
            arr.push({
                role: messageModel.get(i).role,
                text: messageModel.get(i).text,
                time: messageModel.get(i).time
            });
        }
        storage.writeFile(storage.storagePath() + "/messages.json", JSON.stringify(arr));
    }

    function loadMessages() {
        var data = storage.readFile(storage.storagePath() + "/messages.json");
        if (data) {
            try {
                var msgs = JSON.parse(data);
                for (var i = 0; i < msgs.length; i++) {
                    messageModel.append(msgs[i]);
                }
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        loadMessages();
        engine.checkHealth();
        if (plasmoid.configuration.popupWidth <= 0) {
            plasmoid.configuration.popupWidth = Math.round(Screen.width * 0.5);
            plasmoid.configuration.popupHeight = Math.round(Screen.height * 0.85);
        }
    }

    onExpandedChanged: engine.setActive(root.expanded)

    compactRepresentation: Item {
        implicitWidth: 32
        implicitHeight: 32

        StatusIndicator {
            anchors.centerIn: parent
            status: engine.connectionStatus
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        id: popupOuter

        Layout.preferredWidth: plasmoid.configuration.popupWidth > 0 ? plasmoid.configuration.popupWidth : Math.round(Screen.width * 0.5)
        Layout.preferredHeight: plasmoid.configuration.popupHeight > 0 ? plasmoid.configuration.popupHeight : Math.round(Screen.height * 0.85)
        Layout.minimumWidth: 300
        Layout.minimumHeight: 400

        readonly property color themeBg: sysPal.window
        readonly property color themeText: sysPal.windowText
        readonly property color themeHighlight: sysPal.highlight
        readonly property color themeHighlightedText: sysPal.highlightedText
        readonly property color themeGreen: "#4CAF50"
        readonly property color themeRed: "#F44336"
        readonly property color themeOrange: "#FFA726"

        ColumnLayout {
            anchors.fill: parent
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: popupOuter.themeBg
                radius: 6

                RowLayout {
                    x: 4
                    y: 0
                    width: parent.width - 8
                    height: parent.height
                    spacing: 4

                    Item {
                        id: statusWrap
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10

                        HoverHandler { id: statusHover; cursorShape: Qt.PointingHandCursor }

                        StatusIndicator {
                            id: statusDot
                            status: engine.connectionStatus
                            disconnectedColor: Qt.rgba(popupOuter.themeText.r, popupOuter.themeText.g, popupOuter.themeText.b, 0.5)
                            connectedColor: popupOuter.themeGreen
                            errorColor: popupOuter.themeRed
                        }

                        TapHandler {
                            onTapped: {
                                if (engine.connectionStatus === 2)
                                    engine.checkHealth();
                            }
                        }

                        ToolTip {
                            visible: statusHover.hovered
                            text: engine.connectionStatus === 0 ? "Connecting..." :
                                  engine.connectionStatus === 1 ? "Server online" :
                                  "Health check failed — tap to retry"
                            delay: 500
                        }
                    }

                    ModelSelector {
                        id: modelSelector

                        Layout.fillWidth: true
                        models: engine.availableModels
                        enabled: engine.connectionStatus === 1

                        Component.onCompleted: {
                            engine.modelSelectorRef = modelSelector;
                        }

                        onModelSelected: function(modelId) {
                            var parts = modelId.split("/");
                            engine.selectedProviderId = parts[0];
                            engine.selectedModelId = parts.length > 1 ? parts.slice(1).join("/") : parts[0];
                            for (var mi = 0; mi < engine.availableModels.length; mi++) {
                                if (engine.availableModels[mi].value === modelId) {
                                    var d = engine.availableModels[mi].display;
                                    var ci = d.indexOf(": ");
                                    engine.selectedModelName = ci >= 0 ? d.substring(ci + 2) : d;
                                    break;
                                }
                            }
                            plasmoid.configuration.lastModel = modelId;
                        }
                    }

                    Item {
                        Layout.preferredWidth: clearBtn.visible ? 60 : 0
                        Layout.preferredHeight: 24

                        Rectangle {
                            id: clearBtn
                            anchors.fill: parent
                            radius: 4
                            visible: messageModel.count > 0
                            color: clearMouse.containsMouse ? popupOuter.themeRed : Qt.darker(popupOuter.themeBg, 1.3)

                            Label {
                                anchors.centerIn: parent
                                text: "Clear"
                                color: popupOuter.themeText
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: engine.resetChat()
                            }

                            ToolTip {
                                visible: clearMouse.containsMouse
                                text: "Clear chat history"
                                delay: 500
                            }
                        }
                    }
                }
            }

            ChatView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: engine.connectionStatus === 1
                messages: messageModel
                loading: engine.loading
                loadingText: engine.selectedModelName ? "Thinking with " + engine.selectedModelName : "Thinking"
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: engine.connectionStatus !== 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: engine.connectionStatus === 0 ? "Connecting..." : "Server offline"
                        color: engine.connectionStatus === 0 ? popupOuter.themeOrange : popupOuter.themeRed
                        font.pixelSize: 14
                    }

                    Button {
                        Layout.alignment: Qt.AlignHCenter
                        visible: engine.connectionStatus === 2
                        text: "Connect"
                        onClicked: engine.checkHealth()

                        background: Rectangle {
                            color: parent.hovered ? popupOuter.themeGreen : Qt.darker(popupOuter.themeGreen, 1.1)
                            radius: 6
                        }

                        contentItem: Label {
                            text: parent.text
                            color: popupOuter.themeHighlightedText
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                visible: engine.connectionStatus !== 1 || _flashConnected

                RowLayout {
                    anchors.fill: parent
                    spacing: 4
                    opacity: engine.connectionStatus !== 1 ? 1 : 0
                    visible: opacity > 0

                    Label {
                        text: engine.connectionStatus === 0 ? "Connecting\u2026" : "Server offline"
                        color: engine.connectionStatus === 2 ? popupOuter.themeRed : popupOuter.themeOrange
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 3
                        visible: engine.connectionStatus === 2
                        color: startBtn.hovered ? popupOuter.themeGreen : Qt.darker(popupOuter.themeGreen, 1.1)

                        Label {
                            anchors.centerIn: parent
                            text: processManager.serverRunning ? "\u21BB" : "\u25B6"
                            color: "white"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: startBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (processManager.serverRunning)
                                    processManager.restartServer();
                                else
                                    processManager.startServer();
                            }
                        }

                        ToolTip {
                            visible: startBtn.containsMouse
                            text: processManager.serverRunning ? "Restart server" : "Start server"
                            delay: 600
                        }
                    }

                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 3
                        visible: engine.connectionStatus === 2 && processManager.serverRunning
                    color: stopSrvBtn.hovered ? Qt.darker(popupOuter.themeRed, 1.1) : popupOuter.themeRed

                    Label {
                        anchors.centerIn: parent
                        text: "\u25A0"
                        color: popupOuter.themeHighlightedText
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: stopSrvBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: processManager.stopServer()
                        }

                        ToolTip {
                            visible: stopSrvBtn.containsMouse
                            text: "Stop server"
                            delay: 600
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 250 }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    text: "Connected"
                    color: popupOuter.themeGreen
                    font.pixelSize: 10
                    opacity: _flashConnected ? 0.9 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 500 }
                    }
                }
            }

            InputBar {
                Layout.fillWidth: true
                enabled: engine.connectionStatus === 1
                loading: engine.loading
                connectionStatus: engine.connectionStatus

                onSend: function(text) { engine.sendMessage(text); }
                onNewChat: engine.resetChat()
                onStopRequested: engine.stopGeneration()
                onConnectRequested: engine.checkHealth()
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 16
            height: 16
            color: "#40ffffff"

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.strokeStyle = "#80ffffff";
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(width - 6, height);
                    ctx.lineTo(width, height - 6);
                    ctx.moveTo(width - 10, height);
                    ctx.lineTo(width, height - 10);
                    ctx.stroke();
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor
                property real dragX: 0
                property real dragY: 0
                property real startW: 0
                property real startH: 0
                onPressed: {
                    dragX = mouseX;
                    dragY = mouseY;
                    startW = popupOuter.width;
                    startH = popupOuter.height;
                }
                onPositionChanged: {
                    if (!pressed) return;
                    var newW = Math.max(300, startW + (mouseX - dragX));
                    var newH = Math.max(400, startH + (mouseY - dragY));
                    plasmoid.configuration.popupWidth = Math.round(newW);
                    plasmoid.configuration.popupHeight = Math.round(newH);
                }
            }
        }
    }
    Connections {
        target: engine
        function onConnectionStatusChanged() {
            if (engine.connectionStatus === 1) {
                root._flashConnected = true;
                connectedTimer.restart();
            }
        }
    }

    Timer {
        id: connectedTimer
        interval: 2500
        repeat: false
        onTriggered: root._flashConnected = false
    }
}
