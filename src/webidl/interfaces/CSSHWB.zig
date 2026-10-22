//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSHWBImpl = @import("impls").CSSHWB;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSHWB = struct {
    pub const Meta = struct {
        pub const name = "CSSHWB";
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
            .{ "h", "get_h", "set_h" },
            .{ "w", "get_w", "set_w" },
            .{ "b", "get_b", "set_b" },
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
            .{ "h", "get_h", "set_h" },
            .{ "w", "get_w", "set_w" },
            .{ "b", "get_b", "set_b" },
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
            h: *runtime.Instance = undefined,
            w: typedefs.CSSNumberish = undefined,
            b: typedefs.CSSNumberish = undefined,
            alpha: typedefs.CSSNumberish = undefined,
            _internal: ?*CSSHWBImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_h = &get_h,
        .get_w = &get_w,

        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_h = &set_h,
        .set_w = &set_w,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSHWB has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSHWBImpl, "init") and @hasDecl(CSSHWBImpl, "initOwn")) @compileError("CSSHWBImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSHWBImpl, "init")) return CSSHWBImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSHWBImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSHWBImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSHWBImpl, "init")) return false;
        if (comptime @hasDecl(CSSHWBImpl, "construction_args")) {
            inline for (CSSHWBImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSHWBImpl, "deinit") and @hasDecl(CSSHWBImpl, "deinitOwn")) @compileError("CSSHWBImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSHWBImpl, "deinit")) return CSSHWBImpl.deinit(instance);
        if (comptime @hasDecl(CSSHWBImpl, "deinitOwn")) CSSHWBImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSHWB")) {
            if (comptime @hasDecl(impls.CSSHWB, "installHooks")) impls.CSSHWB.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 3;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, h: *runtime.Instance, w: CSSNumberish, b: CSSNumberish, alpha: webidl.Opt(CSSNumberish)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSHWBImpl.call_constructor(ctx, h, w, b, alpha);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "CSSNumericValue" },
    };

    pub fn get_h(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSHWBImpl.get_h(instance);
    }

    pub fn set_h(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSHWBImpl.set_h(instance, value);
    }

    pub fn get_w(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSHWBImpl.get_w(instance);
    }

    pub fn set_w(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSHWBImpl.set_w(instance, value);
    }

    pub fn get_b(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSHWBImpl.get_b(instance);
    }

    pub fn set_b(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSHWBImpl.set_b(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSHWBImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSHWBImpl.set_alpha(instance, value);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_h", 0, "CSSNumericValue" },
    };
};
