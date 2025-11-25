//! Generated from: intersection-observer.idl
//! Generated at: 2025-11-25T14:21:39Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IntersectionObserverEntryImpl = @import("impls").IntersectionObserverEntry;
const Element = @import("interfaces").Element;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const IntersectionObserverEntryInit = @import("dictionaries").IntersectionObserverEntryInit;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;

pub const IntersectionObserverEntry = struct {
    pub const Meta = struct {
        pub const name = "IntersectionObserverEntry";
        pub const is_mixin = false;
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
            .{ "time", "get_time", null },
            .{ "rootBounds", "get_rootBounds", null },
            .{ "boundingClientRect", "get_boundingClientRect", null },
            .{ "intersectionRect", "get_intersectionRect", null },
            .{ "isIntersecting", "get_isIntersecting", null },
            .{ "isVisible", "get_isVisible", null },
            .{ "intersectionRatio", "get_intersectionRatio", null },
            .{ "target", "get_target", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "time", "get_time", null },
            .{ "rootBounds", "get_rootBounds", null },
            .{ "boundingClientRect", "get_boundingClientRect", null },
            .{ "intersectionRect", "get_intersectionRect", null },
            .{ "isIntersecting", "get_isIntersecting", null },
            .{ "isVisible", "get_isVisible", null },
            .{ "intersectionRatio", "get_intersectionRatio", null },
            .{ "target", "get_target", null },
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
            time: DOMHighResTimeStamp = undefined,
            rootBounds: ?*runtime.Instance = null,
            boundingClientRect: *runtime.Instance = undefined,
            intersectionRect: *runtime.Instance = undefined,
            isIntersecting: bool = undefined,
            isVisible: bool = undefined,
            intersectionRatio: f64 = undefined,
            target: *runtime.Instance = undefined,
            _internal: ?*IntersectionObserverEntryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_boundingClientRect = &get_boundingClientRect,
        .get_intersectionRatio = &get_intersectionRatio,
        .get_intersectionRect = &get_intersectionRect,
        .get_isIntersecting = &get_isIntersecting,
        .get_isVisible = &get_isVisible,
        .get_rootBounds = &get_rootBounds,
        .get_target = &get_target,
        .get_time = &get_time,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IntersectionObserverEntryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IntersectionObserverEntryImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, intersectionObserverEntryInit: IntersectionObserverEntryInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try IntersectionObserverEntryImpl.call_constructor(allocator, ctx, intersectionObserverEntryInit);
    }

    pub fn get_time(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try IntersectionObserverEntryImpl.get_time(instance);
    }

    pub fn get_rootBounds(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try IntersectionObserverEntryImpl.get_rootBounds(instance);
    }

    pub fn get_boundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IntersectionObserverEntryImpl.get_boundingClientRect(instance);
    }

    pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IntersectionObserverEntryImpl.get_intersectionRect(instance);
    }

    pub fn get_isIntersecting(instance: *runtime.Instance) anyerror!bool {
        return try IntersectionObserverEntryImpl.get_isIntersecting(instance);
    }

    pub fn get_isVisible(instance: *runtime.Instance) anyerror!bool {
        return try IntersectionObserverEntryImpl.get_isVisible(instance);
    }

    pub fn get_intersectionRatio(instance: *runtime.Instance) anyerror!f64 {
        return try IntersectionObserverEntryImpl.get_intersectionRatio(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IntersectionObserverEntryImpl.get_target(instance);
    }

};
