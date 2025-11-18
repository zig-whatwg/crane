//! Generated from: webusb.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBDeviceImpl = @import("impls").USBDevice;
const USBDirection = @import("enums").USBDirection;
const Promise<USBIsochronousInTransferResult> = @import("interfaces").Promise<USBIsochronousInTransferResult>;
const Promise<USBOutTransferResult> = @import("interfaces").Promise<USBOutTransferResult>;
const BufferSource = @import("typedefs").BufferSource;
const Promise<USBIsochronousOutTransferResult> = @import("interfaces").Promise<USBIsochronousOutTransferResult>;
const USBControlTransferParameters = @import("dictionaries").USBControlTransferParameters;
const USBConfiguration = @import("interfaces").USBConfiguration;
const Promise<USBInTransferResult> = @import("interfaces").Promise<USBInTransferResult>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const DOMString = @import("typedefs").DOMString;
const FrozenArray<USBConfiguration> = @import("interfaces").FrozenArray<USBConfiguration>;

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
        
        // Initialize the instance (Impl receives full instance)
        USBDeviceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBDeviceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_usbVersionMajor(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_usbVersionMajor(instance);
    }

    pub fn get_usbVersionMinor(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_usbVersionMinor(instance);
    }

    pub fn get_usbVersionSubminor(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_usbVersionSubminor(instance);
    }

    pub fn get_deviceClass(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_deviceClass(instance);
    }

    pub fn get_deviceSubclass(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_deviceSubclass(instance);
    }

    pub fn get_deviceProtocol(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_deviceProtocol(instance);
    }

    pub fn get_vendorId(instance: *runtime.Instance) anyerror!u16 {
        return try USBDeviceImpl.get_vendorId(instance);
    }

    pub fn get_productId(instance: *runtime.Instance) anyerror!u16 {
        return try USBDeviceImpl.get_productId(instance);
    }

    pub fn get_deviceVersionMajor(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_deviceVersionMajor(instance);
    }

    pub fn get_deviceVersionMinor(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_deviceVersionMinor(instance);
    }

    pub fn get_deviceVersionSubminor(instance: *runtime.Instance) anyerror!u8 {
        return try USBDeviceImpl.get_deviceVersionSubminor(instance);
    }

    pub fn get_manufacturerName(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.get_manufacturerName(instance);
    }

    pub fn get_productName(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.get_productName(instance);
    }

    pub fn get_serialNumber(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.get_serialNumber(instance);
    }

    pub fn get_configuration(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.get_configuration(instance);
    }

    pub fn get_configurations(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.get_configurations(instance);
    }

    pub fn get_opened(instance: *runtime.Instance) anyerror!bool {
        return try USBDeviceImpl.get_opened(instance);
    }

    pub fn call_releaseInterface(instance: *runtime.Instance, interfaceNumber: u8) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_releaseInterface(instance, interfaceNumber);
    }

    pub fn call_open(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.call_open(instance);
    }

    pub fn call_selectConfiguration(instance: *runtime.Instance, configurationValue: u8) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_selectConfiguration(instance, configurationValue);
    }

    pub fn call_controlTransferOut(instance: *runtime.Instance, setup: USBControlTransferParameters, data: BufferSource) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_controlTransferOut(instance, setup, data);
    }

    pub fn call_controlTransferIn(instance: *runtime.Instance, setup: USBControlTransferParameters, length: u16) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_controlTransferIn(instance, setup, length);
    }

    pub fn call_forget(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.call_forget(instance);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.call_reset(instance);
    }

    pub fn call_transferOut(instance: *runtime.Instance, endpointNumber: u8, data: BufferSource) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_transferOut(instance, endpointNumber, data);
    }

    pub fn call_isochronousTransferIn(instance: *runtime.Instance, endpointNumber: u8, packetLengths: anyopaque) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_isochronousTransferIn(instance, endpointNumber, packetLengths);
    }

    pub fn call_clearHalt(instance: *runtime.Instance, direction: USBDirection, endpointNumber: u8) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_clearHalt(instance, direction, endpointNumber);
    }

    pub fn call_claimInterface(instance: *runtime.Instance, interfaceNumber: u8) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_claimInterface(instance, interfaceNumber);
    }

    pub fn call_selectAlternateInterface(instance: *runtime.Instance, interfaceNumber: u8, alternateSetting: u8) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_selectAlternateInterface(instance, interfaceNumber, alternateSetting);
    }

    pub fn call_isochronousTransferOut(instance: *runtime.Instance, endpointNumber: u8, data: BufferSource, packetLengths: anyopaque) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_isochronousTransferOut(instance, endpointNumber, data, packetLengths);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBDeviceImpl.call_close(instance);
    }

    pub fn call_transferIn(instance: *runtime.Instance, endpointNumber: u8, length: u32) anyerror!anyopaque {
        
        return try USBDeviceImpl.call_transferIn(instance, endpointNumber, length);
    }

};
