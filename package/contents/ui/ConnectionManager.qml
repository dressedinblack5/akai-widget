import QtQml
import QtQuick

Item {
    id: root
    visible: false

    // === State machine ===
    readonly property int stateDisconnected: 0
    readonly property int stateStarting: 1
    readonly property int stateConnecting: 2
    readonly property int stateConnected: 3
    readonly property int stateError: 4

    property int state: stateDisconnected
    property bool isReady: state === stateConnected
    property bool isConnecting: state === stateStarting || state === stateConnecting
    property bool isError: state === stateDisconnected || state === stateError
    property int statusCode: isConnecting ? 0 : (isReady ? 1 : 2)
    readonly property bool serverRunning: root.processManager ? root.processManager.serverRunning : false

    // === Configuration ===
    property string serverUrl: "http://localhost:4096"
    property var processManager: null
    property bool active: true

    // === SSE internals ===
    property var _sseXhr: null
    property string _sseBuffer: ""
    property string _sseLineRemainder: ""
    property int _sseFailCount: 0
    property bool _sseErrorShown: false
    property real _lastSseActivity: 0
    property int _healthRetryCount: 0

    signal connectionStateChanged(int newState, int oldState)
    signal connectionError(string message)
    signal serverReady()
    signal sseEventReceived(string type, var payload)

    function _setState(newState) {
        if (newState === root.state) return;
        var old = root.state;
        root.state = newState;
        console.log("[ConnectionManager] state:", old, "->", newState);
        root.connectionStateChanged(newState, old);
        if (newState === stateConnected)
            root.serverReady();
    }

    // === HTTP helper ===
    function _http(method, path, body, callback, timeout) {
        var xhr = new XMLHttpRequest();
        xhr.open(method, root.serverUrl + path, true);
        xhr.timeout = timeout || 8000;
        if (body)
            xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var data = null;
                var err = xhr.status !== 200 && xhr.status !== 201 && xhr.status !== 204;
                if (xhr.responseText) {
                    try { data = JSON.parse(xhr.responseText); } catch (e) { console.warn("[ConnectionManager] Failed to parse response:", e); }
                }
                callback(err, data, xhr.status);
            }
        };
        xhr.ontimeout = function() { callback(true, null, 0); };
        xhr.onerror = function() { callback(true, null, 0); };
        xhr.send(body ? JSON.stringify(body) : null);
    }

    // === Public API ===

    function start() {
        if (root.state === stateConnected) return;
        if (root.state === stateStarting || root.state === stateConnecting) return;
        console.log("[ConnectionManager] start");
        
        // First, check if server is already running (might be external)
        root._setState(stateConnecting);
        root._http("GET", "/global/health", null, function(err, data, status) {
            if (!root) return;
            if (!err && data && (data.healthy || data.status === "ok")) {
                // Server is already running, go directly to CONNECTED
                console.log("[ConnectionManager] server already running, skipping start");
                root._healthRetryCount = 0;
                root._sseFailCount = 0;
                root._sseErrorShown = false;
                root._setState(stateConnected);
                root._connectSSE();
            } else {
                // Server not responding, try to start it
                if (root.processManager && !root.processManager.serverRunning) {
                    root._setState(stateStarting);
                    root.processManager.startServer();
                } else {
                    root.checkHealth();
                }
            }
        }, 3000);
    }

    function stop() {
        root._teardownSSE();
        if (root.processManager && root.processManager.serverRunning)
            root.processManager.stopServer();
        root._setState(stateDisconnected);
    }

    function restart() {
        root.stop();
        root.start();
    }

    function checkHealth() {
        root._setState(stateConnecting);
        console.log("[ConnectionManager] checkHealth:", root.serverUrl);
        root._http("GET", "/global/health", null, function(err, data, status) {
            console.log("[ConnectionManager] health response, err:", err, "status:", status, "data:", data ? JSON.stringify(data) : "null");
            if (!root) return;
            if (!err && data && (data.healthy || data.status === "ok")) {
                root._healthRetryCount = 0;
                root._sseFailCount = 0;
                root._sseErrorShown = false;
                root._setState(stateConnected);
                root._connectSSE();
            } else {
                root._healthRetryCount++;
                if (root._healthRetryCount < 30) {
                    _healthRetryTimer.start();
                } else {
                    root._setState(stateError);
                    root.connectionError("Server health check failed after retries.");
                }
            }
        }, 3000);
    }

    function setActive(isActive) {
        root.active = isActive === true;
        if (isActive) {
            _sseReaderTimer.running = true;
            if (!root._sseXhr && root.state === stateConnected)
                root._connectSSE();
            else if (root.state !== stateConnected && root.state !== stateStarting && root.state !== stateConnecting)
                root.start();
        } else {
            _sseReaderTimer.running = false;
            root._teardownSSE();
        }
    }

    // === ProcessManager callbacks ===

    function onServerStarted() {
        root.checkHealth();
    }

    function onServerStopped() {
        root._teardownSSE();
        root._setState(stateDisconnected);
    }

    function onServerError(error) {
        root.connectionError("Server error: " + (error || "unknown"));
        root._setState(stateError);
    }

    // === SSE ===

    function _connectSSE() {
        console.log("[ConnectionManager] connectSSE");
        root._teardownSSE();
        var xhr = new XMLHttpRequest();
        root._sseXhr = xhr;
        root._sseBuffer = "";
        root._sseLineRemainder = "";
        root._lastSseActivity = Date.now();
        xhr.open("GET", root.serverUrl + "/global/event", true);
        xhr.timeout = 0;
        xhr.onerror = function() {
            if (!root || root._sseXhr !== xhr) return;
            console.log("[ConnectionManager] SSE error");
            root._sseXhr = null;
            root._sseFailCount++;
            if (root._sseFailCount >= 5 && !root._sseErrorShown && root.active) {
                root._sseErrorShown = true;
                root.connectionError("Live updates disconnected. Responses will use fallback polling.");
            }
            _sseReconnectTimer.start();
        };
        xhr.onload = function() {
            if (!root || root._sseXhr !== xhr) return;
            console.log("[ConnectionManager] SSE ended");
            root._sseXhr = null;
            _sseReconnectTimer.start();
        };
        xhr.send(null);
    }

    function _teardownSSE() {
        if (root._sseXhr) {
            root._sseXhr.abort();
            root._sseXhr = null;
        }
        root._sseBuffer = "";
        root._sseLineRemainder = "";
    }

    // === Timers ===

    Timer {
        id: _sseReconnectTimer
        interval: Math.min(2000 * Math.pow(2, Math.min(root._sseFailCount, 5)), 60000)
        repeat: false
        onTriggered: {
            if (!root.active) return;
            if (root._sseFailCount >= 5) {
                root._setState(stateConnecting);
                root.checkHealth();
            } else {
                root._connectSSE();
            }
        }
    }

    Timer {
        id: _healthRetryTimer
        interval: 2000
        repeat: false
        onTriggered: root.checkHealth()
    }

    Timer {
        id: _sseHeartbeatTimer
        interval: 15000
        repeat: true
        running: root.state === stateConnected
        onTriggered: {
            if (!root._sseXhr && root.state === stateConnected) {
                console.log("[ConnectionManager] SSE heartbeat: reconnecting");
                _sseReconnectTimer.start();
            }
        }
    }

    Timer {
        id: _sseReaderTimer
        interval: 200
        repeat: true
        running: false
        onTriggered: {
            var xhr = root._sseXhr;
            if (!xhr) return;
            if (xhr.readyState !== 3 && xhr.readyState !== 4) return;

            var full = xhr.responseText;
            if (full.length === root._sseBuffer.length) return;

            var newData = full.substring(root._sseBuffer.length);
            root._sseBuffer = full;

            if (newData.length > 0) {
                root._sseFailCount = 0;
                root._sseErrorShown = false;
                root._lastSseActivity = Date.now();
                if (_sseHeartbeatTimer.running) _sseHeartbeatTimer.restart();
            }

            var raw = root._sseLineRemainder + newData;
            root._sseLineRemainder = "";
            var lines = raw.split(/\r?\n/);
            if (raw.length > 0 && raw[raw.length - 1] !== "\n") {
                root._sseLineRemainder = lines.pop();
            } else {
                lines.pop();
            }

            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("data: ") === 0) {
                    try {
                        var ev = JSON.parse(lines[i].substring(6));
                        root.sseEventReceived(ev.type, ev.payload || {});
                    } catch (e) { console.warn("[ConnectionManager] Failed to parse SSE event:", e); }
                }
            }

            if (xhr.readyState === 4) {
                if (root._sseXhr !== xhr) return;
                root._sseXhr = null;
                _sseReconnectTimer.start();
            }
        }
    }

    // === Lifecycle ===

    Component.onCompleted: {
        if (root.active)
            root.start();
    }
}
