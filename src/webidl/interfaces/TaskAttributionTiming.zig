//! Generated from: longtasks.idl
//! Generated at: 2025-11-28T18:57:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TaskAttributionTimingImpl = @import("impls").TaskAttributionTiming;
const mixins = @import("mixins");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const TaskAttributionTiming = struct {
    pub const Meta = struct {
        pub const name = "TaskAttributionTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "containerType", "get_containerType", null },
            .{ "containerSrc", "get_containerSrc", null },
            .{ "containerId", "get_containerId", null },
            .{ "containerName", "get_containerName", null },
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
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "containerType", "get_containerType", null },
            .{ "containerSrc", "get_containerSrc", null },
            .{ "containerId", "get_containerId", null },
            .{ "containerName", "get_containerName", null },
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
            startTime: DOMHighResTimeStamp = undefined,
            duration: DOMHighResTimeStamp = undefined,
            name: runtime.DOMString = undefined,
            entryType: runtime.DOMString = undefined,
            containerType: runtime.DOMString = undefined,
            containerSrc: runtime.DOMString = undefined,
            containerId: runtime.DOMString = undefined,
            containerName: runtime.DOMString = undefined,
            _internal: ?*TaskAttributionTimingImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_containerId = &get_containerId,
        .get_containerName = &get_containerName,
        .get_containerSrc = &get_containerSrc,
        .get_containerType = &get_containerType,
        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_name = &get_name,
        .get_startTime = &get_startTime,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TaskAttributionTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TaskAttributionTimingImpl.deinit(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try TaskAttributionTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try TaskAttributionTimingImpl.get_duration(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_entryType(instance);
    }

    pub fn get_containerType(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_containerType(instance);
    }

    pub fn get_containerSrc(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_containerSrc(instance);
    }

    pub fn get_containerId(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_containerId(instance);
    }

    pub fn get_containerName(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_containerName(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try TaskAttributionTimingImpl.call_toJSON(instance);
    }

};
