pragma ComponentBehavior: Bound

import QtQuick

/**
 * Base component for all interactive UI elements.
 * 
 * Provides common functionality including:
 * - State management with loading, disabled, and error states
 * - Hover effects and cursor management
 * - Keyboard navigation support
 * - Accessibility properties
 * - Consistent animation patterns
 * 
 * This component should be used as a base for all interactive components
 * to ensure consistent behavior across the application.
 */
Item {
    id: root

    /**
     * Component states enumeration
     */
    enum State {
        Normal,     // Default interactive state
        Loading,    // Processing/async operation in progress
        Disabled,   // Non-interactive state
        Error,      // Error state
        Focused     // Keyboard focus state
    }

    /**
     * Current component state
     * @type {InteractiveBase.State}
     * @default InteractiveBase.Normal
     */
    property int state: InteractiveBase.Normal

    /**
     * Whether the component is interactive
     * @type {boolean}
     */
    property bool interactive: state !== InteractiveBase.Disabled && state !== InteractiveBase.Loading

    /**
     * Whether the component is currently hovered
     * @type {boolean}
     * @readonly
     */
    property bool hovered: mouseArea.containsMouse

    /**
     * Whether the component has keyboard focus
     * @type {boolean}
     * @readonly
     */
    property bool focused: activeFocus

    /**
     * Cursor shape when hovering
     * @type {Qt.CursorShape}
     */
    property cursorShape: interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

    /**
     * Accessibility role for screen readers
     * @type {string}
     */
    property string accessibleRole: "button"

    /**
     * Accessibility description
     * @type {string}
     */
    property string accessibleDescription: ""

    /**
     * Emitted when the component is clicked
     */
    signal clicked

    /**
     * Emitted when the component state changes
     * @param {int} newState - The new state value
     */
    signal stateChanged(int newState)

    /**
     * Emitted when hover state changes
     * @param {boolean} hovered - Whether the component is hovered
     */
    signal hoverChanged(bool hovered)

    // Visual feedback
    opacity: state === InteractiveBase.Disabled ? 0.5 : 1.0
    scale: hovered && interactive ? 1.02 : 1.0

    // Animation for scale changes
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // Mouse area for interaction
    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.cursorShape
        enabled: root.interactive

        onClicked: root.clicked()
        onHoveredChanged: root.hoverChanged(containsMouse)
    }

    // Accessibility
    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleDescription
    Accessible.enabled: root.interactive
    Accessible.focusable: true

    // State change handler
    onStateChanged: {
        // Update accessibility based on state
        switch (state) {
            case InteractiveBase.Disabled:
                Accessible.name = root.accessibleDescription + " (disabled)"
                break
            case InteractiveBase.Loading:
                Accessible.name = root.accessibleDescription + " (loading)"
                break
            case InteractiveBase.Error:
                Accessible.name = root.accessibleDescription + " (error)"
                break
            default:
                Accessible.name = root.accessibleDescription
                break
        }
        
        root.stateChanged(state)
    }

    // Focus handling
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
            root.clicked()
            event.accepted = true
        }
    }

    /**
     * Sets the component state with validation
     * @param {int} newState - The state to set
     */
    function setState(newState: int): void {
        if (newState >= InteractiveBase.Normal && newState <= InteractiveBase.Focused) {
            state = newState
        } else {
            console.warn("Invalid state:", newState)
        }
    }

    /**
     * Temporarily disables the component for a specified duration
     * @param {int} duration - Duration in milliseconds
     */
    function disableFor(duration: int): void {
        const previousState: int = state
        setState(InteractiveBase.Disabled)
        
        disableTimer.interval = duration
        disableTimer.restart()
        
        disableTimer.onTriggered = () => {
            setState(previousState)
        }
    }

    // Timer for temporary disable functionality
    Timer {
        id: disableTimer
    }
}
