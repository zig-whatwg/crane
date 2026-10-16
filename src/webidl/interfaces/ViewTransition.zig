//! Generated from: css-view-transitions.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ViewTransitionImpl = @import("impls").ViewTransition;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ViewTransitionTypeSet = @import("interfaces").ViewTransitionTypeSet;
const Element = @import("interfaces").Element;

pub const ViewTransition = struct {
    pub const Meta = struct {
        pub const name = "ViewTransition";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "updateCallbackDone", "get_updateCallbackDone", null },
            .{ "ready", "get_ready", null },
            .{ "finished", "get_finished", null },
            .{ "types", "get_types", "set_types" },
            .{ "transitionRoot", "get_transitionRoot", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "skipTransition", "call_skipTransition", 0 },
            .{ "waitUntil", "call_waitUntil", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "skipTransition",
            "waitUntil",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "updateCallbackDone", "get_updateCallbackDone", null },
            .{ "ready", "get_ready", null },
            .{ "finished", "get_finished", null },
            .{ "types", "get_types", "set_types" },
            .{ "transitionRoot", "get_transitionRoot", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            updateCallbackDone: runtime.JSValue = undefined,
            ready: runtime.JSValue = undefined,
            finished: runtime.JSValue = undefined,
            types: *runtime.Instance = undefined,
            transitionRoot: *runtime.Instance = undefined,
            cached_types: ?*runtime.Instance = null,
            _internal: ?*ViewTransitionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_finished = &get_finished,
        .get_ready = &get_ready,
        .get_transitionRoot = &get_transitionRoot,
        .get_types = &get_types,
        .get_updateCallbackDone = &get_updateCallbackDone,

        .set_types = &set_types,

        .call_skipTransition = &call_skipTransition,
        .call_waitUntil = &call_waitUntil,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ViewTransition has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ViewTransitionImpl, "init") and @hasDecl(ViewTransitionImpl, "initOwn")) @compileError("ViewTransitionImpl defines both init and initOwn");
        if (comptime @hasDecl(ViewTransitionImpl, "init")) return ViewTransitionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ViewTransitionImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ViewTransitionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ViewTransitionImpl, "init")) return false;
        if (comptime @hasDecl(ViewTransitionImpl, "construction_args")) {
            inline for (ViewTransitionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ViewTransitionImpl, "deinit") and @hasDecl(ViewTransitionImpl, "deinitOwn")) @compileError("ViewTransitionImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(ViewTransitionImpl, "deinit")) return ViewTransitionImpl.deinit(instance);
        if (comptime @hasDecl(ViewTransitionImpl, "deinitOwn")) ViewTransitionImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ViewTransition")) {
            if (comptime @hasDecl(impls.ViewTransition, "installHooks")) impls.ViewTransition.installHooks();
        }
    }

    pub fn get_updateCallbackDone(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ViewTransitionImpl.get_updateCallbackDone(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ViewTransitionImpl.get_ready(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ViewTransitionImpl.get_finished(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_types(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_types) |cached| {
            return cached;
        }
        const value = try ViewTransitionImpl.get_types(instance);
        state.own.cached_types = value;
        @import("dom").same_object_cache.made(instance, value, "types");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn set_types(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        const state = instance.getState(State);
        state.own.cached_types = null; // Invalidate [SameObject] cache
        try ViewTransitionImpl.set_types(instance, value);
    }

    pub fn get_transitionRoot(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ViewTransitionImpl.get_transitionRoot(instance);
    }

    pub fn call_skipTransition(instance: *runtime.Instance) anyerror!void {
        return try ViewTransitionImpl.call_skipTransition(instance);
    }

    pub fn call_waitUntil(instance: *runtime.Instance, promise: runtime.JSValue) anyerror!void {
        return try ViewTransitionImpl.call_waitUntil(instance, promise);
    }
};
