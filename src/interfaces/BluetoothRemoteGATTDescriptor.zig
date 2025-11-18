//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTDescriptorImpl = @import("../impls/BluetoothRemoteGATTDescriptor.zig");

pub const BluetoothRemoteGATTDescriptor = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTDescriptor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            characteristic: BluetoothRemoteGATTCharacteristic = undefined,
            uuid: UUID = undefined,
            value: ?DataView = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothRemoteGATTDescriptor, .{
        .deinit_fn = &deinit_wrapper,

        .get_characteristic = &get_characteristic,
        .get_uuid = &get_uuid,
        .get_value = &get_value,

        .call_readValue = &call_readValue,
        .call_writeValue = &call_writeValue,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothRemoteGATTDescriptorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothRemoteGATTDescriptorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_characteristic(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_characteristic) |cached| {
            return cached;
        }
        const value = BluetoothRemoteGATTDescriptorImpl.get_characteristic(state);
        state.cached_characteristic = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTDescriptorImpl.get_uuid(state);
    }

    pub fn get_value(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTDescriptorImpl.get_value(state);
    }

    pub fn call_writeValue(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTDescriptorImpl.call_writeValue(state, value);
    }

    pub fn call_readValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTDescriptorImpl.call_readValue(state);
    }

};
