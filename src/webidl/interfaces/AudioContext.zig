//! Generated from: webaudio.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioContextImpl = @import("impls").AudioContext;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const AudioTimestamp = @import("dictionaries").AudioTimestamp;
const MediaStreamAudioDestinationNode = @import("interfaces").MediaStreamAudioDestinationNode;
const MediaStreamAudioSourceNode = @import("interfaces").MediaStreamAudioSourceNode;
const (DOMString or AudioSinkInfo) = @import("interfaces").(DOMString or AudioSinkInfo);
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const MediaElementAudioSourceNode = @import("interfaces").MediaElementAudioSourceNode;
const AudioContextOptions = @import("dictionaries").AudioContextOptions;
const MediaStream = @import("interfaces").MediaStream;
const (DOMString or AudioSinkOptions) = @import("interfaces").(DOMString or AudioSinkOptions);
const HTMLMediaElement = @import("interfaces").HTMLMediaElement;
const EventHandler = @import("typedefs").EventHandler;
const MediaStreamTrackAudioSourceNode = @import("interfaces").MediaStreamTrackAudioSourceNode;

pub const AudioContext = struct {
    pub const Meta = struct {
        pub const name = "AudioContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *BaseAudioContext;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            baseLatency: f64 = undefined,
            outputLatency: f64 = undefined,
            sinkId: (DOMString or AudioSinkInfo) = undefined,
            onsinkchange: EventHandler = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_audioWorklet = &get_audioWorklet,
        .get_baseLatency = &get_baseLatency,
        .get_currentTime = &get_currentTime,
        .get_destination = &get_destination,
        .get_listener = &get_listener,
        .get_onerror = &get_onerror,
        .get_onsinkchange = &get_onsinkchange,
        .get_onstatechange = &get_onstatechange,
        .get_outputLatency = &get_outputLatency,
        .get_renderQuantumSize = &get_renderQuantumSize,
        .get_sampleRate = &get_sampleRate,
        .get_sinkId = &get_sinkId,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_onsinkchange = &set_onsinkchange,
        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_createAnalyser = &call_createAnalyser,
        .call_createBiquadFilter = &call_createBiquadFilter,
        .call_createBuffer = &call_createBuffer,
        .call_createBufferSource = &call_createBufferSource,
        .call_createChannelMerger = &call_createChannelMerger,
        .call_createChannelSplitter = &call_createChannelSplitter,
        .call_createConstantSource = &call_createConstantSource,
        .call_createConvolver = &call_createConvolver,
        .call_createDelay = &call_createDelay,
        .call_createDynamicsCompressor = &call_createDynamicsCompressor,
        .call_createGain = &call_createGain,
        .call_createIIRFilter = &call_createIIRFilter,
        .call_createMediaElementSource = &call_createMediaElementSource,
        .call_createMediaStreamDestination = &call_createMediaStreamDestination,
        .call_createMediaStreamSource = &call_createMediaStreamSource,
        .call_createMediaStreamTrackSource = &call_createMediaStreamTrackSource,
        .call_createOscillator = &call_createOscillator,
        .call_createPanner = &call_createPanner,
        .call_createPeriodicWave = &call_createPeriodicWave,
        .call_createScriptProcessor = &call_createScriptProcessor,
        .call_createStereoPanner = &call_createStereoPanner,
        .call_createWaveShaper = &call_createWaveShaper,
        .call_decodeAudioData = &call_decodeAudioData,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getOutputTimestamp = &call_getOutputTimestamp,
        .call_removeEventListener = &call_removeEventListener,
        .call_resume = &call_resume,
        .call_setSinkId = &call_setSinkId,
        .call_suspend = &call_suspend,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AudioContextImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioContextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, contextOptions: AudioContextOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try AudioContextImpl.constructor(instance, contextOptions);
        
        return instance;
    }

    pub fn get_destination(instance: *runtime.Instance) anyerror!AudioDestinationNode {
        return try AudioContextImpl.get_destination(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try AudioContextImpl.get_sampleRate(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try AudioContextImpl.get_currentTime(instance);
    }

    pub fn get_listener(instance: *runtime.Instance) anyerror!AudioListener {
        return try AudioContextImpl.get_listener(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!AudioContextState {
        return try AudioContextImpl.get_state(instance);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) anyerror!u32 {
        return try AudioContextImpl.get_renderQuantumSize(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_audioWorklet(instance: *runtime.Instance) anyerror!AudioWorklet {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_audioWorklet) |cached| {
            return cached;
        }
        const value = try AudioContextImpl.get_audioWorklet(instance);
        state.cached_audioWorklet = value;
        return value;
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioContextImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioContextImpl.set_onstatechange(instance, value);
    }

    pub fn get_baseLatency(instance: *runtime.Instance) anyerror!f64 {
        return try AudioContextImpl.get_baseLatency(instance);
    }

    pub fn get_outputLatency(instance: *runtime.Instance) anyerror!f64 {
        return try AudioContextImpl.get_outputLatency(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_sinkId(instance: *runtime.Instance) anyerror!anyopaque {
        return try AudioContextImpl.get_sinkId(instance);
    }

    pub fn get_onsinkchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioContextImpl.get_onsinkchange(instance);
    }

    pub fn set_onsinkchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioContextImpl.set_onsinkchange(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioContextImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioContextImpl.set_onerror(instance, value);
    }

    pub fn call_createMediaStreamSource(instance: *runtime.Instance, mediaStream: MediaStream) anyerror!MediaStreamAudioSourceNode {
        
        return try AudioContextImpl.call_createMediaStreamSource(instance, mediaStream);
    }

    pub fn call_createChannelMerger(instance: *runtime.Instance, numberOfInputs: u32) anyerror!ChannelMergerNode {
        
        return try AudioContextImpl.call_createChannelMerger(instance, numberOfInputs);
    }

    pub fn call_createDynamicsCompressor(instance: *runtime.Instance) anyerror!DynamicsCompressorNode {
        return try AudioContextImpl.call_createDynamicsCompressor(instance);
    }

    pub fn call_createMediaStreamTrackSource(instance: *runtime.Instance, mediaStreamTrack: MediaStreamTrack) anyerror!MediaStreamTrackAudioSourceNode {
        
        return try AudioContextImpl.call_createMediaStreamTrackSource(instance, mediaStreamTrack);
    }

    pub fn call_createWaveShaper(instance: *runtime.Instance) anyerror!WaveShaperNode {
        return try AudioContextImpl.call_createWaveShaper(instance);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AudioContextImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_createConstantSource(instance: *runtime.Instance) anyerror!ConstantSourceNode {
        return try AudioContextImpl.call_createConstantSource(instance);
    }

    pub fn call_createAnalyser(instance: *runtime.Instance) anyerror!AnalyserNode {
        return try AudioContextImpl.call_createAnalyser(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try AudioContextImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, numberOfChannels: u32, length: u32, sampleRate: f32) anyerror!AudioBuffer {
        
        return try AudioContextImpl.call_createBuffer(instance, numberOfChannels, length, sampleRate);
    }

    pub fn call_createDelay(instance: *runtime.Instance, maxDelayTime: f64) anyerror!DelayNode {
        
        return try AudioContextImpl.call_createDelay(instance, maxDelayTime);
    }

    pub fn call_createMediaElementSource(instance: *runtime.Instance, mediaElement: HTMLMediaElement) anyerror!MediaElementAudioSourceNode {
        
        return try AudioContextImpl.call_createMediaElementSource(instance, mediaElement);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try AudioContextImpl.call_close(instance);
    }

    pub fn call_createPanner(instance: *runtime.Instance) anyerror!PannerNode {
        return try AudioContextImpl.call_createPanner(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try AudioContextImpl.call_when(instance, type_, options);
    }

    pub fn call_suspend(instance: *runtime.Instance) anyerror!anyopaque {
        return try AudioContextImpl.call_suspend(instance);
    }

    pub fn call_getOutputTimestamp(instance: *runtime.Instance) anyerror!AudioTimestamp {
        return try AudioContextImpl.call_getOutputTimestamp(instance);
    }

    pub fn call_createMediaStreamDestination(instance: *runtime.Instance) anyerror!MediaStreamAudioDestinationNode {
        return try AudioContextImpl.call_createMediaStreamDestination(instance);
    }

    pub fn call_createPeriodicWave(instance: *runtime.Instance, real: anyopaque, imag: anyopaque, constraints: PeriodicWaveConstraints) anyerror!PeriodicWave {
        
        return try AudioContextImpl.call_createPeriodicWave(instance, real, imag, constraints);
    }

    pub fn call_createConvolver(instance: *runtime.Instance) anyerror!ConvolverNode {
        return try AudioContextImpl.call_createConvolver(instance);
    }

    pub fn call_createBufferSource(instance: *runtime.Instance) anyerror!AudioBufferSourceNode {
        return try AudioContextImpl.call_createBufferSource(instance);
    }

    pub fn call_createStereoPanner(instance: *runtime.Instance) anyerror!StereoPannerNode {
        return try AudioContextImpl.call_createStereoPanner(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AudioContextImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_createGain(instance: *runtime.Instance) anyerror!GainNode {
        return try AudioContextImpl.call_createGain(instance);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!anyopaque {
        return try AudioContextImpl.call_resume(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setSinkId(instance: *runtime.Instance, sinkId: anyopaque) anyerror!anyopaque {
        
        return try AudioContextImpl.call_setSinkId(instance, sinkId);
    }

    pub fn call_createIIRFilter(instance: *runtime.Instance, feedforward: anyopaque, feedback: anyopaque) anyerror!IIRFilterNode {
        
        return try AudioContextImpl.call_createIIRFilter(instance, feedforward, feedback);
    }

    pub fn call_createBiquadFilter(instance: *runtime.Instance) anyerror!BiquadFilterNode {
        return try AudioContextImpl.call_createBiquadFilter(instance);
    }

    pub fn call_createOscillator(instance: *runtime.Instance) anyerror!OscillatorNode {
        return try AudioContextImpl.call_createOscillator(instance);
    }

    pub fn call_createScriptProcessor(instance: *runtime.Instance, bufferSize: u32, numberOfInputChannels: u32, numberOfOutputChannels: u32) anyerror!ScriptProcessorNode {
        
        return try AudioContextImpl.call_createScriptProcessor(instance, bufferSize, numberOfInputChannels, numberOfOutputChannels);
    }

    pub fn call_createChannelSplitter(instance: *runtime.Instance, numberOfOutputs: u32) anyerror!ChannelSplitterNode {
        
        return try AudioContextImpl.call_createChannelSplitter(instance, numberOfOutputs);
    }

    pub fn call_decodeAudioData(instance: *runtime.Instance, audioData: anyopaque, successCallback: anyopaque, errorCallback: anyopaque) anyerror!anyopaque {
        
        return try AudioContextImpl.call_decodeAudioData(instance, audioData, successCallback, errorCallback);
    }

};
