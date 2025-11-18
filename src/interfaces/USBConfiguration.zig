//! Generated from: webusb.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBConfigurationImpl = @import("../impls/USBConfiguration.zig");

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
            interfaces: FrozenArray<USBInterface> = undefined,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        USBConfigurationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        USBConfigurationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, device: anyopaque, configurationValue: u8) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try USBConfigurationImpl.constructor(state, device, configurationValue);
        
        return instance;
    }

    pub fn get_configurationValue(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBConfigurationImpl.get_configurationValue(state);
    }

    pub fn get_configurationName(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBConfigurationImpl.get_configurationName(state);
    }

    pub fn get_interfaces(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBConfigurationImpl.get_interfaces(state);
    }

};
