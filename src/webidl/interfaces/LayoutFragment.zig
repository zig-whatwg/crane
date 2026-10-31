//! Generated from: css-layout-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LayoutFragmentImpl = @import("impls").LayoutFragment;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ChildBreakToken = @import("interfaces").ChildBreakToken;

pub const LayoutFragment = struct {
    pub const Meta = struct {
        pub const name = "LayoutFragment";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "inlineSize", "get_inlineSize", null },
            .{ "blockSize", "get_blockSize", null },
            .{ "inlineOffset", "get_inlineOffset", "set_inlineOffset" },
            .{ "blockOffset", "get_blockOffset", "set_blockOffset" },
            .{ "data", "get_data", null },
            .{ "breakToken", "get_breakToken", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "inlineSize", "get_inlineSize", null },
            .{ "blockSize", "get_blockSize", null },
            .{ "inlineOffset", "get_inlineOffset", "set_inlineOffset" },
            .{ "blockOffset", "get_blockOffset", "set_blockOffset" },
            .{ "data", "get_data", null },
            .{ "breakToken", "get_breakToken", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            inlineSize: f64 = undefined,
            blockSize: f64 = undefined,
            inlineOffset: f64 = undefined,
            blockOffset: f64 = undefined,
            data: runtime.JSValue = undefined,
            breakToken: ?*runtime.Instance = null,
            _internal: ?*LayoutFragmentImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_blockOffset = &get_blockOffset,
        .get_blockSize = &get_blockSize,
        .get_breakToken = &get_breakToken,
        .get_data = &get_data,
        .get_inlineOffset = &get_inlineOffset,
        .get_inlineSize = &get_inlineSize,

        .set_blockOffset = &set_blockOffset,
        .set_inlineOffset = &set_inlineOffset,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("LayoutFragment has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(LayoutFragmentImpl, "init") and @hasDecl(LayoutFragmentImpl, "initOwn")) @compileError("LayoutFragmentImpl defines both init and initOwn");
        if (comptime @hasDecl(LayoutFragmentImpl, "init")) return LayoutFragmentImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(LayoutFragmentImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try LayoutFragmentImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(LayoutFragmentImpl, "init")) return false;
        if (comptime @hasDecl(LayoutFragmentImpl, "construction_args")) {
            inline for (LayoutFragmentImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(LayoutFragmentImpl, "deinit") and @hasDecl(LayoutFragmentImpl, "deinitOwn")) @compileError("LayoutFragmentImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(LayoutFragmentImpl, "deinit")) return LayoutFragmentImpl.deinit(instance);
        if (comptime @hasDecl(LayoutFragmentImpl, "deinitOwn")) LayoutFragmentImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "LayoutFragment")) {
            if (comptime @hasDecl(impls.LayoutFragment, "installHooks")) impls.LayoutFragment.installHooks();
        }
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_inlineSize(instance);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_blockSize(instance);
    }

    pub fn get_inlineOffset(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_inlineOffset(instance);
    }

    pub fn set_inlineOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try LayoutFragmentImpl.set_inlineOffset(instance, value);
    }

    pub fn get_blockOffset(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_blockOffset(instance);
    }

    pub fn set_blockOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try LayoutFragmentImpl.set_blockOffset(instance, value);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try LayoutFragmentImpl.get_data(instance);
    }

    pub fn get_breakToken(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try LayoutFragmentImpl.get_breakToken(instance);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_inlineOffset", 0b1 },
        .{ "set_blockOffset", 0b1 },
    };
};
