//! Generated from: orientation-event.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DeviceOrientationEventImpl = @import("impls").DeviceOrientationEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const PermissionState = @import("enums").PermissionState;
const DeviceOrientationEventInit = @import("dictionaries").DeviceOrientationEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const DeviceOrientationEvent = struct {
    pub const Meta = struct {
        pub const name = "DeviceOrientationEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "alpha", "get_alpha", null },
            .{ "beta", "get_beta", null },
            .{ "gamma", "get_gamma", null },
            .{ "absolute", "get_absolute", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "requestPermission", "call_static_requestPermission", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestPermission",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "alpha", "get_alpha", null },
            .{ "beta", "get_beta", null },
            .{ "gamma", "get_gamma", null },
            .{ "absolute", "get_absolute", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            alpha: ?f64 = null,
            beta: ?f64 = null,
            gamma: ?f64 = null,
            absolute: bool = undefined,
            _internal: ?*DeviceOrientationEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_absolute = &get_absolute,
        .get_alpha = &get_alpha,
        .get_beta = &get_beta,
        .get_gamma = &get_gamma,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("DeviceOrientationEvent has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(DeviceOrientationEventImpl, "init") and @hasDecl(DeviceOrientationEventImpl, "initOwn")) @compileError("DeviceOrientationEventImpl defines both init and initOwn");
        if (comptime @hasDecl(DeviceOrientationEventImpl, "init")) return DeviceOrientationEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(DeviceOrientationEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try DeviceOrientationEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DeviceOrientationEventImpl, "init")) return false;
        if (comptime @hasDecl(DeviceOrientationEventImpl, "construction_args")) {
            inline for (DeviceOrientationEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DeviceOrientationEventImpl, "deinit") and @hasDecl(DeviceOrientationEventImpl, "deinitOwn")) @compileError("DeviceOrientationEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DeviceOrientationEventImpl, "deinit")) return DeviceOrientationEventImpl.deinit(instance);
        if (comptime @hasDecl(DeviceOrientationEventImpl, "deinitOwn")) DeviceOrientationEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DeviceOrientationEvent")) {
            if (comptime @hasDecl(impls.DeviceOrientationEvent, "installHooks")) impls.DeviceOrientationEvent.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(DeviceOrientationEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DeviceOrientationEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceOrientationEventImpl.get_alpha(instance);
    }

    pub fn get_beta(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceOrientationEventImpl.get_beta(instance);
    }

    pub fn get_gamma(instance: *runtime.Instance) anyerror!?f64 {
        return try DeviceOrientationEventImpl.get_gamma(instance);
    }

    pub fn get_absolute(instance: *runtime.Instance) anyerror!bool {
        return try DeviceOrientationEventImpl.get_absolute(instance);
    }

    pub fn call_static_requestPermission(instance: *runtime.Instance, absolute: webidl.Opt(bool)) anyerror!runtime.JSValue {
        return try DeviceOrientationEventImpl.call_static_requestPermission(instance, absolute);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_static_requestPermission",
    };
};
