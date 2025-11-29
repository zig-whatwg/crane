//! Generated from: webvtt.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VTTRegionImpl = @import("impls").VTTRegion;
const mixins = @import("mixins");
const ScrollSetting = @import("enums").ScrollSetting;
const DOMString = @import("typedefs").DOMString;

pub const VTTRegion = struct {
    pub const Meta = struct {
        pub const name = "VTTRegion";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", "set_id" },
            .{ "width", "get_width", "set_width" },
            .{ "lines", "get_lines", "set_lines" },
            .{ "regionAnchorX", "get_regionAnchorX", "set_regionAnchorX" },
            .{ "regionAnchorY", "get_regionAnchorY", "set_regionAnchorY" },
            .{ "viewportAnchorX", "get_viewportAnchorX", "set_viewportAnchorX" },
            .{ "viewportAnchorY", "get_viewportAnchorY", "set_viewportAnchorY" },
            .{ "scroll", "get_scroll", "set_scroll" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", "set_id" },
            .{ "width", "get_width", "set_width" },
            .{ "lines", "get_lines", "set_lines" },
            .{ "regionAnchorX", "get_regionAnchorX", "set_regionAnchorX" },
            .{ "regionAnchorY", "get_regionAnchorY", "set_regionAnchorY" },
            .{ "viewportAnchorX", "get_viewportAnchorX", "set_viewportAnchorX" },
            .{ "viewportAnchorY", "get_viewportAnchorY", "set_viewportAnchorY" },
            .{ "scroll", "get_scroll", "set_scroll" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            width: f64 = undefined,
            lines: u32 = undefined,
            regionAnchorX: f64 = undefined,
            regionAnchorY: f64 = undefined,
            viewportAnchorX: f64 = undefined,
            viewportAnchorY: f64 = undefined,
            scroll: ScrollSetting = undefined,
            _internal: ?*VTTRegionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_id = &get_id,
        .get_lines = &get_lines,
        .get_regionAnchorX = &get_regionAnchorX,
        .get_regionAnchorY = &get_regionAnchorY,
        .get_scroll = &get_scroll,
        .get_viewportAnchorX = &get_viewportAnchorX,
        .get_viewportAnchorY = &get_viewportAnchorY,
        .get_width = &get_width,

        .set_id = &set_id,
        .set_lines = &set_lines,
        .set_regionAnchorX = &set_regionAnchorX,
        .set_regionAnchorY = &set_regionAnchorY,
        .set_scroll = &set_scroll,
        .set_viewportAnchorX = &set_viewportAnchorX,
        .set_viewportAnchorY = &set_viewportAnchorY,
        .set_width = &set_width,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VTTRegionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VTTRegionImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try VTTRegionImpl.call_constructor(allocator, ctx);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try VTTRegionImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try VTTRegionImpl.set_id(instance, value);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try VTTRegionImpl.get_width(instance);
    }

    pub fn set_width(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTRegionImpl.set_width(instance, value);
    }

    pub fn get_lines(instance: *runtime.Instance) anyerror!u32 {
        return try VTTRegionImpl.get_lines(instance);
    }

    pub fn set_lines(instance: *runtime.Instance, value: u32) anyerror!void {
        try VTTRegionImpl.set_lines(instance, value);
    }

    pub fn get_regionAnchorX(instance: *runtime.Instance) anyerror!f64 {
        return try VTTRegionImpl.get_regionAnchorX(instance);
    }

    pub fn set_regionAnchorX(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTRegionImpl.set_regionAnchorX(instance, value);
    }

    pub fn get_regionAnchorY(instance: *runtime.Instance) anyerror!f64 {
        return try VTTRegionImpl.get_regionAnchorY(instance);
    }

    pub fn set_regionAnchorY(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTRegionImpl.set_regionAnchorY(instance, value);
    }

    pub fn get_viewportAnchorX(instance: *runtime.Instance) anyerror!f64 {
        return try VTTRegionImpl.get_viewportAnchorX(instance);
    }

    pub fn set_viewportAnchorX(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTRegionImpl.set_viewportAnchorX(instance, value);
    }

    pub fn get_viewportAnchorY(instance: *runtime.Instance) anyerror!f64 {
        return try VTTRegionImpl.get_viewportAnchorY(instance);
    }

    pub fn set_viewportAnchorY(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTRegionImpl.set_viewportAnchorY(instance, value);
    }

    pub fn get_scroll(instance: *runtime.Instance) anyerror!ScrollSetting {
        return try VTTRegionImpl.get_scroll(instance);
    }

    pub fn set_scroll(instance: *runtime.Instance, value: ScrollSetting) anyerror!void {
        try VTTRegionImpl.set_scroll(instance, value);
    }

};
