//! Generated from: webxrlayers.idl
//! Generated at: 2025-12-05T20:30:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRQuadLayerImpl = @import("impls").XRQuadLayer;
const mixins = @import("mixins");
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

pub const XRQuadLayer = struct {
    pub const Meta = struct {
        pub const name = "XRQuadLayer";
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
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
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
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
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
            width: f32 = undefined,
            height: f32 = undefined,
            onredraw: EventHandler = undefined,
            _internal: ?*XRQuadLayerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_height = &get_height,
        .get_onredraw = &get_onredraw,
        .get_space = &get_space,
        .get_transform = &get_transform,
        .get_width = &get_width,

        .set_height = &set_height,
        .set_onredraw = &set_onredraw,
        .set_space = &set_space,
        .set_transform = &set_transform,
        .set_width = &set_width,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRQuadLayerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRQuadLayerImpl.deinit(instance);
    }

    pub fn get_space(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRQuadLayerImpl.get_space(instance);
    }

    pub fn set_space(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XRQuadLayerImpl.set_space(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRQuadLayerImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XRQuadLayerImpl.set_transform(instance, value);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f32 {
        return try XRQuadLayerImpl.get_width(instance);
    }

    pub fn set_width(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRQuadLayerImpl.set_width(instance, value);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f32 {
        return try XRQuadLayerImpl.get_height(instance);
    }

    pub fn set_height(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRQuadLayerImpl.set_height(instance, value);
    }

    pub fn get_onredraw(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRQuadLayerImpl.get_onredraw(instance);
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRQuadLayerImpl.set_onredraw(instance, value);
    }
};
