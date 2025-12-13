//! Generated from: server-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceServerTimingImpl = @import("impls").PerformanceServerTiming;
const mixins = @import("mixins");
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceServerTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceServerTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "duration", "get_duration", null },
            .{ "description", "get_description", null },
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
            .{ "name", "get_name", null },
            .{ "duration", "get_duration", null },
            .{ "description", "get_description", null },
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
            name: runtime.DOMString = undefined,
            duration: DOMHighResTimeStamp = undefined,
            description: runtime.DOMString = undefined,
            _internal: ?*PerformanceServerTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceServerTiming
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceServerTimingToJSON = struct {
        name: runtime.DOMString,
        duration: DOMHighResTimeStamp,
        description: runtime.DOMString,
    };

    const delegates = .{

        .get_description = &get_description,
        .get_duration = &get_duration,
        .get_name = &get_name,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceServerTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PerformanceServerTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceServerTimingImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceServerTimingImpl.get_name(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceServerTimingImpl.get_duration(instance);
    }

    pub fn get_description(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceServerTimingImpl.get_description(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PerformanceServerTimingImpl.call_toJSON(instance);
    }

};
