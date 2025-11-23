//! Generated from: largest-contentful-paint.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LargestContentfulPaintImpl = @import("impls").LargestContentfulPaint;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("interfaces").PaintTimingMixin;
const Element = @import("interfaces").Element;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const LargestContentfulPaint = struct {
    pub const Meta = struct {
        pub const name = "LargestContentfulPaint";
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
            .{ "loadTime", "get_loadTime", null },
            .{ "renderTime", "get_renderTime", null },
            .{ "size", "get_size", null },
            .{ "id", "get_id", null },
            .{ "url", "get_url", null },
            .{ "element", "get_element", null },
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
            .{ "loadTime", "get_loadTime", null },
            .{ "renderTime", "get_renderTime", null },
            .{ "size", "get_size", null },
            .{ "id", "get_id", null },
            .{ "url", "get_url", null },
            .{ "element", "get_element", null },
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
            loadTime: DOMHighResTimeStamp = undefined,
            renderTime: DOMHighResTimeStamp = undefined,
            size: u32 = undefined,
            id: runtime.DOMString = undefined,
            url: runtime.DOMString = undefined,
            element: ?*runtime.Instance = null,
            paintTime: DOMHighResTimeStamp = undefined,
            presentationTime: ?DOMHighResTimeStamp = null,
            _internal: ?*LargestContentfulPaintImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_element = &get_element,
        .get_id = &get_id,
        .get_loadTime = &get_loadTime,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_renderTime = &get_renderTime,
        .get_size = &get_size,
        .get_url = &get_url,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LargestContentfulPaintImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LargestContentfulPaintImpl.deinit(instance);
    }

    pub fn get_loadTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_loadTime(instance);
    }

    pub fn get_renderTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_renderTime(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try LargestContentfulPaintImpl.get_size(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try LargestContentfulPaintImpl.get_id(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!DOMString {
        return try LargestContentfulPaintImpl.get_url(instance);
    }

    pub fn get_element(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try LargestContentfulPaintImpl.get_element(instance);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_presentationTime(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try LargestContentfulPaintImpl.call_toJSON(instance);
    }

};
