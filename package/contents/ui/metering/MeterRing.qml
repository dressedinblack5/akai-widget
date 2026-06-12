import QtQuick
import QtQuick.Controls

Item {
    id: root

    property real value: 0
    property real minValue: 0
    property real maxValue: 100
    property string label: ""
    property string unit: ""
    property int precision: 0
    property color ringColor: "#3a7bd5"
    property color trackColor: "#333333"
    property color textColor: "#e0e0e0"
    property color labelColor: "#888888"
    property real strokeWidth: 8
    property real startAngle: -Math.PI * 0.75
    property real sweepAngle: Math.PI * 1.5
    property bool showValue: true
    property bool showLabel: true
    property bool animated: true

    property bool useThresholds: false
    property real warnThreshold: 0.7
    property real critThreshold: 0.9
    property color warnColor: "#FFA726"
    property color critColor: "#F44336"

    readonly property real normalizedValue: maxValue === minValue ? 0 : Math.max(0, Math.min(1, (value - minValue) / (maxValue - minValue)))

    readonly property color effectiveRingColor: {
        if (!useThresholds) return ringColor;
        var nv = normalizedValue;
        if (nv >= critThreshold) return critColor;
        if (nv >= warnThreshold) return warnColor;
        return ringColor;
    }

    property real _displayNormalized: 0

    onNormalizedValueChanged: {
        _displayNormalized = normalizedValue;
    }

    on_DisplayNormalizedChanged: canvas.requestPaint()
    onEffectiveRingColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()

    Behavior on _displayNormalized {
        enabled: root.animated
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    implicitWidth: 120
    implicitHeight: 120

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            var cw = width;
            var ch = height;
            var cx = cw / 2;
            var cy = ch / 2;
            var halfStroke = root.strokeWidth / 2;
            var radius = Math.min(cw, ch) / 2 - halfStroke - 2;

            ctx.clearRect(0, 0, cw, ch);

            ctx.beginPath();
            ctx.arc(cx, cy, radius, root.startAngle, root.startAngle + root.sweepAngle, false);
            ctx.strokeStyle = root.trackColor;
            ctx.lineWidth = root.strokeWidth;
            ctx.lineCap = "round";
            ctx.stroke();

            ctx.beginPath();
            ctx.arc(cx, cy, radius, root.startAngle, root.startAngle + root.sweepAngle * root._displayNormalized, false);
            ctx.strokeStyle = root.effectiveRingColor;
            ctx.lineWidth = root.strokeWidth;
            ctx.lineCap = "round";
            ctx.stroke();
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2
        width: parent.width * 0.65

        Label {
            visible: root.showValue
            text: root.value.toFixed(root.precision) + (root.unit.length > 0 ? " " + root.unit : "")
            color: root.textColor
            font.pixelSize: Math.max(10, Math.min(parent.width * 0.28, 22))
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            elide: Text.ElideRight
        }

        Label {
            visible: root.showLabel && root.label.length > 0
            text: root.label
            color: root.labelColor
            font.pixelSize: Math.max(9, Math.min(parent.width * 0.16, 11))
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            elide: Text.ElideRight
        }
    }
}
