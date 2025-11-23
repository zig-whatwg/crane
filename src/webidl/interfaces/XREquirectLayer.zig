//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-23T01:18:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XREquirectLayerImpl = @import("impls").XREquirectLayer;
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
            .{ "centralHorizontalAngle", "get_centralHorizontalAngle", "set_centralHorizontalAngle" },
            .{ "upperVerticalAngle", "get_upperVerticalAngle", "set_upperVerticalAngle" },
            .{ "lowerVerticalAngle", "get_lowerVerticalAngle", "set_lowerVerticalAngle" },
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
            .{ "centralHorizontalAngle", "get_centralHorizontalAngle", "set_centralHorizontalAngle" },
            .{ "upperVerticalAngle", "get_upperVerticalAngle", "set_upperVerticalAngle" },
            .{ "lowerVerticalAngle", "get_lowerVerticalAngle", "set_lowerVerticalAngle" },
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
            space: XRSpace = undefined,
            transform: XRRigidTransform = undefined,
            radius: f32 = undefined,
            centralHorizontalAngle: f32 = undefined,
            upperVerticalAngle: f32 = undefined,
            lowerVerticalAngle: f32 = undefined,
            onredraw: EventHandler = undefined,
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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XREquirectLayerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XREquirectLayerImpl.deinit(instance);
    }

    pub fn get_space(instance: *runtime.Instance) anyerror!XRSpace {
        return try XREquirectLayerImpl.get_space(instance);
    }

    pub fn set_space(instance: *runtime.Instance, value: XRSpace) anyerror!void {
        try XREquirectLayerImpl.set_space(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!XRRigidTransform {
        return try XREquirectLayerImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: XRRigidTransform) anyerror!void {
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

};
