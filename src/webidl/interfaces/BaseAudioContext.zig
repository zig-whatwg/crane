//! Generated from: webaudio.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BaseAudioContextImpl = @import("impls").BaseAudioContext;
const EventTarget = @import("interfaces").EventTarget;
const OscillatorNode = @import("interfaces").OscillatorNode;
const ScriptProcessorNode = @import("interfaces").ScriptProcessorNode;
const DelayNode = @import("interfaces").DelayNode;
const DecodeErrorCallback = @import("callbacks").DecodeErrorCallback;
const AudioDestinationNode = @import("interfaces").AudioDestinationNode;
const ConvolverNode = @import("interfaces").ConvolverNode;
const AudioContextState = @import("enums").AudioContextState;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const PannerNode = @import("interfaces").PannerNode;
const AudioBufferSourceNode = @import("interfaces").AudioBufferSourceNode;
const WaveShaperNode = @import("interfaces").WaveShaperNode;
const IIRFilterNode = @import("interfaces").IIRFilterNode;
const AudioBuffer = @import("interfaces").AudioBuffer;
const Promise<AudioBuffer> = @import("interfaces").Promise<AudioBuffer>;
const EventHandler = @import("typedefs").EventHandler;
const AudioListener = @import("interfaces").AudioListener;
const DecodeSuccessCallback = @import("callbacks").DecodeSuccessCallback;
const AnalyserNode = @import("interfaces").AnalyserNode;
const StereoPannerNode = @import("interfaces").StereoPannerNode;
const GainNode = @import("interfaces").GainNode;
const ChannelSplitterNode = @import("interfaces").ChannelSplitterNode;
const ConstantSourceNode = @import("interfaces").ConstantSourceNode;
const ChannelMergerNode = @import("interfaces").ChannelMergerNode;
const PeriodicWave = @import("interfaces").PeriodicWave;
const PeriodicWaveConstraints = @import("dictionaries").PeriodicWaveConstraints;
const AudioWorklet = @import("interfaces").AudioWorklet;
const BiquadFilterNode = @import("interfaces").BiquadFilterNode;
const DynamicsCompressorNode = @import("interfaces").DynamicsCompressorNode;

