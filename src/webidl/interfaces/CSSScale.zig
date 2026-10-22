//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSScaleImpl = @import("impls").CSSScale;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumberish = @import("typedefs").CSSNumberish;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSScale = struct {
    pub const Meta = struct {
        pub const name = "CSSScale";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSTransformComponent.State;
        pub const ParentInterface = CSSTransformComponent;
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
            .{ "x", "get_x", "set_x" },
            .{ "y", "get_y", "set_y" },
            .{ "z", "get_z", "set_z" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "toMatrix",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "x", "get_x", "set_x" },
            .{ "y", "get_y", "set_y" },
            .{ "z", "get_z", "set_z" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            x: typedefs.CSSNumberish = undefined,
            y: typedefs.CSSNumberish = undefined,
            z: typedefs.CSSNumberish = undefined,
            _internal: ?*CSSScaleImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .set_x = &set_x,
        .set_y = &set_y,
        .set_z = &set_z,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSScale has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSScaleImpl, "init") and @hasDecl(CSSScaleImpl, "initOwn")) @compileError("CSSScaleImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSScaleImpl, "init")) return CSSScaleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSScaleImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSScaleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSScaleImpl, "init")) return false;
        if (comptime @hasDecl(CSSScaleImpl, "construction_args")) {
            inline for (CSSScaleImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSScaleImpl, "deinit") and @hasDecl(CSSScaleImpl, "deinitOwn")) @compileError("CSSScaleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSScaleImpl, "deinit")) return CSSScaleImpl.deinit(instance);
        if (comptime @hasDecl(CSSScaleImpl, "deinitOwn")) CSSScaleImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSScale")) {
            if (comptime @hasDecl(impls.CSSScale, "installHooks")) impls.CSSScale.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, x: CSSNumberish, y: CSSNumberish, z: webidl.Opt(CSSNumberish)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSScaleImpl.call_constructor(ctx, x, y, z);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSScaleImpl.get_x(instance);
    }

    pub fn set_x(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSScaleImpl.set_x(instance, value);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSScaleImpl.get_y(instance);
    }

    pub fn set_y(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSScaleImpl.set_y(instance, value);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSScaleImpl.get_z(instance);
    }

    pub fn set_z(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSScaleImpl.set_z(instance, value);
    }
};
