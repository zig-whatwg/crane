//! Generated from: webusb.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBEndpointImpl = @import("impls").USBEndpoint;
const USBEndpointType = @import("enums").USBEndpointType;
const USBDirection = @import("enums").USBDirection;
const USBAlternateInterface = @import("interfaces").USBAlternateInterface;

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
        
        // Initialize the instance (Impl receives full instance)
        USBEndpointImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBEndpointImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, alternate: USBAlternateInterface, endpointNumber: u8, direction: USBDirection) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try USBEndpointImpl.constructor(instance, alternate, endpointNumber, direction);
        
        return instance;
    }

    pub fn get_endpointNumber(instance: *runtime.Instance) anyerror!u8 {
        return try USBEndpointImpl.get_endpointNumber(instance);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!USBDirection {
        return try USBEndpointImpl.get_direction(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!USBEndpointType {
        return try USBEndpointImpl.get_type(instance);
    }

    pub fn get_packetSize(instance: *runtime.Instance) anyerror!u32 {
        return try USBEndpointImpl.get_packetSize(instance);
    }

};