pub const BaseAudioContext = struct {
    pub const Meta = struct {
        pub const name = "BaseAudioContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            destination: AudioDestinationNode = undefined,
            sampleRate: f32 = undefined,
            currentTime: f64 = undefined,
            listener: AudioListener = undefined,
            state: AudioContextState = undefined,
            renderQuantumSize: u32 = undefined,
            audioWorklet: AudioWorklet = undefined,
            onstatechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BaseAudioContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_audioWorklet = &get_audioWorklet,
        .get_currentTime = &get_currentTime,
        .get_destination = &get_destination,
        .get_listener = &get_listener,
        .get_onstatechange = &get_onstatechange,
        .get_renderQuantumSize = &get_renderQuantumSize,
        .get_sampleRate = &get_sampleRate,
        .get_state = &get_state,

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
        BaseAudioContextImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BaseAudioContextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_destination(instance: *runtime.Instance) anyerror!AudioDestinationNode {
        return try BaseAudioContextImpl.get_destination(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try BaseAudioContextImpl.get_sampleRate(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try BaseAudioContextImpl.get_currentTime(instance);
    }

    pub fn get_listener(instance: *runtime.Instance) anyerror!AudioListener {
        return try BaseAudioContextImpl.get_listener(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!AudioContextState {
        return try BaseAudioContextImpl.get_state(instance);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) anyerror!u32 {
        return try BaseAudioContextImpl.get_renderQuantumSize(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_audioWorklet(instance: *runtime.Instance) anyerror!AudioWorklet {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_audioWorklet) |cached| {
            return cached;
        }
        const value = try BaseAudioContextImpl.get_audioWorklet(instance);
        state.cached_audioWorklet = value;
        return value;
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try BaseAudioContextImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BaseAudioContextImpl.set_onstatechange(instance, value);
    }

    pub fn call_createPanner(instance: *runtime.Instance) anyerror!PannerNode {
        return try BaseAudioContextImpl.call_createPanner(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try BaseAudioContextImpl.call_when(instance, type_, options);
    }

    pub fn call_createChannelMerger(instance: *runtime.Instance, numberOfInputs: u32) anyerror!ChannelMergerNode {
        
        return try BaseAudioContextImpl.call_createChannelMerger(instance, numberOfInputs);
    }

    pub fn call_createDynamicsCompressor(instance: *runtime.Instance) anyerror!DynamicsCompressorNode {
        return try BaseAudioContextImpl.call_createDynamicsCompressor(instance);
    }

    pub fn call_createPeriodicWave(instance: *runtime.Instance, real: anyopaque, imag: anyopaque, constraints: PeriodicWaveConstraints) anyerror!PeriodicWave {
        
        return try BaseAudioContextImpl.call_createPeriodicWave(instance, real, imag, constraints);
    }

    pub fn call_createConvolver(instance: *runtime.Instance) anyerror!ConvolverNode {
        return try BaseAudioContextImpl.call_createConvolver(instance);
    }

    pub fn call_createBufferSource(instance: *runtime.Instance) anyerror!AudioBufferSourceNode {
        return try BaseAudioContextImpl.call_createBufferSource(instance);
    }

    pub fn call_createStereoPanner(instance: *runtime.Instance) anyerror!StereoPannerNode {
        return try BaseAudioContextImpl.call_createStereoPanner(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BaseAudioContextImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BaseAudioContextImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_createConstantSource(instance: *runtime.Instance) anyerror!ConstantSourceNode {
        return try BaseAudioContextImpl.call_createConstantSource(instance);
    }

    pub fn call_createGain(instance: *runtime.Instance) anyerror!GainNode {
        return try BaseAudioContextImpl.call_createGain(instance);
    }

    pub fn call_createAnalyser(instance: *runtime.Instance) anyerror!AnalyserNode {
        return try BaseAudioContextImpl.call_createAnalyser(instance);
    }

    pub fn call_createIIRFilter(instance: *runtime.Instance, feedforward: anyopaque, feedback: anyopaque) anyerror!IIRFilterNode {
        
        return try BaseAudioContextImpl.call_createIIRFilter(instance, feedforward, feedback);
    }

    pub fn call_createWaveShaper(instance: *runtime.Instance) anyerror!WaveShaperNode {
        return try BaseAudioContextImpl.call_createWaveShaper(instance);
    }

    pub fn call_createBiquadFilter(instance: *runtime.Instance) anyerror!BiquadFilterNode {
        return try BaseAudioContextImpl.call_createBiquadFilter(instance);
    }

    pub fn call_createOscillator(instance: *runtime.Instance) anyerror!OscillatorNode {
        return try BaseAudioContextImpl.call_createOscillator(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try BaseAudioContextImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, numberOfChannels: u32, length: u32, sampleRate: f32) anyerror!AudioBuffer {
        
        return try BaseAudioContextImpl.call_createBuffer(instance, numberOfChannels, length, sampleRate);
    }

    pub fn call_createScriptProcessor(instance: *runtime.Instance, bufferSize: u32, numberOfInputChannels: u32, numberOfOutputChannels: u32) anyerror!ScriptProcessorNode {
        
        return try BaseAudioContextImpl.call_createScriptProcessor(instance, bufferSize, numberOfInputChannels, numberOfOutputChannels);
    }

    pub fn call_createDelay(instance: *runtime.Instance, maxDelayTime: f64) anyerror!DelayNode {
        
        return try BaseAudioContextImpl.call_createDelay(instance, maxDelayTime);
    }

    pub fn call_createChannelSplitter(instance: *runtime.Instance, numberOfOutputs: u32) anyerror!ChannelSplitterNode {
        
        return try BaseAudioContextImpl.call_createChannelSplitter(instance, numberOfOutputs);
    }

    pub fn call_decodeAudioData(instance: *runtime.Instance, audioData: anyopaque, successCallback: anyopaque, errorCallback: anyopaque) anyerror!anyopaque {
        
        return try BaseAudioContextImpl.call_decodeAudioData(instance, audioData, successCallback, errorCallback);
    }

};
