//! Generated from: webxr-plane-detection.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRPlaneImpl = @import("impls").XRPlane;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const XRPlaneOrientation = @import("enums").XRPlaneOrientation;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;
const DOMString = @import("typedefs").DOMString;
const XRSpace = @import("interfaces").XRSpace;

pub const XRPlane = struct {
    pub const Meta = struct {
        pub const name = "XRPlane";
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
            .{ "planeSpace", "get_planeSpace", null },
            .{ "polygon", "get_polygon", null },
            .{ "orientation", "get_orientation", null },
            .{ "lastChangedTime", "get_lastChangedTime", null },
            .{ "semanticLabel", "get_semanticLabel", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "planeSpace", "get_planeSpace", null },
            .{ "polygon", "get_polygon", null },
            .{ "orientation", "get_orientation", null },
            .{ "lastChangedTime", "get_lastChangedTime", null },
            .{ "semanticLabel", "get_semanticLabel", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            planeSpace: *runtime.Instance = undefined,
            polygon: runtime.JSValue = undefined,
            orientation: ?enums.XRPlaneOrientation = null,
            lastChangedTime: typedefs.DOMHighResTimeStamp = undefined,
            semanticLabel: ?typedefs.DOMString = null,
            cached_planeSpace: ?*runtime.Instance = null,
            _internal: ?*XRPlaneImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_lastChangedTime = &get_lastChangedTime,
        .get_orientation = &get_orientation,
        .get_planeSpace = &get_planeSpace,
        .get_polygon = &get_polygon,
        .get_semanticLabel = &get_semanticLabel,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRPlane has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRPlaneImpl, "init") and @hasDecl(XRPlaneImpl, "initOwn")) @compileError("XRPlaneImpl defines both init and initOwn");
        if (comptime @hasDecl(XRPlaneImpl, "init")) return XRPlaneImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRPlaneImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRPlaneImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRPlaneImpl, "init")) return false;
        if (comptime @hasDecl(XRPlaneImpl, "construction_args")) {
            inline for (XRPlaneImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRPlaneImpl, "deinit") and @hasDecl(XRPlaneImpl, "deinitOwn")) @compileError("XRPlaneImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(XRPlaneImpl, "deinit")) return XRPlaneImpl.deinit(instance);
        if (comptime @hasDecl(XRPlaneImpl, "deinitOwn")) XRPlaneImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRPlane")) {
            if (comptime @hasDecl(impls.XRPlane, "installHooks")) impls.XRPlane.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_planeSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_planeSpace) |cached| {
            return cached;
        }
        const value = try XRPlaneImpl.get_planeSpace(instance);
        state.own.cached_planeSpace = value;
        @import("dom").same_object_cache.made(instance, value, "planeSpace");
        return value;
    }

    pub fn get_polygon(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XRPlaneImpl.get_polygon(instance);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyerror!?XRPlaneOrientation {
        return try XRPlaneImpl.get_orientation(instance);
    }

    pub fn get_lastChangedTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try XRPlaneImpl.get_lastChangedTime(instance);
    }

    pub fn get_semanticLabel(instance: *runtime.Instance) anyerror!?DOMString {
        return try XRPlaneImpl.get_semanticLabel(instance);
    }
};
