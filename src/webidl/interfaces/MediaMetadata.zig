//! Generated from: mediasession.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaMetadataImpl = @import("impls").MediaMetadata;
const MediaMetadataInit = @import("dictionaries").MediaMetadataInit;
const FrozenArray<object> = @import("interfaces").FrozenArray<object>;
const FrozenArray<ChapterInformation> = @import("interfaces").FrozenArray<ChapterInformation>;

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
        
        // Initialize the instance (Impl receives full instance)
        MediaMetadataImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaMetadataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: MediaMetadataInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try MediaMetadataImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaMetadataImpl.get_title(instance);
    }

    pub fn set_title(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try MediaMetadataImpl.set_title(instance, value);
    }

    pub fn get_artist(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaMetadataImpl.get_artist(instance);
    }

    pub fn set_artist(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try MediaMetadataImpl.set_artist(instance, value);
    }

    pub fn get_album(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaMetadataImpl.get_album(instance);
    }

    pub fn set_album(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try MediaMetadataImpl.set_album(instance, value);
    }

    pub fn get_artwork(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaMetadataImpl.get_artwork(instance);
    }

    pub fn set_artwork(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try MediaMetadataImpl.set_artwork(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_chapterInfo(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_chapterInfo) |cached| {
            return cached;
        }
        const value = try MediaMetadataImpl.get_chapterInfo(instance);
        state.cached_chapterInfo = value;
        return value;
    }

};
