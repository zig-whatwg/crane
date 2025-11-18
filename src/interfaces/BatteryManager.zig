//! Generated from: battery-status.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BatteryManagerImpl = @import("../impls/BatteryManager.zig");
const EventTarget = @import("EventTarget.zig");

pub const BatteryManager = struct {
    pub const Meta = struct {
        pub const name = "BatteryManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            charging: bool = undefined,
            chargingTime: f64 = undefined,
            dischargingTime: f64 = undefined,
            level: f64 = undefined,
            onchargingchange: EventHandler = undefined,
            onchargingtimechange: EventHandler = undefined,
            ondischargingtimechange: EventHandler = undefined,
            onlevelchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BatteryManager, .{
        .deinit_fn = &deinit_wrapper,

        .get_charging = &get_charging,
        .get_chargingTime = &get_chargingTime,
        .get_dischargingTime = &get_dischargingTime,
        .get_level = &get_level,
        .get_onchargingchange = &get_onchargingchange,
        .get_onchargingtimechange = &get_onchargingtimechange,
        .get_ondischargingtimechange = &get_ondischargingtimechange,
        .get_onlevelchange = &get_onlevelchange,

        .set_onchargingchange = &set_onchargingchange,
        .set_onchargingtimechange = &set_onchargingtimechange,
        .set_ondischargingtimechange = &set_ondischargingtimechange,
        .set_onlevelchange = &set_onlevelchange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
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
        
        // Initialize the state (Impl receives full hierarchy)
        BatteryManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BatteryManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_charging(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BatteryManagerImpl.get_charging(state);
    }

    pub fn get_chargingTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return BatteryManagerImpl.get_chargingTime(state);
    }

    pub fn get_dischargingTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return BatteryManagerImpl.get_dischargingTime(state);
    }

    pub fn get_level(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return BatteryManagerImpl.get_level(state);
    }

    pub fn get_onchargingchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BatteryManagerImpl.get_onchargingchange(state);
    }

    pub fn set_onchargingchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BatteryManagerImpl.set_onchargingchange(state, value);
    }

    pub fn get_onchargingtimechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BatteryManagerImpl.get_onchargingtimechange(state);
    }

    pub fn set_onchargingtimechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BatteryManagerImpl.set_onchargingtimechange(state, value);
    }

    pub fn get_ondischargingtimechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BatteryManagerImpl.get_ondischargingtimechange(state);
    }

    pub fn set_ondischargingtimechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BatteryManagerImpl.set_ondischargingtimechange(state, value);
    }

    pub fn get_onlevelchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BatteryManagerImpl.get_onlevelchange(state);
    }

    pub fn set_onlevelchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BatteryManagerImpl.set_onlevelchange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return BatteryManagerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BatteryManagerImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BatteryManagerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BatteryManagerImpl.call_removeEventListener(state, type_, callback, options);
    }

};
