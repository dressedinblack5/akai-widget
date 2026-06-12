import QtQuick

Rectangle {
    property int status: 0
    property color disconnectedColor: "#999999"
    property color connectedColor: "#4CAF50"
    property color errorColor: "#F44336"

    width: 10
    height: 10
    radius: 5
    color: status === 0 ? disconnectedColor
           : status === 1 ? connectedColor
           : errorColor
}
