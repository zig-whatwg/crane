//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataTransferItemImpl = @import("../impls/DataTransferItem.zig");

pub const DataTransferItem = struct {
    pub const Meta = struct {
        pub const name = "DataTransferItem";
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
            kind: runtime.DOMString = undefined,
            type: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DataTransferItem, .{
        .deinit_fn = &deinit_wrapper,

        .get_kind = &get_kind,
        .get_type = &get_type,

        .call_getAsFile = &call_getAsFile,
        .call_getAsFileSystemHandle = &call_getAsFileSystemHandle,
        .call_getAsString = &call_getAsString,
        .call_webkitGetAsEntry = &call_webkitGetAsEntry,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DataTransferItemImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DataTransferItemImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DataTransferItemImpl.get_kind(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DataTransferItemImpl.get_type(state);
    }

    pub fn call_getAsString(instance: *runtime.Instance, _callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DataTransferItemImpl.call_getAsString(state, _callback);
    }

    pub fn call_getAsFileSystemHandle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DataTransferItemImpl.call_getAsFileSystemHandle(state);
    }

    pub fn call_webkitGetAsEntry(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DataTransferItemImpl.call_webkitGetAsEntry(state);
    }

    pub fn call_getAsFile(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DataTransferItemImpl.call_getAsFile(state);
    }

};
