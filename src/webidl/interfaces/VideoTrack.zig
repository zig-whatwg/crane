//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VideoTrackImpl = @import("impls").VideoTrack;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SourceBuffer = @import("interfaces").SourceBuffer;
const DOMString = @import("typedefs").DOMString;

pub const VideoTrack = struct {
    pub const Meta = struct {
        pub const name = "VideoTrack";
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
            .{ "id", "get_id", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "selected", "get_selected", "set_selected" },
            .{ "sourceBuffer", "get_sourceBuffer", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "selected", "get_selected", "set_selected" },
            .{ "sourceBuffer", "get_sourceBuffer", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            kind: runtime.DOMString = undefined,
            label: runtime.DOMString = undefined,
            language: runtime.DOMString = undefined,
            selected: bool = undefined,
            sourceBuffer: ?*runtime.Instance = null,
            _internal: ?*VideoTrackImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_id = &get_id,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_language = &get_language,
        .get_selected = &get_selected,
        .get_sourceBuffer = &get_sourceBuffer,

        .set_selected = &set_selected,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("VideoTrack has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(VideoTrackImpl, "init") and @hasDecl(VideoTrackImpl, "initOwn")) @compileError("VideoTrackImpl defines both init and initOwn");
        if (comptime @hasDecl(VideoTrackImpl, "init")) return VideoTrackImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(VideoTrackImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try VideoTrackImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(VideoTrackImpl, "init")) return false;
        if (comptime @hasDecl(VideoTrackImpl, "construction_args")) {
            inline for (VideoTrackImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(VideoTrackImpl, "deinit") and @hasDecl(VideoTrackImpl, "deinitOwn")) @compileError("VideoTrackImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(VideoTrackImpl, "deinit")) return VideoTrackImpl.deinit(instance);
        if (comptime @hasDecl(VideoTrackImpl, "deinitOwn")) VideoTrackImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "VideoTrack")) {
            if (comptime @hasDecl(impls.VideoTrack, "installHooks")) impls.VideoTrack.installHooks();
        }
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try VideoTrackImpl.get_id(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try VideoTrackImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try VideoTrackImpl.get_label(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try VideoTrackImpl.get_language(instance);
    }

    pub fn get_selected(instance: *runtime.Instance) anyerror!bool {
        return try VideoTrackImpl.get_selected(instance);
    }

    pub fn set_selected(instance: *runtime.Instance, value: bool) anyerror!void {
        try VideoTrackImpl.set_selected(instance, value);
    }

    pub fn get_sourceBuffer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try VideoTrackImpl.get_sourceBuffer(instance);
    }
};
