//! Generated from: encoding.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextEncoderImpl = @import("impls").TextEncoder;
const TextEncoderCommon = @import("interfaces").TextEncoderCommon;
const Uint8Array = @import("interfaces").Uint8Array;
const TextEncoderEncodeIntoResult = @import("dictionaries").TextEncoderEncodeIntoResult;

pub const TextEncoder = struct {
    pub const Meta = struct {
        pub const name = "TextEncoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            TextEncoderCommon,
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextEncoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_encoding = &get_encoding,

        .call_encode = &call_encode,
        .call_encodeInto = &call_encodeInto,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        TextEncoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextEncoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TextEncoderImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try TextEncoderImpl.get_encoding(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_encode(instance: *runtime.Instance, input: runtime.USVString) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try TextEncoderImpl.call_encode(instance, input);
    }

    pub fn call_encodeInto(instance: *runtime.Instance, source: runtime.USVString, destination: anyopaque) anyerror!TextEncoderEncodeIntoResult {
        
        return try TextEncoderImpl.call_encodeInto(instance, source, destination);
    }

};
