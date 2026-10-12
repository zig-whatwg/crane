//! Generated from: battery-status.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BatteryManagerImpl = @import("impls").BatteryManager;
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
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const BatteryManager = struct {
    pub const Meta = struct {
        pub const name = "BatteryManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "charging", "get_charging", null },
            .{ "chargingTime", "get_chargingTime", null },
            .{ "dischargingTime", "get_dischargingTime", null },
            .{ "level", "get_level", null },
            .{ "onchargingchange", "get_onchargingchange", "set_onchargingchange" },
            .{ "onchargingtimechange", "get_onchargingtimechange", "set_onchargingtimechange" },
            .{ "ondischargingtimechange", "get_ondischargingtimechange", "set_ondischargingtimechange" },
            .{ "onlevelchange", "get_onlevelchange", "set_onlevelchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "charging", "get_charging", null },
            .{ "chargingTime", "get_chargingTime", null },
            .{ "dischargingTime", "get_dischargingTime", null },
            .{ "level", "get_level", null },
            .{ "onchargingchange", "get_onchargingchange", "set_onchargingchange" },
            .{ "onchargingtimechange", "get_onchargingtimechange", "set_onchargingtimechange" },
            .{ "ondischargingtimechange", "get_ondischargingtimechange", "set_ondischargingtimechange" },
            .{ "onlevelchange", "get_onlevelchange", "set_onlevelchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            charging: bool = undefined,
            chargingTime: f64 = undefined,
            dischargingTime: f64 = undefined,
            level: f64 = undefined,
            onchargingchange: typedefs.EventHandler = undefined,
            onchargingtimechange: typedefs.EventHandler = undefined,
            ondischargingtimechange: typedefs.EventHandler = undefined,
            onlevelchange: typedefs.EventHandler = undefined,
            _internal: ?*BatteryManagerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_charging = &get_charging,
        .get_chargingTime = &get_chargingTime,
        .get_dischargingTime = &get_dischargingTime,
        .get_level = &get_level,
        .get_onchargingchange = &get_onchargingchange,
        .get_onchargingtimechange = &get_onchargingtimechange,
        .get_ondischargingtimechange = &get_ondischargingtimechange,
        .get_onlevelchange = &get_onlevelchange,

        .set_onchargingchange = &set_onchargingchange,
        .set_onchargingtimechange = &set_onchargingtimechange,
        .set_ondischargingtimechange = &set_ondischargingtimechange,
        .set_onlevelchange = &set_onlevelchange,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("BatteryManager has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(BatteryManagerImpl, "init") and @hasDecl(BatteryManagerImpl, "initOwn")) @compileError("BatteryManagerImpl defines both init and initOwn");
        if (comptime @hasDecl(BatteryManagerImpl, "init")) return BatteryManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(BatteryManagerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try BatteryManagerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BatteryManagerImpl, "init")) return false;
        if (comptime @hasDecl(BatteryManagerImpl, "construction_args")) {
            inline for (BatteryManagerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BatteryManagerImpl, "deinit") and @hasDecl(BatteryManagerImpl, "deinitOwn")) @compileError("BatteryManagerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(BatteryManagerImpl, "deinit")) return BatteryManagerImpl.deinit(instance);
        if (comptime @hasDecl(BatteryManagerImpl, "deinitOwn")) BatteryManagerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BatteryManager")) {
            if (comptime @hasDecl(impls.BatteryManager, "installHooks")) impls.BatteryManager.installHooks();
        }
    }

    pub fn get_charging(instance: *runtime.Instance) anyerror!bool {
        return try BatteryManagerImpl.get_charging(instance);
    }

    pub fn get_chargingTime(instance: *runtime.Instance) anyerror!f64 {
        return try BatteryManagerImpl.get_chargingTime(instance);
    }

    pub fn get_dischargingTime(instance: *runtime.Instance) anyerror!f64 {
        return try BatteryManagerImpl.get_dischargingTime(instance);
    }

    pub fn get_level(instance: *runtime.Instance) anyerror!f64 {
        return try BatteryManagerImpl.get_level(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onchargingchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(BatteryManagerImpl, "get_onchargingchange")) return try BatteryManagerImpl.get_onchargingchange(instance);
        return event_handlers.value(EventHandler, instance, "onchargingchange");
    }

    pub fn set_onchargingchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(BatteryManagerImpl, "set_onchargingchange")) return try BatteryManagerImpl.set_onchargingchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchargingchange", value);
    }

    pub fn get_onchargingtimechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(BatteryManagerImpl, "get_onchargingtimechange")) return try BatteryManagerImpl.get_onchargingtimechange(instance);
        return event_handlers.value(EventHandler, instance, "onchargingtimechange");
    }

    pub fn set_onchargingtimechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(BatteryManagerImpl, "set_onchargingtimechange")) return try BatteryManagerImpl.set_onchargingtimechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchargingtimechange", value);
    }

    pub fn get_ondischargingtimechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(BatteryManagerImpl, "get_ondischargingtimechange")) return try BatteryManagerImpl.get_ondischargingtimechange(instance);
        return event_handlers.value(EventHandler, instance, "ondischargingtimechange");
    }

    pub fn set_ondischargingtimechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(BatteryManagerImpl, "set_ondischargingtimechange")) return try BatteryManagerImpl.set_ondischargingtimechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondischargingtimechange", value);
    }

    pub fn get_onlevelchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(BatteryManagerImpl, "get_onlevelchange")) return try BatteryManagerImpl.get_onlevelchange(instance);
        return event_handlers.value(EventHandler, instance, "onlevelchange");
    }

    pub fn set_onlevelchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(BatteryManagerImpl, "set_onlevelchange")) return try BatteryManagerImpl.set_onlevelchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onlevelchange", value);
    }
};
