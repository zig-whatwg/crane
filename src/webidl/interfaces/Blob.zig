//! Generated from: FileAPI.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BlobImpl = @import("impls").Blob;
const Promise<USVString> = @import("interfaces").Promise<USVString>;
const ReadableStream = @import("interfaces").ReadableStream;
const Promise<ArrayBuffer> = @import("interfaces").Promise<ArrayBuffer>;
const BlobPropertyBag = @import("dictionaries").BlobPropertyBag;
const Promise<Uint8Array> = @import("interfaces").Promise<Uint8Array>;

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
        
        // Initialize the instance (Impl receives full instance)
        BlobImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BlobImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, blobParts: anyopaque, options: BlobPropertyBag) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try BlobImpl.constructor(instance, blobParts, options);
        
        return instance;
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u64 {
        return try BlobImpl.get_size(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try BlobImpl.get_type(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BlobImpl.call_text(instance);
    }

    pub fn call_slice(instance: *runtime.Instance, start: i64, end: i64, contentType: DOMString) anyerror!Blob {
        // [Clamp] on start
        const clamped_start = runtime.clamp(start);
        // [Clamp] on end
        const clamped_end = runtime.clamp(end);
        
        return try BlobImpl.call_slice(instance, clamped_start, clamped_end, contentType);
    }

    /// Extended attributes: [NewObject]
    pub fn call_stream(instance: *runtime.Instance) anyerror!ReadableStream {
        // [NewObject] - Caller owns the returned object
        return try BlobImpl.call_stream(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BlobImpl.call_bytes(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BlobImpl.call_arrayBuffer(instance);
    }

};
