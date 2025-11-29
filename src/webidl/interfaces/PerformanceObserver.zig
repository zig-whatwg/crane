//! Generated from: performance-timeline.idl
//! Generated at: 2025-11-29T02:15:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceObserverImpl = @import("impls").PerformanceObserver;
const mixins = @import("mixins");
const PerformanceEntryList = @import("typedefs").PerformanceEntryList;
const PerformanceObserverInit = @import("dictionaries").PerformanceObserverInit;
const DOMString = @import("typedefs").DOMString;
const PerformanceObserverCallback = @import("callbacks").PerformanceObserverCallback;

pub const PerformanceObserver = struct {
    pub const Meta = struct {
        pub const name = "PerformanceObserver";
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
            .{ "supportedEntryTypes", "get_supportedEntryTypes", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "observe", "call_observe", 0 },
            .{ "disconnect", "call_disconnect", 0 },
            .{ "takeRecords", "call_takeRecords", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "observe",
            "disconnect",
            "takeRecords",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "supportedEntryTypes", "get_supportedEntryTypes", null },
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
            _internal: ?*PerformanceObserverImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_supportedEntryTypes = &get_supportedEntryTypes,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceObserverImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceObserverImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, callback: PerformanceObserverCallback) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PerformanceObserverImpl.call_constructor(allocator, ctx, callback);
    }

    /// Extended attributes: [SameObject]
    pub fn get_supportedEntryTypes(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_supportedEntryTypes) |cached| {
            return cached;
        }
        const value = try PerformanceObserverImpl.get_supportedEntryTypes(instance);
        state.own.cached_supportedEntryTypes = value;
        return value;
    }

    pub fn call_observe(instance: *runtime.Instance, options: webidl.Opt(PerformanceObserverInit)) anyerror!void {
        
        return try PerformanceObserverImpl.call_observe(instance, options);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try PerformanceObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!PerformanceEntryList {
        return try PerformanceObserverImpl.call_takeRecords(instance);
    }

};
