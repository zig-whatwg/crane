//! Generated from: fetch.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BodyImpl = @import("impls").Body;
const Promise<ArrayBuffer> = @import("interfaces").Promise<ArrayBuffer>;
const ReadableStream = @import("interfaces").ReadableStream;
const Promise<Blob> = @import("interfaces").Promise<Blob>;
const Promise<FormData> = @import("interfaces").Promise<FormData>;
const Promise<any> = @import("interfaces").Promise<any>;
const Promise<USVString> = @import("interfaces").Promise<USVString>;
const Promise<Uint8Array> = @import("interfaces").Promise<Uint8Array>;

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
        
        // Initialize the instance (Impl receives full instance)
        BodyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BodyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!anyopaque {
        return try BodyImpl.get_body(instance);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
        return try BodyImpl.get_bodyUsed(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_blob(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_formData(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_text(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_json(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_json(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_bytes(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_arrayBuffer(instance);
    }

};
