import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "metering"

Rectangle {
    id: root

    property var usageTracker: null
    property color themeBg: "#1a1a1a"
    property color themeText: "#e0e0e0"
    property color themeMuted: "#888888"
    property color themeAccent: "#3a7bd5"

    signal closeRequested()

    color: "transparent"
    clip: true

    ListModel { id: modelItems }
    ListModel { id: providerItems }

    property int _summaryReqs: 0
    property int _summaryErrors: 0
    property real _summaryRate: 100
    property int _summaryAvgMs: 0
    property var _sparklineData: []

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: refreshData()
    }

    Component.onCompleted: refreshData()

    Connections {
        target: root.usageTracker
        function onDataChanged() { refreshData(); }
    }

    function refreshData() {
        if (!root.usageTracker) return;

        var stats = root.usageTracker.getTotalStats();
        _summaryReqs = stats.totalRequests;
        _summaryErrors = stats.totalErrors;
        _summaryRate = stats.successRate;
        _summaryAvgMs = stats.avgTimeMs;

        modelItems.clear();
        var models = root.usageTracker.getModels();
        var maxReq = 1;
        for (var i = 0; i < models.length; i++)
            maxReq = Math.max(maxReq, models[i].requests);
        for (var i = 0; i < models.length; i++) {
            modelItems.append({
                key: models[i].key,
                label: models[i].providerId + "/" + models[i].modelId,
                requests: models[i].requests,
                maxValue: maxReq,
                avgTimeMs: models[i].avgTimeMs,
                errors: models[i].errors
            });
        }

        providerItems.clear();
        var providers = root.usageTracker.getProviderBreakdown();
        var maxPr = 1;
        for (var i = 0; i < providers.length; i++)
            maxPr = Math.max(maxPr, providers[i].requests);
        for (var i = 0; i < providers.length; i++) {
            providerItems.append({
                providerId: providers[i].providerId,
                requests: providers[i].requests,
                maxValue: maxPr,
                avgTimeMs: providers[i].totalTimeMs > 0 && providers[i].requests > 0
                    ? Math.round(providers[i].totalTimeMs / providers[i].requests) : 0,
                errors: providers[i].errors
            });
        }

        var series = root.usageTracker.getTimeSeries();
        var vals = [];
        for (var si = 0; si < series.length; si++)
            vals.push(series[si].durationMs);
        _sparklineData = vals;
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 4
        contentHeight: contentCol.implicitHeight + 20
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2

                Label {
                    text: "Usage Dashboard"
                    color: root.themeText
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }

                Button {
                    text: "\u2715"
                    implicitWidth: 24
                    implicitHeight: 24
                    onClicked: root.closeRequested()

                    background: Rectangle {
                        color: parent.hovered ? "#F44336" : "transparent"
                        radius: 4
                    }
                    contentItem: Label {
                        text: parent.text
                        color: parent.hovered ? "#ffffff" : root.themeText
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            MeterPanel {
                Layout.fillWidth: true
                columns: 4
                title: "Summary"
                titleColor: root.themeText
                bodyColor: root.themeBg
                borderColor: "#404040"
                headerColor: "#2a2a2a"

                MeterLabel {
                    label: "Total Requests"
                    value: root._summaryReqs.toString()
                    valueColor: root.themeText
                    labelColor: root.themeMuted
                    accentColor: root.themeAccent
                }
                MeterLabel {
                    label: "Success Rate"
                    value: root._summaryRate.toFixed(0) + "%"
                    valueColor: root.themeText
                    labelColor: root.themeMuted
                    accentColor: root.themeAccent
                }
                MeterLabel {
                    label: "Avg Response"
                    value: _formatDuration(root._summaryAvgMs)
                    valueColor: root.themeText
                    labelColor: root.themeMuted
                    accentColor: root.themeAccent
                }
                MeterLabel {
                    label: "Errors"
                    value: root._summaryErrors.toString()
                    valueColor: root._summaryErrors > 0 ? "#F44336" : root.themeText
                    labelColor: root.themeMuted
                    accentColor: root._summaryErrors > 0 ? "#F44336" : root.themeAccent
                }
            }

            MeterPanel {
                Layout.fillWidth: true
                title: "Per-Model Usage"
                titleColor: root.themeText
                bodyColor: root.themeBg
                borderColor: "#404040"
                headerColor: "#2a2a2a"

                Repeater {
                    model: modelItems

                    MeterBar {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        label: model.label
                        value: model.requests
                        maxValue: model.maxValue > 0 ? model.maxValue : 1
                        showValue: true
                        unit: "req"
                        barColor: _barColor(model.key)
                        labelColor: root.themeMuted
                        textColor: root.themeText
                        barHeight: 8
                        animated: true
                        precision: 0
                    }
                }

                Label {
                    visible: modelItems.count === 0
                    text: "No usage data yet. Send a message to start tracking."
                    color: root.themeMuted
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MeterPanel {
                Layout.fillWidth: true
                title: "By Provider"
                titleColor: root.themeText
                bodyColor: root.themeBg
                borderColor: "#404040"
                headerColor: "#2a2a2a"

                Repeater {
                    model: providerItems

                    MeterBar {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        label: model.providerId
                        value: model.requests
                        maxValue: model.maxValue > 0 ? model.maxValue : 1
                        showValue: true
                        unit: "req"
                        barColor: _barColor(model.providerId)
                        labelColor: root.themeMuted
                        textColor: root.themeText
                        barHeight: 8
                        precision: 0
                    }
                }

                Label {
                    visible: providerItems.count === 0
                    text: "No provider data yet."
                    color: root.themeMuted
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MeterPanel {
                Layout.fillWidth: true
                title: "Response Time History"
                titleColor: root.themeText
                bodyColor: root.themeBg
                borderColor: "#404040"
                headerColor: "#2a2a2a"

                Item {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 60
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 4

                    Sparkline {
                        anchors.fill: parent
                        values: root._sparklineData
                        lineColor: root.themeAccent
                        fillColor: Qt.rgba(0.227, 0.482, 0.835, 0.2)
                        lineWidth: 1.5
                        showFill: true
                        autoScale: true
                    }
                }

                Label {
                    visible: root._sparklineData.length < 2
                    text: "Not enough data for chart."
                    color: root.themeMuted
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.bottomMargin: 4
                }
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8
                text: "Reset Statistics"
                onClicked: {
                    if (root.usageTracker) {
                        root.usageTracker.resetStats();
                        refreshData();
                    }
                }

                background: Rectangle {
                    color: parent.hovered ? "#4a4a4a" : "#333333"
                    radius: 4
                    border.width: 1
                    border.color: parent.hovered ? "#F44336" : "#404040"
                }
                contentItem: Label {
                    text: parent.text
                    color: "#e0e0e0"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    function _formatDuration(ms) {
        if (ms < 1000) return ms + "ms";
        return (ms / 1000).toFixed(1) + "s";
    }

    function _barColor(key) {
        var colors = ["#3a7bd5", "#43A047", "#FFA726", "#AB47BC", "#26C6DA", "#EF5350", "#66BB6A", "#FF7043"];
        var hash = 0;
        for (var i = 0; i < key.length; i++)
            hash = key.charCodeAt(i) + ((hash << 5) - hash);
        return colors[Math.abs(hash) % colors.length];
    }
}
