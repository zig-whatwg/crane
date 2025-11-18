//! Generated from: webaudio.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OfflineAudioContextImpl = @import("impls").OfflineAudioContext;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const Promise<AudioBuffer> = @import("interfaces").Promise<AudioBuffer>;
const OfflineAudioContextOptions = @import("dictionaries").OfflineAudioContextOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const EventHandler = @import("typedefs").EventHandler;

pub const OfflineAudioContext = struct {
    pub const Meta = struct {
        pub const name = "OfflineAudioContext";
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
            length: u32 = undefined,
            oncomplete: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(OfflineAudioContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_audioWorklet = &get_audioWorklet,
        .get_currentTime = &get_currentTime,
        .get_destination = &get_destination,
        .get_length = &get_length,
        .get_listener = &get_listener,
        .get_oncomplete = &get_oncomplete,
        .get_onstatechange = &get_onstatechange,
        .get_renderQuantumSize = &get_renderQuantumSize,
        .get_sampleRate = &get_sampleRate,
        .get_state = &get_state,

        .set_oncomplete = &set_oncomplete,
        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
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
        .call_createOscillator = &call_createOscillator,
        .call_createPanner = &call_createPanner,
        .call_createPeriodicWave = &call_createPeriodicWave,
        .call_createScriptProcessor = &call_createScriptProcessor,
        .call_createStereoPanner = &call_createStereoPanner,
        .call_createWaveShaper = &call_createWaveShaper,
        .call_decodeAudioData = &call_decodeAudioData,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_resume = &call_resume,
        .call_startRendering = &call_startRendering,
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
        OfflineAudioContextImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OfflineAudioContextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, contextOptions: OfflineAudioContextOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try OfflineAudioContextImpl.constructor(instance, contextOptions);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, numberOfChannels: u32, length: u32, sampleRate: f32) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try OfflineAudioContextImpl.constructor(instance, numberOfChannels, length, sampleRate);
        
        return instance;
    }

    pub fn get_destination(instance: *runtime.Instance) anyerror!AudioDestinationNode {
        return try OfflineAudioContextImpl.get_destination(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try OfflineAudioContextImpl.get_sampleRate(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try OfflineAudioContextImpl.get_currentTime(instance);
    }

    pub fn get_listener(instance: *runtime.Instance) anyerror!AudioListener {
        return try OfflineAudioContextImpl.get_listener(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!AudioContextState {
        return try OfflineAudioContextImpl.get_state(instance);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) anyerror!u32 {
        return try OfflineAudioContextImpl.get_renderQuantumSize(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_audioWorklet(instance: *runtime.Instance) anyerror!AudioWorklet {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_audioWorklet) |cached| {
            return cached;
        }
        const value = try OfflineAudioContextImpl.get_audioWorklet(instance);
        state.cached_audioWorklet = value;
        return value;
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try OfflineAudioContextImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try OfflineAudioContextImpl.set_onstatechange(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try OfflineAudioContextImpl.get_length(instance);
    }

    pub fn get_oncomplete(instance: *runtime.Instance) anyerror!EventHandler {
        return try OfflineAudioContextImpl.get_oncomplete(instance);
    }

    pub fn set_oncomplete(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try OfflineAudioContextImpl.set_oncomplete(instance, value);
    }

    pub fn call_createChannelMerger(instance: *runtime.Instance, numberOfInputs: u32) anyerror!ChannelMergerNode {
        
        return try OfflineAudioContextImpl.call_createChannelMerger(instance, numberOfInputs);
    }

    pub fn call_createDynamicsCompressor(instance: *runtime.Instance) anyerror!DynamicsCompressorNode {
        return try OfflineAudioContextImpl.call_createDynamicsCompressor(instance);
    }

    pub fn call_startRendering(instance: *runtime.Instance) anyerror!anyopaque {
        return try OfflineAudioContextImpl.call_startRendering(instance);
    }

    pub fn call_createWaveShaper(instance: *runtime.Instance) anyerror!WaveShaperNode {
        return try OfflineAudioContextImpl.call_createWaveShaper(instance);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try OfflineAudioContextImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_createConstantSource(instance: *runtime.Instance) anyerror!ConstantSourceNode {
        return try OfflineAudioContextImpl.call_createConstantSource(instance);
    }

    pub fn call_createAnalyser(instance: *runtime.Instance) anyerror!AnalyserNode {
        return try OfflineAudioContextImpl.call_createAnalyser(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try OfflineAudioContextImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, numberOfChannels: u32, length: u32, sampleRate: f32) anyerror!AudioBuffer {
        
        return try OfflineAudioContextImpl.call_createBuffer(instance, numberOfChannels, length, sampleRate);
    }

    pub fn call_createDelay(instance: *runtime.Instance, maxDelayTime: f64) anyerror!DelayNode {
        
        return try OfflineAudioContextImpl.call_createDelay(instance, maxDelayTime);
    }

    pub fn call_createPanner(instance: *runtime.Instance) anyerror!PannerNode {
        return try OfflineAudioContextImpl.call_createPanner(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try OfflineAudioContextImpl.call_when(instance, type_, options);
    }

    pub fn call_suspend(instance: *runtime.Instance, suspendTime: f64) anyerror!anyopaque {
        
        return try OfflineAudioContextImpl.call_suspend(instance, suspendTime);
    }

    pub fn call_createPeriodicWave(instance: *runtime.Instance, real: anyopaque, imag: anyopaque, constraints: PeriodicWaveConstraints) anyerror!PeriodicWave {
        
        return try OfflineAudioContextImpl.call_createPeriodicWave(instance, real, imag, constraints);
    }

    pub fn call_createConvolver(instance: *runtime.Instance) anyerror!ConvolverNode {
        return try OfflineAudioContextImpl.call_createConvolver(instance);
    }

    pub fn call_createBufferSource(instance: *runtime.Instance) anyerror!AudioBufferSourceNode {
        return try OfflineAudioContextImpl.call_createBufferSource(instance);
    }

    pub fn call_createStereoPanner(instance: *runtime.Instance) anyerror!StereoPannerNode {
        return try OfflineAudioContextImpl.call_createStereoPanner(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try OfflineAudioContextImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_createGain(instance: *runtime.Instance) anyerror!GainNode {
        return try OfflineAudioContextImpl.call_createGain(instance);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!anyopaque {
        return try OfflineAudioContextImpl.call_resume(instance);
    }

    pub fn call_createIIRFilter(instance: *runtime.Instance, feedforward: anyopaque, feedback: anyopaque) anyerror!IIRFilterNode {
        
        return try OfflineAudioContextImpl.call_createIIRFilter(instance, feedforward, feedback);
    }

    pub fn call_createBiquadFilter(instance: *runtime.Instance) anyerror!BiquadFilterNode {
        return try OfflineAudioContextImpl.call_createBiquadFilter(instance);
    }

    pub fn call_createOscillator(instance: *runtime.Instance) anyerror!OscillatorNode {
        return try OfflineAudioContextImpl.call_createOscillator(instance);
    }

    pub fn call_createScriptProcessor(instance: *runtime.Instance, bufferSize: u32, numberOfInputChannels: u32, numberOfOutputChannels: u32) anyerror!ScriptProcessorNode {
        
        return try OfflineAudioContextImpl.call_createScriptProcessor(instance, bufferSize, numberOfInputChannels, numberOfOutputChannels);
    }

    pub fn call_createChannelSplitter(instance: *runtime.Instance, numberOfOutputs: u32) anyerror!ChannelSplitterNode {
        
        return try OfflineAudioContextImpl.call_createChannelSplitter(instance, numberOfOutputs);
    }

    pub fn call_decodeAudioData(instance: *runtime.Instance, audioData: anyopaque, successCallback: anyopaque, errorCallback: anyopaque) anyerror!anyopaque {
        
        return try OfflineAudioContextImpl.call_decodeAudioData(instance, audioData, successCallback, errorCallback);
    }

};
