//! Generated from: compression.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DecompressionStreamImpl = @import("../impls/DecompressionStream.zig");
const GenericTransformStream = @import("GenericTransformStream.zig");

pub const DecompressionStream = struct {
    pub const Meta = struct {
        pub const name = "DecompressionStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GenericTransformStream,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            readable: ReadableStream = undefined,
            writable: WritableStream = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DecompressionStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_readable = &get_readable,
        .get_writable = &get_writable,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DecompressionStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DecompressionStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, format: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try DecompressionStreamImpl.constructor(state, format);
        
        return instance;
    }

    pub fn get_readable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DecompressionStreamImpl.get_readable(state);
    }

    pub fn get_writable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DecompressionStreamImpl.get_writable(state);
    }

};
