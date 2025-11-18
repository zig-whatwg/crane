//! Generated from: webusb.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBIsochronousOutTransferResultImpl = @import("impls").USBIsochronousOutTransferResult;
const FrozenArray<USBIsochronousOutTransferPacket> = @import("interfaces").FrozenArray<USBIsochronousOutTransferPacket>;

pub const USBIsochronousOutTransferResult = struct {
    pub const Meta = struct {
        pub const name = "USBIsochronousOutTransferResult";
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
            packets: FrozenArray<USBIsochronousOutTransferPacket> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBIsochronousOutTransferResult, .{
        .deinit_fn = &deinit_wrapper,

        .get_packets = &get_packets,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        USBIsochronousOutTransferResultImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBIsochronousOutTransferResultImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, packets: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try USBIsochronousOutTransferResultImpl.constructor(instance, packets);
        
        return instance;
    }

    pub fn get_packets(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBIsochronousOutTransferResultImpl.get_packets(instance);
    }

};
