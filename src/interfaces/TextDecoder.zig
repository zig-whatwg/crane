//! Generated from: encoding.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextDecoderImpl = @import("../impls/TextDecoder.zig");
const TextDecoderCommon = @import("TextDecoderCommon.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        TextDecoderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TextDecoderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, label: runtime.DOMString, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try TextDecoderImpl.constructor(state, label, options);
        
        return instance;
    }

    pub fn get_encoding(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TextDecoderImpl.get_encoding(state);
    }

    pub fn get_fatal(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TextDecoderImpl.get_fatal(state);
    }

    pub fn get_ignoreBOM(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TextDecoderImpl.get_ignoreBOM(state);
    }

    pub fn call_decode(instance: *runtime.Instance, input: anyopaque, options: anyopaque) runtime.USVString {
        const state = instance.getState(State);
        
        return TextDecoderImpl.call_decode(state, input, options);
    }

};
