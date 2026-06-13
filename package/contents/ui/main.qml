import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "code"
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "utils.js" as Utils

PlasmoidItem {
    id: root

    SystemPalette { id: sysPal; colorGroup: SystemPalette.Active }

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.StandardBackground
    Plasmoid.icon: "dialog-messages"

    property bool showUsage: false

    ChatEngine {
        id: engine

        serverUrl: "http://" + (plasmoid.configuration.serverHost || "localhost") + ":" + (plasmoid.configuration.serverPort || 4096)
        messageModel: messageModel
        processManager: processManager
        usageTracker: usageTracker
        savedModel: plasmoid.configuration.lastModel || ""

        onMessageAdded: saveMessages()
    }

    ProcessManager {
        id: processManager

        onServerStarted: engine.checkHealth()
        onServerStopped: Qt.callLater(engine.checkHealth)
        onServerError: function(error) {
            engine.addMessage("assistant", "Server error: " + error);
            Qt.callLater(engine.checkHealth);
        }
    }

    StorageHelper {
        id: storage
    }

    UsageTracker {
        id: usageTracker
        storage: storage
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

    onExpandedChanged: {
        engine.setActive(root.expanded);
    }

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
            spacing: 2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: popupOuter.themeBg

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
                            Qt.callLater(function() { engine.selectDefaultModel(); });
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

                    Rectangle {
                        id: clearBtn
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 4
                        visible: messageModel.count > 0
                        color: clearMouse.containsMouse ? Qt.darker(popupOuter.themeRed, 1.1) : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: clearMouse.containsMouse ? popupOuter.themeHighlightedText : popupOuter.themeText
                            font.pixelSize: 14
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

                    Rectangle {
                        id: usageBtn
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 4
                        color: usageMouse.containsMouse ? Qt.darker(popupOuter.themeHighlight, 1.1) : (root.showUsage ? popupOuter.themeHighlight : "transparent")

                        Label {
                            anchors.centerIn: parent
                            text: "\u2607"
                            color: root.showUsage ? popupOuter.themeHighlightedText : (usageMouse.containsMouse ? popupOuter.themeHighlightedText : popupOuter.themeText)
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: usageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showUsage = !root.showUsage
                        }

                        ToolTip {
                            visible: usageMouse.containsMouse
                            text: root.showUsage ? "Back to chat" : "Usage statistics"
                            delay: 500
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ChatView {
                    anchors.fill: parent
                    visible: !root.showUsage && engine.connectionStatus === 1
                    messages: messageModel
                    loading: engine.loading
                    loadingText: engine.selectedModelName ? "Thinking with " + engine.selectedModelName : "Thinking"
                }

                Item {
                    anchors.fill: parent
                    visible: !root.showUsage && engine.connectionStatus !== 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: engine.connectionStatus === 0 ? "Connecting\u2026" : "Server offline"
                            color: engine.connectionStatus === 0 ? popupOuter.themeOrange : popupOuter.themeRed
                            font.pixelSize: 14
                            opacity: engine.connectionStatus === 0 ? 0.4 : 1.0

                            SequentialAnimation on opacity {
                                running: engine.connectionStatus === 0
                                loops: Animation.Infinite
                                PropertyAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                                PropertyAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutQuad }
                            }
                        }

                        Rectangle {
                            id: statusPulse
                            Layout.alignment: Qt.AlignHCenter
                            width: 12
                            height: 12
                            radius: 6
                            visible: engine.connectionStatus === 0
                            color: popupOuter.themeOrange

                            SequentialAnimation on opacity {
                                running: engine.connectionStatus === 0
                                loops: Animation.Infinite
                                PropertyAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                                PropertyAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                            }
                        }

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            visible: engine.connectionStatus === 0 || engine.connectionStatus === 2
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 4
                                color: srvStartBtn.containsMouse ? popupOuter.themeGreen : Qt.darker(popupOuter.themeGreen, 1.1)

                                Label {
                                    anchors.centerIn: parent
                                    text: processManager.serverRunning ? "\u21BB" : "\u25B6"
                                    color: "white"
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: srvStartBtn
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
                                    visible: srvStartBtn.containsMouse
                                    text: processManager.serverRunning ? "Restart server" : "Start server"
                                    delay: 500
                                }
                            }

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 4
                                visible: processManager.serverRunning
                                color: srvStopBtn.containsMouse ? Qt.darker(popupOuter.themeRed, 1.1) : popupOuter.themeRed

                                Label {
                                    anchors.centerIn: parent
                                    text: "\u25A0"
                                    color: popupOuter.themeHighlightedText
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: srvStopBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: processManager.stopServer()
                                }

                                ToolTip {
                                    visible: srvStopBtn.containsMouse
                                    text: "Stop server"
                                    delay: 500
                                }
                            }
                        }
                    }
                }

                UsageDashboard {
                    anchors.fill: parent
                    visible: root.showUsage
                    usageTracker: usageTracker
                    themeBg: popupOuter.themeBg
                    themeText: popupOuter.themeText
                    themeMuted: Qt.darker(popupOuter.themeText, 1.5)
                    themeAccent: popupOuter.themeHighlight

                    onCloseRequested: root.showUsage = false
                }
            }

            InputBar {
                Layout.fillWidth: true
                visible: !root.showUsage
                enabled: engine.connectionStatus === 1
                loading: engine.loading

                onSend: function(text) { engine.sendMessage(text); }
                onNewChat: engine.resetChat()
                onStopRequested: engine.stopGeneration()
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 16
            height: 16
            color: "#20ffffff"

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.strokeStyle = "#40ffffff";
                    ctx.lineWidth = 1;
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

}
