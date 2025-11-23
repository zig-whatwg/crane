//! Generated from: webaudio.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OfflineAudioContextImpl = @import("impls").OfflineAudioContext;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const DynamicsCompressorNode = @import("interfaces").DynamicsCompressorNode;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OscillatorNode = @import("interfaces").OscillatorNode;
const ScriptProcessorNode = @import("interfaces").ScriptProcessorNode;
const DelayNode = @import("interfaces").DelayNode;
const DecodeErrorCallback = @import("callbacks").DecodeErrorCallback;
const AudioDestinationNode = @import("interfaces").AudioDestinationNode;
const ConvolverNode = @import("interfaces").ConvolverNode;
const AudioContextState = @import("enums").AudioContextState;
const PannerNode = @import("interfaces").PannerNode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioBufferSourceNode = @import("interfaces").AudioBufferSourceNode;
const WaveShaperNode = @import("interfaces").WaveShaperNode;
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
const AudioWorklet = @import("interfaces").AudioWorklet;
const OfflineAudioContextOptions = @import("dictionaries").OfflineAudioContextOptions;
const BiquadFilterNode = @import("interfaces").BiquadFilterNode;
const PeriodicWaveConstraints = @import("dictionaries").PeriodicWaveConstraints;
const DOMString = @import("typedefs").DOMString;

pub const OfflineAudioContext = struct {
    pub const Meta = struct {
        pub const name = "OfflineAudioContext";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *BaseAudioContext;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "oncomplete", "get_oncomplete", "set_oncomplete" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "startRendering", "call_startRendering", 0 },
            .{ "resume", "call_resume", 0 },
            .{ "suspend", "call_suspend", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "startRendering",
            "resume",
            "suspend",
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
            .{ "length", "get_length", null },
            .{ "oncomplete", "get_oncomplete", "set_oncomplete" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            oncomplete: EventHandler = undefined,
            _internal: ?*OfflineAudioContextImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_oncomplete = &get_oncomplete,

        .set_oncomplete = &set_oncomplete,

        .call_resume = &call_resume,
        .call_startRendering = &call_startRendering,
        .call_suspend = &call_suspend,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OfflineAudioContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OfflineAudioContextImpl.deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(contextOptions)
        OfflineAudioContextOptions: OfflineAudioContextOptions,
        /// constructor(numberOfChannels, length, sampleRate)
        unsigned_long_unsigned_long_float: struct {
            numberOfChannels: u32,
            length: u32,
            sampleRate: f32,
        },
    };

    /// WebIDL constructor (overloaded)
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try OfflineAudioContextImpl.call_constructor(allocator, ctx, args);
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

    pub fn call_suspend(instance: *runtime.Instance, suspendTime: f64) anyerror!*const anyopaque {
        
        return try OfflineAudioContextImpl.call_suspend(instance, suspendTime);
    }

    pub fn call_startRendering(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try OfflineAudioContextImpl.call_startRendering(instance);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try OfflineAudioContextImpl.call_resume(instance);
    }

};
