//! Generated from: fetch.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BodyImpl = @import("../impls/Body.zig");

pub const Body = struct {
    pub const Meta = struct {
        pub const name = "Body";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            body: ?ReadableStream = null,
            bodyUsed: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Body, .{
        .deinit_fn = &deinit_wrapper,

        .get_body = &get_body,
        .get_bodyUsed = &get_bodyUsed,

        .call_arrayBuffer = &call_arrayBuffer,
        .call_blob = &call_blob,
        .call_bytes = &call_bytes,
        .call_formData = &call_formData,
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
        BodyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BodyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BodyImpl.get_body(state);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BodyImpl.get_bodyUsed(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BodyImpl.call_blob(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BodyImpl.call_formData(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BodyImpl.call_text(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_json(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BodyImpl.call_json(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BodyImpl.call_bytes(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BodyImpl.call_arrayBuffer(state);
    }

};
