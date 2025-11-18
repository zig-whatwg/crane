//! Generated from: streams.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WritableStreamDefaultWriterImpl = @import("../impls/WritableStreamDefaultWriter.zig");

pub const WritableStreamDefaultWriter = struct {
    pub const Meta = struct {
        pub const name = "WritableStreamDefaultWriter";
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
            closed: Promise<undefined> = undefined,
            desiredSize: ?f64 = null,
            ready: Promise<undefined> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WritableStreamDefaultWriter, .{
        .deinit_fn = &deinit_wrapper,

        .get_closed = &get_closed,
        .get_desiredSize = &get_desiredSize,
        .get_ready = &get_ready,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_releaseLock = &call_releaseLock,
        .call_write = &call_write,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WritableStreamDefaultWriterImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WritableStreamDefaultWriterImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, stream: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try WritableStreamDefaultWriterImpl.constructor(state, stream);
        
        return instance;
    }

    pub fn get_closed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WritableStreamDefaultWriterImpl.get_closed(state);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WritableStreamDefaultWriterImpl.get_desiredSize(state);
    }

    pub fn get_ready(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WritableStreamDefaultWriterImpl.get_ready(state);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WritableStreamDefaultWriterImpl.call_releaseLock(state);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WritableStreamDefaultWriterImpl.call_abort(state, reason);
    }

    pub fn call_write(instance: *runtime.Instance, chunk: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WritableStreamDefaultWriterImpl.call_write(state, chunk);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WritableStreamDefaultWriterImpl.call_close(state);
    }

};
