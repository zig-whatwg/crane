//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MemoryImpl = @import("../impls/Memory.zig");

pub const Memory = struct {
    pub const Meta = struct {
        pub const name = "Memory";
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
            buffer: ArrayBuffer = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Memory, .{
        .deinit_fn = &deinit_wrapper,

        .get_buffer = &get_buffer,

        .call_grow = &call_grow,
        .call_toFixedLengthBuffer = &call_toFixedLengthBuffer,
        .call_toResizableBuffer = &call_toResizableBuffer,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MemoryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MemoryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, descriptor: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try MemoryImpl.constructor(state, descriptor);
        
        return instance;
    }

    pub fn get_buffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MemoryImpl.get_buffer(state);
    }

    pub fn call_grow(instance: *runtime.Instance, delta: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MemoryImpl.call_grow(state, delta);
    }

    pub fn call_toFixedLengthBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MemoryImpl.call_toFixedLengthBuffer(state);
    }

    pub fn call_toResizableBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MemoryImpl.call_toResizableBuffer(state);
    }

};
