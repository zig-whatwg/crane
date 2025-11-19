//! Generated from: web-bluetooth-scanning.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothDataFilterImpl = @import("impls").BluetoothDataFilter;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const BluetoothDataFilterInit = @import("dictionaries").BluetoothDataFilterInit;

pub const BluetoothDataFilter = struct {
    pub const Meta = struct {
        pub const name = "BluetoothDataFilter";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            dataPrefix: ArrayBuffer = undefined,
            mask: ArrayBuffer = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothDataFilter, .{
        .deinit_fn = &deinit_wrapper,

        .get_dataPrefix = &get_dataPrefix,
        .get_mask = &get_mask,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return BluetoothDataFilterImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothDataFilterImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init_data: BluetoothDataFilterInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try BluetoothDataFilterImpl.constructor(instance, init_data);
        
        return instance;
    }

    pub fn get_dataPrefix(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothDataFilterImpl.get_dataPrefix(instance);
    }

    pub fn get_mask(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothDataFilterImpl.get_mask(instance);
    }

};
