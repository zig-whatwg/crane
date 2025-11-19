//! Generated from: streams.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableByteStreamControllerImpl = @import("impls").ReadableByteStreamController;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const ReadableStreamBYOBRequest = @import("interfaces").ReadableStreamBYOBRequest;

pub const ReadableByteStreamController = struct {
    pub const Meta = struct {
        pub const name = "ReadableByteStreamController";
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
            byobRequest: ?ReadableStreamBYOBRequest = null,
            desiredSize: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableByteStreamController, .{
        .deinit_fn = &deinit_wrapper,

        .get_byobRequest = &get_byobRequest,
        .get_desiredSize = &get_desiredSize,

        .call_close = &call_close,
        .call_enqueue = &call_enqueue,
        .call_error = &call_error,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ReadableByteStreamControllerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableByteStreamControllerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_byobRequest(instance: *runtime.Instance) anyerror!ReadableStreamBYOBRequest {
        return try ReadableByteStreamControllerImpl.get_byobRequest(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyerror!f64 {
        return try ReadableByteStreamControllerImpl.get_desiredSize(instance);
    }

    pub fn call_error(instance: *runtime.Instance, e: anyopaque) anyerror!void {
        
        return try ReadableByteStreamControllerImpl.call_error(instance, e);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try ReadableByteStreamControllerImpl.call_close(instance);
    }

    pub fn call_enqueue(instance: *runtime.Instance, chunk: ArrayBufferView) anyerror!void {
        
        return try ReadableByteStreamControllerImpl.call_enqueue(instance, chunk);
    }

};
