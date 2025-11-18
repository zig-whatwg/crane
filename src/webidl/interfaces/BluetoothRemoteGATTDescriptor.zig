//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTDescriptorImpl = @import("impls").BluetoothRemoteGATTDescriptor;
const DataView = @import("interfaces").DataView;
const BluetoothRemoteGATTCharacteristic = @import("interfaces").BluetoothRemoteGATTCharacteristic;
const Promise<DataView> = @import("interfaces").Promise<DataView>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const UUID = @import("typedefs").UUID;
const BufferSource = @import("typedefs").BufferSource;

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
        
        // Initialize the instance (Impl receives full instance)
        BluetoothRemoteGATTDescriptorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothRemoteGATTDescriptorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_characteristic(instance: *runtime.Instance) anyerror!BluetoothRemoteGATTCharacteristic {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_characteristic) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTDescriptorImpl.get_characteristic(instance);
        state.cached_characteristic = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyerror!UUID {
        return try BluetoothRemoteGATTDescriptorImpl.get_uuid(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothRemoteGATTDescriptorImpl.get_value(instance);
    }

    pub fn call_writeValue(instance: *runtime.Instance, value: BufferSource) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTDescriptorImpl.call_writeValue(instance, value);
    }

    pub fn call_readValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothRemoteGATTDescriptorImpl.call_readValue(instance);
    }

};
