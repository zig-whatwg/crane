//! Generated from: observable.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SubscriberImpl = @import("impls").Subscriber;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AbortSignal = @import("interfaces").AbortSignal;
const VoidFunction = @import("callbacks").VoidFunction;

pub const Subscriber = struct {
    pub const Meta = struct {
        pub const name = "Subscriber";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "active", "get_active", null },
            .{ "signal", "get_signal", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "next", "call_next", 1 },
            .{ "error", "call_error", 1 },
            .{ "complete", "call_complete", 0 },
            .{ "addTeardown", "call_addTeardown", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "next",
            "error",
            "complete",
            "addTeardown",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "active", "get_active", null },
            .{ "signal", "get_signal", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            active: bool = undefined,
            signal: *runtime.Instance = undefined,
            _internal: ?*SubscriberImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_active = &get_active,
        .get_signal = &get_signal,

        .call_addTeardown = &call_addTeardown,
        .call_complete = &call_complete,
        .call_error = &call_error,
        .call_next = &call_next,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Subscriber has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SubscriberImpl, "init") and @hasDecl(SubscriberImpl, "initOwn")) @compileError("SubscriberImpl defines both init and initOwn");
        if (comptime @hasDecl(SubscriberImpl, "init")) return SubscriberImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SubscriberImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SubscriberImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SubscriberImpl, "init")) return false;
        if (comptime @hasDecl(SubscriberImpl, "construction_args")) {
            inline for (SubscriberImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(SubscriberImpl, "deinit") and @hasDecl(SubscriberImpl, "deinitOwn")) @compileError("SubscriberImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SubscriberImpl, "deinit")) return SubscriberImpl.deinit(instance);
        if (comptime @hasDecl(SubscriberImpl, "deinitOwn")) SubscriberImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Subscriber")) {
            if (comptime @hasDecl(impls.Subscriber, "installHooks")) impls.Subscriber.installHooks();
        }
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!bool {
        return try SubscriberImpl.get_active(instance);
    }

    pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SubscriberImpl.get_signal(instance);
    }

    pub fn call_complete(instance: *runtime.Instance) anyerror!void {
        return try SubscriberImpl.call_complete(instance);
    }

    pub fn call_next(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        return try SubscriberImpl.call_next(instance, value);
    }

    pub fn call_error(instance: *runtime.Instance, @"error": runtime.JSValue) anyerror!void {
        return try SubscriberImpl.call_error(instance, @"error");
    }

    pub fn call_addTeardown(instance: *runtime.Instance, teardown: VoidFunction) anyerror!void {
        return try SubscriberImpl.call_addTeardown(instance, teardown);
    }
};
