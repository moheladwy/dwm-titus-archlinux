import QtQuick
import qs.core

Loader {
    id: root

    required property bool selected
    required property bool windowVisible
    property bool dataLoading: false
    property bool visited: false
    property bool presented: false
    property Item paneItem: null

    // Keep visited items alive to preserve drafts and scroll positions. Reserve
    // the whole pane while its initial asynchronous snapshot and layout settle.
    active: visited
    asynchronous: true
    visible: selected
    focus: true

    function updatePresentation() {
        if (!windowVisible || !selected) return;
        visited = true;
        if (!presented && status === Loader.Ready && !dataLoading)
            presentationTimer.restart();
    }
    onSelectedChanged: updatePresentation()
    onWindowVisibleChanged: updatePresentation()
    onDataLoadingChanged: updatePresentation()
    onStatusChanged: updatePresentation()
    Component.onCompleted: updatePresentation()

    // An asynchronous Loader parents the incubating pane before it finishes
    // the pane's bindings and assigns `item`, so hide that child directly.
    onChildrenChanged: {
        for (const child of children) {
            if (child !== loadingText) paneItem = child;
        }
    }

    // Opacity keeps the loaded layout participating in polish while hiding
    // intermediate geometry. Later refreshes never hide usable controls.
    Binding {
        target: root.paneItem
        property: "opacity"
        value: root.presented ? 1 : 0
        when: root.paneItem !== null
    }
    Binding {
        target: root.paneItem
        property: "enabled"
        value: root.presented
        when: root.paneItem !== null
    }
    Timer {
        id: presentationTimer
        interval: 0
        onTriggered: {
            if (root.windowVisible && root.selected && root.status === Loader.Ready
                    && !root.dataLoading)
                root.presented = true;
        }
    }
    UiText {
        id: loadingText

        anchors.centerIn: parent
        width: Math.max(0, parent.width - Theme.spacingXl * 2)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !root.presented
        text: root.status === Loader.Error ? "This settings panel could not be loaded."
            : "Loading settings..."
        color: Theme.menuMutedText
    }
}
