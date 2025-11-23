//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRCylinderLayerImpl = @import("impls").XRCylinderLayer;
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

pub const XRCylinderLayer = struct {
    pub const Meta = struct {
        pub const name = "XRCylinderLayer";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRCompositionLayer;
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
            .{ "centralAngle", "get_centralAngle", "set_centralAngle" },
            .{ "aspectRatio", "get_aspectRatio", "set_aspectRatio" },
            .{ "onredraw", "get_onredraw", "set_onredraw" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
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
            .{ "centralAngle", "get_centralAngle", "set_centralAngle" },
            .{ "aspectRatio", "get_aspectRatio", "set_aspectRatio" },
            .{ "onredraw", "get_onredraw", "set_onredraw" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            space: *runtime.Instance = undefined,
            transform: *runtime.Instance = undefined,
            radius: f32 = undefined,
            centralAngle: f32 = undefined,
            aspectRatio: f32 = undefined,
            onredraw: EventHandler = undefined,
            _internal: ?*XRCylinderLayerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_aspectRatio = &get_aspectRatio,
        .get_centralAngle = &get_centralAngle,
        .get_onredraw = &get_onredraw,
        .get_radius = &get_radius,
        .get_space = &get_space,
        .get_transform = &get_transform,

        .set_aspectRatio = &set_aspectRatio,
        .set_centralAngle = &set_centralAngle,
        .set_onredraw = &set_onredraw,
        .set_radius = &set_radius,
        .set_space = &set_space,
        .set_transform = &set_transform,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRCylinderLayerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRCylinderLayerImpl.deinit(instance);
    }

    pub fn get_space(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRCylinderLayerImpl.get_space(instance);
    }

    pub fn set_space(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XRCylinderLayerImpl.set_space(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRCylinderLayerImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try XRCylinderLayerImpl.set_transform(instance, value);
    }

    pub fn get_radius(instance: *runtime.Instance) anyerror!f32 {
        return try XRCylinderLayerImpl.get_radius(instance);
    }

    pub fn set_radius(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCylinderLayerImpl.set_radius(instance, value);
    }

    pub fn get_centralAngle(instance: *runtime.Instance) anyerror!f32 {
        return try XRCylinderLayerImpl.get_centralAngle(instance);
    }

    pub fn set_centralAngle(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCylinderLayerImpl.set_centralAngle(instance, value);
    }

    pub fn get_aspectRatio(instance: *runtime.Instance) anyerror!f32 {
        return try XRCylinderLayerImpl.get_aspectRatio(instance);
    }

    pub fn set_aspectRatio(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCylinderLayerImpl.set_aspectRatio(instance, value);
    }

    pub fn get_onredraw(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRCylinderLayerImpl.get_onredraw(instance);
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRCylinderLayerImpl.set_onredraw(instance, value);
    }

};
