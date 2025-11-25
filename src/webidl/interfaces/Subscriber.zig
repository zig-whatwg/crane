//! Generated from: observable.idl
//! Generated at: 2025-11-25T13:07:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SubscriberImpl = @import("impls").Subscriber;
const AbortSignal = @import("interfaces").AbortSignal;
const VoidFunction = @import("callbacks").VoidFunction;

pub const Subscriber = struct {
    pub const Meta = struct {
        pub const name = "Subscriber";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "active", "get_active", null },
            .{ "signal", "get_signal", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "next", "call_next", 1 },
            .{ "error", "call_error", 1 },
            .{ "complete", "call_complete", 0 },
            .{ "addTeardown", "call_addTeardown", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "next",
            "error",
            "complete",
            "addTeardown",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "active", "get_active", null },
            .{ "signal", "get_signal", null },
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
            active: bool = undefined,
            signal: *runtime.Instance = undefined,
            _internal: ?*SubscriberImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_active = &get_active,
        .get_signal = &get_signal,

        .call_addTeardown = &call_addTeardown,
        .call_complete = &call_complete,
        .call_error = &call_error,
        .call_next = &call_next,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SubscriberImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SubscriberImpl.deinit(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!bool {
        return try SubscriberImpl.get_active(instance);
    }

    pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SubscriberImpl.get_signal(instance);
    }

    pub fn call_error(instance: *runtime.Instance, @"error": *const anyopaque) anyerror!void {
        
        return try SubscriberImpl.call_error(instance, @"error");
    }

    pub fn call_complete(instance: *runtime.Instance) anyerror!void {
        return try SubscriberImpl.call_complete(instance);
    }

    pub fn call_addTeardown(instance: *runtime.Instance, teardown: VoidFunction) anyerror!void {
        
        return try SubscriberImpl.call_addTeardown(instance, teardown);
    }

    pub fn call_next(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        
        return try SubscriberImpl.call_next(instance, value);
    }

};
