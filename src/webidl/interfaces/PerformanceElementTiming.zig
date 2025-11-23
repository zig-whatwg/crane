//! Generated from: element-timing.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceElementTimingImpl = @import("impls").PerformanceElementTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("interfaces").PaintTimingMixin;
const Element = @import("interfaces").Element;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceElementTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceElementTiming";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
        pub const MixinTypes = &.{
            PaintTimingMixin,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "renderTime", "get_renderTime", null },
            .{ "loadTime", "get_loadTime", null },
            .{ "intersectionRect", "get_intersectionRect", null },
            .{ "identifier", "get_identifier", null },
            .{ "naturalWidth", "get_naturalWidth", null },
            .{ "naturalHeight", "get_naturalHeight", null },
            .{ "id", "get_id", null },
            .{ "element", "get_element", null },
            .{ "url", "get_url", null },
            .{ "paintTime", "get_paintTime", null },
            .{ "presentationTime", "get_presentationTime", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "renderTime", "get_renderTime", null },
            .{ "loadTime", "get_loadTime", null },
            .{ "intersectionRect", "get_intersectionRect", null },
            .{ "identifier", "get_identifier", null },
            .{ "naturalWidth", "get_naturalWidth", null },
            .{ "naturalHeight", "get_naturalHeight", null },
            .{ "id", "get_id", null },
            .{ "element", "get_element", null },
            .{ "url", "get_url", null },
            .{ "paintTime", "get_paintTime", null },
            .{ "presentationTime", "get_presentationTime", null },
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
            renderTime: DOMHighResTimeStamp = undefined,
            loadTime: DOMHighResTimeStamp = undefined,
            intersectionRect: DOMRectReadOnly = undefined,
            identifier: runtime.DOMString = undefined,
            naturalWidth: u32 = undefined,
            naturalHeight: u32 = undefined,
            id: runtime.DOMString = undefined,
            element: ?Element = null,
            url: runtime.USVString = undefined,
            paintTime: DOMHighResTimeStamp = undefined,
            presentationTime: ?DOMHighResTimeStamp = null,
            _internal: ?*PerformanceElementTimingImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_element = &get_element,
        .get_id = &get_id,
        .get_identifier = &get_identifier,
        .get_intersectionRect = &get_intersectionRect,
        .get_loadTime = &get_loadTime,
        .get_naturalHeight = &get_naturalHeight,
        .get_naturalWidth = &get_naturalWidth,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_renderTime = &get_renderTime,
        .get_url = &get_url,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceElementTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceElementTimingImpl.deinit(instance);
    }

    pub fn get_renderTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_renderTime(instance);
    }

    pub fn get_loadTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_loadTime(instance);
    }

    pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!DOMRectReadOnly {
        return try PerformanceElementTimingImpl.get_intersectionRect(instance);
    }

    pub fn get_identifier(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceElementTimingImpl.get_identifier(instance);
    }

    pub fn get_naturalWidth(instance: *runtime.Instance) anyerror!u32 {
        return try PerformanceElementTimingImpl.get_naturalWidth(instance);
    }

    pub fn get_naturalHeight(instance: *runtime.Instance) anyerror!u32 {
        return try PerformanceElementTimingImpl.get_naturalHeight(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceElementTimingImpl.get_id(instance);
    }

    pub fn get_element(instance: *runtime.Instance) anyerror!Element {
        return try PerformanceElementTimingImpl.get_element(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PerformanceElementTimingImpl.get_url(instance);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_presentationTime(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceElementTimingImpl.call_toJSON(instance);
    }

};
