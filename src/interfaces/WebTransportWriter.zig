//! Generated from: webtransport.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportWriterImpl = @import("../impls/WebTransportWriter.zig");
const WritableStreamDefaultWriter = @import("WritableStreamDefaultWriter.zig");

pub const WebTransportWriter = struct {
    pub const Meta = struct {
        pub const name = "WebTransportWriter";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WritableStreamDefaultWriter;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebTransportWriter, .{
        .deinit_fn = &deinit_wrapper,

        .get_closed = &get_closed,
        .get_desiredSize = &get_desiredSize,
        .get_ready = &get_ready,

        .call_abort = &call_abort,
        .call_atomicWrite = &call_atomicWrite,
        .call_close = &call_close,
        .call_commit = &call_commit,
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
        WebTransportWriterImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebTransportWriterImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportWriterImpl.get_closed(state);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportWriterImpl.get_desiredSize(state);
    }

    pub fn get_ready(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportWriterImpl.get_ready(state);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportWriterImpl.call_releaseLock(state);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportWriterImpl.call_abort(state, reason);
    }

    pub fn call_write(instance: *runtime.Instance, chunk: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportWriterImpl.call_write(state, chunk);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportWriterImpl.call_close(state);
    }

    pub fn call_atomicWrite(instance: *runtime.Instance, chunk: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportWriterImpl.call_atomicWrite(state, chunk);
    }

    pub fn call_commit(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportWriterImpl.call_commit(state);
    }

};
