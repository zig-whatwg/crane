//! Generated from: observable.idl
//! Generated at: 2025-11-18T18:28:11Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            active: bool = undefined,
            signal: AbortSignal = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Subscriber, .{
        .deinit_fn = &deinit_wrapper,

        .get_active = &get_active,
        .get_signal = &get_signal,

        .call_addTeardown = &call_addTeardown,
        .call_complete = &call_complete,
        .call_error = &call_error,
        .call_next = &call_next,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SubscriberImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SubscriberImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!bool {
        return try SubscriberImpl.get_active(instance);
    }

    pub fn get_signal(instance: *runtime.Instance) anyerror!AbortSignal {
        return try SubscriberImpl.get_signal(instance);
    }

    pub fn call_error(instance: *runtime.Instance, error_: anyopaque) anyerror!void {
        
        return try SubscriberImpl.call_error(instance, error_);
    }

    pub fn call_complete(instance: *runtime.Instance) anyerror!void {
        return try SubscriberImpl.call_complete(instance);
    }

    pub fn call_addTeardown(instance: *runtime.Instance, teardown: VoidFunction) anyerror!void {
        
        return try SubscriberImpl.call_addTeardown(instance, teardown);
    }

    pub fn call_next(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        
        return try SubscriberImpl.call_next(instance, value);
    }

};
