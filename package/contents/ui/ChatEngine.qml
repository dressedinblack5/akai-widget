import QtQml
import QtQuick
import "utils.js" as Utils

Item {
    id: engine
    visible: false

    property string serverUrl: "http://localhost:4096"
    property int connectionStatus: 0
    property bool loading: false
    property string sessionId: ""
    property var availableModels: []
    property string selectedProviderId: ""
    property string selectedModelId: ""
    property string selectedModelName: ""
    property var cachedProviderData: null
    property var recentModelValues: []
    property var messageModel: null
    property var processManager: null
    property bool active: true

    property var sseXhr: null
    property string sseBuffer: ""
    property string sseResponseText: ""
    property bool streaming: false
    property int streamIndex: -1
    property int stallCount: 0
    property int sseFailCount: 0
    property bool _sseErrorShown: false
    property real _lastSseActivity: 0
    property int healthRetryCount: 0
    property var seenMessageIds: ({})
    property int promptSeq: 0
    property string _lastUserMessageId: ""
    property var modelSelectorRef: null
    property string savedModel: ""

    signal messageAdded(string role, string text, string time)

    function httpRequest(method, path, body, callback) {
        var xhr = new XMLHttpRequest();
        xhr.open(method, engine.serverUrl + path, true);
        xhr.timeout = 8000;
        if (body)
            xhr.setRequestHeader("Content-Type", "application/json");
        var safeCallback = function(error, data, status) {
            if (!engine) return;
            callback(error, data, status);
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var data = null;
                var error = xhr.status !== 200 && xhr.status !== 201 && xhr.status !== 204;
                if (xhr.responseText) {
                    try { data = JSON.parse(xhr.responseText); } catch (e) {}
                }
                safeCallback(error, data, xhr.status);
            }
        };
        xhr.ontimeout = function() { safeCallback(true, null, 0); };
        xhr.onerror = function() { safeCallback(true, null, 0); };
        xhr.send(body ? JSON.stringify(body) : null);
    }

    function checkHealth() {
        engine.connectionStatus = 0;
        engine.httpRequest("GET", "/global/health", null, function(error, data, status) {
            if (!error && data && (data.healthy || data.status === "ok")) {
                engine.connectionStatus = 1;
                engine.sseFailCount = 0;
                engine._sseErrorShown = false;
                engine.healthRetryCount = 0;
                engine.connectSSE();
                engine.fetchProviders();
                engine.createSession(function(success) {});
            } else {
                if (engine.processManager && engine.processManager.serverRunning && engine.healthRetryCount < 5) {
                    engine.healthRetryCount++;
                    healthRetryTimer.start();
                } else {
                    engine.connectionStatus = 2;
                    engine.healthRetryCount = 0;
                    if (engine.processManager && !engine.processManager.serverRunning)
                        engine.processManager.startServer();
                }
            }
        });
    }

    function connectSSE() {
        if (engine.sseXhr) {
            engine.sseXhr.abort();
            engine.sseXhr = null;
        }
        var xhr = new XMLHttpRequest();
        engine.sseXhr = xhr;
        engine.sseBuffer = "";
        engine._lastSseActivity = Date.now();
        xhr.open("GET", engine.serverUrl + "/global/event", true);
        xhr.timeout = 0;
        xhr.onerror = function() {
            if (!engine || engine.sseXhr !== xhr) return;
            engine.sseXhr = null;
            engine.sseFailCount++;
            if (engine.sseFailCount >= 3 && !engine._sseErrorShown && engine.active) {
                engine._sseErrorShown = true;
                engine.addMessage("assistant", "Live updates disconnected. Responses will use fallback polling.");
            }
            sseReconnectTimer.start();
        };
        xhr.onload = function() {
            if (!engine || engine.sseXhr !== xhr) return;
            engine.sseXhr = null;
            engine.sseFailCount++;
            sseReconnectTimer.start();
        };
        xhr.send(null);
    }

    function handleSSEEvent(event) {
        var payload = event.payload || event;
        if (!payload || !payload.type) return;

        var type = payload.type;
        var props = payload.properties || {};

        if (type === "session.error") {
            if (engine.loading) {
                engine.loading = false;
                responseTimeoutTimer.stop();
                fallbackPollerTimer.stop();
                engine.stallCount = 0;
            }
            var sessErr = props.error || {};
            var errMsg = (sessErr.data && sessErr.data.message) || sessErr.name || "Session error";
            finalizeResponse("Error: " + errMsg, true);
            return;
        }

        var evtSid = props.sessionID || "";
        if (evtSid !== engine.sessionId) return;

        if (type === "message.part.delta") {
            if (!engine.loading) return;
            engine.sseResponseText += props.delta || "";
            engine.stallCount = 0;

            if (!engine.streaming) {
                engine.streaming = true;
                engine.streamIndex = engine.messageModel.count;
                engine.messageModel.append({"role": "assistant", "text": engine.sseResponseText, "time": ""});
            } else if (engine.streamIndex >= 0) {
                engine.messageModel.setProperty(engine.streamIndex, "text", engine.sseResponseText);
            }
            return;
        }

        if (type === "message.part.updated") {
            if (!engine.loading) return;
            var part = props.part || {};
            if (part.synthetic) return;
            if (part.messageID === engine._lastUserMessageId) return;
            if (part.type === "text" && part.text && part.text.length > 0) {
                engine.sseResponseText = part.text;
                engine.stallCount = 0;

                if (!engine.streaming) {
                    engine.streaming = true;
                    engine.streamIndex = engine.messageModel.count;
                    engine.messageModel.append({"role": "assistant", "text": part.text, "time": ""});
                } else if (engine.streamIndex >= 0) {
                    engine.messageModel.setProperty(engine.streamIndex, "text", part.text);
                }
            }
            return;
        }

        if (type === "session.idle" || (type === "message.updated" && props.info && props.info.finish === "stop")) {
            var finalText = props.info && props.info.text ? props.info.text : engine.sseResponseText;
            finalizeResponse(finalText, false);
            return;
        }

        if (type === "error" || type === "message.error" || type === "provider.error" || type === "rate_limit") {
            var errMsg = props.message || props.error || (props.data && props.data.message) || "An error occurred";
            var code = props.code || "";
            var prefix = "Error";
            if (type === "rate_limit" || (code && code.indexOf("rate") >= 0))
                prefix = "Rate limited";
            else if (type === "provider.error")
                prefix = "Provider error";
            finalizeResponse(prefix + ": " + errMsg, true);
        }
    }

    function finalizeResponse(text, isError) {
        if (!engine.loading) return;

        engine.loading = false;
        responseTimeoutTimer.stop();
        fallbackPollerTimer.stop();
        engine.stallCount = 0;

        if (engine.streaming && engine.streamIndex >= 0) {
            if (text) {
                engine.messageModel.setProperty(engine.streamIndex, "text", text);
            } else {
                engine.messageModel.remove(engine.streamIndex);
            }
        } else if (text) {
            engine.addMessage("assistant", text);
        }

        engine.streaming = false;
        engine.streamIndex = -1;
        engine.sseResponseText = "";
    }

    function fetchProviders() {
        engine.httpRequest("GET", "/provider", null, function(error, data) {
            if (!error && data) {
                engine.cachedProviderData = data;
                engine.availableModels = Utils.buildModelList(data, engine.recentModelValues);
                engine.selectDefaultModel();
            } else {
                engine.httpRequest("GET", "/config", null, function(err2, data2) {
                    if (!err2 && data2) {
                        engine.cachedProviderData = data2;
                        engine.availableModels = Utils.buildModelListFromConfig(data2, engine.recentModelValues);
                        engine.selectDefaultModel();
                    }
                });
            }
        });
    }

    function rebuildModels() {
        if (!engine.cachedProviderData) return;
        engine.availableModels = Utils.buildModelList(engine.cachedProviderData, engine.recentModelValues);
    }

    function selectDefaultModel() {
        var models = engine.availableModels;
        if (!models || models.length === 0 || models[0].value === "") return;
        if (!engine.modelSelectorRef) return;

        var saved = engine.savedModel;
        if (saved) {
            var currentModel = engine.selectedProviderId + "/" + engine.selectedModelId;
            if (saved !== currentModel) {
                for (var si = 0; si < models.length; si++) {
                    if (models[si].value === saved) {
                        engine.modelSelectorRef.selectModel(saved);
                        return;
                    }
                }
            }
        }
        var priority = ["opencode-go", "ollama", "opencode", "google", "github-copilot", "horde"];
        for (var pi = 0; pi < priority.length; pi++) {
            for (var mi = 0; mi < models.length; mi++) {
                if (models[mi].value.indexOf(priority[pi] + "/") === 0) {
                    engine.modelSelectorRef.selectModel(models[mi].value);
                    return;
                }
            }
        }
        engine.modelSelectorRef.selectModel(models[0].value);
    }

    function createSession(callback) {
        engine.httpRequest("POST", "/session", {}, function(error, data) {
            if (!error && data && data.id) {
                engine.sessionId = data.id;
                if (callback) callback(true);
            } else {
                if (callback) callback(false);
            }
        });
    }

    function sendMessage(text) {
        if (!engine.sessionId) {
            engine.loading = true;
            engine.promptSeq++;
            engine.createSession(function(success) {
                if (success) engine.doSendMessage(text);
                else {
                    engine.loading = false;
                    engine.addMessage("assistant", "Error: Could not create session. Is the server running?");
                }
            });
        } else {
            engine.promptSeq++;
            engine.doSendMessage(text);
        }
    }

    function doSendMessage(text) {
        engine.addMessage("user", text);
        engine.loading = true;
        engine.streaming = false;
        engine.streamIndex = -1;
        engine.sseResponseText = "";
        engine.seenMessageIds = {};
        engine.stallCount = 0;
        engine._lastSseActivity = Date.now();

        var curValue = engine.selectedProviderId + "/" + engine.selectedModelId;
        var idx = engine.recentModelValues.indexOf(curValue);
        if (idx >= 0) engine.recentModelValues.splice(idx, 1);
        engine.recentModelValues.unshift(curValue);
        if (engine.recentModelValues.length > 5) engine.recentModelValues.splice(5);
        engine.rebuildModels();

        var now = Date.now();
        var r0 = Math.random().toString(36).substring(2, 22);
        var r1 = Math.random().toString(36).substring(2, 22);
        var r2 = Math.random().toString(36).substring(2, 22);
        var body = {
            "model": {"modelID": engine.selectedModelId, "providerID": engine.selectedProviderId},
            "messageID": "msg_" + now + "001" + r1,
            "parts": [
                {"id": "prt_" + now + "000" + r0, "type": "text", "text": "Be concise. Answer in 1-2 sentences. Do not repeat the question. Do not show your thought process.", "synthetic": true},
                {"id": "prt_" + now + "002" + r2, "type": "text", "text": text}
            ]
        };
        engine._lastUserMessageId = body.messageID;

        if (sseHeartbeatTimer.running) sseHeartbeatTimer.restart();
        responseTimeoutTimer.start();
        fallbackPollerTimer.start();

        engine.httpRequest("POST", "/session/" + engine.sessionId + "/prompt_async", body, function(error, data, status) {
            if (!engine.loading) return;
            if (error) {
                var msg = "Error: ";
                if (status === 429) msg += "Rate limited — too many requests. Wait and try a different model.";
                else if (status === 503) msg += "Service unavailable. The model provider may be down.";
                else if (status === 502) msg += "Bad gateway from provider. The model may be overloaded.";
                else if (status === 500) msg += "Internal server error from provider.";
                else if (status === 403) msg += "Access denied (403). The provider may require authentication.";
                else if (status === 401) msg += "Unauthorized (401). Check your API credentials.";
                else if (status === 400) msg += "Invalid request (400). The model may not accept this input.";
                else if (status === 0) msg += "Connection failed. Is the server running?";
                else msg += "Failed to send prompt (HTTP " + status + ")";
                if (data) {
                    if (data.error) msg += " (" + data.error + ")";
                    else if (data.message) msg += " (" + data.message + ")";
                }
                finalizeResponse(msg, true);
            }
        });
    }

    function addMessage(role, text) {
        var now = new Date();
        var h = now.getHours().toString().padStart(2, '0');
        var m = now.getMinutes().toString().padStart(2, '0');
        engine.messageModel.append({"role": role, "text": text, "time": h + ":" + m});
        engine.messageAdded(role, text, h + ":" + m);
    }

    function stopGeneration() {
        if (!engine.loading) return;

        if (engine.sessionId) {
            engine.httpRequest("POST", "/session/" + engine.sessionId + "/cancel", {}, function() {});
        }

        if (engine.sseXhr) {
            engine.sseXhr.abort();
            engine.sseXhr = null;
            engine.sseBuffer = "";
        }

        engine.addMessage("assistant", "_[stopped]_");
        finalizeResponse("", true);
    }

    function resetChat() {
        engine.loading = false;
        engine.streaming = false;
        engine.streamIndex = -1;
        engine.sseResponseText = "";
        engine.seenMessageIds = {};
        engine.stallCount = 0;
        engine.sessionId = "";
        engine.promptSeq++;

        responseTimeoutTimer.stop();
        fallbackPollerTimer.stop();
        engine.messageModel.clear();

        if (engine.connectionStatus === 1)
            engine.createSession(function(success) {
                if (!success) engine.addMessage("assistant", "Warning: Could not create new session.");
            });
    }

    function setActive(isActive) {
        engine.active = isActive === true;
        if (isActive) {
            sseReaderTimer.running = true;
            if (!engine.sseXhr && engine.connectionStatus === 1)
                engine.connectSSE();
        } else {
            if (!engine.loading) {
                sseReaderTimer.running = false;
                if (engine.sseXhr) {
                    engine.sseXhr.abort();
                    engine.sseXhr = null;
                    engine.sseBuffer = "";
                }
            }
        }
    }

    Timer {
        id: sseReconnectTimer
        interval: Math.min(2000 * Math.pow(2, engine.sseFailCount), 60000)
        repeat: false
        onTriggered: {
            if (engine.sseFailCount >= 10) {
                engine.connectionStatus = 2;
                return;
            }
            if (engine.connectionStatus !== 1) return;
            if (engine.sseFailCount >= 3) engine.checkHealth();
            else engine.connectSSE();
        }
    }

    Timer {
        id: healthRetryTimer
        interval: 2000
        repeat: false
        onTriggered: engine.checkHealth()
    }

    Timer {
        id: sseHeartbeatTimer
        interval: 15000
        repeat: true
        running: engine.sseXhr !== null
        onTriggered: {
            if (engine.sseXhr && (Date.now() - engine._lastSseActivity) > 15000 && engine.loading)
                engine.connectSSE();
        }
    }

    Timer {
        id: sseReaderTimer
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            var xhr = engine.sseXhr;
            if (!xhr) return;
            if (xhr.readyState !== 3 && xhr.readyState !== 4) return;

            var full = xhr.responseText;
            if (full.length === engine.sseBuffer.length) return;

            var newData = full.substring(engine.sseBuffer.length);
            engine.sseBuffer = full;

            if (newData.length > 0) {
                engine.sseFailCount = 0;
                engine._sseErrorShown = false;
                engine._lastSseActivity = Date.now();
                if (sseHeartbeatTimer.running) sseHeartbeatTimer.restart();
            }

            var lines = newData.split(/\r?\n/);
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("data: ") === 0) {
                    try {
                        engine.handleSSEEvent(JSON.parse(lines[i].substring(6)));
                    } catch (e) {}
                }
            }

            if (xhr.readyState === 4) {
                if (engine.sseXhr !== xhr) return;
                engine.sseXhr = null;
                sseReconnectTimer.start();
            }
        }
    }

    Timer {
        id: fallbackPollerTimer
        interval: 2000
        repeat: true
        onTriggered: {
            if (!engine.loading || !engine.sessionId) return;

            engine.httpRequest("GET", "/session/" + engine.sessionId + "/message?limit=10", null, function(error, data, status) {
                if (!engine.loading) return;

                if (error || !data) {
                    engine.stallCount++;
                    if (engine.stallCount >= 3) {
                        engine.stallCount = 0;
                        var tail = data && (data.error || data.message) ? " (" + (data.error || data.message) + ")" : "";
                        finalizeResponse("No response from " + engine.selectedModelName + " (poll failed" + tail + ").", true);
                    }
                    return;
                }

                var msgs = data.data || data;
                if (!Array.isArray(msgs)) return;

                var foundNew = false;
                for (var i = 0; i < msgs.length; i++) {
                    var msg = msgs[i];
                    if (!msg) continue;
                    var msgId = msg.info ? msg.info.id : "";
                    var role = msg.info ? msg.info.role : "";
                    if (role !== "assistant") continue;
                    if (msgId && engine.seenMessageIds[msgId]) continue;

                    var parts = msg.parts || [];
                    var hasText = false;
                    for (var j = 0; j < parts.length; j++) {
                        var pt = parts[j];
                        if (pt.type === "text" && pt.text && pt.text.length > 0) {
                            hasText = true;
                            foundNew = true;
                            engine.stallCount = 0;
                            if (msgId) engine.seenMessageIds[msgId] = true;
                            finalizeResponse(pt.text, false);
                            return;
                        }
                    }
                    if (!hasText) {
                        foundNew = true;
                        engine.stallCount = 0;
                    }
                }

                if (!foundNew) {
                    engine.stallCount++;
                    if (engine.stallCount >= 15) {
                        engine.stallCount = 0;
                        finalizeResponse("No response from " + engine.selectedModelName + " (stalled after 30s). Try a different model.", true);
                    }
                }
            });
        }
    }

    Timer {
        id: responseTimeoutTimer
        interval: 60000
        repeat: false
        onTriggered: {
            finalizeResponse("No response from " + engine.selectedModelName + " (60s timeout). Try a different model.", true);
        }
    }
}
