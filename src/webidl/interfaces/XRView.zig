//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRViewImpl = @import("impls").XRView;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRViewGeometry = @import("mixins").XRViewGeometry;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XREye = @import("enums").XREye;
const XRCamera = @import("interfaces").XRCamera;

pub const XRView = struct {
    pub const Meta = struct {
        pub const name = "XRView";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            XRViewGeometry,
        };
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "eye", "get_eye", null },
            .{ "index", "get_index", null },
            .{ "recommendedViewportScale", "get_recommendedViewportScale", null },
            .{ "camera", "get_camera", null },
            .{ "isFirstPersonObserver", "get_isFirstPersonObserver", null },
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestViewportScale", "call_requestViewportScale", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestViewportScale",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "eye", "get_eye", null },
            .{ "index", "get_index", null },
            .{ "recommendedViewportScale", "get_recommendedViewportScale", null },
            .{ "camera", "get_camera", null },
            .{ "isFirstPersonObserver", "get_isFirstPersonObserver", null },
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            eye: enums.XREye = undefined,
            index: u32 = undefined,
            recommendedViewportScale: ?f64 = null,
            camera: ?*runtime.Instance = null,
            isFirstPersonObserver: bool = undefined,
            projectionMatrix: runtime.Float32Array = undefined,
            transform: *runtime.Instance = undefined,
            cached_camera: ?*runtime.Instance = null,
            cached_transform: ?*runtime.Instance = null,
            _internal: ?*XRViewImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_camera = &get_camera,
        .get_eye = &get_eye,
        .get_index = &get_index,
        .get_isFirstPersonObserver = &get_isFirstPersonObserver,
        .get_projectionMatrix = &get_projectionMatrix,
        .get_recommendedViewportScale = &get_recommendedViewportScale,
        .get_transform = &get_transform,

        .call_requestViewportScale = &call_requestViewportScale,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRView has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRViewImpl, "init") and @hasDecl(XRViewImpl, "initOwn")) @compileError("XRViewImpl defines both init and initOwn");
        if (comptime @hasDecl(XRViewImpl, "init")) return XRViewImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRViewImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRViewImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRViewImpl, "init")) return false;
        if (comptime @hasDecl(XRViewImpl, "construction_args")) {
            inline for (XRViewImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRViewImpl, "deinit") and @hasDecl(XRViewImpl, "deinitOwn")) @compileError("XRViewImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRViewImpl, "deinit")) return XRViewImpl.deinit(instance);
        if (comptime @hasDecl(XRViewImpl, "deinitOwn")) XRViewImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRView")) {
            if (comptime @hasDecl(impls.XRView, "installHooks")) impls.XRView.installHooks();
        }
    }

    pub fn get_eye(instance: *runtime.Instance) anyerror!XREye {
        return try XRViewImpl.get_eye(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!u32 {
        return try XRViewImpl.get_index(instance);
    }

    pub fn get_recommendedViewportScale(instance: *runtime.Instance) anyerror!?f64 {
        return try XRViewImpl.get_recommendedViewportScale(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_camera(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_camera) |cached| {
            return cached;
        }
        const value = try XRViewImpl.get_camera(instance);
        state.own.cached_camera = value;
        return value;
    }

    pub fn get_isFirstPersonObserver(instance: *runtime.Instance) anyerror!bool {
        return try XRViewImpl.get_isFirstPersonObserver(instance);
    }

    pub const get_projectionMatrix = mixins.XRViewGeometry.get_projectionMatrix;

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_transform) |cached| {
            return cached;
        }
        const value = try mixins.XRViewGeometry.get_transform(instance);
        state.own.cached_transform = value;
        return value;
    }

    pub fn call_requestViewportScale(instance: *runtime.Instance, scale: ?f64) anyerror!void {
        return try XRViewImpl.call_requestViewportScale(instance, scale);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_requestViewportScale", 0b1 },
    };
};
