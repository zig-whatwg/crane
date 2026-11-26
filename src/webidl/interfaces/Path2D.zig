//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const Path2DImpl = @import("impls").Path2D;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasPath = @import("mixins").CanvasPath;
const Path2DOrDOMString = @import("typedefs").Path2DOrDOMString;
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const UnrestrictedDoubleOrDOMPointInitOrSequenceOfUnrestrictedDoubleOrDOMPointInit = @import("typedefs").UnrestrictedDoubleOrDOMPointInitOrSequenceOfUnrestrictedDoubleOrDOMPointInit;

pub const Path2D = struct {
    pub const Meta = struct {
        pub const name = "Path2D";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            CanvasPath,
        };
        pub const extended_attributes = .{
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
            .{ "addPath", "call_addPath", 1 },
            .{ "closePath", "call_closePath", 0 },
            .{ "moveTo", "call_moveTo", 2 },
            .{ "lineTo", "call_lineTo", 2 },
            .{ "quadraticCurveTo", "call_quadraticCurveTo", 4 },
            .{ "bezierCurveTo", "call_bezierCurveTo", 6 },
            .{ "arcTo", "call_arcTo", 5 },
            .{ "rect", "call_rect", 4 },
            .{ "roundRect", "call_roundRect", 4 },
            .{ "arc", "call_arc", 5 },
            .{ "ellipse", "call_ellipse", 7 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addPath",
            "closePath",
            "moveTo",
            "lineTo",
            "quadraticCurveTo",
            "bezierCurveTo",
            "arcTo",
            "rect",
            "roundRect",
            "arc",
            "ellipse",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*Path2DImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_addPath = &call_addPath,
        .call_arc = &call_arc,
        .call_arcTo = &call_arcTo,
        .call_bezierCurveTo = &call_bezierCurveTo,
        .call_closePath = &call_closePath,
        .call_ellipse = &call_ellipse,
        .call_lineTo = &call_lineTo,
        .call_moveTo = &call_moveTo,
        .call_quadraticCurveTo = &call_quadraticCurveTo,
        .call_rect = &call_rect,
        .call_roundRect = &call_roundRect,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("Path2D has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(Path2DImpl, "init") and @hasDecl(Path2DImpl, "initOwn")) @compileError("Path2DImpl defines both init and initOwn");
        if (comptime @hasDecl(Path2DImpl, "init")) return Path2DImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(Path2DImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try Path2DImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(Path2DImpl, "init")) return false;
        if (comptime @hasDecl(Path2DImpl, "construction_args")) {
            inline for (Path2DImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(Path2DImpl, "deinit") and @hasDecl(Path2DImpl, "deinitOwn")) @compileError("Path2DImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(Path2DImpl, "deinit")) return Path2DImpl.deinit(instance);
        if (comptime @hasDecl(Path2DImpl, "deinitOwn")) Path2DImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Path2D")) {
            if (comptime @hasDecl(impls.Path2D, "installHooks")) impls.Path2D.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, path: webidl.Opt(Path2DOrDOMString)) !*runtime.Instance {
        if (comptime @FieldType(std.meta.ArgsTuple(@TypeOf(Path2DImpl.call_constructor)), "0") == *runtime.Instance) {
            // WebIDL 3.7.1 step 1.8: internally create a new object implementing
            // the interface. Until it is returned, the construction is its only
            // owner: a failed step frees it whole.
            const instance = try init(ctx.allocator, ctx);
            errdefer runtime.gc.releaseFailedConstruction(instance);
            // Step 1.9: perform the constructor steps with object as this.
            try Path2DImpl.call_constructor(instance, path);
            return instance;
        } else {
            // A factory: the impl makes the object, and frees it whole when a
            // step fails (tools/lint_constructors.zig).
            return try Path2DImpl.call_constructor(ctx, path);
        }
    }

    pub const call_arc = mixins.CanvasPath.call_arc;

    pub const call_rect = mixins.CanvasPath.call_rect;

    pub fn call_addPath(instance: *runtime.Instance, path: *runtime.Instance, transform: webidl.Opt(DOMMatrix2DInit)) anyerror!void {
        return try Path2DImpl.call_addPath(instance, path, transform);
    }

    pub const call_closePath = mixins.CanvasPath.call_closePath;

    pub const call_moveTo = mixins.CanvasPath.call_moveTo;

    pub const call_bezierCurveTo = mixins.CanvasPath.call_bezierCurveTo;

    pub const call_roundRect = mixins.CanvasPath.call_roundRect;

    pub const call_quadraticCurveTo = mixins.CanvasPath.call_quadraticCurveTo;

    pub const call_ellipse = mixins.CanvasPath.call_ellipse;

    pub const call_lineTo = mixins.CanvasPath.call_lineTo;

    pub const call_arcTo = mixins.CanvasPath.call_arcTo;

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_addPath", 0, "Path2D" },
    };
};
