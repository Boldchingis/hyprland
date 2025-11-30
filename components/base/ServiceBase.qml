pragma ComponentBehavior: Bound

import QtQuick

/**
 * Service base class for all service singletons.
 * 
 * Provides common service functionality including:
 * - Initialization and cleanup lifecycle management
 * - Error handling and logging
 * - Service state tracking
 * - Event emission patterns
 * - Configuration integration
 * 
 * All service singletons should inherit from this base to ensure
 * consistent behavior and proper resource management.
 */
Item {
    id: root

    /**
     * Service states enumeration
     */
    enum ServiceState {
        Uninitialized,  // Service not yet initialized
        Initializing,  // Service is starting up
        Ready,         // Service is ready and operational
        Error,         // Service encountered an error
        Stopping,      // Service is shutting down
        Stopped        // Service has been stopped
    }

    /**
     * Current service state
     * @type {ServiceBase.ServiceState}
     * @readonly
     */
    property int state: ServiceBase.Uninitialized

    /**
     * Service identifier for logging and debugging
     * @type {string}
     */
    property string serviceId: ""

    /**
     * Whether the service is ready for use
     * @type {boolean}
     * @readonly
     */
    property bool ready: state === ServiceBase.Ready

    /**
     * Whether the service has encountered an error
     * @type {boolean}
     * @readonly
     */
    property bool hasError: state === ServiceBase.Error

    /**
     * Last error message (if any)
     * @type {string}
     * @readonly
     */
    property string lastError: ""

    /**
     * Service version
     * @type {string}
     * @readonly
     */
    property string version: "1.0.0"

    /**
     * Emitted when service state changes
     * @param {int} newState - The new service state
     * @param {int} oldState - The previous service state
     */
    signal stateChanged(int newState, int oldState)

    /**
     * Emitted when the service encounters an error
     * @param {string} error - Error description
     * @param {object} context - Additional error context
     */
    signal serviceError(string error, var context)

    /**
     * Emitted when the service is ready for use
     */
    signal serviceReady()

    /**
     * Emitted when the service is shutting down
     */
    signal serviceStopping()

    /**
     * Sets the service state with proper transition handling
     * @param {int} newState - The new service state
     * @private
     */
    function setState(newState: int): void {
        const oldState: int = state
        
        if (oldState === newState) {
            return
        }

        // Validate state transitions
        if (!isValidTransition(oldState, newState)) {
            logError(`Invalid state transition: ${oldState} -> ${newState}`)
            return
        }

        state = newState
        logInfo(`Service state changed: ${oldState} -> ${newState}`)
        
        stateChanged(newState, oldState)

        // Handle specific state transitions
        switch (newState) {
            case ServiceBase.Ready:
                serviceReady()
                break
            case ServiceBase.Error:
                serviceError(lastError, {})
                break
            case ServiceBase.Stopping:
                serviceStopping()
                break
        }
    }

    /**
     * Validates state transitions
     * @param {int} fromState - Current state
     * @param {int} toState - Target state
     * @returns {boolean} Whether the transition is valid
     * @private
     */
    function isValidTransition(fromState: int, toState: int): boolean {
        // Define valid transitions
        const validTransitions = {
            [ServiceBase.Uninitialized]: [ServiceBase.Initializing],
            [ServiceBase.Initializing]: [ServiceBase.Ready, ServiceBase.Error],
            [ServiceBase.Ready]: [ServiceBase.Stopping, ServiceBase.Error],
            [ServiceBase.Error]: [ServiceBase.Initializing, ServiceBase.Stopping],
            [ServiceBase.Stopping]: [ServiceBase.Stopped],
            [ServiceBase.Stopped]: [ServiceBase.Initializing]
        }

        return validTransitions[fromState]?.includes(toState) || false
    }

    /**
     * Initializes the service
     * Override this method in derived classes
     * @returns {Promise<void>}
     */
    function initialize(): void {
        setState(ServiceBase.Initializing)
        
        try {
            // Perform initialization logic here
            setState(ServiceBase.Ready)
        } catch (error) {
            setError(`Initialization failed: ${error}`)
        }
    }

    /**
     * Stops the service
     * Override this method in derived classes
     * @returns {Promise<void>}
     */
    function stop(): void {
        if (state === ServiceBase.Stopped || state === ServiceBase.Stopping) {
            return
        }

        setState(ServiceBase.Stopping)
        
        try {
            // Perform cleanup logic here
            setState(ServiceBase.Stopped)
        } catch (error) {
            setError(`Stop failed: ${error}`)
        }
    }

    /**
     * Sets an error state with message
     * @param {string} error - Error description
     * @param {object} context - Additional error context
     */
    function setError(error: string, context: object = {}): void {
        lastError = error
        logError(error, context)
        setState(ServiceBase.Error)
    }

    /**
     * Logs an informational message
     * @param {string} message - Message to log
     * @param {object} context - Additional context
     */
    function logInfo(message: string, context: object = {}): void {
        const prefix = serviceId ? `[${serviceId}]` : "[Service]"
        console.log(`${prefix} ${message}`, context)
    }

    /**
     * Logs a warning message
     * @param {string} message - Warning to log
     * @param {object} context - Additional context
     */
    function logWarning(message: string, context: object = {}): void {
        const prefix = serviceId ? `[${serviceId}]` : "[Service]"
        console.warn(`${prefix} ${message}`, context)
    }

    /**
     * Logs an error message
     * @param {string} message - Error to log
     * @param {object} context - Additional context
     */
    function logError(message: string, context: object = {}): void {
        const prefix = serviceId ? `[${serviceId}]` : "[Service]"
        console.error(`${prefix} ${message}`, context)
    }

    /**
     * Restarts the service
     */
    function restart(): void {
        stop()
        
        // Wait for stop to complete before reinitializing
        restartTimer.restart()
    }

    // Timer for restart functionality
    Timer {
        id: restartTimer
        interval: 100
        onTriggered: initialize()
    }

    // Auto-initialize on component completion if configured
    Component.onCompleted: {
        if (serviceId) {
            logInfo("Service component created")
        }
    }

    // Cleanup on destruction
    Component.onDestruction: {
        if (state !== ServiceBase.Stopped) {
            stop()
        }
    }
}
