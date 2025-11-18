//! Generated from: streams.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WritableStreamImpl = @import("impls").WritableStream;
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;

pub const WritableStream = struct {
    pub const Meta = struct {
        pub const name = "WritableStream";
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
            locked: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WritableStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_locked = &get_locked,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_getWriter = &call_getWriter,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WritableStreamImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WritableStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, underlyingSink: anyopaque, strategy: QueuingStrategy) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try WritableStreamImpl.constructor(instance, underlyingSink, strategy);
        
        return instance;
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try WritableStreamImpl.get_locked(instance);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyerror!WritableStreamDefaultWriter {
        return try WritableStreamImpl.call_getWriter(instance);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try WritableStreamImpl.call_abort(instance, reason);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try WritableStreamImpl.call_close(instance);
    }

};
