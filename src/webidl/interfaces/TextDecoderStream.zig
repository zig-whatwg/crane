//! Generated from: encoding.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextDecoderStreamImpl = @import("impls").TextDecoderStream;
const TextDecoderCommon = @import("interfaces").TextDecoderCommon;
const GenericTransformStream = @import("interfaces").GenericTransformStream;
const TextDecoderOptions = @import("dictionaries").TextDecoderOptions;
const ReadableStream = @import("interfaces").ReadableStream;
const WritableStream = @import("interfaces").WritableStream;

pub const TextDecoderStream = struct {
    pub const Meta = struct {
        pub const name = "TextDecoderStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            TextDecoderCommon,
            GenericTransformStream,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            encoding: runtime.DOMString = undefined,
            fatal: bool = undefined,
            ignoreBOM: bool = undefined,
            readable: ReadableStream = undefined,
            writable: WritableStream = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextDecoderStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_encoding = &get_encoding,
        .get_fatal = &get_fatal,
        .get_ignoreBOM = &get_ignoreBOM,
        .get_readable = &get_readable,
        .get_writable = &get_writable,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        TextDecoderStreamImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextDecoderStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, label: DOMString, options: TextDecoderOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TextDecoderStreamImpl.constructor(instance, label, options);
        
        return instance;
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try TextDecoderStreamImpl.get_encoding(instance);
    }

    pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
        return try TextDecoderStreamImpl.get_fatal(instance);
    }

    pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
        return try TextDecoderStreamImpl.get_ignoreBOM(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!ReadableStream {
        return try TextDecoderStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!WritableStream {
        return try TextDecoderStreamImpl.get_writable(instance);
    }

};
