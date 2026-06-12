import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property string value: "—"
    property string unit: ""
    property color valueColor: "#e0e0e0"
    property color labelColor: "#888888"
    property color accentColor: "#3a7bd5"
    property bool showAccent: true

    implicitHeight: 40
    implicitWidth: 120
    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 2

        Rectangle {
            visible: root.showAccent
            height: 3
            width: 24
            radius: 1.5
            color: root.accentColor
            Layout.alignment: Qt.AlignLeft
        }

        Label {
            id: valueLabel
            text: root.value + (root.unit.length > 0 ? " " + root.unit : "")
            color: root.valueColor
            font.pixelSize: 18
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            id: labelText
            visible: root.label.length > 0
            text: root.label
            color: root.labelColor
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
