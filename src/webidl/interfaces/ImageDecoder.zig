//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageDecoderImpl = @import("impls").ImageDecoder;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const ImageDecodeOptions = @import("dictionaries").ImageDecodeOptions;
const ImageDecoderInit = @import("dictionaries").ImageDecoderInit;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ImageTrackList = @import("interfaces").ImageTrackList;
const Promise<ImageDecodeResult> = @import("interfaces").Promise<ImageDecodeResult>;

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
        
        // Initialize the instance (Impl receives full instance)
        ImageDecoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageDecoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: ImageDecoderInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ImageDecoderImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try ImageDecoderImpl.get_type(instance);
    }

    pub fn get_complete(instance: *runtime.Instance) anyerror!bool {
        return try ImageDecoderImpl.get_complete(instance);
    }

    pub fn get_completed(instance: *runtime.Instance) anyerror!anyopaque {
        return try ImageDecoderImpl.get_completed(instance);
    }

    pub fn get_tracks(instance: *runtime.Instance) anyerror!ImageTrackList {
        return try ImageDecoderImpl.get_tracks(instance);
    }

    pub fn call_decode(instance: *runtime.Instance, options: ImageDecodeOptions) anyerror!anyopaque {
        
        return try ImageDecoderImpl.call_decode(instance, options);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try ImageDecoderImpl.call_reset(instance);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, type_: DOMString) anyerror!anyopaque {
        
        return try ImageDecoderImpl.call_isTypeSupported(instance, type_);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try ImageDecoderImpl.call_close(instance);
    }

};
