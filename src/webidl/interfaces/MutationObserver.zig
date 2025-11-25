//! Generated from: dom.idl
//! Generated at: 2025-11-25T13:07:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MutationObserverImpl = @import("impls").MutationObserver;
const MutationCallback = @import("callbacks").MutationCallback;
const Node = @import("interfaces").Node;
const MutationRecord = @import("interfaces").MutationRecord;
const MutationObserverInit = @import("dictionaries").MutationObserverInit;

pub const MutationObserver = struct {
    pub const Meta = struct {
        pub const name = "MutationObserver";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "observe", "call_observe", 1 },
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
            _internal: ?*MutationObserverImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MutationObserverImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MutationObserverImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, callback: MutationCallback) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MutationObserverImpl.call_constructor(allocator, ctx, callback);
    }

    pub fn call_observe(instance: *runtime.Instance, target: *runtime.Instance, options: MutationObserverInit) anyerror!void {
        
        return try MutationObserverImpl.call_observe(instance, target, options);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try MutationObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MutationObserverImpl.call_takeRecords(instance);
    }

};
