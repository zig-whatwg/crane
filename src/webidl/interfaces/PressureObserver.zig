//! Generated from: compute-pressure.idl
//! Generated at: 2025-12-07T19:32:58Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const PressureObserverImpl = @import("impls").PressureObserver;
const mixins = @import("mixins");
const PressureSource = @import("enums").PressureSource;
const PressureRecord = @import("interfaces").PressureRecord;
const PressureObserverOptions = @import("dictionaries").PressureObserverOptions;
const PressureUpdateCallback = @import("callbacks").PressureUpdateCallback;

pub const PressureObserver = struct {
    pub const Meta = struct {
        pub const name = "PressureObserver";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "knownSources", "get_knownSources", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "observe", "call_observe", 1 },
            .{ "unobserve", "call_unobserve", 1 },
            .{ "disconnect", "call_disconnect", 0 },
            .{ "takeRecords", "call_takeRecords", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "observe",
            "unobserve",
            "disconnect",
            "takeRecords",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "knownSources", "get_knownSources", null },
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
            _internal: ?*PressureObserverImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_knownSources = &get_knownSources,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
        .call_unobserve = &call_unobserve,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PressureObserverImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PressureObserverImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, callback: PressureUpdateCallback) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PressureObserverImpl.call_constructor(allocator, ctx, callback);
    }

    /// Extended attributes: [SameObject]
    pub fn get_knownSources(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_knownSources) |cached| {
            return cached;
        }
        const value = try PressureObserverImpl.get_knownSources(instance);
        state.own.cached_knownSources = value;
        return value;
    }

    pub fn call_observe(instance: *runtime.Instance, source: PressureSource, options: webidl.Opt(PressureObserverOptions)) anyerror!*const anyopaque {
        
        return try PressureObserverImpl.call_observe(instance, source, options);
    }

    pub fn call_unobserve(instance: *runtime.Instance, source: PressureSource) anyerror!void {
        
        return try PressureObserverImpl.call_unobserve(instance, source);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try PressureObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PressureObserverImpl.call_takeRecords(instance);
    }

};
