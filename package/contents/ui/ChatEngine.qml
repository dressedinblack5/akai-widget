import QtQml
import QtQuick
import "utils.js" as Utils

Item {
    id: engine
    visible: false

    property string serverUrl: "http://localhost:4096"
    property bool loading: false
    property string sessionId: ""
    property var availableModels: []
    property string selectedProviderId: ""
    property string selectedModelId: ""
    property string selectedModelName: ""
    property var cachedProviderData: null
    property var recentModelValues: []
    property var messageModel: null
    property var connectionManager: null
    property bool active: true

    property int stallCount: 0
    property var seenMessageIds: ({})
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
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var data = null;
                var error = xhr.status !== 200 && xhr.status !== 201 && xhr.status !== 204;
                if (xhr.responseText) {
                    try { data = JSON.parse(xhr.responseText); } catch (e) { console.warn("[ChatEngine] Failed to parse response:", e); }
                }
                callback(error, data, xhr.status);
            }
        };
        xhr.ontimeout = function() { callback(true, null, 0); };
        xhr.onerror = function() { callback(true, null, 0); };
        xhr.send(body ? JSON.stringify(body) : null);
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
        var priority = ["opencode", "opencode-go", "ollama", "google", "github-copilot", "horde"];
        for (var pi = 0; pi < priority.length; pi++) {
            for (var mi = 0; mi < models.length; mi++) {
                if (models[mi].value.indexOf(priority[pi] + "/") === 0) {
                    engine.modelSelectorRef.selectModel(models[mi].value);
                    return;
                }
            }
        }
        var fallbackModels = ["opencode-go/deepseek-v4-flash", "opencode-go/qwen3.7-plus", "google/gemini-2.5-flash"];
        for (var fi = 0; fi < fallbackModels.length; fi++) {
            for (var mi = 0; mi < models.length; mi++) {
                if (models[mi].value === fallbackModels[fi]) {
                    engine.modelSelectorRef.selectModel(fallbackModels[fi]);
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

        // F1 — Model guard: prevent entering stuck loading state with no model selected
        if (!engine.selectedModelId) {
            if (engine.availableModels && engine.availableModels.length > 0) {
                engine.selectDefaultModel();
            }
            if (!engine.selectedModelId) {
                console.log("[ChatEngine] sendMessage: no model selected");
                engine.addMessage("assistant", "Error: No model selected. Select a model from the dropdown or wait for providers to load.");
                return;
            }
        }

        function doSend() {
            engine.createSession(function(success) {
                if (success) engine.doSendMessage(text);
                else {
                    engine.loading = false;
                    engine.addMessage("assistant", "Error: Could not create session. Is the server running?");
                }
            });
        }

        if (engine.connectionManager && !engine.connectionManager.isReady) {
            engine.connectionManager.start();
            engine.loading = false;
            engine.addMessage("assistant", "Server not ready \u2014 connection being established. Try again in a moment.");
            return;
        }

        engine.loading = true;
        doSend();
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
            {"id": "prt_" + now + "000" + r0, "type": "text", "text": "Answer naturally and thoroughly. Do not repeat the question. Do not show your thought process."}
        ];
        if (history.length > 0) {
            parts.push({"id": "prt_" + now + "001" + r3, "type": "text", "text": "Previous conversation:\n" + history + "\n\nCurrent message:"});
        }
        parts.push({"id": "prt_" + now + "002" + r2, "type": "text", "text": text});
        var body = {
            "model": {"modelID": engine.selectedModelId, "providerID": engine.selectedProviderId},
            "messageID": "msg_" + now + "001" + r1,
            "system": "You are a helpful and knowledgeable chatbot. Do NOT use any tools. Answer conversationally with text only.",
            "parts": parts
        };
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

        responseTimeoutTimer.stop();
        fallbackPollerTimer.stop();
        engine.messageModel.clear();

        if (engine.connectionManager && engine.connectionManager.isReady) {
            var gen = ++engine._sessionGen;
            engine.createSession(function(success) {
                if (!success && gen === engine._sessionGen)
                    engine.addMessage("assistant", "Warning: Could not create new session.");
            });
        }
    }

    function setActive(isActive) {
        engine.active = isActive === true;
        if (engine.connectionManager)
            engine.connectionManager.setActive(isActive);
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
            // F2 — After 10 ticks (~15s), do one final poll with isFinal=true to report error
            if (engine.stallCount >= 10) {
                engine.pollForResponse(true);
                return;
            }

            engine.pollForResponse(false);
        }
    }

    Timer {
        id: responseTimeoutTimer
        interval: 20000
        repeat: false
        onTriggered: {
            if (engine.loading) {
                engine.loading = false;
                fallbackPollerTimer.stop();
                engine.stallCount = 0;
                engine.addMessage("assistant", "No response from " + engine.selectedModelName + " (timeout). Try a different model.");
            }
        }
    }

    Connections {
        target: engine.connectionManager

        function onSseEventReceived(type, payload) {
            if (type === "session.error") {
                if (engine.loading) {
                    engine.loading = false;
                    responseTimeoutTimer.stop();
                    fallbackPollerTimer.stop();
                    engine.stallCount = 0;
                }
                var sessErr = payload.error || {};
                var errMsg = (sessErr.data && sessErr.data.message) || sessErr.name || "Session error";
                engine.addMessage("assistant", "Error: " + errMsg);
                return;
            }

            if (type === "session.idle" || (type === "session.status" && payload.status && payload.status.type === "idle")) {
                if (payload.sessionID && payload.sessionID !== engine.sessionId) return;
                console.log("[ChatEngine] session idle, loading:", engine.loading);
                if (engine.loading) {
                    fallbackPollerTimer.stop();
                    responseTimeoutTimer.stop();
                    engine.stallCount = 0;
                    engine.pollForResponse(true);
                }
                return;
            }
        }
    }
}
