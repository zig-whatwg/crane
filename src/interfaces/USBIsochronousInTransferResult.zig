//! Generated from: webusb.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBIsochronousInTransferResultImpl = @import("../impls/USBIsochronousInTransferResult.zig");

pub const USBIsochronousInTransferResult = struct {
    pub const Meta = struct {
        pub const name = "USBIsochronousInTransferResult";
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
            data: ?DataView = null,
            packets: FrozenArray<USBIsochronousInTransferPacket> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBIsochronousInTransferResult, .{
        .deinit_fn = &deinit_wrapper,

        .get_data = &get_data,
        .get_packets = &get_packets,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        USBIsochronousInTransferResultImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        USBIsochronousInTransferResultImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, packets: anyopaque, data: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try USBIsochronousInTransferResultImpl.constructor(state, packets, data);
        
        return instance;
    }

    pub fn get_data(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBIsochronousInTransferResultImpl.get_data(state);
    }

    pub fn get_packets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBIsochronousInTransferResultImpl.get_packets(state);
    }

};
