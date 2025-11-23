//! Generated from: webaudio.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BaseAudioContextImpl = @import("impls").BaseAudioContext;
const EventTarget = @import("interfaces").EventTarget;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OscillatorNode = @import("interfaces").OscillatorNode;
const ScriptProcessorNode = @import("interfaces").ScriptProcessorNode;
const DelayNode = @import("interfaces").DelayNode;
const DecodeErrorCallback = @import("callbacks").DecodeErrorCallback;
const AudioDestinationNode = @import("interfaces").AudioDestinationNode;
const ConvolverNode = @import("interfaces").ConvolverNode;
const AudioContextState = @import("enums").AudioContextState;
const PannerNode = @import("interfaces").PannerNode;
const AudioBufferSourceNode = @import("interfaces").AudioBufferSourceNode;
const WaveShaperNode = @import("interfaces").WaveShaperNode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const IIRFilterNode = @import("interfaces").IIRFilterNode;
const AudioBuffer = @import("interfaces").AudioBuffer;
const EventHandler = @import("typedefs").EventHandler;
const AudioListener = @import("interfaces").AudioListener;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DecodeSuccessCallback = @import("callbacks").DecodeSuccessCallback;
const AnalyserNode = @import("interfaces").AnalyserNode;
const StereoPannerNode = @import("interfaces").StereoPannerNode;
const GainNode = @import("interfaces").GainNode;
const ChannelSplitterNode = @import("interfaces").ChannelSplitterNode;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const ConstantSourceNode = @import("interfaces").ConstantSourceNode;
const ChannelMergerNode = @import("interfaces").ChannelMergerNode;
const PeriodicWave = @import("interfaces").PeriodicWave;
const PeriodicWaveConstraints = @import("dictionaries").PeriodicWaveConstraints;
const AudioWorklet = @import("interfaces").AudioWorklet;
const BiquadFilterNode = @import("interfaces").BiquadFilterNode;
const DOMString = @import("typedefs").DOMString;
const DynamicsCompressorNode = @import("interfaces").DynamicsCompressorNode;

