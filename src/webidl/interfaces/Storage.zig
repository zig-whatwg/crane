//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageImpl = @import("impls").Storage;
const DOMString = @import("typedefs").DOMString;

pub const Storage = struct {
    pub const Meta = struct {
        pub const name = "Storage";
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

    pub const vtable = runtime.buildVTable(Storage, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_clear = &call_clear,
        .call_getItem = &call_getItem,
        .call_key = &call_key,
        .call_removeItem = &call_removeItem,
        .call_setItem = &call_setItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        StorageImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try StorageImpl.get_length(instance);
    }

    pub fn call_removeItem(instance: *runtime.Instance, key: DOMString) anyerror!void {
        
        return try StorageImpl.call_removeItem(instance, key);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try StorageImpl.call_clear(instance);
    }

    pub fn call_key(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try StorageImpl.call_key(instance, index);
    }

    pub fn call_getItem(instance: *runtime.Instance, key: DOMString) anyerror!anyopaque {
        
        return try StorageImpl.call_getItem(instance, key);
    }

    pub fn call_setItem(instance: *runtime.Instance, key: DOMString, value: DOMString) anyerror!void {
        
        return try StorageImpl.call_setItem(instance, key, value);
    }

};
