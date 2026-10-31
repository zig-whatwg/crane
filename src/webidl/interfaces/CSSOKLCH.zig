//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSOKLCHImpl = @import("impls").CSSOKLCH;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSColorAngle = @import("typedefs").CSSColorAngle;
const CSSColorPercent = @import("typedefs").CSSColorPercent;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSOKLCH = struct {
    pub const Meta = struct {
        pub const name = "CSSOKLCH";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSColorValue.State;
        pub const ParentInterface = CSSColorValue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "l", "get_l", "set_l" },
            .{ "c", "get_c", "set_c" },
            .{ "h", "get_h", "set_h" },
            .{ "alpha", "get_alpha", "set_alpha" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parse",
            "parseAll",
            "parse",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "l", "get_l", "set_l" },
            .{ "c", "get_c", "set_c" },
            .{ "h", "get_h", "set_h" },
            .{ "alpha", "get_alpha", "set_alpha" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            l: typedefs.CSSColorPercent = undefined,
            c: typedefs.CSSColorPercent = undefined,
            h: typedefs.CSSColorAngle = undefined,
            alpha: typedefs.CSSColorPercent = undefined,
            _internal: ?*CSSOKLCHImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_alpha = &get_alpha,
        .get_c = &get_c,
        .get_h = &get_h,
        .get_l = &get_l,

        .set_alpha = &set_alpha,
        .set_c = &set_c,
        .set_h = &set_h,
        .set_l = &set_l,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("CSSOKLCH has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CSSOKLCHImpl, "init") and @hasDecl(CSSOKLCHImpl, "initOwn")) @compileError("CSSOKLCHImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSOKLCHImpl, "init")) return CSSOKLCHImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSOKLCHImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSOKLCHImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSOKLCHImpl, "init")) return false;
        if (comptime @hasDecl(CSSOKLCHImpl, "construction_args")) {
            inline for (CSSOKLCHImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSOKLCHImpl, "deinit") and @hasDecl(CSSOKLCHImpl, "deinitOwn")) @compileError("CSSOKLCHImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSOKLCHImpl, "deinit")) return CSSOKLCHImpl.deinit(instance);
        if (comptime @hasDecl(CSSOKLCHImpl, "deinitOwn")) CSSOKLCHImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSOKLCH")) {
            if (comptime @hasDecl(impls.CSSOKLCH, "installHooks")) impls.CSSOKLCH.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 3;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, l: CSSColorPercent, c: CSSColorPercent, h: CSSColorAngle, alpha: webidl.Opt(CSSColorPercent)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSOKLCHImpl.call_constructor(ctx, l, c, h, alpha);
    }

    pub fn get_l(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSOKLCHImpl.get_l(instance);
    }

    pub fn set_l(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSOKLCHImpl.set_l(instance, value);
    }

    pub fn get_c(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSOKLCHImpl.get_c(instance);
    }

    pub fn set_c(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSOKLCHImpl.set_c(instance, value);
    }

    pub fn get_h(instance: *runtime.Instance) anyerror!CSSColorAngle {
        return try CSSOKLCHImpl.get_h(instance);
    }

    pub fn set_h(instance: *runtime.Instance, value: CSSColorAngle) anyerror!void {
        try CSSOKLCHImpl.set_h(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSOKLCHImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSOKLCHImpl.set_alpha(instance, value);
    }
};
