//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OfflineAudioContextImpl = @import("impls").OfflineAudioContext;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const BaseAudioContext = @import("BaseAudioContext.zig").BaseAudioContext;
const DynamicsCompressorNode = @import("DynamicsCompressorNode.zig").DynamicsCompressorNode;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OscillatorNode = @import("OscillatorNode.zig").OscillatorNode;
const ScriptProcessorNode = @import("ScriptProcessorNode.zig").ScriptProcessorNode;
const DelayNode = @import("DelayNode.zig").DelayNode;
const DecodeErrorCallback = @import("callbacks").DecodeErrorCallback;
const AudioDestinationNode = @import("AudioDestinationNode.zig").AudioDestinationNode;
const ConvolverNode = @import("ConvolverNode.zig").ConvolverNode;
const AudioContextState = @import("enums").AudioContextState;
const PannerNode = @import("PannerNode.zig").PannerNode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioBufferSourceNode = @import("AudioBufferSourceNode.zig").AudioBufferSourceNode;
const WaveShaperNode = @import("WaveShaperNode.zig").WaveShaperNode;
const EventListener = @import("EventListener.zig").EventListener;
const IIRFilterNode = @import("IIRFilterNode.zig").IIRFilterNode;
const AudioBuffer = @import("AudioBuffer.zig").AudioBuffer;
const EventHandler = @import("typedefs").EventHandler;
const AudioListener = @import("AudioListener.zig").AudioListener;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DecodeSuccessCallback = @import("callbacks").DecodeSuccessCallback;
const AnalyserNode = @import("AnalyserNode.zig").AnalyserNode;
const StereoPannerNode = @import("StereoPannerNode.zig").StereoPannerNode;
const GainNode = @import("GainNode.zig").GainNode;
const ChannelSplitterNode = @import("ChannelSplitterNode.zig").ChannelSplitterNode;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const ConstantSourceNode = @import("ConstantSourceNode.zig").ConstantSourceNode;
const ChannelMergerNode = @import("ChannelMergerNode.zig").ChannelMergerNode;
const PeriodicWave = @import("PeriodicWave.zig").PeriodicWave;
const AudioWorklet = @import("AudioWorklet.zig").AudioWorklet;
const OfflineAudioContextOptions = @import("dictionaries").OfflineAudioContextOptions;
const BiquadFilterNode = @import("BiquadFilterNode.zig").BiquadFilterNode;
const PeriodicWaveConstraints = @import("dictionaries").PeriodicWaveConstraints;
const DOMString = @import("typedefs").DOMString;

pub const OfflineAudioContext = struct {
    pub const Meta = struct {
        pub const name = "OfflineAudioContext";
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
            .{ "length", "get_length", null },
            .{ "oncomplete", "get_oncomplete", "set_oncomplete" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            oncomplete: typedefs.EventHandler = undefined,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OfflineAudioContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return OfflineAudioContextImpl.init(allocator, StateType, vtable_ptr, ctx);
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
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try OfflineAudioContextImpl.call_constructor(ctx, args);
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

    pub fn call_resume(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try OfflineAudioContextImpl.call_resume(instance);
    }

    pub fn call_startRendering(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try OfflineAudioContextImpl.call_startRendering(instance);
    }

    pub fn call_suspend(instance: *runtime.Instance, suspendTime: f64) anyerror!runtime.JSValue {
        
        return try OfflineAudioContextImpl.call_suspend(instance, suspendTime);
    }

};
