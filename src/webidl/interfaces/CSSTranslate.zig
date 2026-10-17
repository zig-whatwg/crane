//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSTranslateImpl = @import("impls").CSSTranslate;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSTranslate = struct {
    pub const Meta = struct {
        pub const name = "CSSTranslate";
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
            x: *runtime.Instance = undefined,
            y: *runtime.Instance = undefined,
            z: *runtime.Instance = undefined,
            _internal: ?*CSSTranslateImpl.InternalState = null,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSTranslate has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSTranslateImpl, "init") and @hasDecl(CSSTranslateImpl, "initOwn")) @compileError("CSSTranslateImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSTranslateImpl, "init")) return CSSTranslateImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSTranslateImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSTranslateImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSTranslateImpl, "init")) return false;
        if (comptime @hasDecl(CSSTranslateImpl, "construction_args")) {
            inline for (CSSTranslateImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSTranslateImpl, "deinit") and @hasDecl(CSSTranslateImpl, "deinitOwn")) @compileError("CSSTranslateImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSTranslateImpl, "deinit")) return CSSTranslateImpl.deinit(instance);
        if (comptime @hasDecl(CSSTranslateImpl, "deinitOwn")) CSSTranslateImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSTranslate")) {
            if (comptime @hasDecl(impls.CSSTranslate, "installHooks")) impls.CSSTranslate.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, x: *runtime.Instance, y: *runtime.Instance, z: webidl.Opt(*runtime.Instance)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSTranslateImpl.call_constructor(ctx, x, y, z);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "CSSNumericValue" },
        .{ "", 1, "CSSNumericValue" },
        .{ "", 2, "CSSNumericValue" },
    };

    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSTranslateImpl.get_x(instance);
    }

    pub fn set_x(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSTranslateImpl.set_x(instance, value);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSTranslateImpl.get_y(instance);
    }

    pub fn set_y(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSTranslateImpl.set_y(instance, value);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSTranslateImpl.get_z(instance);
    }

    pub fn set_z(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSTranslateImpl.set_z(instance, value);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_x", 0, "CSSNumericValue" },
        .{ "set_y", 0, "CSSNumericValue" },
        .{ "set_z", 0, "CSSNumericValue" },
    };
};
