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
            .{ "close", "call_close", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "startRendering",
            "resume",
            "suspend",
            "close",
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
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: ?u32 = null,
            oncomplete: typedefs.EventHandler = undefined,
            _internal: ?*OfflineAudioContextImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_oncomplete = &get_oncomplete,

        .set_oncomplete = &set_oncomplete,

        .call_close = &call_close,
        .call_resume = &call_resume,
        .call_startRendering = &call_startRendering,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("OfflineAudioContext has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(OfflineAudioContextImpl, "init") and @hasDecl(OfflineAudioContextImpl, "initOwn")) @compileError("OfflineAudioContextImpl defines both init and initOwn");
        if (comptime @hasDecl(OfflineAudioContextImpl, "init")) return OfflineAudioContextImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(OfflineAudioContextImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try OfflineAudioContextImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(OfflineAudioContextImpl, "init")) return false;
        if (comptime @hasDecl(OfflineAudioContextImpl, "construction_args")) {
            inline for (OfflineAudioContextImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(OfflineAudioContextImpl, "deinit") and @hasDecl(OfflineAudioContextImpl, "deinitOwn")) @compileError("OfflineAudioContextImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(OfflineAudioContextImpl, "deinit")) return OfflineAudioContextImpl.deinit(instance);
        if (comptime @hasDecl(OfflineAudioContextImpl, "deinitOwn")) OfflineAudioContextImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "OfflineAudioContext")) {
            if (comptime @hasDecl(impls.OfflineAudioContext, "installHooks")) impls.OfflineAudioContext.installHooks();
        }
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

    /// WebIDL overload set of the constructor: one entry per variant of
    /// ConstructorArgs, in its order, for the overload resolution algorithm
    /// (webidl.overload_resolution) the binding runs to pick the variant.
    pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{
        .{ .function = "OfflineAudioContextOptions", .args = &.{.{ .kinds = &.{.dictionary} }} },
        .{ .function = "unsigned_long_unsigned_long_float", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try OfflineAudioContextImpl.call_constructor(ctx, args);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!?u32 {
        return try OfflineAudioContextImpl.get_length(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_oncomplete(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(OfflineAudioContextImpl, "get_oncomplete")) return try OfflineAudioContextImpl.get_oncomplete(instance);
        return event_handlers.value(EventHandler, instance, "oncomplete");
    }

    pub fn set_oncomplete(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(OfflineAudioContextImpl, "set_oncomplete")) return try OfflineAudioContextImpl.set_oncomplete(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncomplete", value);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try OfflineAudioContextImpl.call_resume(instance);
    }

    pub fn call_startRendering(instance: *runtime.Instance, chunkSize: webidl.Opt(?u32)) anyerror!runtime.JSValue {
        return try OfflineAudioContextImpl.call_startRendering(instance, chunkSize);
    }

    pub fn call_suspend(instance: *runtime.Instance, suspendTime: f64) anyerror!runtime.JSValue {
        return try OfflineAudioContextImpl.call_suspend(instance, suspendTime);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try OfflineAudioContextImpl.call_close(instance);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_suspend", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_resume",
        "call_startRendering",
        "call_suspend",
        "call_close",
    };
};
