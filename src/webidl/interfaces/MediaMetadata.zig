//! Generated from: mediasession.idl
//! Generated at: 2025-12-07T20:02:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const MediaMetadataImpl = @import("impls").MediaMetadata;
const mixins = @import("mixins");
const MediaMetadataInit = @import("dictionaries").MediaMetadataInit;
const ChapterInformation = @import("interfaces").ChapterInformation;
const DOMString = @import("typedefs").DOMString;

pub const MediaMetadata = struct {
    pub const Meta = struct {
        pub const name = "MediaMetadata";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "title", "get_title", "set_title" },
            .{ "artist", "get_artist", "set_artist" },
            .{ "album", "get_album", "set_album" },
            .{ "artwork", "get_artwork", "set_artwork" },
            .{ "chapterInfo", "get_chapterInfo", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "title", "get_title", "set_title" },
            .{ "artist", "get_artist", "set_artist" },
            .{ "album", "get_album", "set_album" },
            .{ "artwork", "get_artwork", "set_artwork" },
            .{ "chapterInfo", "get_chapterInfo", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            title: runtime.DOMString = undefined,
            artist: runtime.DOMString = undefined,
            album: runtime.DOMString = undefined,
            artwork: runtime.FrozenArray(v8.JSValue) = undefined,
            chapterInfo: runtime.FrozenArray(ChapterInformation) = undefined,
            cached_chapterInfo: ?runtime.FrozenArray(ChapterInformation) = null,
            _internal: ?*MediaMetadataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_album = &get_album,
        .get_artist = &get_artist,
        .get_artwork = &get_artwork,
        .get_chapterInfo = &get_chapterInfo,
        .get_title = &get_title,

        .set_album = &set_album,
        .set_artist = &set_artist,
        .set_artwork = &set_artwork,
        .set_title = &set_title,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaMetadataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaMetadataImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: webidl.Opt(MediaMetadataInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaMetadataImpl.call_constructor(allocator, ctx, init_data);
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

    pub fn get_artwork(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MediaMetadataImpl.get_artwork(instance);
    }

    pub fn set_artwork(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try MediaMetadataImpl.set_artwork(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_chapterInfo(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_chapterInfo) |cached| {
            return cached;
        }
        const value = try MediaMetadataImpl.get_chapterInfo(instance);
        state.own.cached_chapterInfo = value;
        return value;
    }

};
