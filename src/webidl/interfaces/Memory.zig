//! Generated from: wasm-js-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MemoryImpl = @import("impls").Memory;
const MemoryDescriptor = @import("dictionaries").MemoryDescriptor;
const AddressValue = @import("typedefs").AddressValue;
const ArrayBuffer = @import("interfaces").ArrayBuffer;

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
        
        // Initialize the instance (Impl receives full instance)
        MemoryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MemoryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, descriptor: MemoryDescriptor) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try MemoryImpl.constructor(instance, descriptor);
        
        return instance;
    }

    pub fn get_buffer(instance: *runtime.Instance) anyerror!anyopaque {
        return try MemoryImpl.get_buffer(instance);
    }

    pub fn call_grow(instance: *runtime.Instance, delta: AddressValue) anyerror!AddressValue {
        
        return try MemoryImpl.call_grow(instance, delta);
    }

    pub fn call_toFixedLengthBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        return try MemoryImpl.call_toFixedLengthBuffer(instance);
    }

    pub fn call_toResizableBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        return try MemoryImpl.call_toResizableBuffer(instance);
    }

};
