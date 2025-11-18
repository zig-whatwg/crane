//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataTransferItemListImpl = @import("impls").DataTransferItemList;
const DataTransferItem = @import("interfaces").DataTransferItem;
const File = @import("interfaces").File;

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DataTransferItemListImpl.init(instance);
        
        return instance;
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

    /// Arguments for add (WebIDL overloading)
    pub const AddArgs = union(enum) {
        /// add(data, type)
        string_string: struct {
            data: DOMString,
            type_: DOMString,
        },
        /// add(data)
        File: File,
    };

    pub fn call_add(instance: *runtime.Instance, args: AddArgs) anyerror!anyopaque {
        switch (args) {
            .string_string => |a| return try DataTransferItemListImpl.string_string(instance, a.data, a.type_),
            .File => |arg| return try DataTransferItemListImpl.File(instance, arg),
        }
    }

    pub fn call_remove(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try DataTransferItemListImpl.call_remove(instance, index);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try DataTransferItemListImpl.call_clear(instance);
    }

};
