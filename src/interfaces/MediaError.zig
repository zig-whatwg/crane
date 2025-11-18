//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaErrorImpl = @import("../impls/MediaError.zig");

pub const MediaError = struct {
    pub const Meta = struct {
        pub const name = "MediaError";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            code: u16 = undefined,
            message: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short MEDIA_ERR_ABORTED = 1;
    pub fn get_MEDIA_ERR_ABORTED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short MEDIA_ERR_NETWORK = 2;
    pub fn get_MEDIA_ERR_NETWORK() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short MEDIA_ERR_DECODE = 3;
    pub fn get_MEDIA_ERR_DECODE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short MEDIA_ERR_SRC_NOT_SUPPORTED = 4;
    pub fn get_MEDIA_ERR_SRC_NOT_SUPPORTED() u16 {
        return 4;
    }

    pub const vtable = runtime.buildVTable(MediaError, .{
        .deinit_fn = &deinit_wrapper,

        .get_MEDIA_ERR_ABORTED = &get_MEDIA_ERR_ABORTED,
        .get_MEDIA_ERR_DECODE = &get_MEDIA_ERR_DECODE,
        .get_MEDIA_ERR_NETWORK = &get_MEDIA_ERR_NETWORK,
        .get_MEDIA_ERR_SRC_NOT_SUPPORTED = &get_MEDIA_ERR_SRC_NOT_SUPPORTED,
        .get_code = &get_code,
        .get_message = &get_message,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MediaErrorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaErrorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_code(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return MediaErrorImpl.get_code(state);
    }

    pub fn get_message(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaErrorImpl.get_message(state);
    }

};
