//! Generated from: DOM-Style.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RectImpl = @import("impls").Rect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSPrimitiveValue = @import("interfaces").CSSPrimitiveValue;

pub const Rect = struct {
    pub const Meta = struct {
        pub const name = "Rect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "top", "get_top", null },
            .{ "right", "get_right", null },
            .{ "bottom", "get_bottom", null },
            .{ "left", "get_left", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "top", "get_top", null },
            .{ "right", "get_right", null },
            .{ "bottom", "get_bottom", null },
            .{ "left", "get_left", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            top: *runtime.Instance = undefined,
            right: *runtime.Instance = undefined,
            bottom: *runtime.Instance = undefined,
            left: *runtime.Instance = undefined,
            _internal: ?*RectImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_bottom = &get_bottom,
        .get_left = &get_left,
        .get_right = &get_right,
        .get_top = &get_top,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Rect has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RectImpl, "init") and @hasDecl(RectImpl, "initOwn")) @compileError("RectImpl defines both init and initOwn");
        if (comptime @hasDecl(RectImpl, "init")) return RectImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(RectImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try RectImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RectImpl, "init")) return false;
        if (comptime @hasDecl(RectImpl, "construction_args")) {
            inline for (RectImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RectImpl, "deinit") and @hasDecl(RectImpl, "deinitOwn")) @compileError("RectImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RectImpl, "deinit")) return RectImpl.deinit(instance);
        if (comptime @hasDecl(RectImpl, "deinitOwn")) RectImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Rect")) {
            if (comptime @hasDecl(impls.Rect, "installHooks")) impls.Rect.installHooks();
        }
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RectImpl.get_top(instance);
    }

    pub fn get_right(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RectImpl.get_right(instance);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RectImpl.get_bottom(instance);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RectImpl.get_left(instance);
    }
};
