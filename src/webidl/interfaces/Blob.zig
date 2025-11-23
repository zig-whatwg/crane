//! Generated from: FileAPI.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BlobImpl = @import("impls").Blob;
const ReadableStream = @import("interfaces").ReadableStream;
const BlobPart = @import("typedefs").BlobPart;
const USVString = @import("interfaces").USVString;
const BlobPropertyBag = @import("dictionaries").BlobPropertyBag;
const DOMString = @import("typedefs").DOMString;

pub const Blob = struct {
    pub const Meta = struct {
        pub const name = "Blob";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "size", "get_size", null },
            .{ "type", "get_type", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "slice", "call_slice", 0 },
            .{ "stream", "call_stream", 0 },
            .{ "text", "call_text", 0 },
            .{ "arrayBuffer", "call_arrayBuffer", 0 },
            .{ "bytes", "call_bytes", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "slice",
            "stream",
            "text",
            "arrayBuffer",
            "bytes",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
            .{ "type", "get_type", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u64 = undefined,
            @"type": runtime.DOMString = undefined,
            _internal: ?*BlobImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_size = &get_size,
        .get_type = &get_type,

        .call_arrayBuffer = &call_arrayBuffer,
        .call_bytes = &call_bytes,
        .call_slice = &call_slice,
        .call_stream = &call_stream,
        .call_text = &call_text,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BlobImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BlobImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, blobParts: *const anyopaque, options: BlobPropertyBag) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BlobImpl.call_constructor(allocator, ctx, blobParts, options);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u64 {
        return try BlobImpl.get_size(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try BlobImpl.get_type(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BlobImpl.call_text(instance);
    }

    pub fn call_slice(instance: *runtime.Instance, start: i64, end: i64, contentType: DOMString) anyerror!*runtime.Instance {
        // [Clamp] on start
        const clamped_start = runtime.clamp(i64, start);
        // [Clamp] on end
        const clamped_end = runtime.clamp(i64, end);
        
        return try BlobImpl.call_slice(instance, clamped_start, clamped_end, contentType);
    }

    /// Extended attributes: [NewObject]
    pub fn call_stream(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try BlobImpl.call_stream(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BlobImpl.call_bytes(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BlobImpl.call_arrayBuffer(instance);
    }

};
