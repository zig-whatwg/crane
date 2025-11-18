//! Generated from: encoding.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextEncoderStreamImpl = @import("../impls/TextEncoderStream.zig");
const TextEncoderCommon = @import("TextEncoderCommon.zig");
const GenericTransformStream = @import("GenericTransformStream.zig");

pub const TextEncoderStream = struct {
    pub const Meta = struct {
        pub const name = "TextEncoderStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            TextEncoderCommon,
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
            readable: ReadableStream = undefined,
            writable: WritableStream = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextEncoderStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_encoding = &get_encoding,
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
        
        // Initialize the state (Impl receives full hierarchy)
        TextEncoderStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TextEncoderStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try TextEncoderStreamImpl.constructor(state);
        
        return instance;
    }

    pub fn get_encoding(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TextEncoderStreamImpl.get_encoding(state);
    }

    pub fn get_readable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextEncoderStreamImpl.get_readable(state);
    }

    pub fn get_writable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextEncoderStreamImpl.get_writable(state);
    }

};
