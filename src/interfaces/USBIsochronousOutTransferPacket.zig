//! Generated from: webusb.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBIsochronousOutTransferPacketImpl = @import("../impls/USBIsochronousOutTransferPacket.zig");

pub const USBIsochronousOutTransferPacket = struct {
    pub const Meta = struct {
        pub const name = "USBIsochronousOutTransferPacket";
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
            bytesWritten: u32 = undefined,
            status: USBTransferStatus = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBIsochronousOutTransferPacket, .{
        .deinit_fn = &deinit_wrapper,

        .get_bytesWritten = &get_bytesWritten,
        .get_status = &get_status,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        USBIsochronousOutTransferPacketImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        USBIsochronousOutTransferPacketImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, status: anyopaque, bytesWritten: u32) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try USBIsochronousOutTransferPacketImpl.constructor(state, status, bytesWritten);
        
        return instance;
    }

    pub fn get_bytesWritten(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return USBIsochronousOutTransferPacketImpl.get_bytesWritten(state);
    }

    pub fn get_status(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBIsochronousOutTransferPacketImpl.get_status(state);
    }

};
