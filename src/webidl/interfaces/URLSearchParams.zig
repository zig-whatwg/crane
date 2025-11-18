//! Generated from: url.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const URLSearchParamsImpl = @import("impls").URLSearchParams;
const (sequence or record or USVString) = @import("interfaces").(sequence or record or USVString);
const USVString = @import("interfaces").USVString;

pub const URLSearchParams = struct {
    pub const Meta = struct {
        pub const name = "URLSearchParams";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            size: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(URLSearchParams, .{
        .deinit_fn = &deinit_wrapper,

        .get_size = &get_size,

        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
        .call_set = &call_set,
        .call_sort = &call_sort,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        URLSearchParamsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        URLSearchParamsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try URLSearchParamsImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try URLSearchParamsImpl.get_size(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        
        return try URLSearchParamsImpl.call_delete(instance, name, value);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        
        return try URLSearchParamsImpl.call_append(instance, name, value);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!anyopaque {
        
        return try URLSearchParamsImpl.call_getAll(instance, name);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!bool {
        
        return try URLSearchParamsImpl.call_has(instance, name, value);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        
        return try URLSearchParamsImpl.call_set(instance, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!anyopaque {
        
        return try URLSearchParamsImpl.call_get(instance, name);
    }

    pub fn call_sort(instance: *runtime.Instance) anyerror!void {
        return try URLSearchParamsImpl.call_sort(instance);
    }

};
