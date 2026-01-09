//! Generated from: longtasks.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceLongTaskTimingImpl = @import("impls").PerformanceLongTaskTiming;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceEntry = @import("PerformanceEntry.zig").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const TaskAttributionTiming = @import("TaskAttributionTiming.zig").TaskAttributionTiming;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceLongTaskTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceLongTaskTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = PerformanceEntry.State;
        pub const ParentInterface = PerformanceEntry;
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
            .{ "attribution", "get_attribution", null },
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
            .{ "attribution", "get_attribution", null },
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
            startTime: typedefs.DOMHighResTimeStamp = undefined,
            duration: typedefs.DOMHighResTimeStamp = undefined,
            name: typedefs.DOMString = undefined,
            entryType: typedefs.DOMString = undefined,
            attribution: runtime.JSValue = undefined,
            _internal: ?*PerformanceLongTaskTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceLongTaskTiming
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceLongTaskTimingToJSON = struct {
        id: u64,
        name: runtime.DOMString,
        entryType: runtime.DOMString,
        startTime: DOMHighResTimeStamp,
        duration: DOMHighResTimeStamp,
        navigationId: u64,
        attribution: runtime.JSValue,
    };

    const delegates = .{

        .get_attribution = &get_attribution,
        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_name = &get_name,
        .get_startTime = &get_startTime,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceLongTaskTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PerformanceLongTaskTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceLongTaskTimingImpl.deinit(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongTaskTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongTaskTimingImpl.get_duration(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceLongTaskTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceLongTaskTimingImpl.get_entryType(instance);
    }

    pub fn get_attribution(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PerformanceLongTaskTimingImpl.get_attribution(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceLongTaskTimingToJSON {
        return try PerformanceLongTaskTimingImpl.call_toJSON(instance);
    }

};
