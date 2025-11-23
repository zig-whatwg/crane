//! Generated from: event-timing.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceEventTimingImpl = @import("impls").PerformanceEventTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceEventTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceEventTiming";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "processingStart", "get_processingStart", null },
            .{ "processingEnd", "get_processingEnd", null },
            .{ "cancelable", "get_cancelable", null },
            .{ "target", "get_target", null },
            .{ "targetSelector", "get_targetSelector", null },
            .{ "interactionId", "get_interactionId", null },
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
            .{ "processingStart", "get_processingStart", null },
            .{ "processingEnd", "get_processingEnd", null },
            .{ "cancelable", "get_cancelable", null },
            .{ "target", "get_target", null },
            .{ "targetSelector", "get_targetSelector", null },
            .{ "interactionId", "get_interactionId", null },
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
            processingStart: DOMHighResTimeStamp = undefined,
            processingEnd: DOMHighResTimeStamp = undefined,
            cancelable: bool = undefined,
            target: ?Node = null,
            targetSelector: runtime.DOMString = undefined,
            interactionId: u64 = undefined,
            _internal: ?*PerformanceEventTimingImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_cancelable = &get_cancelable,
        .get_interactionId = &get_interactionId,
        .get_processingEnd = &get_processingEnd,
        .get_processingStart = &get_processingStart,
        .get_target = &get_target,
        .get_targetSelector = &get_targetSelector,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceEventTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceEventTimingImpl.deinit(instance);
    }

    pub fn get_processingStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceEventTimingImpl.get_processingStart(instance);
    }

    pub fn get_processingEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceEventTimingImpl.get_processingEnd(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try PerformanceEventTimingImpl.get_cancelable(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!Node {
        return try PerformanceEventTimingImpl.get_target(instance);
    }

    pub fn get_targetSelector(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceEventTimingImpl.get_targetSelector(instance);
    }

    pub fn get_interactionId(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceEventTimingImpl.get_interactionId(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceEventTimingImpl.call_toJSON(instance);
    }

};
