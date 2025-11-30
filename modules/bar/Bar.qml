pragma ComponentBehavior: Bound

import qs.services
import qs.config
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import Quickshell
import QtQuick
import QtQuick.Layouts

/**
 * Main status bar component for the Hyprland shell.
 * 
 * Provides a flexible bar system with configurable components including:
 * - Workspace management and navigation
 * - System tray integration
 * - Clock display
 * - Active window information
 * - Status icons and system indicators
 * - Power management controls
 * 
 * Features mouse wheel controls for volume/brightness and popout support.
 */
ColumnLayout {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    readonly property int vPadding: Appearance.padding.large

    /**
     * Closes the system tray if it's expanded and in compact mode
     */
    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i: number = 0; i < repeater.count; i++) {
            const item: WrappedLoader = repeater.itemAt(i);
            if (item?.enabled && item.id === "tray") {
                item.item.expanded = false;
            }
        }
    }

    /**
     * Checks for popout interactions at a specific Y coordinate
     * @param {real} y - Y coordinate to check for hover
     */
    function checkPopout(y: real): void {
        const ch: WrappedLoader = childAt(width / 2, y) as WrappedLoader;

        if (ch?.id !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id: string = ch.id;
        const top: real = ch.y;
        const item: Item = ch.item;
        const itemHeight: real = item.implicitHeight;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items: Item = item.items;
            const icon: Item = items.childAt(items.width / 2, mapToItem(items, 0, y).y);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            if (!Config.bar.tray.compact || (item.expanded && !item.expandIcon.contains(mapToItem(item.expandIcon, item.implicitWidth / 2, y)))) {
                const index: number = Math.floor(((y - top - item.padding * 2 + item.spacing) / item.layout.implicitHeight) * item.items.count);
                const trayItem: Item = item.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                item.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = item.mapToItem(root, 0, itemHeight / 2).y;
            popouts.hasCurrent = true;
        }
    }

    /**
     * Handles mouse wheel events for scrolling actions
     * @param {real} y - Y coordinate where the wheel event occurred
     * @param {point} angleDelta - Wheel scroll delta (positive = up, negative = down)
     */
    function handleWheel(y: real, angleDelta: point): void {
        const ch: WrappedLoader = childAt(width / 2, y) as WrappedLoader;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon: PwMonitor = (Config.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs: string = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (Config.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(`workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (y < screen.height / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor: BrightnessMonitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + 0.1);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - 0.1);
        }
    }

    spacing: Appearance.spacing.normal

    Repeater {
        id: repeater

        model: Config.bar.entries

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: WrappedLoader {
                    Layout.fillHeight: enabled
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: WrappedLoader {
                    sourceComponent: OsIcon {}
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    sourceComponent: Workspaces {
                        screen: root.screen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
                    sourceComponent: ActiveWindow {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    sourceComponent: Tray {}
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    sourceComponent: Clock {}
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: WrappedLoader {
                    sourceComponent: StatusIcons {}
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    sourceComponent: Power {
                        visibilities: root.visibilities
                    }
                }
            }
        }
    }

    component WrappedLoader: Loader {
        required property bool enabled
        required property string id
        required property int index

        /**
         * Finds the first enabled item in the repeater
         * @returns {Item|null} The first enabled item or null if none found
         */
        function findFirstEnabled(): Item {
            const count: number = repeater.count;
            for (let i: number = 0; i < count; i++) {
                const item: WrappedLoader = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        /**
         * Finds the last enabled item in the repeater
         * @returns {Item|null} The last enabled item or null if none found
         */
        function findLastEnabled(): Item {
            for (let i: number = repeater.count - 1; i >= 0; i--) {
                const item: WrappedLoader = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        Layout.alignment: Qt.AlignHCenter

        // Cursed ahh thing to add padding to first and last enabled components
        Layout.topMargin: findFirstEnabled() === this ? root.vPadding : 0
        Layout.bottomMargin: findLastEnabled() === this ? root.vPadding : 0

        visible: enabled
        active: enabled
    }
}
