//! Generated from: webxrlayers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XREquirectLayerImpl = @import("impls").XREquirectLayer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XRLayerQuality = @import("enums").XRLayerQuality;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRSpace = @import("interfaces").XRSpace;
const EventListener = @import("interfaces").EventListener;
const XRLayerLayout = @import("enums").XRLayerLayout;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const XREquirectLayer = struct {
    pub const Meta = struct {
        pub const name = "XREquirectLayer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRCompositionLayer.State;
        pub const ParentInterface = XRCompositionLayer;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "space", "get_space", "set_space" },
            .{ "transform", "get_transform", "set_transform" },
            .{ "radius", "get_radius", "set_radius" },
            .{ "centralHorizontalAngle", "get_centralHorizontalAngle", "set_centralHorizontalAngle" },
            .{ "upperVerticalAngle", "get_upperVerticalAngle", "set_upperVerticalAngle" },
            .{ "lowerVerticalAngle", "get_lowerVerticalAngle", "set_lowerVerticalAngle" },
            .{ "onredraw", "get_onredraw", "set_onredraw" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "destroy",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "space", "get_space", "set_space" },
            .{ "transform", "get_transform", "set_transform" },
            .{ "radius", "get_radius", "set_radius" },
            .{ "centralHorizontalAngle", "get_centralHorizontalAngle", "set_centralHorizontalAngle" },
            .{ "upperVerticalAngle", "get_upperVerticalAngle", "set_upperVerticalAngle" },
            .{ "lowerVerticalAngle", "get_lowerVerticalAngle", "set_lowerVerticalAngle" },
            .{ "onredraw", "get_onredraw", "set_onredraw" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            space: *runtime.Instance = undefined,
            transform: *runtime.Instance = undefined,
            radius: f32 = undefined,
            centralHorizontalAngle: f32 = undefined,
            upperVerticalAngle: f32 = undefined,
            lowerVerticalAngle: f32 = undefined,
            onredraw: typedefs.EventHandler = undefined,
            _internal: ?*XREquirectLayerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_centralHorizontalAngle = &get_centralHorizontalAngle,
        .get_lowerVerticalAngle = &get_lowerVerticalAngle,
        .get_onredraw = &get_onredraw,
        .get_radius = &get_radius,
        .get_space = &get_space,
        .get_transform = &get_transform,
        .get_upperVerticalAngle = &get_upperVerticalAngle,

        .set_centralHorizontalAngle = &set_centralHorizontalAngle,
        .set_lowerVerticalAngle = &set_lowerVerticalAngle,
        .set_onredraw = &set_onredraw,
        .set_radius = &set_radius,
        .set_space = &set_space,
        .set_transform = &set_transform,
        .set_upperVerticalAngle = &set_upperVerticalAngle,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XREquirectLayer has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XREquirectLayerImpl, "init") and @hasDecl(XREquirectLayerImpl, "initOwn")) @compileError("XREquirectLayerImpl defines both init and initOwn");
        if (comptime @hasDecl(XREquirectLayerImpl, "init")) return XREquirectLayerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XREquirectLayerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XREquirectLayerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XREquirectLayerImpl, "init")) return false;
        if (comptime @hasDecl(XREquirectLayerImpl, "construction_args")) {
            inline for (XREquirectLayerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XREquirectLayerImpl, "deinit") and @hasDecl(XREquirectLayerImpl, "deinitOwn")) @compileError("XREquirectLayerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XREquirectLayerImpl, "deinit")) return XREquirectLayerImpl.deinit(instance);
        if (comptime @hasDecl(XREquirectLayerImpl, "deinitOwn")) XREquirectLayerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XREquirectLayer")) {
            if (comptime @hasDecl(impls.XREquirectLayer, "installHooks")) impls.XREquirectLayer.installHooks();
        }
    }

    pub fn get_space(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XREquirectLayerImpl.get_space(instance);
    }

    pub fn set_space(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XREquirectLayerImpl.set_space(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XREquirectLayerImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XREquirectLayerImpl.set_transform(instance, value);
    }

    pub fn get_radius(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_radius(instance);
    }

    pub fn set_radius(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_radius(instance, value);
    }

    pub fn get_centralHorizontalAngle(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_centralHorizontalAngle(instance);
    }

    pub fn set_centralHorizontalAngle(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_centralHorizontalAngle(instance, value);
    }

    pub fn get_upperVerticalAngle(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_upperVerticalAngle(instance);
    }

    pub fn set_upperVerticalAngle(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_upperVerticalAngle(instance, value);
    }

    pub fn get_lowerVerticalAngle(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_lowerVerticalAngle(instance);
    }

    pub fn set_lowerVerticalAngle(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_lowerVerticalAngle(instance, value);
    }

    pub fn get_onredraw(instance: *runtime.Instance) anyerror!EventHandler {
        return try XREquirectLayerImpl.get_onredraw(instance);
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XREquirectLayerImpl.set_onredraw(instance, value);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_radius", 0b1 },
        .{ "set_centralHorizontalAngle", 0b1 },
        .{ "set_upperVerticalAngle", 0b1 },
        .{ "set_lowerVerticalAngle", 0b1 },
    };
};
