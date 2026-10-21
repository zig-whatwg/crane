//! Generated from: css-highlight-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HighlightImpl = @import("impls").Highlight;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HighlightType = @import("enums").HighlightType;
const AbstractRange = @import("interfaces").AbstractRange;

pub const Highlight = struct {
    pub const Meta = struct {
        pub const name = "Highlight";
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
            .{ "priority", "get_priority", "set_priority" },
            .{ "type", "get_type", "set_type" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "priority", "get_priority", "set_priority" },
            .{ "type", "get_type", "set_type" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            priority: i32 = undefined,
            type: enums.HighlightType = undefined,
            _internal: ?*HighlightImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    const delegates = .{
        .get_priority = &get_priority,
        .get_type = &get_type,

        .set_priority = &set_priority,
        .set_type = &set_type,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Highlight has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HighlightImpl, "init") and @hasDecl(HighlightImpl, "initOwn")) @compileError("HighlightImpl defines both init and initOwn");
        if (comptime @hasDecl(HighlightImpl, "init")) return HighlightImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(HighlightImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try HighlightImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HighlightImpl, "init")) return false;
        if (comptime @hasDecl(HighlightImpl, "construction_args")) {
            inline for (HighlightImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HighlightImpl, "deinit") and @hasDecl(HighlightImpl, "deinitOwn")) @compileError("HighlightImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HighlightImpl, "deinit")) return HighlightImpl.deinit(instance);
        if (comptime @hasDecl(HighlightImpl, "deinitOwn")) HighlightImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Highlight")) {
            if (comptime @hasDecl(impls.Highlight, "installHooks")) impls.Highlight.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, initialRanges: []const *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HighlightImpl.call_constructor(ctx, initialRanges);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "AbstractRange" },
    };

    pub fn get_priority(instance: *runtime.Instance) anyerror!i32 {
        return try HighlightImpl.get_priority(instance);
    }

    pub fn set_priority(instance: *runtime.Instance, value: i32) anyerror!void {
        try HighlightImpl.set_priority(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!HighlightType {
        return try HighlightImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: HighlightType) anyerror!void {
        try HighlightImpl.set_type(instance, value);
    }
};
