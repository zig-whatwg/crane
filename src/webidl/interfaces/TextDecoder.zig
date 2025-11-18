//! Generated from: encoding.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextDecoderImpl = @import("impls").TextDecoder;
const TextDecoderCommon = @import("interfaces").TextDecoderCommon;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const TextDecoderOptions = @import("dictionaries").TextDecoderOptions;
const TextDecodeOptions = @import("dictionaries").TextDecodeOptions;

pub const TextDecoder = struct {
    pub const Meta = struct {
        pub const name = "TextDecoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            TextDecoderCommon,
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextDecoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_encoding = &get_encoding,
        .get_fatal = &get_fatal,
        .get_ignoreBOM = &get_ignoreBOM,

        .call_decode = &call_decode,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        TextDecoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextDecoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, label: DOMString, options: TextDecoderOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TextDecoderImpl.constructor(instance, label, options);
        
        return instance;
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try TextDecoderImpl.get_encoding(instance);
    }

    pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
        return try TextDecoderImpl.get_fatal(instance);
    }

    pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
        return try TextDecoderImpl.get_ignoreBOM(instance);
    }

    pub fn call_decode(instance: *runtime.Instance, input: AllowSharedBufferSource, options: TextDecodeOptions) anyerror!runtime.USVString {
        
        return try TextDecoderImpl.call_decode(instance, input, options);
    }

};
