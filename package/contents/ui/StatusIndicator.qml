import QtQuick

Rectangle {
    property int status: 0

    width: 10
    height: 10
    radius: 5
    color: status === 0 ? "#999999"
         : status === 1 ? "#4CAF50"
         : "#F44336"

    Behavior on color {
        ColorAnimation { duration: 300 }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.2)
    }
}
