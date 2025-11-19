//! Generated from: webusb.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBConfigurationImpl = @import("impls").USBConfiguration;
const USBInterface = @import("interfaces").USBInterface;
const USBDevice = @import("interfaces").USBDevice;
const DOMString = @import("typedefs").DOMString;

pub const USBConfiguration = struct {
    pub const Meta = struct {
        pub const name = "USBConfiguration";
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
            configurationValue: u8 = undefined,
            configurationName: ?runtime.DOMString = null,
            interfaces: runtime.FrozenArray(USBInterface) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBConfiguration, .{
        .deinit_fn = &deinit_wrapper,

        .get_configurationName = &get_configurationName,
        .get_configurationValue = &get_configurationValue,
        .get_interfaces = &get_interfaces,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return USBConfigurationImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBConfigurationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, device: USBDevice, configurationValue: u8) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try USBConfigurationImpl.constructor(instance, device, configurationValue);
        
        return instance;
    }

    pub fn get_configurationValue(instance: *runtime.Instance) anyerror!u8 {
        return try USBConfigurationImpl.get_configurationValue(instance);
    }

    pub fn get_configurationName(instance: *runtime.Instance) anyerror!DOMString {
        return try USBConfigurationImpl.get_configurationName(instance);
    }

    pub fn get_interfaces(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBConfigurationImpl.get_interfaces(instance);
    }

};
