//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TableImpl = @import("impls").Table;
const AddressValue = @import("typedefs").AddressValue;
const TableDescriptor = @import("dictionaries").TableDescriptor;

pub const Table = struct {
    pub const Meta = struct {
        pub const name = "Table";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: AddressValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Table, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_get = &call_get,
        .call_grow = &call_grow,
        .call_set = &call_set,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        TableImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TableImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, descriptor: TableDescriptor, value: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TableImpl.constructor(instance, descriptor, value);
        
        return instance;
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!AddressValue {
        return try TableImpl.get_length(instance);
    }

    pub fn call_get(instance: *runtime.Instance, index: AddressValue) anyerror!anyopaque {
        
        return try TableImpl.call_get(instance, index);
    }

    pub fn call_grow(instance: *runtime.Instance, delta: AddressValue, value: anyopaque) anyerror!AddressValue {
        
        return try TableImpl.call_grow(instance, delta, value);
    }

    pub fn call_set(instance: *runtime.Instance, index: AddressValue, value: anyopaque) anyerror!void {
        
        return try TableImpl.call_set(instance, index, value);
    }

};
