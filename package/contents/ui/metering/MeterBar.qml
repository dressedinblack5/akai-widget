import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property real value: 0
    property real minValue: 0
    property real maxValue: 100
    property string label: ""
    property string unit: ""
    property int precision: 0
    property color barColor: "#3a7bd5"
    property color trackColor: "#333333"
    property color textColor: "#e0e0e0"
    property color labelColor: "#888888"
    property int barHeight: 6
    property bool showValue: true
    property bool showLabel: true
    property bool animated: true

    property bool useThresholds: false
    property real warnThreshold: 0.7
    property real critThreshold: 0.9
    property color warnColor: "#FFA726"
    property color critColor: "#F44336"

    readonly property real normalizedValue: maxValue === minValue ? 0 : Math.max(0, Math.min(1, (value - minValue) / (maxValue - minValue)))

    readonly property color effectiveBarColor: {
        if (!useThresholds) return barColor;
        var nv = normalizedValue;
        if (nv >= critThreshold) return critColor;
        if (nv >= warnThreshold) return warnColor;
        return barColor;
    }

    implicitHeight: {
        var h = 0;
        if (showLabel || showValue) h += 14;
        if (h > 0) h += 4;
        return h + barHeight;
    }
    implicitWidth: 200
    color: "transparent"

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 14
        spacing: 4

        Label {
            id: labelText
            visible: root.showLabel && root.label.length > 0
            text: root.label
            color: root.labelColor
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            id: valueText
            visible: root.showValue
            text: root.value.toFixed(root.precision) + (root.unit.length > 0 ? " " + root.unit : "")
            color: root.textColor
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
        }
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: (root.showLabel && root.label.length > 0) || root.showValue ? 18 : 0
        height: root.barHeight
        radius: height / 2
        color: root.trackColor

        Rectangle {
            id: fill
            height: parent.height
            width: parent.width * root.normalizedValue
            radius: parent.radius
            color: root.effectiveBarColor

            Behavior on width {
                enabled: root.animated
                SmoothedAnimation { duration: 300 }
            }
            Behavior on color {
                enabled: root.animated
                ColorAnimation { duration: 300 }
            }
        }
    }
}
