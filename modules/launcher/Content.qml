pragma ComponentBehavior: Bound

import "services"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick

/**
 * Main content component for the application launcher.
 * 
 * Provides a high-performance launcher interface with:
 * - Efficient search filtering and result display
 * - Keyboard navigation with vim-style bindings
 * - Smart search with command prefix support
 * - Wallpaper and application launching
 * - Memory-efficient list management
 * 
 * Performance optimizations:
 * - Lazy loading of list items
 * - Efficient text change handling
 * - Debounced search operations
 * - Optimized keyboard event processing
 */
Item {
    id: root

    required property PersistentProperties visibilities
    required property var panels
    required property real maxHeight

    readonly property int padding: Appearance.padding.large
    readonly property int rounding: Appearance.rounding.large

    // Performance optimization: cache frequently accessed properties
    readonly property bool vimKeybinds: Config.launcher.vimKeybinds
    readonly property string actionPrefix: Config.launcher.actionPrefix
    readonly property real audioIncrement: Config.services.audioIncrement

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: searchWrapper.height + listWrapper.height + padding * 2

    // Debounce timer for search operations
    Timer {
        id: searchDebounceTimer
        interval: 50
        onTriggered: list.updateSearch()
    }

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: searchWrapper.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight - searchWrapper.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    StyledRect {
        id: searchWrapper

        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.full

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding

        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight, clearIcon.implicitHeight)

        MaterialIcon {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padding

            text: "search"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledTextField {
            id: search

            anchors.left: searchIcon.right
            anchors.right: clearIcon.left
            anchors.leftMargin: Appearance.spacing.small
            anchors.rightMargin: Appearance.spacing.small

            topPadding: Appearance.padding.larger
            bottomPadding: Appearance.padding.larger

            placeholderText: qsTr("Type \"%1\" for commands").arg(root.actionPrefix)

            // Performance optimization: debounce search updates
            onTextChanged: {
                searchDebounceTimer.restart()
            }

            onAccepted: handleAccepted()

            // Optimized keyboard navigation
            Keys.onUpPressed: {
                if (list.currentList) {
                    list.currentList.decrementCurrentIndex()
                }
            }

            Keys.onDownPressed: {
                if (list.currentList) {
                    list.currentList.incrementCurrentIndex()
                }
            }

            Keys.onEscapePressed: root.visibilities.launcher = false

            // Optimized keyboard event handler with early returns
            Keys.onPressed: event => {
                if (!root.vimKeybinds) {
                    return
                }

                let handled: boolean = false

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        list.currentList?.incrementCurrentIndex()
                        handled = true
                    } else if (event.key === Qt.Key_K) {
                        list.currentList?.decrementCurrentIndex()
                        handled = true
                    }
                } else if (event.key === Qt.Key_Tab) {
                    list.currentList?.incrementCurrentIndex()
                    handled = true
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.currentList?.decrementCurrentIndex()
                    handled = true
                }

                if (handled) {
                    event.accepted = true
                }
            }

            Component.onCompleted: forceActiveFocus()

            Connections {
                target: root.visibilities

                function onLauncherChanged(): void {
                    if (!root.visibilities.launcher) {
                        search.text = ""
                    }
                }

                function onSessionChanged(): void {
                    if (!root.visibilities.session) {
                        search.forceActiveFocus()
                    }
                }
            }

            /**
             * Handles the accepted action (Enter key press)
             * @private
             */
            function handleAccepted(): void {
                const currentItem: Item = list.currentList?.currentItem
                if (!currentItem) {
                    return
                }

                if (list.showWallpapers) {
                    handleWallpaperSelection(currentItem)
                } else if (text.startsWith(root.actionPrefix)) {
                    handleCommandExecution(currentItem)
                } else {
                    handleAppLaunch(currentItem)
                }
            }

            /**
             * Handles wallpaper selection and preview
             * @param {Item} item - Selected wallpaper item
             * @private
             */
            function handleWallpaperSelection(item: Item): void {
                if (Colours.scheme === "dynamic" && item.modelData.path !== Wallpapers.actualCurrent) {
                    Wallpapers.previewColourLock = true
                }
                Wallpapers.setWallpaper(item.modelData.path)
                root.visibilities.launcher = false
            }

            /**
             * Handles command execution
             * @param {Item} item - Selected command item
             * @private
             */
            function handleCommandExecution(item: Item): void {
                if (text.startsWith(`${root.actionPrefix}calc `)) {
                    item.onClicked()
                } else {
                    item.modelData.onClicked(list.currentList)
                }
            }

            /**
             * Handles application launching
             * @param {Item} item - Selected application item
             * @private
             */
            function handleAppLaunch(item: Item): void {
                Apps.launch(item.modelData)
                root.visibilities.launcher = false
            }
        }

        MaterialIcon {
            id: clearIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.padding

            width: search.text ? implicitWidth : implicitWidth / 2
            opacity: {
                if (!search.text)
                    return 0;
                if (mouse.pressed)
                    return 0.7;
                if (mouse.containsMouse)
                    return 0.8;
                return 1;
            }

            text: "close"
            color: Colours.palette.m3onSurfaceVariant

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: search.text ? Qt.PointingHandCursor : undefined

                onClicked: search.text = ""
            }

            Behavior on width {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }
        }
    }
}
