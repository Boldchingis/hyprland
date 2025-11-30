import ".."
import qs.services
import qs.config
import QtQuick

/**
 * A versatile icon button component with Material Design 3 styling.
 * 
 * This component provides three button types:
 * - Filled: Solid background with contrasting icon
 * - Tonal: Subtle background with contrasting icon  
 * - Text: Transparent background with colored icon
 * 
 * Features:
 * - Toggle functionality with state persistence
 * - Disabled state handling
 * - Smooth animations and transitions
 * - Material Design 3 color system integration
 * - Ripple effect through StateLayer
 * 
 * @example
 * IconButton {
 *     icon: "home"
 *     type: IconButton.Filled
 *     toggle: true
 *     onClicked: console.log("Button clicked")
 * }
 */
StyledRect {
    id: root

    /**
     * Button type enumeration following Material Design 3
     */
    enum Type {
        Filled,  // Solid background button
        Tonal,   // Subtle background button
        Text     // Transparent background button
    }

    /**
     * Icon identifier from Material Design Icons set
     * @type {string}
     */
    property alias icon: label.text
    
    /**
     * Checked state for toggle functionality
     * @type {boolean}
     */
    property bool checked
    
    /**
     * Whether button acts as a toggle switch
     * @type {boolean}
     */
    property bool toggle
    
    /**
     * Internal padding around the icon
     * @type {real}
     */
    property real padding: type === IconButton.Text ? Appearance.padding.small / 2 : Appearance.padding.smaller
    
    /**
     * Font properties for the icon
     * @type {font}
     */
    property alias font: label.font
    
    /**
     * Button visual style (Filled/Tonal/Text)
     * @type {IconButton.Type}
     * @default IconButton.Filled
     */
    property int type: IconButton.Filled
    
    /**
     * Whether button is disabled and non-interactive
     * @type {boolean}
     */
    property bool disabled

    property alias stateLayer: stateLayer
    property alias label: label
    property alias radiusAnim: radiusAnim

    property bool internalChecked
    property color activeColour: type === IconButton.Filled ? Colours.palette.m3primary : Colours.palette.m3secondary
    property color inactiveColour: {
        if (!toggle && type === IconButton.Filled)
            return Colours.palette.m3primary;
        return type === IconButton.Filled ? Colours.tPalette.m3surfaceContainer : Colours.palette.m3secondaryContainer;
    }
    property color activeOnColour: type === IconButton.Filled ? Colours.palette.m3onPrimary : type === IconButton.Tonal ? Colours.palette.m3onSecondary : Colours.palette.m3primary
    property color inactiveOnColour: {
        if (!toggle && type === IconButton.Filled)
            return Colours.palette.m3onPrimary;
        return type === IconButton.Tonal ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant;
    }
    property color disabledColour: Qt.alpha(Colours.palette.m3onSurface, 0.1)
    property color disabledOnColour: Qt.alpha(Colours.palette.m3onSurface, 0.38)

    /**
     * Emitted when the button is clicked
     */
    signal clicked

    onCheckedChanged: internalChecked = checked

    radius: internalChecked ? Appearance.rounding.small : implicitHeight / 2
    color: type === IconButton.Text ? "transparent" : disabled ? disabledColour : internalChecked ? activeColour : inactiveColour

    implicitWidth: implicitHeight
    implicitHeight: label.implicitHeight + padding * 2

    StateLayer {
        id: stateLayer

        color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        disabled: root.disabled

        function onClicked(): void {
            if (root.toggle)
                root.internalChecked = !root.internalChecked;
            root.clicked();
        }
    }

    MaterialIcon {
        id: label

        anchors.centerIn: parent
        color: root.disabled ? root.disabledOnColour : root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        fill: !root.toggle || root.internalChecked ? 1 : 0

        Behavior on fill {
            Anim {}
        }
    }

    Behavior on radius {
        Anim {
            id: radiusAnim
        }
    }
}
