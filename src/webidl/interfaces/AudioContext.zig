//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioContextImpl = @import("impls").AudioContext;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const BaseAudioContext = @import("BaseAudioContext.zig").BaseAudioContext;
const PeriodicWaveConstraints = @import("dictionaries").PeriodicWaveConstraints;
const MediaStreamAudioDestinationNode = @import("MediaStreamAudioDestinationNode.zig").MediaStreamAudioDestinationNode;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OscillatorNode = @import("OscillatorNode.zig").OscillatorNode;
const AudioSinkInfo = @import("AudioSinkInfo.zig").AudioSinkInfo;
const ScriptProcessorNode = @import("ScriptProcessorNode.zig").ScriptProcessorNode;
const DelayNode = @import("DelayNode.zig").DelayNode;
const MediaStreamAudioSourceNode = @import("MediaStreamAudioSourceNode.zig").MediaStreamAudioSourceNode;
const DecodeErrorCallback = @import("callbacks").DecodeErrorCallback;
const AudioDestinationNode = @import("AudioDestinationNode.zig").AudioDestinationNode;
const MediaStreamTrack = @import("MediaStreamTrack.zig").MediaStreamTrack;
const ConvolverNode = @import("ConvolverNode.zig").ConvolverNode;
const MediaElementAudioSourceNode = @import("MediaElementAudioSourceNode.zig").MediaElementAudioSourceNode;
const AudioContextState = @import("enums").AudioContextState;
const DynamicsCompressorNode = @import("DynamicsCompressorNode.zig").DynamicsCompressorNode;
const MediaStream = @import("MediaStream.zig").MediaStream;
const PannerNode = @import("PannerNode.zig").PannerNode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioBufferSourceNode = @import("AudioBufferSourceNode.zig").AudioBufferSourceNode;
const WaveShaperNode = @import("WaveShaperNode.zig").WaveShaperNode;
const EventListener = @import("EventListener.zig").EventListener;
const IIRFilterNode = @import("IIRFilterNode.zig").IIRFilterNode;
const AudioBuffer = @import("AudioBuffer.zig").AudioBuffer;
const EventHandler = @import("typedefs").EventHandler;
const MediaStreamTrackAudioSourceNode = @import("MediaStreamTrackAudioSourceNode.zig").MediaStreamTrackAudioSourceNode;
const AudioListener = @import("AudioListener.zig").AudioListener;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DecodeSuccessCallback = @import("callbacks").DecodeSuccessCallback;
const AnalyserNode = @import("AnalyserNode.zig").AnalyserNode;
const StereoPannerNode = @import("StereoPannerNode.zig").StereoPannerNode;
const GainNode = @import("GainNode.zig").GainNode;
const ChannelSplitterNode = @import("ChannelSplitterNode.zig").ChannelSplitterNode;
const AudioContextOptions = @import("dictionaries").AudioContextOptions;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const ConstantSourceNode = @import("ConstantSourceNode.zig").ConstantSourceNode;
const ChannelMergerNode = @import("ChannelMergerNode.zig").ChannelMergerNode;
const HTMLMediaElement = @import("HTMLMediaElement.zig").HTMLMediaElement;
const PeriodicWave = @import("PeriodicWave.zig").PeriodicWave;
const AudioWorklet = @import("AudioWorklet.zig").AudioWorklet;
const BiquadFilterNode = @import("BiquadFilterNode.zig").BiquadFilterNode;
const AudioSinkOptions = @import("dictionaries").AudioSinkOptions;
const DOMString = @import("typedefs").DOMString;
const AudioTimestamp = @import("dictionaries").AudioTimestamp;

