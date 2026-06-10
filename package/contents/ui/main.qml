import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "utils.js" as Utils

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.StandardBackground
    Plasmoid.icon: "system-run"

    // -- state --
    property string serverUrl: "http://localhost:4096"
    property var messages: []
    property string sessionId: ""
    property var availableModels: []
    property string selectedProviderId: ""
    property string selectedModelId: ""
    property int connectionStatus: 0
    property bool loading: false

    // -- full representation --
    fullRepresentation: ColumnLayout {
        id: layout
        implicitWidth: 420
        implicitHeight: 540
        spacing: 6
        anchors.margins: 4

        // header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#1a1a1a"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                StatusIndicator {
                    id: statusDot
                    status: root.connectionStatus
                }

                ModelSelector {
                    id: modelSelector
                    Layout.fillWidth: true
                    models: root.availableModels
                    enabled: root.connectionStatus === 1
                    onModelSelected: function(modelId) {
                        var parts = modelId.split("/")
                        root.selectedProviderId = parts[0]
                        root.selectedModelId = parts.length > 1 ? parts.slice(1).join("/") : parts[0]
                    }
                }

            }
        }

        // chat area
        ChatView {
            id: chatView
            Layout.fillWidth: true
            Layout.fillHeight: true
            messages: root.messages
            loading: root.loading
            loadingText: selectedModelId
                ? "Thinking with " + selectedProviderId + "/" + selectedModelId + "..."
                : "Thinking..."
        }

        // status bar
        Label {
            visible: root.connectionStatus !== 1
            text: root.connectionStatus === 0
                ? "Connecting to opencode..."
                : root.connectionStatus === 2
                    ? "Server offline — run 'opencode serve'"
                    : ""
            color: root.connectionStatus === 2 ? "#F44336" : "#FFA726"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.bottomMargin: -2
        }

        // input
        InputBar {
            id: inputBar
            Layout.fillWidth: true
            enabled: root.connectionStatus === 1
            loading: root.loading
            onSend: function(text) { sendMessage(text) }
            onNewChat: resetChat()
        }
    }

    // -- initialization --
    Component.onCompleted: {
        console.log("AI Chat widget starting")
        checkHealth()
    }

    // -- HTTP --
    function httpRequest(method, path, body, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, root.serverUrl + path, true)

        if (body) {
            xhr.setRequestHeader("Content-Type", "application/json")
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var data = null
                var error = xhr.status !== 200 && xhr.status !== 201 && xhr.status !== 204
                if (!error && xhr.responseText) {
                    try { data = JSON.parse(xhr.responseText) }
                    catch (e) { error = true }
                }
                callback(error, data, xhr.status)
            }
        }

        xhr.send(body ? JSON.stringify(body) : null)
    }

    function checkHealth() {
        root.connectionStatus = 0
        httpRequest("GET", "/global/health", null, function(error, data) {
            if (!error && data && (data.healthy || data.status === "ok")) {
                root.connectionStatus = 1
                console.log("Server connected, version:", data.version || "unknown")
                fetchProviders()
            } else {
                root.connectionStatus = 2
                console.log("Health check failed: " + (data ? JSON.stringify(data) : "no response"))
            }
        })
    }

    function fetchProviders() {
        httpRequest("GET", "/provider", null, function(error, data) {
            if (!error && data) {
                root.availableModels = Utils.buildModelList(data)
            } else {
                console.log("Failed to fetch providers, trying /config")
                httpRequest("GET", "/config", null, function(err2, data2) {
                    if (!err2 && data2) {
                        root.availableModels = Utils.buildModelListFromConfig(data2)
                    }
                })
            }
        })
    }

    function createSession(callback) {
        httpRequest("POST", "/session", null, function(error, data) {
            if (!error && data && data.id) {
                root.sessionId = data.id
                console.log("Session created:", data.id)
                if (callback) callback(true)
            } else {
                console.log("Session creation failed")
                if (callback) callback(false)
            }
        })
    }

    function sendMessage(text) {
        if (!root.sessionId) {
            root.loading = true
            createSession(function(success) {
                if (success) {
                    doSendMessage(text)
                } else {
                    root.loading = false
                    addMessage("assistant", "Error: Could not create session. Is the server running?")
                }
            })
        } else {
            doSendMessage(text)
        }
    }

    function doSendMessage(text) {
        addMessage("user", text)
        root.loading = true

        var now = Date.now()
        var r1 = Math.random().toString(36).substring(2, 22)
        var r2 = Math.random().toString(36).substring(2, 22)
        var msgId = "msg_" + now + "001" + r1
        var partId = "prt_" + now + "002" + r2

        var body = {
            agent: "build",
            model: {
                modelID: root.selectedModelId,
                providerID: root.selectedProviderId
            },
            messageID: msgId,
            parts: [{
                id: partId,
                type: "text",
                text: text
            }]
        }

        httpRequest("POST", "/session/" + root.sessionId + "/prompt_async", body, function(error) {
            if (error) {
                root.loading = false
                addMessage("assistant", "Error: Failed to send prompt")
                return
            }
            pollForResponse(root.sessionId)
        })
    }

    function pollForResponse(sessionId) {
        var maxPolls = 120
        var pollCount = 0
        var seenIds = {}

        var timerId = setInterval(function() {
            if (pollCount >= maxPolls) {
                clearInterval(timerId)
                root.loading = false
                addMessage("assistant", "No response from " + root.selectedProviderId + "/" + root.selectedModelId + " (timeout). Try a different model or provider.")
                return
            }
            pollCount++

            httpRequest("GET", "/session/" + sessionId + "/message?limit=20", null, function(error, data) {
                if (error || !data) return

                var msgs = data.data || data
                if (!Array.isArray(msgs)) return

                for (var i = 0; i < msgs.length; i++) {
                    var msg = msgs[i]
                    if (!msg || !msg.id || seenIds[msg.id]) continue
                    seenIds[msg.id] = true

                    var role = msg.info ? msg.info.role : ""
                    if (role !== "assistant") continue

                    var parts = msg.parts || []
                    for (var j = 0; j < parts.length; j++) {
                        if (parts[j].type === "text" && parts[j].text) {
                            clearInterval(timerId)
                            root.loading = false
                            addMessage("assistant", parts[j].text)
                            return
                        }
                    }
                }
            })
        }, 2000)
    }

    function addMessage(role, text) {
        root.messages = Utils.addMessage(role, text, root.messages)
    }

    function resetChat() {
        root.sessionId = ""
        root.messages = []
        if (root.connectionStatus === 1) {
            createSession(function(success) {
                if (!success) {
                    addMessage("assistant", "Warning: Could not create new session.")
                }
            })
        }
    }
}
