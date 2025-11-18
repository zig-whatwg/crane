//! Generated from: webcodecs.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageDecoderImpl = @import("../impls/ImageDecoder.zig");

pub const ImageDecoder = struct {
    pub const Meta = struct {
        pub const name = "ImageDecoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: runtime.DOMString = undefined,
            complete: bool = undefined,
            completed: Promise<undefined> = undefined,
            tracks: ImageTrackList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ImageDecoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_complete = &get_complete,
        .get_completed = &get_completed,
        .get_tracks = &get_tracks,
        .get_type = &get_type,

        .call_close = &call_close,
        .call_decode = &call_decode,
        .call_isTypeSupported = &call_isTypeSupported,
        .call_reset = &call_reset,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ImageDecoderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ImageDecoderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ImageDecoderImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ImageDecoderImpl.get_type(state);
    }

    pub fn get_complete(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ImageDecoderImpl.get_complete(state);
    }

    pub fn get_completed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageDecoderImpl.get_completed(state);
    }

    pub fn get_tracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageDecoderImpl.get_tracks(state);
    }

    pub fn call_decode(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ImageDecoderImpl.call_decode(state, options);
    }

    pub fn call_reset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageDecoderImpl.call_reset(state);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, type_: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return ImageDecoderImpl.call_isTypeSupported(state, type_);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageDecoderImpl.call_close(state);
    }

};
