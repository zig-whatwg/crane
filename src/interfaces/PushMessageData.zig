//! Generated from: push-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushMessageDataImpl = @import("../impls/PushMessageData.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PushMessageDataImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PushMessageDataImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_blob(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PushMessageDataImpl.call_blob(state);
    }

    pub fn call_text(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PushMessageDataImpl.call_text(state);
    }

    pub fn call_json(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PushMessageDataImpl.call_json(state);
    }

    pub fn call_bytes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PushMessageDataImpl.call_bytes(state);
    }

    pub fn call_arrayBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PushMessageDataImpl.call_arrayBuffer(state);
    }

};
