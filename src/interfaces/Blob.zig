//! Generated from: FileAPI.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BlobImpl = @import("../impls/Blob.zig");

pub const Blob = struct {
    pub const Meta = struct {
        pub const name = "Blob";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            size: u64 = undefined,
            type: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Blob, .{
        .deinit_fn = &deinit_wrapper,

        .get_size = &get_size,
        .get_type = &get_type,

        .call_arrayBuffer = &call_arrayBuffer,
        .call_bytes = &call_bytes,
        .call_slice = &call_slice,
        .call_stream = &call_stream,
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
        BlobImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BlobImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, blobParts: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try BlobImpl.constructor(state, blobParts, options);
        
        return instance;
    }

    pub fn get_size(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return BlobImpl.get_size(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BlobImpl.get_type(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BlobImpl.call_text(state);
    }

    pub fn call_slice(instance: *runtime.Instance, start: i64, end: i64, contentType: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [Clamp] on start
        const clamped_start = runtime.clamp(start);
        // [Clamp] on end
        const clamped_end = runtime.clamp(end);
        
        return BlobImpl.call_slice(state, clamped_start, clamped_end, contentType);
    }

    /// Extended attributes: [NewObject]
    pub fn call_stream(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BlobImpl.call_stream(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BlobImpl.call_bytes(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return BlobImpl.call_arrayBuffer(state);
    }

};
