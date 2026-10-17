//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OscillatorNodeImpl = @import("impls").OscillatorNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioScheduledSourceNode = @import("interfaces").AudioScheduledSourceNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const OscillatorOptions = @import("dictionaries").OscillatorOptions;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const PeriodicWave = @import("interfaces").PeriodicWave;
const AudioParam = @import("interfaces").AudioParam;
const OscillatorType = @import("enums").OscillatorType;
const EventListener = @import("interfaces").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const AudioNode = @import("interfaces").AudioNode;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const OscillatorNode = struct {
    pub const Meta = struct {
        pub const name = "OscillatorNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AudioScheduledSourceNode.State;
        pub const ParentInterface = AudioScheduledSourceNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", "set_type" },
            .{ "frequency", "get_frequency", null },
            .{ "detune", "get_detune", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setPeriodicWave", "call_setPeriodicWave", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPeriodicWave",
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
            "start",
            "stop",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", "set_type" },
            .{ "frequency", "get_frequency", null },
            .{ "detune", "get_detune", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: enums.OscillatorType = undefined,
            frequency: *runtime.Instance = undefined,
            detune: *runtime.Instance = undefined,
            _internal: ?*OscillatorNodeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_detune = &get_detune,
        .get_frequency = &get_frequency,
        .get_type = &get_type,

        .set_type = &set_type,

        .call_setPeriodicWave = &call_setPeriodicWave,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("OscillatorNode has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(OscillatorNodeImpl, "init") and @hasDecl(OscillatorNodeImpl, "initOwn")) @compileError("OscillatorNodeImpl defines both init and initOwn");
        if (comptime @hasDecl(OscillatorNodeImpl, "init")) return OscillatorNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(OscillatorNodeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try OscillatorNodeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(OscillatorNodeImpl, "init")) return false;
        if (comptime @hasDecl(OscillatorNodeImpl, "construction_args")) {
            inline for (OscillatorNodeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(OscillatorNodeImpl, "deinit") and @hasDecl(OscillatorNodeImpl, "deinitOwn")) @compileError("OscillatorNodeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(OscillatorNodeImpl, "deinit")) return OscillatorNodeImpl.deinit(instance);
        if (comptime @hasDecl(OscillatorNodeImpl, "deinitOwn")) OscillatorNodeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "OscillatorNode")) {
            if (comptime @hasDecl(impls.OscillatorNode, "installHooks")) impls.OscillatorNode.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, context: *runtime.Instance, options: webidl.Opt(OscillatorOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OscillatorNodeImpl.call_constructor(ctx, context, options);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "BaseAudioContext" },
    };

    pub fn get_type(instance: *runtime.Instance) anyerror!OscillatorType {
        return try OscillatorNodeImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: OscillatorType) anyerror!void {
        try OscillatorNodeImpl.set_type(instance, value);
    }

    pub fn get_frequency(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OscillatorNodeImpl.get_frequency(instance);
    }

    pub fn get_detune(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OscillatorNodeImpl.get_detune(instance);
    }

    pub fn call_setPeriodicWave(instance: *runtime.Instance, periodicWave: *runtime.Instance) anyerror!void {
        return try OscillatorNodeImpl.call_setPeriodicWave(instance, periodicWave);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_setPeriodicWave", 0, "PeriodicWave" },
    };
};
