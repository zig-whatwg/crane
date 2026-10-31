//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigationPreloadManagerImpl = @import("impls").NavigationPreloadManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ByteString = @import("typedefs").ByteString;
const NavigationPreloadState = @import("dictionaries").NavigationPreloadState;

pub const NavigationPreloadManager = struct {
    pub const Meta = struct {
        pub const name = "NavigationPreloadManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "enable", "call_enable", 0 },
            .{ "disable", "call_disable", 0 },
            .{ "setHeaderValue", "call_setHeaderValue", 1 },
            .{ "getState", "call_getState", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "enable",
            "disable",
            "setHeaderValue",
            "getState",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*NavigationPreloadManagerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_disable = &call_disable,
        .call_enable = &call_enable,
        .call_getState = &call_getState,
        .call_setHeaderValue = &call_setHeaderValue,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("NavigationPreloadManager has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(NavigationPreloadManagerImpl, "init") and @hasDecl(NavigationPreloadManagerImpl, "initOwn")) @compileError("NavigationPreloadManagerImpl defines both init and initOwn");
        if (comptime @hasDecl(NavigationPreloadManagerImpl, "init")) return NavigationPreloadManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(NavigationPreloadManagerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try NavigationPreloadManagerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NavigationPreloadManagerImpl, "init")) return false;
        if (comptime @hasDecl(NavigationPreloadManagerImpl, "construction_args")) {
            inline for (NavigationPreloadManagerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NavigationPreloadManagerImpl, "deinit") and @hasDecl(NavigationPreloadManagerImpl, "deinitOwn")) @compileError("NavigationPreloadManagerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NavigationPreloadManagerImpl, "deinit")) return NavigationPreloadManagerImpl.deinit(instance);
        if (comptime @hasDecl(NavigationPreloadManagerImpl, "deinitOwn")) NavigationPreloadManagerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NavigationPreloadManager")) {
            if (comptime @hasDecl(impls.NavigationPreloadManager, "installHooks")) impls.NavigationPreloadManager.installHooks();
        }
    }

    pub fn call_getState(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationPreloadManagerImpl.call_getState(instance);
    }

    pub fn call_setHeaderValue(instance: *runtime.Instance, value: runtime.ByteString) anyerror!runtime.JSValue {
        return try NavigationPreloadManagerImpl.call_setHeaderValue(instance, value);
    }

    pub fn call_enable(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationPreloadManagerImpl.call_enable(instance);
    }

    pub fn call_disable(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationPreloadManagerImpl.call_disable(instance);
    }

    /// WebIDL ByteString values: a code unit above 0xFF throws a TypeError
    /// for (bit i = argument i; an attribute setter's value is bit 0).
    pub const byte_string_arguments = .{
        .{ "call_setHeaderValue", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getState",
        "call_setHeaderValue",
        "call_enable",
        "call_disable",
    };
};
