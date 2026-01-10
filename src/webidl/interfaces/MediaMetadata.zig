//! Generated from: mediasession.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaMetadataImpl = @import("impls").MediaMetadata;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaMetadataInit = @import("dictionaries").MediaMetadataInit;
const ChapterInformation = @import("ChapterInformation.zig").ChapterInformation;
const DOMString = @import("typedefs").DOMString;

pub const MediaMetadata = struct {
    pub const Meta = struct {
        pub const name = "MediaMetadata";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            title: typedefs.DOMString = undefined,
            artist: typedefs.DOMString = undefined,
            album: typedefs.DOMString = undefined,
            artwork: runtime.JSValue = undefined,
            chapterInfo: runtime.JSValue = undefined,
            cached_chapterInfo: ?runtime.JSValue = null,
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

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaMetadataImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaMetadataImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(MediaMetadataInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaMetadataImpl.call_constructor(ctx, init_data);
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

    pub fn get_artwork(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaMetadataImpl.get_artwork(instance);
    }

    pub fn set_artwork(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try MediaMetadataImpl.set_artwork(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_chapterInfo(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
