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
    property string sseLineRemainder: ""
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
    property int _sessionGen: 0
    property int _pollCount: 0

    signal messageAdded(string role, string text, string time)

    function httpRequest(method, path, body, callback, timeout) {
        var xhr = new XMLHttpRequest();
        xhr.open(method, engine.serverUrl + path, true);
        xhr.timeout = timeout || 8000;
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
        if (engine.processManager && !engine.processManager.serverRunning)
            engine.processManager.startServer();
        engine.httpRequest("GET", "/global/health", null, function(error, data, status) {
            if (!error && data && (data.healthy || data.status === "ok")) {
                engine.connectionStatus = 1;
                engine.sseFailCount = 0;
                engine._sseErrorShown = false;
                engine.healthRetryCount = 0;
                engine.connectSSE();
                engine.fetchProviders();
            } else {
                engine.healthRetryCount++;
                if (engine.healthRetryCount < 30)
                    healthRetryTimer.start();
                else
                    engine.connectionStatus = 2;
            }
        }, 3000);
    }

    function connectSSE() {
        console.log("[ChatEngine] connectSSE called, aborting existing connection:", !!engine.sseXhr);
        if (engine.sseXhr) {
            engine.sseXhr.abort();
            engine.sseXhr = null;
        }
        var xhr = new XMLHttpRequest();
        engine.sseXhr = xhr;
        engine.sseBuffer = "";
        engine.sseLineRemainder = "";
        engine._lastSseActivity = Date.now();
        console.log("[ChatEngine] SSE buffer reset, opening connection to:", engine.serverUrl + "/global/event");
        xhr.open("GET", engine.serverUrl + "/global/event", true);
        xhr.timeout = 0;
        xhr.onerror = function() {
            if (!engine || engine.sseXhr !== xhr) return;
            console.log("[ChatEngine] SSE error");
            engine.sseXhr = null;
            engine.sseFailCount++;
            if (engine.sseFailCount >= 5 && !engine._sseErrorShown && engine.active) {
                engine._sseErrorShown = true;
                engine.addMessage("assistant", "Live updates disconnected. Responses will use fallback polling.");
            }
            sseReconnectTimer.start();
        };
        xhr.onload = function() {
            if (!engine || engine.sseXhr !== xhr) return;
            console.log("[ChatEngine] SSE connection ended");
            engine.sseXhr = null;
            sseReconnectTimer.start();
        };
        xhr.send(null);
    }

    function handleSSEEvent(event) {
        if (!event || !event.type) return;

        var type = event.type;
        var props = event.payload || {};
        console.log("[ChatEngine] SSE event:", type);

        if (type === "session.error") {
            if (engine.loading) {
                engine.loading = false;
                responseTimeoutTimer.stop();
                fallbackPollerTimer.stop();
                engine.stallCount = 0;
            }
            var sessErr = props.error || {};
            var errMsg = (sessErr.data && sessErr.data.message) || sessErr.name || "Session error";
            engine.addMessage("assistant", "Error: " + errMsg);
            return;
        }

        if (type === "session.idle") {
            console.log("[ChatEngine] session.idle, loading:", engine.loading);
            if (engine.loading) {
                fallbackPollerTimer.stop();
                responseTimeoutTimer.stop();
                engine.stallCount = 0;
                engine.pollForResponse(true);
            }
            return;
        }
    }

    function addMessage(role, text) {
        var now = new Date();
        var h = now.getHours().toString().padStart(2, '0');
        var m = now.getMinutes().toString().padStart(2, '0');
        engine.messageModel.append({"role": role, "text": text, "time": h + ":" + m});
        engine.messageAdded(role, text, h + ":" + m);
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
                    } else {
                        engine.addMessage("assistant", "Error: Could not load providers. The server may be misconfigured.");
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
        var gen = ++engine._sessionGen;
        engine.httpRequest("POST", "/session", {}, function(error, data) {
            if (gen !== engine._sessionGen) return;
            if (!error && data && data.id) {
                engine.sessionId = data.id;
                if (callback) callback(true);
            } else {
                if (callback) callback(false);
            }
        });
    }

    function sendMessage(text) {
        console.log("[ChatEngine] sendMessage called, loading:", engine.loading);
        if (engine.loading) {
            console.log("[ChatEngine] sendMessage: blocked, already loading");
            return;
        }
        engine.loading = true;
        engine.promptSeq++;
        engine.createSession(function(success) {
            console.log("[ChatEngine] createSession callback, success:", success);
            if (success) engine.doSendMessage(text);
            else {
                engine.loading = false;
                engine.addMessage("assistant", "Error: Could not create session. Is the server running?");
            }
        });
    }

    function buildHistory() {
        if (!engine.messageModel || engine.messageModel.count === 0) return "";
        var lines = [];
        var start = Math.max(0, engine.messageModel.count - 20);
        for (var i = start; i < engine.messageModel.count; i++) {
            var m = engine.messageModel.get(i);
            if (m.role === "user") lines.push("User: " + m.text);
            else if (m.role === "assistant") lines.push("Assistant: " + m.text);
        }
        return lines.join("\n");
    }

    function doSendMessage(text) {
        console.log("[ChatEngine] doSendMessage called, text length:", text.length);
        var history = buildHistory();
        engine.addMessage("user", text);
        console.log("[ChatEngine] User message added to model");
        engine.loading = true;
        engine._pollCount = 0;
        console.log("[ChatEngine] loading set to true");
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
        var r3 = Math.random().toString(36).substring(2, 22);
        var parts = [
            {"id": "prt_" + now + "000" + r0, "type": "text", "text": "Be concise. Answer in 1-2 sentences. Do not repeat the question. Do not show your thought process.", "synthetic": true}
        ];
        if (history.length > 0) {
            parts.push({"id": "prt_" + now + "001" + r3, "type": "text", "text": "Previous conversation:\n" + history + "\n\nCurrent message:", "synthetic": true});
        }
        parts.push({"id": "prt_" + now + "002" + r2, "type": "text", "text": text});
        var body = {
            "model": {"modelID": engine.selectedModelId, "providerID": engine.selectedProviderId},
            "messageID": "msg_" + now + "001" + r1,
            "parts": parts
        };
        engine._lastUserMessageId = body.messageID;

        if (sseHeartbeatTimer.running) sseHeartbeatTimer.restart();
        responseTimeoutTimer.start();
        fallbackPollerTimer.start();

        engine.httpRequest("POST", "/session/" + engine.sessionId + "/prompt_async", body, function(error, data, status) {
            console.log("[ChatEngine] prompt_async response, error:", error, "status:", status);
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
                engine.loading = false;
                responseTimeoutTimer.stop();
                fallbackPollerTimer.stop();
                engine.stallCount = 0;
                engine.addMessage("assistant", msg);
            }
        });
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
        engine.loading = false;
        responseTimeoutTimer.stop();
        fallbackPollerTimer.stop();
        engine.stallCount = 0;
    }

    function resetChat() {
        engine.loading = false;
        engine.seenMessageIds = {};
        engine.stallCount = 0;
        engine.sessionId = "";
        engine.promptSeq++;

        responseTimeoutTimer.stop();
        fallbackPollerTimer.stop();
        engine.messageModel.clear();

        if (engine.connectionStatus === 1) {
            var gen = ++engine._sessionGen;
            engine.createSession(function(success) {
                if (!success && gen === engine._sessionGen)
                    engine.addMessage("assistant", "Warning: Could not create new session.");
            });
        }
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
        running: engine.connectionStatus === 1
        onTriggered: {
            if (!engine.sseXhr && engine.connectionStatus === 1) {
                console.log("[ChatEngine] SSE heartbeat: no connection, starting reconnect");
                sseReconnectTimer.start();
            }
        }
    }

    Timer {
        id: sseReaderTimer
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            var xhr = engine.sseXhr;
            if (!xhr) {
                console.log("[ChatEngine] SSE reader: no xhr, skipping");
                return;
            }
            if (xhr.readyState !== 3 && xhr.readyState !== 4) {
                console.log("[ChatEngine] SSE reader: wrong readyState:", xhr.readyState);
                return;
            }

            var full = xhr.responseText;
            if (full.length === engine.sseBuffer.length) return;

            var newData = full.substring(engine.sseBuffer.length);
            engine.sseBuffer = full;

            console.log("[ChatEngine] SSE reader: newData length:", newData.length, "buffer length:", engine.sseBuffer.length);

            if (newData.length > 0) {
                engine.sseFailCount = 0;
                engine._sseErrorShown = false;
                engine._lastSseActivity = Date.now();
                if (sseHeartbeatTimer.running) sseHeartbeatTimer.restart();
            }

            var raw = engine.sseLineRemainder + newData;
            engine.sseLineRemainder = "";
            var lines = raw.split(/\r?\n/);

            if (raw.length > 0 && raw[raw.length - 1] !== "\n") {
                engine.sseLineRemainder = lines.pop();
            } else {
                lines.pop();
            }

            console.log("[ChatEngine] SSE reader: processing", lines.length, "lines");

            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("data: ") === 0) {
                    try {
                        var eventData = JSON.parse(lines[i].substring(6));
                        console.log("[ChatEngine] SSE reader: parsed event, type:", eventData.type);
                        engine.handleSSEEvent(eventData);
                    } catch (e) {
                        console.log("[ChatEngine] SSE reader: JSON parse error:", e.message, "line:", lines[i].substring(0, 100));
                    }
                }
            }

            if (xhr.readyState === 4) {
                if (engine.sseXhr !== xhr) return;
                console.log("[ChatEngine] SSE reader: connection closed");
                engine.sseXhr = null;
                sseReconnectTimer.start();
            }
        }
    }

    function pollForResponse(isFinal) {
        if (!engine.sessionId) return;
        engine.httpRequest("GET", "/session/" + engine.sessionId + "/message?limit=5", null, function(error, data, status) {
            if (!engine.loading) return;

            if (error || !data) {
                if (isFinal) {
                    engine.loading = false;
                    engine.addMessage("assistant", "No response from " + engine.selectedModelName + " (connection failed).");
                }
                return;
            }

            var msgs = data.data || data;
            if (!Array.isArray(msgs)) {
                if (isFinal) {
                    engine.loading = false;
                    engine.addMessage("assistant", "No response from " + engine.selectedModelName + ".");
                }
                return;
            }

            for (var i = 0; i < msgs.length; i++) {
                var msg = msgs[i];
                if (!msg) continue;
                var msgId = msg.info ? msg.info.id : "";
                var role = msg.info ? msg.info.role : "";

                if (role !== "assistant") continue;
                if (msgId && engine.seenMessageIds[msgId]) continue;

                var parts = msg.parts || [];
                for (var j = 0; j < parts.length; j++) {
                    var pt = parts[j];
                    if (pt.type === "text" && pt.text && pt.text.length > 0 && !pt.synthetic) {
                        console.log("[ChatEngine] Found assistant message, length:", pt.text.length);
                        if (msgId) engine.seenMessageIds[msgId] = true;
                        engine.addMessage("assistant", pt.text);
                        engine.loading = false;
                        responseTimeoutTimer.stop();
                        fallbackPollerTimer.stop();
                        engine.stallCount = 0;
                        return;
                    }
                }
            }

            if (isFinal) {
                engine.loading = false;
                engine.addMessage("assistant", "No response from " + engine.selectedModelName + ".");
            }
        });
    }

    Timer {
        id: fallbackPollerTimer
        interval: 1500
        repeat: true
        onTriggered: {
            if (!engine.loading || !engine.sessionId) return;
            engine._pollCount++;
            console.log("[ChatEngine] Poll tick", engine._pollCount, "loading:", engine.loading);

            engine.stallCount++;
            if (engine.stallCount >= 40) {
                engine.stallCount = 0;
                engine.loading = false;
                responseTimeoutTimer.stop();
                fallbackPollerTimer.stop();
                engine.addMessage("assistant", "No response from " + engine.selectedModelName + " (timeout after 60s).");
                return;
            }

            engine.pollForResponse(false);
        }
    }

    Timer {
        id: responseTimeoutTimer
        interval: 60000
        repeat: false
        onTriggered: {
            if (engine.loading) {
                engine.loading = false;
                fallbackPollerTimer.stop();
                engine.stallCount = 0;
                engine.addMessage("assistant", "No response from " + engine.selectedModelName + " (60s timeout). Try a different model.");
            }
        }
    }
}
