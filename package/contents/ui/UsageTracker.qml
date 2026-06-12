import QtQml
import QtQuick

Item {
    id: tracker
    visible: false

    property var storage: null

    property int totalRequests: 0
    property int totalErrors: 0
    property real successRate: 100
    property int avgTimeMs: 0
    property int modelCount: 0
    property var modelList: []
    property var providerBreakdown: []
    property var timeSeries: []

    signal dataChanged()

    property var _modelData: ({})
    property var _timeSeries: []
    property int _maxTimeSeries: 50
    property string _currentProvider: ""
    property string _currentModel: ""
    property real _currentStartTime: 0
    property bool _requestActive: false
    property string _lastReset: ""

    function beginRequest(providerId, modelId) {
        _currentProvider = providerId;
        _currentModel = modelId;
        _currentStartTime = Date.now();
        _requestActive = true;
    }

    function endRequest(success) {
        if (!_requestActive) return;
        _requestActive = false;

        var duration = Date.now() - _currentStartTime;
        var key = _currentProvider + "/" + _currentModel;

        _ensureEntry(key);
        var entry = _modelData[key];
        entry.requests++;
        entry.totalTimeMs += duration;
        if (duration < entry.minTimeMs) entry.minTimeMs = duration;
        if (duration > entry.maxTimeMs) entry.maxTimeMs = duration;
        if (!success) entry.errors++;
        entry.lastUsed = new Date().toISOString();

        _timeSeries.push({
            time: Date.now(),
            key: key,
            durationMs: duration,
            success: success
        });
        while (_timeSeries.length > _maxTimeSeries)
            _timeSeries.shift();

        _updateProperties();
        _save();
    }

    function _ensureEntry(key) {
        if (!_modelData[key]) {
            _modelData[key] = {
                requests: 0,
                totalTimeMs: 0,
                minTimeMs: Infinity,
                maxTimeMs: 0,
                errors: 0,
                lastUsed: ""
            };
        }
    }

    function getModels() {
        var result = [];
        for (var key in _modelData) {
            if (!_modelData.hasOwnProperty(key)) continue;
            var d = _modelData[key];
            var parts = key.split("/");
            result.push({
                key: key,
                providerId: parts[0],
                modelId: parts.slice(1).join("/"),
                requests: d.requests,
                avgTimeMs: d.requests > 0 ? Math.round(d.totalTimeMs / d.requests) : 0,
                minTimeMs: d.minTimeMs === Infinity ? 0 : d.minTimeMs,
                maxTimeMs: d.maxTimeMs,
                totalTimeMs: d.totalTimeMs,
                errors: d.errors,
                lastUsed: d.lastUsed
            });
        }
        result.sort(function(a, b) { return b.requests - a.requests; });
        return result;
    }

    function getTotalStats() {
        var totalReqs = 0, totalErrors = 0, totalTime = 0;
        for (var key in _modelData) {
            if (!_modelData.hasOwnProperty(key)) continue;
            var d = _modelData[key];
            totalReqs += d.requests;
            totalErrors += d.errors;
            totalTime += d.totalTimeMs;
        }
        return {
            totalRequests: totalReqs,
            totalErrors: totalErrors,
            totalTimeMs: totalTime,
            avgTimeMs: totalReqs > 0 ? Math.round(totalTime / totalReqs) : 0,
            modelCount: Object.keys(_modelData).length,
            successRate: totalReqs > 0 ? ((totalReqs - totalErrors) / totalReqs * 100) : 100
        };
    }

    function getTimeSeries() {
        return _timeSeries.slice();
    }

    function getProviderBreakdown() {
        var providers = {};
        for (var key in _modelData) {
            if (!_modelData.hasOwnProperty(key)) continue;
            var d = _modelData[key];
            var pid = key.split("/")[0];
            if (!providers[pid])
                providers[pid] = { providerId: pid, requests: 0, totalTimeMs: 0, errors: 0 };
            providers[pid].requests += d.requests;
            providers[pid].totalTimeMs += d.totalTimeMs;
            providers[pid].errors += d.errors;
        }
        var result = [];
        for (var pid in providers) {
            if (!providers.hasOwnProperty(pid)) continue;
            result.push(providers[pid]);
        }
        result.sort(function(a, b) { return b.requests - a.requests; });
        return result;
    }

    function _updateProperties() {
        var stats = getTotalStats();
        totalRequests = stats.totalRequests;
        totalErrors = stats.totalErrors;
        successRate = stats.successRate;
        avgTimeMs = stats.avgTimeMs;
        modelCount = stats.modelCount;
        modelList = getModels();
        providerBreakdown = getProviderBreakdown();
        timeSeries = _timeSeries.slice();
        dataChanged();
    }

    function resetStats() {
        _modelData = {};
        _timeSeries = [];
        _requestActive = false;
        _lastReset = new Date().toISOString();
        _updateProperties();
        _save();
    }

    function load() {
        if (!tracker.storage) return;
        var data = tracker.storage.readFile(tracker.storage.storagePath() + "/usage.json");
        if (data) {
            try {
                var parsed = JSON.parse(data);
                _modelData = parsed.models || {};
                _timeSeries = parsed.timeSeries || [];
                _lastReset = parsed.lastReset || "";
            } catch (e) {}
        }
        _updateProperties();
    }

    function _save() {
        if (!tracker.storage) return;
        tracker.storage.writeFile(tracker.storage.storagePath() + "/usage.json",
            JSON.stringify({ models: _modelData, timeSeries: _timeSeries, lastReset: _lastReset }));
    }

    Component.onCompleted: load()
}
