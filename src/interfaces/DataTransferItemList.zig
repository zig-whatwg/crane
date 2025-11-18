//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataTransferItemListImpl = @import("../impls/DataTransferItemList.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        DataTransferItemListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DataTransferItemListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return DataTransferItemListImpl.get_length(state);
    }

    /// Arguments for add (WebIDL overloading)
    pub const AddArgs = union(enum) {
        /// add(data, type)
        string_string: struct {
            data: runtime.DOMString,
            type_: runtime.DOMString,
        },
        /// add(data)
        File: anyopaque,
    };

    pub fn call_add(instance: *runtime.Instance, args: AddArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .string_string => |a| return DataTransferItemListImpl.string_string(state, a.data, a.type_),
            .File => |arg| return DataTransferItemListImpl.File(state, arg),
        }
    }

    pub fn call_remove(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return DataTransferItemListImpl.call_remove(state, index);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DataTransferItemListImpl.call_clear(state);
    }

};
