import QtQuick
import QtQuick.Layouts
import qs.core

PanelPill {
    id: root

    signal activated

    Layout.preferredWidth: Theme.pillHeight
    Layout.preferredHeight: Theme.pillHeight
    hovered: logoMouse.containsMouse

    Image {
        id: logoImage

        anchors.centerIn: parent
        width: Theme.scaledSize(22)
        height: Theme.scaledSize(22)
        // Shipped by the Arch Linux filesystem package, which every Arch
        // system has installed.
        source: "file:///usr/share/pixmaps/archlinux-logo.svg"
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }

    UiText {
        anchors.centerIn: parent
        visible: logoImage.status === Image.Error
        text: "Arch"
        color: Theme.accent
        font.pixelSize: Theme.tinyFontSize
        font.bold: true
    }

    MouseArea {
        id: logoMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
