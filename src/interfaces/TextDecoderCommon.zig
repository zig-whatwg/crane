//! Generated from: encoding.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextDecoderCommonImpl = @import("../impls/TextDecoderCommon.zig");

pub const TextDecoderCommon = struct {
    pub const Meta = struct {
        pub const name = "TextDecoderCommon";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
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

    pub const vtable = runtime.buildVTable(TextDecoderCommon, .{
        .deinit_fn = &deinit_wrapper,

        .get_encoding = &get_encoding,
        .get_fatal = &get_fatal,
        .get_ignoreBOM = &get_ignoreBOM,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TextDecoderCommonImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TextDecoderCommonImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_encoding(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TextDecoderCommonImpl.get_encoding(state);
    }

    pub fn get_fatal(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TextDecoderCommonImpl.get_fatal(state);
    }

    pub fn get_ignoreBOM(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TextDecoderCommonImpl.get_ignoreBOM(state);
    }

};
