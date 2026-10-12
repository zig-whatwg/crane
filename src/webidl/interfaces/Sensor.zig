//! Generated from: generic-sensor.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SensorImpl = @import("impls").Sensor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const Sensor = struct {
    pub const Meta = struct {
        pub const name = "Sensor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "Window" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "activated", "get_activated", null },
            .{ "hasReading", "get_hasReading", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "onreading", "get_onreading", "set_onreading" },
            .{ "onactivate", "get_onactivate", "set_onactivate" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
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
            .{ "activated", "get_activated", null },
            .{ "hasReading", "get_hasReading", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "onreading", "get_onreading", "set_onreading" },
            .{ "onactivate", "get_onactivate", "set_onactivate" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            activated: bool = undefined,
            hasReading: bool = undefined,
            timestamp: ?typedefs.DOMHighResTimeStamp = null,
            onreading: typedefs.EventHandler = undefined,
            onactivate: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            _internal: ?*SensorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_activated = &get_activated,
        .get_hasReading = &get_hasReading,
        .get_onactivate = &get_onactivate,
        .get_onerror = &get_onerror,
        .get_onreading = &get_onreading,
        .get_timestamp = &get_timestamp,

        .set_onactivate = &set_onactivate,
        .set_onerror = &set_onerror,
        .set_onreading = &set_onreading,

        .call_start = &call_start,
        .call_stop = &call_stop,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Sensor has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SensorImpl, "init") and @hasDecl(SensorImpl, "initOwn")) @compileError("SensorImpl defines both init and initOwn");
        if (comptime @hasDecl(SensorImpl, "init")) return SensorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SensorImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SensorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SensorImpl, "init")) return false;
        if (comptime @hasDecl(SensorImpl, "construction_args")) {
            inline for (SensorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SensorImpl, "deinit") and @hasDecl(SensorImpl, "deinitOwn")) @compileError("SensorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SensorImpl, "deinit")) return SensorImpl.deinit(instance);
        if (comptime @hasDecl(SensorImpl, "deinitOwn")) SensorImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Sensor")) {
            if (comptime @hasDecl(impls.Sensor, "installHooks")) impls.Sensor.installHooks();
        }
    }

    pub fn get_activated(instance: *runtime.Instance) anyerror!bool {
        return try SensorImpl.get_activated(instance);
    }

    pub fn get_hasReading(instance: *runtime.Instance) anyerror!bool {
        return try SensorImpl.get_hasReading(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try SensorImpl.get_timestamp(instance);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        return try SensorImpl.get_onreading(instance);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SensorImpl.set_onreading(instance, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try SensorImpl.get_onactivate(instance);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SensorImpl.set_onactivate(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SensorImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SensorImpl.set_onerror(instance, value);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try SensorImpl.call_start(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try SensorImpl.call_stop(instance);
    }
};
