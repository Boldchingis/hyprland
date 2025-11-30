pragma Singleton

import qs.config
import Caelestia.Services
import Caelestia
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

/**
 * Audio service singleton for managing system audio through Pipewire.
 * 
 * Provides comprehensive audio control including:
 * - Volume management for sinks and sources
 * - Audio device switching
 * - Mute/unmute functionality  
 * - Audio visualization (cava and beat tracking)
 * - Toast notifications for device changes
 * - Error handling and recovery
 * 
 * @singleton
 */
Singleton {
    id: root

    /**
     * Previous audio sink name for change detection
     * @type {string}
     * @private
     */
    property string previousSinkName: ""
    
    /**
     * Previous audio source name for change detection
     * @type {string}
     * @private
     */
    property string previousSourceName: ""

    /**
     * Service ID for logging
     * @type {string}
     * @private
     */
    readonly property string serviceId: "Audio"

    /**
     * Processed audio nodes categorized by type
     * @type {{sinks: PwNode[], sources: PwNode[]}}
     * @readonly
     */
    readonly property var nodes: Pipewire.nodes.values.reduce((acc, node) => {
        if (!node.isStream) {
            if (node.isSink)
                acc.sinks.push(node);
            else if (node.audio)
                acc.sources.push(node);
        }
        return acc;
    }, {
        sources: [],
        sinks: []
    })

    /**
     * Available audio output devices (speakers, headphones, etc.)
     * @type {PwNode[]}
     * @readonly
     */
    readonly property list<PwNode> sinks: nodes.sinks
    
    /**
     * Available audio input devices (microphones, etc.)
     * @type {PwNode[]}
     * @readonly
     */
    readonly property list<PwNode> sources: nodes.sources

    /**
     * Currently active audio output device
     * @type {PwNode}
     * @readonly
     */
    readonly property PwNode sink: Pipewire.defaultAudioSink
    
    /**
     * Currently active audio input device
     * @type {PwNode}
     * @readonly
     */
    readonly property PwNode source: Pipewire.defaultAudioSource

    /**
     * Whether the current audio output is muted
     * @type {boolean}
     * @readonly
     */
    readonly property bool muted: !!sink?.audio?.muted
    
    /**
     * Current audio output volume (0.0 to 1.0)
     * @type {real}
     * @readonly
     */
    readonly property real volume: sink?.audio?.volume ?? 0

    /**
     * Whether the current audio input is muted
     * @type {boolean}
     * @readonly
     */
    readonly property bool sourceMuted: !!source?.audio?.muted
    
    /**
     * Current audio input volume (0.0 to 1.0)
     * @type {real}
     * @readonly
     */
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    /**
     * Audio visualization provider (cava)
     * @type {CavaProvider}
     * @readonly
     */
    readonly property alias cava: cava
    
    /**
     * Beat tracking provider for audio visualization
     * @type {BeatTracker}
     * @readonly
     */
    readonly property alias beatTracker: beatTracker

    /**
     * Sets the audio output volume with bounds checking
     * @param {real} newVolume - Volume level (0.0 to 1.0)
     */
    function setVolume(newVolume: real): void {
        const operationId: string = Logger.startTimer("Audio.setVolume")
        
        try {
            if (!sink?.ready || !sink?.audio) {
                Logger.error("Cannot set volume: audio sink not ready", {
                    sinkExists: !!sink,
                    sinkReady: sink?.ready,
                    sinkAudio: !!sink?.audio,
                    requestedVolume: newVolume
                }, serviceId)
                return
            }

            if (newVolume < 0 || newVolume > 1) {
                Logger.warning("Audio volume out of bounds, clamping", {
                    requestedVolume: newVolume,
                    minVolume: 0,
                    maxVolume: 1
                }, serviceId)
                newVolume = Math.max(0, Math.min(1, newVolume))
            }

            const clampedVolume: real = Math.max(0, Math.min(Config.services.maxVolume, newVolume))
            
            sink.audio.muted = false
            sink.audio.volume = clampedVolume
            
            Logger.info("Volume set successfully", {
                newVolume: clampedVolume,
                deviceName: sink.description || sink.name
            }, serviceId)
            
        } catch (error) {
            Logger.error("Failed to set volume", {
                error: error.toString(),
                requestedVolume: newVolume,
                sink: sink?.name
            }, serviceId)
        } finally {
            Logger.endTimer(operationId, 50)
        }
    }

    /**
     * Increases the audio output volume by a specified amount
     * @param {real} amount - Amount to increase (defaults to config value)
     */
    function incrementVolume(amount: real): void {
        const incrementAmount: real = amount || Config.services.audioIncrement
        const currentVolume: real = volume
        
        Logger.debug("Incrementing volume", {
            currentVolume: currentVolume,
            incrementAmount: incrementAmount
        }, serviceId)
        
        setVolume(currentVolume + incrementAmount)
    }

    /**
     * Decreases the audio output volume by a specified amount
     * @param {real} amount - Amount to decrease (defaults to config value)
     */
    function decrementVolume(amount: real): void {
        const decrementAmount: real = amount || Config.services.audioIncrement
        const currentVolume: real = volume
        
        Logger.debug("Decrementing volume", {
            currentVolume: currentVolume,
            decrementAmount: decrementAmount
        }, serviceId)
        
        setVolume(currentVolume - decrementAmount)
    }

    /**
     * Sets the audio input volume with bounds checking
     * @param {real} newVolume - Volume level (0.0 to 1.0)
     */
    function setSourceVolume(newVolume: real): void {
        const operationId: string = Logger.startTimer("Audio.setSourceVolume")
        
        try {
            if (!source?.ready || !source?.audio) {
                Logger.error("Cannot set source volume: audio source not ready", {
                    sourceExists: !!source,
                    sourceReady: source?.ready,
                    sourceAudio: !!source?.audio,
                    requestedVolume: newVolume
                }, serviceId)
                return
            }

            const clampedVolume: real = Math.max(0, Math.min(Config.services.maxVolume, newVolume))
            
            source.audio.muted = false
            source.audio.volume = clampedVolume
            
            Logger.info("Source volume set successfully", {
                newVolume: clampedVolume,
                deviceName: source.description || source.name
            }, serviceId)
            
        } catch (error) {
            Logger.error("Failed to set source volume", {
                error: error.toString(),
                requestedVolume: newVolume,
                source: source?.name
            }, serviceId)
        } finally {
            Logger.endTimer(operationId, 50)
        }
    }

    /**
     * Increases the audio input volume by a specified amount
     * @param {real} amount - Amount to increase (defaults to config value)
     */
    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || Config.services.audioIncrement));
    }

    /**
     * Decreases the audio input volume by a specified amount
     * @param {real} amount - Amount to decrease (defaults to config value)
     */
    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || Config.services.audioIncrement));
    }

    /**
     * Sets the default audio output device
     * @param {PwNode} newSink - The audio sink to set as default
     */
    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
    }

    /**
     * Sets the default audio input device
     * @param {PwNode} newSource - The audio source to set as default
     */
    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || qsTr("Unknown Device");

        if (previousSinkName && previousSinkName !== newSinkName && Config.utilities.toasts.audioOutputChanged)
            Toaster.toast(qsTr("Audio output changed"), qsTr("Now using: %1").arg(newSinkName), "volume_up");

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || qsTr("Unknown Device");

        if (previousSourceName && previousSourceName !== newSourceName && Config.utilities.toasts.audioInputChanged)
            Toaster.toast(qsTr("Audio input changed"), qsTr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    Component.onCompleted: {
        previousSinkName = sink?.description || sink?.name || qsTr("Unknown Device");
        previousSourceName = source?.description || source?.name || qsTr("Unknown Device");
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources]
    }

    CavaProvider {
        id: cava

        bars: Config.services.visualiserBars
    }

    BeatTracker {
        id: beatTracker
    }
}
