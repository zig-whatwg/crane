//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataTransferItemListImpl = @import("impls").DataTransferItemList;
const DataTransferItem = @import("interfaces").DataTransferItem;
const File = @import("interfaces").File;
const DOMString = @import("typedefs").DOMString;

pub const DataTransferItemList = struct {
    pub const Meta = struct {
        pub const name = "DataTransferItemList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DataTransferItemList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_add = &call_add,
        .call_clear = &call_clear,
        .call_remove = &call_remove,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return DataTransferItemListImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DataTransferItemListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try DataTransferItemListImpl.get_length(instance);
    }

    pub fn call_add(instance: *runtime.Instance, data: DOMString, @"type": DOMString) anyerror!DataTransferItem {
        
        return try DataTransferItemListImpl.call_add(instance, data, @"type");
    }

    pub fn call_remove(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try DataTransferItemListImpl.call_remove(instance, index);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try DataTransferItemListImpl.call_clear(instance);
    }

};
