//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigationTransitionImpl = @import("impls").NavigationTransition;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const NavigationDestination = @import("interfaces").NavigationDestination;
const NavigationType = @import("enums").NavigationType;
const NavigationHistoryEntry = @import("interfaces").NavigationHistoryEntry;

pub const NavigationTransition = struct {
    pub const Meta = struct {
        pub const name = "NavigationTransition";
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
            .{ "navigationType", "get_navigationType", null },
            .{ "from", "get_from", null },
            .{ "to", "get_to", null },
            .{ "committed", "get_committed", null },
            .{ "finished", "get_finished", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "navigationType", "get_navigationType", null },
            .{ "from", "get_from", null },
            .{ "to", "get_to", null },
            .{ "committed", "get_committed", null },
            .{ "finished", "get_finished", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            navigationType: enums.NavigationType = undefined,
            from: *runtime.Instance = undefined,
            to: *runtime.Instance = undefined,
            committed: runtime.JSValue = undefined,
            finished: runtime.JSValue = undefined,
            _internal: ?*NavigationTransitionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_committed = &get_committed,
        .get_finished = &get_finished,
        .get_from = &get_from,
        .get_navigationType = &get_navigationType,
        .get_to = &get_to,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("NavigationTransition has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(NavigationTransitionImpl, "init") and @hasDecl(NavigationTransitionImpl, "initOwn")) @compileError("NavigationTransitionImpl defines both init and initOwn");
        if (comptime @hasDecl(NavigationTransitionImpl, "init")) return NavigationTransitionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(NavigationTransitionImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try NavigationTransitionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NavigationTransitionImpl, "init")) return false;
        if (comptime @hasDecl(NavigationTransitionImpl, "construction_args")) {
            inline for (NavigationTransitionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NavigationTransitionImpl, "deinit") and @hasDecl(NavigationTransitionImpl, "deinitOwn")) @compileError("NavigationTransitionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NavigationTransitionImpl, "deinit")) return NavigationTransitionImpl.deinit(instance);
        if (comptime @hasDecl(NavigationTransitionImpl, "deinitOwn")) NavigationTransitionImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NavigationTransition")) {
            if (comptime @hasDecl(impls.NavigationTransition, "installHooks")) impls.NavigationTransition.installHooks();
        }
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyerror!NavigationType {
        return try NavigationTransitionImpl.get_navigationType(instance);
    }

    pub fn get_from(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigationTransitionImpl.get_from(instance);
    }

    pub fn get_to(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigationTransitionImpl.get_to(instance);
    }

    pub fn get_committed(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationTransitionImpl.get_committed(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationTransitionImpl.get_finished(instance);
    }
};
