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
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const PeriodicWaveConstraints = @import("dictionaries").PeriodicWaveConstraints;
const MediaStreamAudioDestinationNode = @import("interfaces").MediaStreamAudioDestinationNode;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OscillatorNode = @import("interfaces").OscillatorNode;
const AudioSinkInfo = @import("interfaces").AudioSinkInfo;
const ScriptProcessorNode = @import("interfaces").ScriptProcessorNode;
const DelayNode = @import("interfaces").DelayNode;
const MediaStreamAudioSourceNode = @import("interfaces").MediaStreamAudioSourceNode;
const DecodeErrorCallback = @import("callbacks").DecodeErrorCallback;
const AudioDestinationNode = @import("interfaces").AudioDestinationNode;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const ConvolverNode = @import("interfaces").ConvolverNode;
const MediaElementAudioSourceNode = @import("interfaces").MediaElementAudioSourceNode;
const AudioContextState = @import("enums").AudioContextState;
const DynamicsCompressorNode = @import("interfaces").DynamicsCompressorNode;
const AudioPlaybackStats = @import("interfaces").AudioPlaybackStats;
const MediaStream = @import("interfaces").MediaStream;
const PannerNode = @import("interfaces").PannerNode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioBufferSourceNode = @import("interfaces").AudioBufferSourceNode;
const WaveShaperNode = @import("interfaces").WaveShaperNode;
const EventListener = @import("interfaces").EventListener;
const IIRFilterNode = @import("interfaces").IIRFilterNode;
const AudioBuffer = @import("interfaces").AudioBuffer;
const EventHandler = @import("typedefs").EventHandler;
const MediaStreamTrackAudioSourceNode = @import("interfaces").MediaStreamTrackAudioSourceNode;
const AudioListener = @import("interfaces").AudioListener;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DecodeSuccessCallback = @import("callbacks").DecodeSuccessCallback;
const AnalyserNode = @import("interfaces").AnalyserNode;
const StereoPannerNode = @import("interfaces").StereoPannerNode;
const GainNode = @import("interfaces").GainNode;
const ChannelSplitterNode = @import("interfaces").ChannelSplitterNode;
const AudioContextOptions = @import("dictionaries").AudioContextOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const ConstantSourceNode = @import("interfaces").ConstantSourceNode;
const ChannelMergerNode = @import("interfaces").ChannelMergerNode;
const HTMLMediaElement = @import("interfaces").HTMLMediaElement;
const PeriodicWave = @import("interfaces").PeriodicWave;
const AudioWorklet = @import("interfaces").AudioWorklet;
const BiquadFilterNode = @import("interfaces").BiquadFilterNode;
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
            .{ "playbackStats", "get_playbackStats", null },
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
            .{ "playbackStats", "get_playbackStats", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "sinkId",
            "setSinkId",
        };
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
            playbackStats: *runtime.Instance = undefined,
            cached_playbackStats: ?*runtime.Instance = null,
            _internal: ?*AudioContextImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_baseLatency = &get_baseLatency,
        .get_onerror = &get_onerror,
        .get_onsinkchange = &get_onsinkchange,
        .get_outputLatency = &get_outputLatency,
        .get_playbackStats = &get_playbackStats,
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
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioContext has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(AudioContextImpl, "init") and @hasDecl(AudioContextImpl, "initOwn")) @compileError("AudioContextImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioContextImpl, "init")) return AudioContextImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AudioContextImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AudioContextImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioContextImpl, "init")) return false;
        if (comptime @hasDecl(AudioContextImpl, "construction_args")) {
            inline for (AudioContextImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(AudioContextImpl, "deinit") and @hasDecl(AudioContextImpl, "deinitOwn")) @compileError("AudioContextImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(AudioContextImpl, "deinit")) return AudioContextImpl.deinit(instance);
        if (comptime @hasDecl(AudioContextImpl, "deinitOwn")) AudioContextImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioContext")) {
            if (comptime @hasDecl(impls.AudioContext, "installHooks")) impls.AudioContext.installHooks();
        }
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

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onsinkchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AudioContextImpl, "get_onsinkchange")) return try AudioContextImpl.get_onsinkchange(instance);
        return event_handlers.value(EventHandler, instance, "onsinkchange");
    }

    pub fn set_onsinkchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AudioContextImpl, "set_onsinkchange")) return try AudioContextImpl.set_onsinkchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsinkchange", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AudioContextImpl, "get_onerror")) return try AudioContextImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AudioContextImpl, "set_onerror")) return try AudioContextImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_playbackStats(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_playbackStats) |cached| {
            return cached;
        }
        const value = try AudioContextImpl.get_playbackStats(instance);
        state.own.cached_playbackStats = value;
        @import("dom").same_object_cache.made(instance, value, "playbackStats");
        return value;
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

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_createMediaStreamTrackSource", 0, "MediaStreamTrack" },
        .{ "call_createMediaElementSource", 0, "HTMLMediaElement" },
        .{ "call_createMediaStreamSource", 0, "MediaStream" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_resume",
        "call_setSinkId",
        "call_suspend",
        "call_close",
    };
};
