//! Generated from: element-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceElementTimingImpl = @import("impls").PerformanceElementTiming;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("mixins").PaintTimingMixin;
const Element = @import("interfaces").Element;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceElementTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceElementTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = PerformanceEntry.State;
        pub const ParentInterface = PerformanceEntry;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            renderTime: typedefs.DOMHighResTimeStamp = undefined,
            loadTime: typedefs.DOMHighResTimeStamp = undefined,
            intersectionRect: *runtime.Instance = undefined,
            identifier: typedefs.DOMString = undefined,
            naturalWidth: u32 = undefined,
            naturalHeight: u32 = undefined,
            id: typedefs.DOMString = undefined,
            element: ?*runtime.Instance = null,
            url: runtime.USVString = undefined,
            paintTime: typedefs.DOMHighResTimeStamp = undefined,
            presentationTime: ?typedefs.DOMHighResTimeStamp = null,
            _internal: ?*PerformanceElementTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceElementTiming
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceElementTimingToJSON = struct {
        id: runtime.DOMString,
        name: runtime.DOMString,
        entryType: runtime.DOMString,
        startTime: DOMHighResTimeStamp,
        duration: DOMHighResTimeStamp,
        navigationId: u64,
        renderTime: DOMHighResTimeStamp,
        loadTime: DOMHighResTimeStamp,
        intersectionRect: *runtime.Instance,
        identifier: runtime.DOMString,
        naturalWidth: u32,
        naturalHeight: u32,
        element: *runtime.Instance,
        url: runtime.USVString,
        paintTime: DOMHighResTimeStamp,
        presentationTime: DOMHighResTimeStamp,
    };

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceElementTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PerformanceElementTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
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

    pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

    pub fn get_element(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PerformanceElementTimingImpl.get_element(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PerformanceElementTimingImpl.get_url(instance);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_presentationTime(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceElementTimingToJSON {
        return try PerformanceElementTimingImpl.call_toJSON(instance);
    }

};
