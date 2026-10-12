//! Generated from: screen-wake-lock.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WakeLockSentinelImpl = @import("impls").WakeLockSentinel;
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
const WakeLockType = @import("enums").WakeLockType;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const WakeLockSentinel = struct {
    pub const Meta = struct {
        pub const name = "WakeLockSentinel";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{"Window"} } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "released", "get_released", null },
            .{ "type", "get_type", null },
            .{ "onrelease", "get_onrelease", "set_onrelease" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "release", "call_release", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "release",
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
            .{ "released", "get_released", null },
            .{ "type", "get_type", null },
            .{ "onrelease", "get_onrelease", "set_onrelease" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            released: bool = undefined,
            type: enums.WakeLockType = undefined,
            onrelease: typedefs.EventHandler = undefined,
            _internal: ?*WakeLockSentinelImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onrelease = &get_onrelease,
        .get_released = &get_released,
        .get_type = &get_type,

        .set_onrelease = &set_onrelease,

        .call_release = &call_release,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WakeLockSentinel has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WakeLockSentinelImpl, "init") and @hasDecl(WakeLockSentinelImpl, "initOwn")) @compileError("WakeLockSentinelImpl defines both init and initOwn");
        if (comptime @hasDecl(WakeLockSentinelImpl, "init")) return WakeLockSentinelImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(WakeLockSentinelImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try WakeLockSentinelImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WakeLockSentinelImpl, "init")) return false;
        if (comptime @hasDecl(WakeLockSentinelImpl, "construction_args")) {
            inline for (WakeLockSentinelImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WakeLockSentinelImpl, "deinit") and @hasDecl(WakeLockSentinelImpl, "deinitOwn")) @compileError("WakeLockSentinelImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WakeLockSentinelImpl, "deinit")) return WakeLockSentinelImpl.deinit(instance);
        if (comptime @hasDecl(WakeLockSentinelImpl, "deinitOwn")) WakeLockSentinelImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WakeLockSentinel")) {
            if (comptime @hasDecl(impls.WakeLockSentinel, "installHooks")) impls.WakeLockSentinel.installHooks();
        }
    }

    pub fn get_released(instance: *runtime.Instance) anyerror!bool {
        return try WakeLockSentinelImpl.get_released(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!WakeLockType {
        return try WakeLockSentinelImpl.get_type(instance);
    }

    pub fn get_onrelease(instance: *runtime.Instance) anyerror!EventHandler {
        return try WakeLockSentinelImpl.get_onrelease(instance);
    }

    pub fn set_onrelease(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WakeLockSentinelImpl.set_onrelease(instance, value);
    }

    pub fn call_release(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WakeLockSentinelImpl.call_release(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_release",
    };
};
