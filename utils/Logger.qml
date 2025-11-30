pragma Singleton

import QtQuick

/**
 * Global error handling and logging utility.
 * 
 * Provides centralized error handling, logging, and debugging functionality:
 * - Structured logging with multiple levels
 * - Error collection and reporting
 * - Performance monitoring
 * - Debug utilities
 * - Error recovery suggestions
 * 
 * @singleton
 */
Singleton {
    id: root

    /**
     * Log levels enumeration
     */
    enum LogLevel {
        Debug = 0,
        Info = 1,
        Warning = 2,
        Error = 3,
        Critical = 4
    }

    /**
     * Current log level (messages below this level are filtered)
     * @type {Logger.LogLevel}
     */
    property int logLevel: Logger.LogLevel.Info

    /**
     * Whether to enable debug logging
     * @type {boolean}
     */
    property bool debugMode: false

    /**
     * Maximum number of errors to keep in memory
     * @type {int}
     */
    property int maxErrorHistory: 100

    /**
     * Collection of recent errors for debugging
     * @type {list<ErrorEntry>}
     * @readonly
     */
    property list<var> errorHistory: []

    /**
     * Performance metrics collection
     * @type {var}
     * @readonly
     */
    property var performanceMetrics: ({
        componentLoadTimes: {},
        operationTimes: {},
        memoryUsage: []
    })

    /**
     * Emitted when a new error is logged
     * @param {string} message - Error message
     * @param {object} context - Error context
     * @param {string} timestamp - Error timestamp
     */
    signal errorLogged(string message, var context, string timestamp)

    /**
     * Emitted when performance threshold is exceeded
     * @param {string} operation - Operation name
     * @param {real} duration - Operation duration in ms
     * @param {real} threshold - Threshold that was exceeded
     */
    signal performanceWarning(string operation, real duration, real threshold)

    /**
     * Logs a debug message
     * @param {string} message - Message to log
     * @param {object} context - Additional context data
     * @param {string} component - Component identifier
     */
    function debug(message: string, context: object = {}, component: string = ""): void {
        log(Logger.LogLevel.Debug, message, context, component)
    }

    /**
     * Logs an informational message
     * @param {string} message - Message to log
     * @param {object} context - Additional context data
     * @param {string} component - Component identifier
     */
    function info(message: string, context: object = {}, component: string = ""): void {
        log(Logger.LogLevel.Info, message, context, component)
    }

    /**
     * Logs a warning message
     * @param {string} message - Warning to log
     * @param {object} context - Additional context data
     * @param {string} component - Component identifier
     */
    function warning(message: string, context: object = {}, component: string = ""): void {
        log(Logger.LogLevel.Warning, message, context, component)
    }

    /**
     * Logs an error message
     * @param {string} message - Error to log
     * @param {object} context - Additional context data
     * @param {string} component - Component identifier
     */
    function error(message: string, context: object = {}, component: string = ""): void {
        log(Logger.LogLevel.Error, message, context, component)
    }

    /**
     * Logs a critical error message
     * @param {string} message - Critical error to log
     * @param {object} context - Additional context data
     * @param {string} component - Component identifier
     */
    function critical(message: string, context: object = {}, component: string = ""): void {
        log(Logger.LogLevel.Critical, message, context, component)
    }

    /**
     * Core logging function
     * @param {int} level - Log level
     * @param {string} message - Message to log
     * @param {object} context - Additional context data
     * @param {string} component - Component identifier
     * @private
     */
    function log(level: int, message: string, context: object, component: string): void {
        if (level < logLevel) {
            return
        }

        const timestamp: string = new Date().toISOString()
        const levelName: string = ["DEBUG", "INFO", "WARN", "ERROR", "CRITICAL"][level]
        const componentPrefix: string = component ? `[${component}]` : ""
        const formattedMessage: string = `${timestamp} ${levelName} ${componentPrefix} ${message}`

        // Output to console
        switch (level) {
            case Logger.LogLevel.Debug:
            case Logger.LogLevel.Info:
                console.log(formattedMessage, context)
                break
            case Logger.LogLevel.Warning:
                console.warn(formattedMessage, context)
                break
            case Logger.LogLevel.Error:
            case Logger.LogLevel.Critical:
                console.error(formattedMessage, context)
                break
        }

        // Store errors in history
        if (level >= Logger.LogLevel.Error) {
            addErrorToHistory(message, context, component, timestamp, level)
        }
    }

    /**
     * Adds an error to the error history
     * @param {string} message - Error message
     * @param {object} context - Error context
     * @param {string} component - Component where error occurred
     * @param {string} timestamp - Error timestamp
     * @param {int} level - Error level
     * @private
     */
    function addErrorToHistory(message: string, context: object, component: string, timestamp: string, level: int): void {
        const errorEntry = {
            message: message,
            context: context,
            component: component,
            timestamp: timestamp,
            level: level,
            id: errorHistory.length
        }

        errorHistory.push(errorEntry)

        // Trim history if it exceeds maximum
        if (errorHistory.length > maxErrorHistory) {
            errorHistory.splice(0, errorHistory.length - maxErrorHistory)
        }

        errorLogged(message, context, timestamp)
    }

    /**
     * Starts performance monitoring for an operation
     * @param {string} operation - Operation name
     * @returns {string} Operation ID for ending timing
     */
    function startTimer(operation: string): string {
        const operationId: string = `${operation}_${Date.now()}_${Math.random()}`
        performanceMetrics.operationTimes[operationId] = Date.now()
        return operationId
    }

    /**
     * Ends performance monitoring for an operation
     * @param {string} operationId - Operation ID from startTimer
     * @param {real} warningThreshold - Threshold for performance warning (ms)
     */
    function endTimer(operationId: string, warningThreshold: real = 100): void {
        const startTime: real = performanceMetrics.operationTimes[operationId]
        if (!startTime) {
            warning("Timer not found for operation ID", { operationId: operationId }, "Logger")
            return
        }

        const duration: real = Date.now() - startTime
        delete performanceMetrics.operationTimes[operationId]

        // Extract operation name from ID
        const operation: string = operationId.split('_').slice(0, -2).join('_')

        // Store performance data
        if (!performanceMetrics.componentLoadTimes[operation]) {
            performanceMetrics.componentLoadTimes[operation] = []
        }
        performanceMetrics.componentLoadTimes[operation].push(duration)

        // Check threshold
        if (duration > warningThreshold) {
            performanceWarning(operation, duration, warningThreshold)
            warning(`Performance threshold exceeded: ${operation} took ${duration}ms`, {
                operation: operation,
                duration: duration,
                threshold: warningThreshold
            }, "Logger")
        }

        debug(`Operation completed: ${operation} in ${duration}ms`, { operation: operation, duration: duration }, "Logger")
    }

    /**
     * Monitors memory usage
     * @param {string} component - Component being monitored
     */
    function trackMemoryUsage(component: string): void {
        // Note: QML doesn't have direct memory access, but we can track component creation/destruction
        performanceMetrics.memoryUsage.push({
            component: component,
            timestamp: Date.now(),
            type: "component_created"
        })

        // Keep only recent memory usage data
        if (performanceMetrics.memoryUsage.length > 1000) {
            performanceMetrics.memoryUsage.splice(0, 500)
        }
    }

    /**
     * Gets error statistics
     * @returns {object} Error statistics object
     */
    function getErrorStats(): object {
        const stats = {
            total: errorHistory.length,
            byLevel: {},
            byComponent: {},
            recent: errorHistory.slice(-10)
        }

        for (let i = 0; i < errorHistory.length; i++) {
            const error = errorHistory[i]
            const levelName = ["DEBUG", "INFO", "WARN", "ERROR", "CRITICAL"][error.level]
            
            stats.byLevel[levelName] = (stats.byLevel[levelName] || 0) + 1
            stats.byComponent[error.component] = (stats.byComponent[error.component] || 0) + 1
        }

        return stats
    }

    /**
     * Clears error history
     */
    function clearErrors(): void {
        errorHistory.splice(0, errorHistory.length)
        info("Error history cleared", {}, "Logger")
    }

    /**
     * Generates a performance report
     * @returns {object} Performance report
     */
    function getPerformanceReport(): object {
        const report = {
            componentLoadTimes: {},
            slowOperations: [],
            memoryStats: {
                totalTracked: performanceMetrics.memoryUsage.length
            }
        }

        // Calculate average load times
        for (const component in performanceMetrics.componentLoadTimes) {
            const times = performanceMetrics.componentLoadTimes[component]
            const avg = times.reduce((sum, time) => sum + time, 0) / times.length
            const max = Math.max(...times)
            const min = Math.min(...times)

            report.componentLoadTimes[component] = {
                average: avg,
                max: max,
                min: min,
                samples: times.length
            }

            if (avg > 100) {
                report.slowOperations.push({
                    component: component,
                    averageTime: avg,
                    maxTime: max
                })
            }
        }

        return report
    }

    /**
     * Handles uncaught exceptions
     * @param {Error} error - The uncaught error
     * @param {string} component - Component where error occurred
     */
    function handleUncaughtError(error: Error, component: string = ""): void {
        critical(`Uncaught error: ${error.message}`, {
            stack: error.stack,
            name: error.name
        }, component || "Unknown")

        // Try to recover gracefully
        try {
            // Log additional context
            error("Attempting error recovery", { component: component }, "Logger")
        } catch (recoveryError) {
            critical("Error recovery failed", { recoveryError: recoveryError.toString() }, "Logger")
        }
    }

    Component.onCompleted: {
        info("Logger initialized", { logLevel: logLevel, debugMode: debugMode }, "Logger")
    }
}
