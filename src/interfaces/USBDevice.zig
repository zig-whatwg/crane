//! Generated from: webusb.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBDeviceImpl = @import("../impls/USBDevice.zig");

pub const USBDevice = struct {
    pub const Meta = struct {
        pub const name = "USBDevice";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Worker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Worker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            usbVersionMajor: u8 = undefined,
            usbVersionMinor: u8 = undefined,
            usbVersionSubminor: u8 = undefined,
            deviceClass: u8 = undefined,
            deviceSubclass: u8 = undefined,
            deviceProtocol: u8 = undefined,
            vendorId: u16 = undefined,
            productId: u16 = undefined,
            deviceVersionMajor: u8 = undefined,
            deviceVersionMinor: u8 = undefined,
            deviceVersionSubminor: u8 = undefined,
            manufacturerName: ?runtime.DOMString = null,
            productName: ?runtime.DOMString = null,
            serialNumber: ?runtime.DOMString = null,
            configuration: ?USBConfiguration = null,
            configurations: FrozenArray<USBConfiguration> = undefined,
            opened: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBDevice, .{
        .deinit_fn = &deinit_wrapper,

        .get_configuration = &get_configuration,
        .get_configurations = &get_configurations,
        .get_deviceClass = &get_deviceClass,
        .get_deviceProtocol = &get_deviceProtocol,
        .get_deviceSubclass = &get_deviceSubclass,
        .get_deviceVersionMajor = &get_deviceVersionMajor,
        .get_deviceVersionMinor = &get_deviceVersionMinor,
        .get_deviceVersionSubminor = &get_deviceVersionSubminor,
        .get_manufacturerName = &get_manufacturerName,
        .get_opened = &get_opened,
        .get_productId = &get_productId,
        .get_productName = &get_productName,
        .get_serialNumber = &get_serialNumber,
        .get_usbVersionMajor = &get_usbVersionMajor,
        .get_usbVersionMinor = &get_usbVersionMinor,
        .get_usbVersionSubminor = &get_usbVersionSubminor,
        .get_vendorId = &get_vendorId,

        .call_claimInterface = &call_claimInterface,
        .call_clearHalt = &call_clearHalt,
        .call_close = &call_close,
        .call_controlTransferIn = &call_controlTransferIn,
        .call_controlTransferOut = &call_controlTransferOut,
        .call_forget = &call_forget,
        .call_isochronousTransferIn = &call_isochronousTransferIn,
        .call_isochronousTransferOut = &call_isochronousTransferOut,
        .call_open = &call_open,
        .call_releaseInterface = &call_releaseInterface,
        .call_reset = &call_reset,
        .call_selectAlternateInterface = &call_selectAlternateInterface,
        .call_selectConfiguration = &call_selectConfiguration,
        .call_transferIn = &call_transferIn,
        .call_transferOut = &call_transferOut,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        USBDeviceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        USBDeviceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_usbVersionMajor(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_usbVersionMajor(state);
    }

    pub fn get_usbVersionMinor(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_usbVersionMinor(state);
    }

    pub fn get_usbVersionSubminor(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_usbVersionSubminor(state);
    }

    pub fn get_deviceClass(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_deviceClass(state);
    }

    pub fn get_deviceSubclass(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_deviceSubclass(state);
    }

    pub fn get_deviceProtocol(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_deviceProtocol(state);
    }

    pub fn get_vendorId(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_vendorId(state);
    }

    pub fn get_productId(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_productId(state);
    }

    pub fn get_deviceVersionMajor(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_deviceVersionMajor(state);
    }

    pub fn get_deviceVersionMinor(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_deviceVersionMinor(state);
    }

    pub fn get_deviceVersionSubminor(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBDeviceImpl.get_deviceVersionSubminor(state);
    }

    pub fn get_manufacturerName(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.get_manufacturerName(state);
    }

    pub fn get_productName(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.get_productName(state);
    }

    pub fn get_serialNumber(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.get_serialNumber(state);
    }

    pub fn get_configuration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.get_configuration(state);
    }

    pub fn get_configurations(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.get_configurations(state);
    }

    pub fn get_opened(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return USBDeviceImpl.get_opened(state);
    }

    pub fn call_releaseInterface(instance: *runtime.Instance, interfaceNumber: u8) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_releaseInterface(state, interfaceNumber);
    }

    pub fn call_open(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.call_open(state);
    }

    pub fn call_selectConfiguration(instance: *runtime.Instance, configurationValue: u8) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_selectConfiguration(state, configurationValue);
    }

    pub fn call_controlTransferOut(instance: *runtime.Instance, setup: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_controlTransferOut(state, setup, data);
    }

    pub fn call_controlTransferIn(instance: *runtime.Instance, setup: anyopaque, length: u16) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_controlTransferIn(state, setup, length);
    }

    pub fn call_forget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.call_forget(state);
    }

    pub fn call_reset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.call_reset(state);
    }

    pub fn call_transferOut(instance: *runtime.Instance, endpointNumber: u8, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_transferOut(state, endpointNumber, data);
    }

    pub fn call_isochronousTransferIn(instance: *runtime.Instance, endpointNumber: u8, packetLengths: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_isochronousTransferIn(state, endpointNumber, packetLengths);
    }

    pub fn call_clearHalt(instance: *runtime.Instance, direction: anyopaque, endpointNumber: u8) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_clearHalt(state, direction, endpointNumber);
    }

    pub fn call_claimInterface(instance: *runtime.Instance, interfaceNumber: u8) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_claimInterface(state, interfaceNumber);
    }

    pub fn call_selectAlternateInterface(instance: *runtime.Instance, interfaceNumber: u8, alternateSetting: u8) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_selectAlternateInterface(state, interfaceNumber, alternateSetting);
    }

    pub fn call_isochronousTransferOut(instance: *runtime.Instance, endpointNumber: u8, data: anyopaque, packetLengths: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_isochronousTransferOut(state, endpointNumber, data, packetLengths);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBDeviceImpl.call_close(state);
    }

    pub fn call_transferIn(instance: *runtime.Instance, endpointNumber: u8, length: u32) anyopaque {
        const state = instance.getState(State);
        
        return USBDeviceImpl.call_transferIn(state, endpointNumber, length);
    }

};
