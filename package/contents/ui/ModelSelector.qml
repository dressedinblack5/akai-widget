import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    property var models: []
    property var missingProviders: []
    property string selectedModelId: ""
    property bool _suppressSignal: false

    SystemPalette { id: sysPal; colorGroup: SystemPalette.Active }

    signal modelSelected(string modelId)

    function syncModels() {
        var prev = root.selectedModelId;
        listModel.clear();
        var prefIdx = -1;
        for (var i = 0; i < root.models.length; i++) {
            var v = root.models[i].value;
            listModel.append({"display": root.models[i].display, "value": v});
            if (v === prev) prefIdx = i;
        }
        var idx = prefIdx >= 0 ? prefIdx : 0;
        if (listModel.count > 0) {
            root._suppressSignal = true;
            modelCombo.currentIndex = idx;
            root._suppressSignal = false;
            root.selectedModelId = listModel.get(idx).value;
        }
    }

    function selectModel(value) {
        for (var si = 0; si < listModel.count; si++) {
            if (listModel.get(si).value === value) {
                root._suppressSignal = true;
                modelCombo.currentIndex = si;
                root._suppressSignal = false;
                root.selectedModelId = value;
                root.modelSelected(value);
                return;
            }
        }
    }

    ComboBox {
        id: modelCombo

        Layout.fillWidth: true
        enabled: root.enabled && root.models.length > 0
        textRole: "display"
        valueRole: "value"

        onActivated: {
            if (root._suppressSignal) return;
            var item = listModel.get(currentIndex);
            if (item) {
                root.selectedModelId = item.value;
                root.modelSelected(item.value);
            }
        }

        Component.onCompleted: root.syncModels()

        model: ListModel {
            id: listModel
        }
    }

    Label {
        visible: root.missingProviders.length > 0
        text: "\u26A0"
        color: "#FFA726"
        font.pixelSize: 14

        HoverHandler {
            id: missingHover
            cursorShape: Qt.PointingHandCursor
        }

        ToolTip {
            visible: missingHover.hovered
            text: "Some providers unavailable:\n" + root.missingProviders.join(", ") + "\n\nEnsure Ollama is running or API keys are configured."
            delay: 300
        }
    }

    Connections {
        target: root
        function onModelsChanged() { root.syncModels(); }
    }
}
