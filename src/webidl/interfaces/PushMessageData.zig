//! Generated from: push-api.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushMessageDataImpl = @import("impls").PushMessageData;
const Uint8Array = @import("interfaces").Uint8Array;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const Blob = @import("interfaces").Blob;
const USVString = @import("interfaces").USVString;

pub const PushMessageData = struct {
    pub const Meta = struct {
        pub const name = "PushMessageData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PushMessageData, .{
        .deinit_fn = &deinit_wrapper,

        .call_arrayBuffer = &call_arrayBuffer,
        .call_blob = &call_blob,
        .call_bytes = &call_bytes,
        .call_json = &call_json,
        .call_text = &call_text,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return PushMessageDataImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushMessageDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_blob(instance: *runtime.Instance) anyerror!Blob {
        return try PushMessageDataImpl.call_blob(instance);
    }

    pub fn call_text(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PushMessageDataImpl.call_text(instance);
    }

    pub fn call_json(instance: *runtime.Instance) anyerror!anyopaque {
        return try PushMessageDataImpl.call_json(instance);
    }

    pub fn call_bytes(instance: *runtime.Instance) anyerror!anyopaque {
        return try PushMessageDataImpl.call_bytes(instance);
    }

    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        return try PushMessageDataImpl.call_arrayBuffer(instance);
    }

};
