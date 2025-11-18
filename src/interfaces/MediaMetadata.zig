//! Generated from: mediasession.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaMetadataImpl = @import("../impls/MediaMetadata.zig");

pub const MediaMetadata = struct {
    pub const Meta = struct {
        pub const name = "MediaMetadata";
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
            title: runtime.DOMString = undefined,
            artist: runtime.DOMString = undefined,
            album: runtime.DOMString = undefined,
            artwork: FrozenArray<object> = undefined,
            chapterInfo: FrozenArray<ChapterInformation> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaMetadata, .{
        .deinit_fn = &deinit_wrapper,

        .get_album = &get_album,
        .get_artist = &get_artist,
        .get_artwork = &get_artwork,
        .get_chapterInfo = &get_chapterInfo,
        .get_title = &get_title,

        .set_album = &set_album,
        .set_artist = &set_artist,
        .set_artwork = &set_artwork,
        .set_title = &set_title,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MediaMetadataImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaMetadataImpl.deinit(state);
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
        try MediaMetadataImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_title(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaMetadataImpl.get_title(state);
    }

    pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        MediaMetadataImpl.set_title(state, value);
    }

    pub fn get_artist(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaMetadataImpl.get_artist(state);
    }

    pub fn set_artist(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        MediaMetadataImpl.set_artist(state, value);
    }

    pub fn get_album(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaMetadataImpl.get_album(state);
    }

    pub fn set_album(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        MediaMetadataImpl.set_album(state, value);
    }

    pub fn get_artwork(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaMetadataImpl.get_artwork(state);
    }

    pub fn set_artwork(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaMetadataImpl.set_artwork(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_chapterInfo(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_chapterInfo) |cached| {
            return cached;
        }
        const value = MediaMetadataImpl.get_chapterInfo(state);
        state.cached_chapterInfo = value;
        return value;
    }

};