pub const AudioContext = struct {
    pub const Meta = struct {
        pub const name = "AudioContext";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = BaseAudioContext.State;
        pub const ParentInterface = BaseAudioContext;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "baseLatency", "get_baseLatency", null },
            .{ "outputLatency", "get_outputLatency", null },
            .{ "sinkId", "get_sinkId", null },
            .{ "onsinkchange", "get_onsinkchange", "set_onsinkchange" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getOutputTimestamp", "call_getOutputTimestamp", 0 },
            .{ "resume", "call_resume", 0 },
            .{ "suspend", "call_suspend", 0 },
            .{ "close", "call_close", 0 },
            .{ "setSinkId", "call_setSinkId", 1 },
            .{ "createMediaElementSource", "call_createMediaElementSource", 1 },
            .{ "createMediaStreamSource", "call_createMediaStreamSource", 1 },
            .{ "createMediaStreamTrackSource", "call_createMediaStreamTrackSource", 1 },
            .{ "createMediaStreamDestination", "call_createMediaStreamDestination", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getOutputTimestamp",
            "resume",
            "suspend",
            "close",
            "setSinkId",
            "createMediaElementSource",
            "createMediaStreamSource",
            "createMediaStreamTrackSource",
            "createMediaStreamDestination",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
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
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "baseLatency", "get_baseLatency", null },
            .{ "outputLatency", "get_outputLatency", null },
            .{ "sinkId", "get_sinkId", null },
            .{ "onsinkchange", "get_onsinkchange", "set_onsinkchange" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            baseLatency: f64 = undefined,
            outputLatency: f64 = undefined,
            sinkId: union(enum) {
                DOMString: runtime.DOMString,
                AudioSinkInfo: AudioSinkInfo,
            } = undefined,
            onsinkchange: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            _internal: ?*AudioContextImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_baseLatency = &get_baseLatency,
        .get_onerror = &get_onerror,
        .get_onsinkchange = &get_onsinkchange,
        .get_outputLatency = &get_outputLatency,
        .get_sinkId = &get_sinkId,

        .set_onerror = &set_onerror,
        .set_onsinkchange = &set_onsinkchange,

        .call_close = &call_close,
        .call_createMediaElementSource = &call_createMediaElementSource,
        .call_createMediaStreamDestination = &call_createMediaStreamDestination,
        .call_createMediaStreamSource = &call_createMediaStreamSource,
        .call_createMediaStreamTrackSource = &call_createMediaStreamTrackSource,
        .call_getOutputTimestamp = &call_getOutputTimestamp,
        .call_resume = &call_resume,
        .call_setSinkId = &call_setSinkId,
        .call_suspend = &call_suspend,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return AudioContextImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioContextImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, contextOptions: webidl.Opt(AudioContextOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioContextImpl.call_constructor(ctx, contextOptions);
    }

    pub fn get_baseLatency(instance: *runtime.Instance) anyerror!f64 {
        return try AudioContextImpl.get_baseLatency(instance);
    }

    pub fn get_outputLatency(instance: *runtime.Instance) anyerror!f64 {
        return try AudioContextImpl.get_outputLatency(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_sinkId(instance: *runtime.Instance) anyerror!runtime.JSValue {
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

    pub fn call_createMediaStreamTrackSource(instance: *runtime.Instance, mediaStreamTrack: *runtime.Instance) anyerror!*runtime.Instance {
        
        return try AudioContextImpl.call_createMediaStreamTrackSource(instance, mediaStreamTrack);
    }

    pub fn call_createMediaElementSource(instance: *runtime.Instance, mediaElement: *runtime.Instance) anyerror!*runtime.Instance {
        
        return try AudioContextImpl.call_createMediaElementSource(instance, mediaElement);
    }

    pub fn call_createMediaStreamDestination(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioContextImpl.call_createMediaStreamDestination(instance);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AudioContextImpl.call_resume(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setSinkId(instance: *runtime.Instance, sinkId: runtime.JSValue) anyerror!runtime.JSValue {
        
        return try AudioContextImpl.call_setSinkId(instance, sinkId);
    }

    pub fn call_suspend(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AudioContextImpl.call_suspend(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AudioContextImpl.call_close(instance);
    }

    pub fn call_getOutputTimestamp(instance: *runtime.Instance) anyerror!AudioTimestamp {
        return try AudioContextImpl.call_getOutputTimestamp(instance);
    }

    pub fn call_createMediaStreamSource(instance: *runtime.Instance, mediaStream: *runtime.Instance) anyerror!*runtime.Instance {
        
        return try AudioContextImpl.call_createMediaStreamSource(instance, mediaStream);
    }

};
