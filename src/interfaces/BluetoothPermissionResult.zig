//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothPermissionResultImpl = @import("../impls/BluetoothPermissionResult.zig");
const PermissionStatus = @import("PermissionStatus.zig");

pub const BluetoothPermissionResult = struct {
    pub const Meta = struct {
        pub const name = "BluetoothPermissionResult";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PermissionStatus;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            devices: FrozenArray<BluetoothDevice> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothPermissionResult, .{
        .deinit_fn = &deinit_wrapper,

        .get_devices = &get_devices,
        .get_name = &get_name,
        .get_onchange = &get_onchange,
        .get_state = &get_state,

        .set_devices = &set_devices,
        .set_onchange = &set_onchange,

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
        BluetoothPermissionResultImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothPermissionResultImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothPermissionResultImpl.get_state(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BluetoothPermissionResultImpl.get_name(state);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothPermissionResultImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothPermissionResultImpl.set_onchange(state, value);
    }

    pub fn get_devices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothPermissionResultImpl.get_devices(state);
    }

    pub fn set_devices(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothPermissionResultImpl.set_devices(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return BluetoothPermissionResultImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothPermissionResultImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothPermissionResultImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothPermissionResultImpl.call_removeEventListener(state, type_, callback, options);
    }

};
