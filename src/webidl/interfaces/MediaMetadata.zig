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
const ChapterInformation = @import("interfaces").ChapterInformation;
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
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "title", "get_title", "set_title" },
            .{ "artist", "get_artist", "set_artist" },
            .{ "album", "get_album", "set_album" },
            .{ "artwork", "get_artwork", "set_artwork" },
            .{ "chapterInfo", "get_chapterInfo", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            title: runtime.DOMString = undefined,
            artist: runtime.DOMString = undefined,
            album: runtime.DOMString = undefined,
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
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("MediaMetadata has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(MediaMetadataImpl, "init") and @hasDecl(MediaMetadataImpl, "initOwn")) @compileError("MediaMetadataImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaMetadataImpl, "init")) return MediaMetadataImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MediaMetadataImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MediaMetadataImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaMetadataImpl, "init")) return false;
        if (comptime @hasDecl(MediaMetadataImpl, "construction_args")) {
            inline for (MediaMetadataImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(MediaMetadataImpl, "deinit") and @hasDecl(MediaMetadataImpl, "deinitOwn")) @compileError("MediaMetadataImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(MediaMetadataImpl, "deinit")) return MediaMetadataImpl.deinit(instance);
        if (comptime @hasDecl(MediaMetadataImpl, "deinitOwn")) MediaMetadataImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaMetadata")) {
            if (comptime @hasDecl(impls.MediaMetadata, "installHooks")) impls.MediaMetadata.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(MediaMetadataInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaMetadataImpl.call_constructor(ctx, init_data);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MediaMetadataImpl.get_title(instance);
    }

    pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try MediaMetadataImpl.set_title(instance, value);
    }

    pub fn get_artist(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MediaMetadataImpl.get_artist(instance);
    }

    pub fn set_artist(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try MediaMetadataImpl.set_artist(instance, value);
    }

    pub fn get_album(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MediaMetadataImpl.get_album(instance);
    }

    pub fn set_album(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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
        return try MediaMetadataImpl.get_chapterInfo(instance);
    }
};
