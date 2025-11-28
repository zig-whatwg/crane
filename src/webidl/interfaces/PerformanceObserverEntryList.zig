//! Generated from: performance-timeline.idl
//! Generated at: 2025-11-28T22:33:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceObserverEntryListImpl = @import("impls").PerformanceObserverEntryList;
const mixins = @import("mixins");
const PerformanceEntryList = @import("typedefs").PerformanceEntryList;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceObserverEntryList = struct {
    pub const Meta = struct {
        pub const name = "PerformanceObserverEntryList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getEntries", "call_getEntries", 0 },
            .{ "getEntriesByType", "call_getEntriesByType", 1 },
            .{ "getEntriesByName", "call_getEntriesByName", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getEntries",
            "getEntriesByType",
            "getEntriesByName",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*PerformanceObserverEntryListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getEntries = &call_getEntries,
        .call_getEntriesByName = &call_getEntriesByName,
        .call_getEntriesByType = &call_getEntriesByType,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceObserverEntryListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceObserverEntryListImpl.deinit(instance);
    }

    pub fn call_getEntries(instance: *runtime.Instance) anyerror!PerformanceEntryList {
        return try PerformanceObserverEntryListImpl.call_getEntries(instance);
    }

    pub fn call_getEntriesByType(instance: *runtime.Instance, @"type": DOMString) anyerror!PerformanceEntryList {
        
        return try PerformanceObserverEntryListImpl.call_getEntriesByType(instance, @"type");
    }

    pub fn call_getEntriesByName(instance: *runtime.Instance, name: DOMString, @"type": webidl.Opt(DOMString)) anyerror!PerformanceEntryList {
        
        return try PerformanceObserverEntryListImpl.call_getEntriesByName(instance, name, @"type");
    }

};
