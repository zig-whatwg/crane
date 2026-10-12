//! Generated from: webxrlayers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRProjectionLayerImpl = @import("impls").XRProjectionLayer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const EventListener = @import("interfaces").EventListener;
const XRLayerLayout = @import("enums").XRLayerLayout;
const XRLayerQuality = @import("enums").XRLayerQuality;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const XRProjectionLayer = struct {
    pub const Meta = struct {
        pub const name = "XRProjectionLayer";
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
            .{ "textureWidth", "get_textureWidth", null },
            .{ "textureHeight", "get_textureHeight", null },
            .{ "textureArrayLength", "get_textureArrayLength", null },
            .{ "ignoreDepthValues", "get_ignoreDepthValues", null },
            .{ "fixedFoveation", "get_fixedFoveation", "set_fixedFoveation" },
            .{ "deltaPose", "get_deltaPose", "set_deltaPose" },
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
            .{ "textureWidth", "get_textureWidth", null },
            .{ "textureHeight", "get_textureHeight", null },
            .{ "textureArrayLength", "get_textureArrayLength", null },
            .{ "ignoreDepthValues", "get_ignoreDepthValues", null },
            .{ "fixedFoveation", "get_fixedFoveation", "set_fixedFoveation" },
            .{ "deltaPose", "get_deltaPose", "set_deltaPose" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            textureWidth: u32 = undefined,
            textureHeight: u32 = undefined,
            textureArrayLength: u32 = undefined,
            ignoreDepthValues: bool = undefined,
            fixedFoveation: ?f32 = null,
            deltaPose: ?*runtime.Instance = null,
            _internal: ?*XRProjectionLayerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_deltaPose = &get_deltaPose,
        .get_fixedFoveation = &get_fixedFoveation,
        .get_ignoreDepthValues = &get_ignoreDepthValues,
        .get_textureArrayLength = &get_textureArrayLength,
        .get_textureHeight = &get_textureHeight,
        .get_textureWidth = &get_textureWidth,

        .set_deltaPose = &set_deltaPose,
        .set_fixedFoveation = &set_fixedFoveation,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRProjectionLayer has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRProjectionLayerImpl, "init") and @hasDecl(XRProjectionLayerImpl, "initOwn")) @compileError("XRProjectionLayerImpl defines both init and initOwn");
        if (comptime @hasDecl(XRProjectionLayerImpl, "init")) return XRProjectionLayerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRProjectionLayerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRProjectionLayerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRProjectionLayerImpl, "init")) return false;
        if (comptime @hasDecl(XRProjectionLayerImpl, "construction_args")) {
            inline for (XRProjectionLayerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRProjectionLayerImpl, "deinit") and @hasDecl(XRProjectionLayerImpl, "deinitOwn")) @compileError("XRProjectionLayerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRProjectionLayerImpl, "deinit")) return XRProjectionLayerImpl.deinit(instance);
        if (comptime @hasDecl(XRProjectionLayerImpl, "deinitOwn")) XRProjectionLayerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRProjectionLayer")) {
            if (comptime @hasDecl(impls.XRProjectionLayer, "installHooks")) impls.XRProjectionLayer.installHooks();
        }
    }

    pub fn get_textureWidth(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureWidth(instance);
    }

    pub fn get_textureHeight(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureHeight(instance);
    }

    pub fn get_textureArrayLength(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureArrayLength(instance);
    }

    pub fn get_ignoreDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRProjectionLayerImpl.get_ignoreDepthValues(instance);
    }

    pub fn get_fixedFoveation(instance: *runtime.Instance) anyerror!?f32 {
        return try XRProjectionLayerImpl.get_fixedFoveation(instance);
    }

    pub fn set_fixedFoveation(instance: *runtime.Instance, value: ?f32) anyerror!void {
        try XRProjectionLayerImpl.set_fixedFoveation(instance, value);
    }

    pub fn get_deltaPose(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try XRProjectionLayerImpl.get_deltaPose(instance);
    }

    pub fn set_deltaPose(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try XRProjectionLayerImpl.set_deltaPose(instance, value);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_fixedFoveation", 0b1 },
    };
};
