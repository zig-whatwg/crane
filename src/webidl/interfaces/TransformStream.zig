//! Generated from: streams.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TransformStreamImpl = @import("impls").TransformStream;
const ReadableStream = @import("interfaces").ReadableStream;
const WritableStream = @import("interfaces").WritableStream;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;

pub const TransformStream = struct {
    pub const Meta = struct {
        pub const name = "TransformStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Transferable" },
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

    pub const vtable = runtime.buildVTable(TransformStream, .{
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
        
        // Initialize the instance (Impl receives full instance)
        TransformStreamImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TransformStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, transformer: anyopaque, writableStrategy: QueuingStrategy, readableStrategy: QueuingStrategy) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TransformStreamImpl.constructor(instance, transformer, writableStrategy, readableStrategy);
        
        return instance;
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!ReadableStream {
        return try TransformStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!WritableStream {
        return try TransformStreamImpl.get_writable(instance);
    }

};
