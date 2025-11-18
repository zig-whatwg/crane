//! Generated from: webusb.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBEndpointImpl = @import("../impls/USBEndpoint.zig");

pub const USBEndpoint = struct {
    pub const Meta = struct {
        pub const name = "USBEndpoint";
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
            endpointNumber: u8 = undefined,
            direction: USBDirection = undefined,
            type: USBEndpointType = undefined,
            packetSize: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBEndpoint, .{
        .deinit_fn = &deinit_wrapper,

        .get_direction = &get_direction,
        .get_endpointNumber = &get_endpointNumber,
        .get_packetSize = &get_packetSize,
        .get_type = &get_type,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        USBEndpointImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        USBEndpointImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, alternate: anyopaque, endpointNumber: u8, direction: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try USBEndpointImpl.constructor(state, alternate, endpointNumber, direction);
        
        return instance;
    }

    pub fn get_endpointNumber(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBEndpointImpl.get_endpointNumber(state);
    }

    pub fn get_direction(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBEndpointImpl.get_direction(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBEndpointImpl.get_type(state);
    }

    pub fn get_packetSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return USBEndpointImpl.get_packetSize(state);
    }

};