pub const BaseAudioContext = struct {
    pub const Meta = struct {
        pub const name = "BaseAudioContext";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "destination", "get_destination", null },
            .{ "sampleRate", "get_sampleRate", null },
            .{ "currentTime", "get_currentTime", null },
            .{ "listener", "get_listener", null },
            .{ "state", "get_state", null },
            .{ "renderQuantumSize", "get_renderQuantumSize", null },
            .{ "audioWorklet", "get_audioWorklet", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "createAnalyser", "call_createAnalyser", 0 },
            .{ "createBiquadFilter", "call_createBiquadFilter", 0 },
            .{ "createBuffer", "call_createBuffer", 3 },
            .{ "createBufferSource", "call_createBufferSource", 0 },
            .{ "createChannelMerger", "call_createChannelMerger", 0 },
            .{ "createChannelSplitter", "call_createChannelSplitter", 0 },
            .{ "createConstantSource", "call_createConstantSource", 0 },
            .{ "createConvolver", "call_createConvolver", 0 },
            .{ "createDelay", "call_createDelay", 0 },
            .{ "createDynamicsCompressor", "call_createDynamicsCompressor", 0 },
            .{ "createGain", "call_createGain", 0 },
            .{ "createIIRFilter", "call_createIIRFilter", 2 },
            .{ "createOscillator", "call_createOscillator", 0 },
            .{ "createPanner", "call_createPanner", 0 },
            .{ "createPeriodicWave", "call_createPeriodicWave", 2 },
            .{ "createScriptProcessor", "call_createScriptProcessor", 0 },
            .{ "createStereoPanner", "call_createStereoPanner", 0 },
            .{ "createWaveShaper", "call_createWaveShaper", 0 },
            .{ "decodeAudioData", "call_decodeAudioData", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createAnalyser",
            "createBiquadFilter",
            "createBuffer",
            "createBufferSource",
            "createChannelMerger",
            "createChannelSplitter",
            "createConstantSource",
            "createConvolver",
            "createDelay",
            "createDynamicsCompressor",
            "createGain",
            "createIIRFilter",
            "createOscillator",
            "createPanner",
            "createPeriodicWave",
            "createScriptProcessor",
            "createStereoPanner",
            "createWaveShaper",
            "decodeAudioData",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "destination", "get_destination", null },
            .{ "sampleRate", "get_sampleRate", null },
            .{ "currentTime", "get_currentTime", null },
            .{ "listener", "get_listener", null },
            .{ "state", "get_state", null },
            .{ "renderQuantumSize", "get_renderQuantumSize", null },
            .{ "audioWorklet", "get_audioWorklet", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            destination: *runtime.Instance = undefined,
            sampleRate: f32 = undefined,
            currentTime: f64 = undefined,
            listener: *runtime.Instance = undefined,
            state: AudioContextState = undefined,
            renderQuantumSize: u32 = undefined,
            audioWorklet: *runtime.Instance = undefined,
            onstatechange: EventHandler = undefined,
            cached_audioWorklet: ?*runtime.Instance = null,
            _internal: ?*BaseAudioContextImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_audioWorklet = &get_audioWorklet,
        .get_currentTime = &get_currentTime,
        .get_destination = &get_destination,
        .get_listener = &get_listener,
        .get_onstatechange = &get_onstatechange,
        .get_renderQuantumSize = &get_renderQuantumSize,
        .get_sampleRate = &get_sampleRate,
        .get_state = &get_state,

        .set_onstatechange = &set_onstatechange,

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BaseAudioContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BaseAudioContextImpl.deinit(instance);
    }

    pub fn get_destination(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.get_destination(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try BaseAudioContextImpl.get_sampleRate(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try BaseAudioContextImpl.get_currentTime(instance);
    }

    pub fn get_listener(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.get_listener(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!AudioContextState {
        return try BaseAudioContextImpl.get_state(instance);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) anyerror!u32 {
        return try BaseAudioContextImpl.get_renderQuantumSize(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_audioWorklet(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_audioWorklet) |cached| {
            return cached;
        }
        const value = try BaseAudioContextImpl.get_audioWorklet(instance);
        state.own.cached_audioWorklet = value;
        return value;
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try BaseAudioContextImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BaseAudioContextImpl.set_onstatechange(instance, value);
    }

    pub fn call_createPanner(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createPanner(instance);
    }

    pub fn call_createChannelMerger(instance: *runtime.Instance, numberOfInputs: u32) anyerror!*runtime.Instance {
        
        return try BaseAudioContextImpl.call_createChannelMerger(instance, numberOfInputs);
    }

    pub fn call_createDynamicsCompressor(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createDynamicsCompressor(instance);
    }

    pub fn call_createPeriodicWave(instance: *runtime.Instance, real: *const anyopaque, imag: *const anyopaque, constraints: PeriodicWaveConstraints) anyerror!*runtime.Instance {
        
        return try BaseAudioContextImpl.call_createPeriodicWave(instance, real, imag, constraints);
    }

    pub fn call_createConvolver(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createConvolver(instance);
    }

    pub fn call_createBufferSource(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createBufferSource(instance);
    }

    pub fn call_createStereoPanner(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createStereoPanner(instance);
    }

    pub fn call_createGain(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createGain(instance);
    }

    pub fn call_createWaveShaper(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createWaveShaper(instance);
    }

    pub fn call_createConstantSource(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createConstantSource(instance);
    }

    pub fn call_createAnalyser(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createAnalyser(instance);
    }

    pub fn call_createIIRFilter(instance: *runtime.Instance, feedforward: *const anyopaque, feedback: *const anyopaque) anyerror!*runtime.Instance {
        
        return try BaseAudioContextImpl.call_createIIRFilter(instance, feedforward, feedback);
    }

    pub fn call_createBiquadFilter(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createBiquadFilter(instance);
    }

    pub fn call_createOscillator(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BaseAudioContextImpl.call_createOscillator(instance);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, numberOfChannels: u32, length: u32, sampleRate: f32) anyerror!*runtime.Instance {
        
        return try BaseAudioContextImpl.call_createBuffer(instance, numberOfChannels, length, sampleRate);
    }

    pub fn call_createScriptProcessor(instance: *runtime.Instance, bufferSize: u32, numberOfInputChannels: u32, numberOfOutputChannels: u32) anyerror!*runtime.Instance {
        
        return try BaseAudioContextImpl.call_createScriptProcessor(instance, bufferSize, numberOfInputChannels, numberOfOutputChannels);
    }

    pub fn call_createDelay(instance: *runtime.Instance, maxDelayTime: f64) anyerror!*runtime.Instance {
        
        return try BaseAudioContextImpl.call_createDelay(instance, maxDelayTime);
    }

    pub fn call_createChannelSplitter(instance: *runtime.Instance, numberOfOutputs: u32) anyerror!*runtime.Instance {
        
        return try BaseAudioContextImpl.call_createChannelSplitter(instance, numberOfOutputs);
    }

    pub fn call_decodeAudioData(instance: *runtime.Instance, audioData: *const anyopaque, successCallback: DecodeSuccessCallback, errorCallback: DecodeErrorCallback) anyerror!*const anyopaque {
        
        return try BaseAudioContextImpl.call_decodeAudioData(instance, audioData, successCallback, errorCallback);
    }

};
