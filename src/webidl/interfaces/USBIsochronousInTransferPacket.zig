//! Generated from: webusb.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBIsochronousInTransferPacketImpl = @import("impls").USBIsochronousInTransferPacket;
const DataView = @import("interfaces").DataView;
const USBTransferStatus = @import("enums").USBTransferStatus;

pub const USBIsochronousInTransferPacket = struct {
    pub const Meta = struct {
        pub const name = "USBIsochronousInTransferPacket";
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
            status: USBTransferStatus = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBIsochronousInTransferPacket, .{
        .deinit_fn = &deinit_wrapper,

        .get_data = &get_data,
        .get_status = &get_status,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return USBIsochronousInTransferPacketImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBIsochronousInTransferPacketImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, status: USBTransferStatus, data: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try USBIsochronousInTransferPacketImpl.constructor(instance, status, data);
        
        return instance;
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBIsochronousInTransferPacketImpl.get_data(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!USBTransferStatus {
        return try USBIsochronousInTransferPacketImpl.get_status(instance);
    }

};
