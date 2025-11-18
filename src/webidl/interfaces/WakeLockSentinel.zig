//! Generated from: screen-wake-lock.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WakeLockSentinelImpl = @import("impls").WakeLockSentinel;
const EventTarget = @import("interfaces").EventTarget;
const WakeLockType = @import("enums").WakeLockType;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const EventHandler = @import("typedefs").EventHandler;

pub const WakeLockSentinel = struct {
    pub const Meta = struct {
        pub const name = "WakeLockSentinel";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            released: bool = undefined,
            type: WakeLockType = undefined,
            onrelease: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WakeLockSentinel, .{
        .deinit_fn = &deinit_wrapper,

        .get_onrelease = &get_onrelease,
        .get_released = &get_released,
        .get_type = &get_type,

        .set_onrelease = &set_onrelease,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_release = &call_release,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WakeLockSentinelImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WakeLockSentinelImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_released(instance: *runtime.Instance) anyerror!bool {
        return try WakeLockSentinelImpl.get_released(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!WakeLockType {
        return try WakeLockSentinelImpl.get_type(instance);
    }

    pub fn get_onrelease(instance: *runtime.Instance) anyerror!EventHandler {
        return try WakeLockSentinelImpl.get_onrelease(instance);
    }

    pub fn set_onrelease(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WakeLockSentinelImpl.set_onrelease(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try WakeLockSentinelImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_release(instance: *runtime.Instance) anyerror!anyopaque {
        return try WakeLockSentinelImpl.call_release(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try WakeLockSentinelImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try WakeLockSentinelImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try WakeLockSentinelImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
