//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnalyserNodeImpl = @import("impls").AnalyserNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const AnalyserOptions = @import("dictionaries").AnalyserOptions;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const AnalyserNode = struct {
    pub const Meta = struct {
        pub const name = "AnalyserNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AudioNode.State;
        pub const ParentInterface = AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "fftSize", "get_fftSize", "set_fftSize" },
            .{ "frequencyBinCount", "get_frequencyBinCount", null },
            .{ "minDecibels", "get_minDecibels", "set_minDecibels" },
            .{ "maxDecibels", "get_maxDecibels", "set_maxDecibels" },
            .{ "smoothingTimeConstant", "get_smoothingTimeConstant", "set_smoothingTimeConstant" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getFloatFrequencyData", "call_getFloatFrequencyData", 1 },
            .{ "getByteFrequencyData", "call_getByteFrequencyData", 1 },
            .{ "getFloatTimeDomainData", "call_getFloatTimeDomainData", 1 },
            .{ "getByteTimeDomainData", "call_getByteTimeDomainData", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getFloatFrequencyData",
            "getByteFrequencyData",
            "getFloatTimeDomainData",
            "getByteTimeDomainData",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "fftSize", "get_fftSize", "set_fftSize" },
            .{ "frequencyBinCount", "get_frequencyBinCount", null },
            .{ "minDecibels", "get_minDecibels", "set_minDecibels" },
            .{ "maxDecibels", "get_maxDecibels", "set_maxDecibels" },
            .{ "smoothingTimeConstant", "get_smoothingTimeConstant", "set_smoothingTimeConstant" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            fftSize: u32 = undefined,
            frequencyBinCount: u32 = undefined,
            minDecibels: f64 = undefined,
            maxDecibels: f64 = undefined,
            smoothingTimeConstant: f64 = undefined,
            _internal: ?*AnalyserNodeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_fftSize = &get_fftSize,
        .get_frequencyBinCount = &get_frequencyBinCount,
        .get_maxDecibels = &get_maxDecibels,
        .get_minDecibels = &get_minDecibels,
        .get_smoothingTimeConstant = &get_smoothingTimeConstant,

        .set_fftSize = &set_fftSize,
        .set_maxDecibels = &set_maxDecibels,
        .set_minDecibels = &set_minDecibels,
        .set_smoothingTimeConstant = &set_smoothingTimeConstant,

        .call_getByteFrequencyData = &call_getByteFrequencyData,
        .call_getByteTimeDomainData = &call_getByteTimeDomainData,
        .call_getFloatFrequencyData = &call_getFloatFrequencyData,
        .call_getFloatTimeDomainData = &call_getFloatTimeDomainData,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AnalyserNode has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AnalyserNodeImpl, "init") and @hasDecl(AnalyserNodeImpl, "initOwn")) @compileError("AnalyserNodeImpl defines both init and initOwn");
        if (comptime @hasDecl(AnalyserNodeImpl, "init")) return AnalyserNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AnalyserNodeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AnalyserNodeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AnalyserNodeImpl, "init")) return false;
        if (comptime @hasDecl(AnalyserNodeImpl, "construction_args")) {
            inline for (AnalyserNodeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AnalyserNodeImpl, "deinit") and @hasDecl(AnalyserNodeImpl, "deinitOwn")) @compileError("AnalyserNodeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AnalyserNodeImpl, "deinit")) return AnalyserNodeImpl.deinit(instance);
        if (comptime @hasDecl(AnalyserNodeImpl, "deinitOwn")) AnalyserNodeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AnalyserNode")) {
            if (comptime @hasDecl(impls.AnalyserNode, "installHooks")) impls.AnalyserNode.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: webidl.Opt(AnalyserOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AnalyserNodeImpl.call_constructor(ctx, context, options);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "BaseAudioContext" },
    };

    pub fn get_fftSize(instance: *runtime.Instance) anyerror!u32 {
        return try AnalyserNodeImpl.get_fftSize(instance);
    }

    pub fn set_fftSize(instance: *runtime.Instance, value: u32) anyerror!void {
        try AnalyserNodeImpl.set_fftSize(instance, value);
    }

    pub fn get_frequencyBinCount(instance: *runtime.Instance) anyerror!u32 {
        return try AnalyserNodeImpl.get_frequencyBinCount(instance);
    }

    pub fn get_minDecibels(instance: *runtime.Instance) anyerror!f64 {
        return try AnalyserNodeImpl.get_minDecibels(instance);
    }

    pub fn set_minDecibels(instance: *runtime.Instance, value: f64) anyerror!void {
        try AnalyserNodeImpl.set_minDecibels(instance, value);
    }

    pub fn get_maxDecibels(instance: *runtime.Instance) anyerror!f64 {
        return try AnalyserNodeImpl.get_maxDecibels(instance);
    }

    pub fn set_maxDecibels(instance: *runtime.Instance, value: f64) anyerror!void {
        try AnalyserNodeImpl.set_maxDecibels(instance, value);
    }

    pub fn get_smoothingTimeConstant(instance: *runtime.Instance) anyerror!f64 {
        return try AnalyserNodeImpl.get_smoothingTimeConstant(instance);
    }

    pub fn set_smoothingTimeConstant(instance: *runtime.Instance, value: f64) anyerror!void {
        try AnalyserNodeImpl.set_smoothingTimeConstant(instance, value);
    }

    pub fn call_getByteFrequencyData(instance: *runtime.Instance, array: runtime.JSValue) anyerror!void {
        return try AnalyserNodeImpl.call_getByteFrequencyData(instance, array);
    }

    pub fn call_getFloatFrequencyData(instance: *runtime.Instance, array: runtime.JSValue) anyerror!void {
        return try AnalyserNodeImpl.call_getFloatFrequencyData(instance, array);
    }

    pub fn call_getFloatTimeDomainData(instance: *runtime.Instance, array: runtime.JSValue) anyerror!void {
        return try AnalyserNodeImpl.call_getFloatTimeDomainData(instance, array);
    }

    pub fn call_getByteTimeDomainData(instance: *runtime.Instance, array: runtime.JSValue) anyerror!void {
        return try AnalyserNodeImpl.call_getByteTimeDomainData(instance, array);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_minDecibels", 0b1 },
        .{ "set_maxDecibels", 0b1 },
        .{ "set_smoothingTimeConstant", 0b1 },
    };
};
