import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    property var models: []
    property string selectedModelId: ""
    property bool enabled: true
    property string preferredProvider: "opencode"

    signal modelSelected(string modelId)

    Label {
        text: "Model:"
        color: "#cccccc"
    }

    ComboBox {
        id: modelCombo
        Layout.fillWidth: true
        enabled: root.enabled && models.length > 0
        textRole: "display"
        valueRole: "value"

        model: ListModel { id: listModel }

        onActivated: {
            var item = listModel.get(currentIndex)
            if (item) {
                root.selectedModelId = item.value
                root.modelSelected(item.value)
            }
        }

        Component.onCompleted: syncModels()
    }

    Connections {
        target: root
        function onModelsChanged() {
            modelCombo.syncModels()
        }
    }

    function syncModels() {
        var prev = root.selectedModelId
        listModel.clear()
        var prefIdx = -1
        for (var i = 0; i < root.models.length; i++) {
            var v = root.models[i].value
            listModel.append({ display: root.models[i].display, value: v })
            if (v === prev) prefIdx = i
            if (prefIdx < 0 && root.preferredProvider && v.indexOf(root.preferredProvider + "/") === 0)
                prefIdx = i
        }
        var idx = prefIdx >= 0 ? prefIdx : 0
        if (listModel.count > 0) {
            modelCombo.currentIndex = idx
            var item = listModel.get(idx).value
            root.selectedModelId = item
            root.modelSelected(item)
        }
    }
}
