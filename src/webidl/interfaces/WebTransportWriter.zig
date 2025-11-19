//! Generated from: webtransport.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportWriterImpl = @import("impls").WebTransportWriter;
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const WritableStream = @import("interfaces").WritableStream;

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
        return WebTransportWriterImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportWriterImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportWriterImpl.get_closed(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!f64 {
        return try WebTransportWriterImpl.get_desiredSize(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportWriterImpl.get_ready(instance);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
        return try WebTransportWriterImpl.call_releaseLock(instance);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try WebTransportWriterImpl.call_abort(instance, reason);
    }

    pub fn call_write(instance: *runtime.Instance, chunk: anyopaque) anyerror!anyopaque {
        
        return try WebTransportWriterImpl.call_write(instance, chunk);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportWriterImpl.call_close(instance);
    }

    pub fn call_atomicWrite(instance: *runtime.Instance, chunk: anyopaque) anyerror!anyopaque {
        
        return try WebTransportWriterImpl.call_atomicWrite(instance, chunk);
    }

    pub fn call_commit(instance: *runtime.Instance) anyerror!void {
        return try WebTransportWriterImpl.call_commit(instance);
    }

};
