//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TableImpl = @import("../impls/Table.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        TableImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TableImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, descriptor: anyopaque, value: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try TableImpl.constructor(state, descriptor, value);
        
        return instance;
    }

    pub fn get_length(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TableImpl.get_length(state);
    }

    pub fn call_get(instance: *runtime.Instance, index: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TableImpl.call_get(state, index);
    }

    pub fn call_grow(instance: *runtime.Instance, delta: anyopaque, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TableImpl.call_grow(state, delta, value);
    }

    pub fn call_set(instance: *runtime.Instance, index: anyopaque, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TableImpl.call_set(state, index, value);
    }

};
