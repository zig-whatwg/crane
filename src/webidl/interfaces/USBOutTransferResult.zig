//! Generated from: webusb.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBOutTransferResultImpl = @import("impls").USBOutTransferResult;
const USBTransferStatus = @import("enums").USBTransferStatus;

pub const USBOutTransferResult = struct {
    pub const Meta = struct {
        pub const name = "USBOutTransferResult";
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

    pub const vtable = runtime.buildVTable(USBOutTransferResult, .{
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
        
        // Initialize the instance (Impl receives full instance)
        USBOutTransferResultImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBOutTransferResultImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, status: USBTransferStatus, bytesWritten: u32) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try USBOutTransferResultImpl.constructor(instance, status, bytesWritten);
        
        return instance;
    }

    pub fn get_bytesWritten(instance: *runtime.Instance) anyerror!u32 {
        return try USBOutTransferResultImpl.get_bytesWritten(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!USBTransferStatus {
        return try USBOutTransferResultImpl.get_status(instance);
    }

};
