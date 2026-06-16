pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    spacing: Config.menu.spacing
    focus: true

    property int currentIndex: -1
    property int draggingIndex: -1
    property int dropTargetIndex: -1
    property real dragTranslateY: 0

    function computeDropIndex(draggedIndex: int, translationY: real): int {
        let itemHeight = entryRepeater.count > 0 ? entryRepeater.itemAt(0).height : 30;
        let offset = Math.round(translationY / itemHeight);
        let target = draggedIndex + offset;
        return Math.max(0, Math.min(target, displayModel.length - 1));
    }

    function commitReorder(fromIndex: int, toIndex: int) {
        if (fromIndex === toIndex) return;
        let order = displayModel.map(e => e.id);
        let item = order.splice(fromIndex, 1)[0];
        order.splice(toIndex, 0, item);
        Config.state.setSystrayBarOrder(order);
    }

    // Build display model: ordered list of {id, isOthers} entries.
    // Real systray items + the "" (Others) placeholder, sorted by systrayBarOrder.
    property var displayModel: {
        void(Config.state.systrayBarOrder);
        void(repeater.count);
        let order = Config.state.systrayBarOrder;
        let items = [];
        for (let i = 0; i < repeater.count; i++) {
            let d = repeater.itemAt(i);
            if (!d || d.itemData.status === Status.Passive) continue;
            items.push({ id: d.itemData.id, isOthers: false });
        }
        items.push({ id: "", isOthers: true });
        items.sort((a, b) => {
            let ai = order.indexOf(a.id);
            let bi = order.indexOf(b.id);
            if (ai < 0 && bi < 0) return 0;
            if (ai < 0) return 1;
            if (bi < 0) return -1;
            return ai - bi;
        });
        return items;
    }

    onActiveFocusChanged: {
        if (activeFocus && currentIndex < 0) {
            navigateDown();
        }
    }

    function navigateUp() {
        for (let i = currentIndex - 1; i >= 0; i--) {
            let item = entryRepeater.itemAt(i);
            if (item && item.visible) {
                currentIndex = i;
                return;
            }
        }
    }

    function navigateDown() {
        for (let i = (currentIndex < 0 ? 0 : currentIndex + 1); i < entryRepeater.count; i++) {
            let item = entryRepeater.itemAt(i);
            if (item && item.visible) {
                currentIndex = i;
                return;
            }
        }
    }

    function activateCurrent() {
        if (currentIndex < 0 || currentIndex >= displayModel.length) return;
        Config.state.toggleSystrayItemInBar(displayModel[currentIndex].id);
    }

    Keys.onUpPressed: navigateUp()
    Keys.onDownPressed: navigateDown()
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()
    Keys.onSpacePressed: activateCurrent()

    Text {
        text: "Systray Bar Visibility"
        font.family: Config.menu.font.family
        font.pointSize: Config.menu.font.pointSize
        font.bold: true
        color: Config.theme.color.text
        Layout.bottomMargin: 4
    }

    // Hidden repeater to access SystemTray items by index
    Repeater {
        id: repeater
        model: SystemTray.items
        Item {
            required property var modelData
            property var itemData: modelData
            visible: false
        }
    }

    Repeater {
        id: entryRepeater
        model: root.displayModel.length

        Rectangle {
            id: entryRow
            required property int index
            property var item: modelData
            // visible: item.status != Status.Passive

            readonly property var entry: root.displayModel[index]
            readonly property string entryId: entry ? entry.id : ""
            readonly property bool isOthers: entry ? entry.isOthers : false
            readonly property bool isDragging: root.draggingIndex === index

            Layout.fillWidth: true
            implicitHeight: rowLayout.implicitHeight + 4
            color: (index === root.currentIndex || itemHover.hovered) ? Config.menu.hoverBackground : "transparent"
            radius: Config.cc.radius
            z: isDragging ? 100 : 0
            opacity: isDragging ? 0.8 : 1.0

            transform: Translate {
                y: entryRow.isDragging ? root.dragTranslateY : 0
            }

            // Drop indicator
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -1
                height: 2
                color: Config.theme.color.active
                visible: root.dropTargetIndex === entryRow.index && root.draggingIndex !== -1 && root.draggingIndex !== entryRow.index && root.dropTargetIndex < root.draggingIndex
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -1
                height: 2
                color: Config.theme.color.active
                visible: root.dropTargetIndex === entryRow.index && root.draggingIndex !== -1 && root.draggingIndex !== entryRow.index && root.dropTargetIndex >= root.draggingIndex
            }

            HoverHandler {
                id: itemHover
            }

            TapHandler {
                onTapped: Config.state.toggleSystrayItemInBar(entryRow.entryId)
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.leftMargin: Config.menu.padding
                anchors.rightMargin: Config.menu.padding
                spacing: Config.menu.colSpacing

                Item {
                    id: dragHandle
                    implicitWidth: dragHandleText.implicitWidth + 8
                    Layout.fillHeight: true

                    Text {
                        id: dragHandleText
                        text: "⠿"
                        font.family: Config.menu.font.family
                        font.pointSize: Config.menu.font.pointSize
                        color: Config.theme.color.textMuted
                        anchors.centerIn: parent
                    }

                    DragHandler {
                        id: dragHandler
                        xAxis.enabled: false
                        grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByHandlersOfSameType
                        onActiveChanged: {
                            console.error(active)
                            if (active) {
                                root.draggingIndex = entryRow.index;
                                root.dragTranslateY = 0;
                                root.dropTargetIndex = entryRow.index;
                            } else {
                                if (root.draggingIndex !== -1) {
                                    root.commitReorder(root.draggingIndex, root.dropTargetIndex);
                                }
                                root.draggingIndex = -1;
                                root.dropTargetIndex = -1;
                                root.dragTranslateY = 0;
                            }
                        }
                        onActiveTranslationChanged: {
                            if (!active) return;
                            // root.dragTranslateY = activeTranslation.y;
                            // root.dropTargetIndex = root.computeDropIndex(entryRow.index, activeTranslation.y);
                        }
                    }
                }

                SystemIcon {
                    source: Config.checkboxIcon(!Config.state.isSystrayItemHiddenInBar(entryRow.entryId))
                    size: Config.menu.iconSize
                }

                SystemIcon {
                    visible: !entryRow.isOthers
                    source: {
                        if (entryRow.isOthers) return "";
                        for (let i = 0; i < repeater.count; i++) {
                            let d = repeater.itemAt(i);
                            if (d && d.itemData.id === entryRow.entryId) return d.itemData.icon;
                        }
                        return "";
                    }
                    size: Config.menu.iconSize
                }

                Text {
                    text: entryRow.isOthers ? "Others" : entryRow.entryId
                    font.family: Config.menu.font.family
                    font.pointSize: Config.menu.font.pointSize
                    font.italic: entryRow.isOthers
                    color: Config.theme.color.text
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
