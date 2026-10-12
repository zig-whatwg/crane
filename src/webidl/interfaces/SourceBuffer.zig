//! Generated from: media-source.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SourceBufferImpl = @import("impls").SourceBuffer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const AudioTrackList = @import("interfaces").AudioTrackList;
const TextTrackList = @import("interfaces").TextTrackList;
const TimeRanges = @import("interfaces").TimeRanges;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BufferSource = @import("typedefs").BufferSource;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const VideoTrackList = @import("interfaces").VideoTrackList;
const DOMString = @import("typedefs").DOMString;
const AppendMode = @import("enums").AppendMode;

pub const SourceBuffer = struct {
    pub const Meta = struct {
        pub const name = "SourceBuffer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mode", "get_mode", "set_mode" },
            .{ "updating", "get_updating", null },
            .{ "buffered", "get_buffered", null },
            .{ "timestampOffset", "get_timestampOffset", "set_timestampOffset" },
            .{ "audioTracks", "get_audioTracks", null },
            .{ "videoTracks", "get_videoTracks", null },
            .{ "textTracks", "get_textTracks", null },
            .{ "appendWindowStart", "get_appendWindowStart", "set_appendWindowStart" },
            .{ "appendWindowEnd", "get_appendWindowEnd", "set_appendWindowEnd" },
            .{ "onupdatestart", "get_onupdatestart", "set_onupdatestart" },
            .{ "onupdate", "get_onupdate", "set_onupdate" },
            .{ "onupdateend", "get_onupdateend", "set_onupdateend" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onabort", "get_onabort", "set_onabort" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "appendBuffer", "call_appendBuffer", 1 },
            .{ "abort", "call_abort", 0 },
            .{ "changeType", "call_changeType", 1 },
            .{ "remove", "call_remove", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "appendBuffer",
            "abort",
            "changeType",
            "remove",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mode", "get_mode", "set_mode" },
            .{ "updating", "get_updating", null },
            .{ "buffered", "get_buffered", null },
            .{ "timestampOffset", "get_timestampOffset", "set_timestampOffset" },
            .{ "audioTracks", "get_audioTracks", null },
            .{ "videoTracks", "get_videoTracks", null },
            .{ "textTracks", "get_textTracks", null },
            .{ "appendWindowStart", "get_appendWindowStart", "set_appendWindowStart" },
            .{ "appendWindowEnd", "get_appendWindowEnd", "set_appendWindowEnd" },
            .{ "onupdatestart", "get_onupdatestart", "set_onupdatestart" },
            .{ "onupdate", "get_onupdate", "set_onupdate" },
            .{ "onupdateend", "get_onupdateend", "set_onupdateend" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onabort", "get_onabort", "set_onabort" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mode: enums.AppendMode = undefined,
            updating: bool = undefined,
            buffered: *runtime.Instance = undefined,
            timestampOffset: f64 = undefined,
            audioTracks: *runtime.Instance = undefined,
            videoTracks: *runtime.Instance = undefined,
            textTracks: *runtime.Instance = undefined,
            appendWindowStart: f64 = undefined,
            appendWindowEnd: f64 = undefined,
            onupdatestart: typedefs.EventHandler = undefined,
            onupdate: typedefs.EventHandler = undefined,
            onupdateend: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            onabort: typedefs.EventHandler = undefined,
            _internal: ?*SourceBufferImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_appendWindowEnd = &get_appendWindowEnd,
        .get_appendWindowStart = &get_appendWindowStart,
        .get_audioTracks = &get_audioTracks,
        .get_buffered = &get_buffered,
        .get_mode = &get_mode,
        .get_onabort = &get_onabort,
        .get_onerror = &get_onerror,
        .get_onupdate = &get_onupdate,
        .get_onupdateend = &get_onupdateend,
        .get_onupdatestart = &get_onupdatestart,
        .get_textTracks = &get_textTracks,
        .get_timestampOffset = &get_timestampOffset,
        .get_updating = &get_updating,
        .get_videoTracks = &get_videoTracks,

        .set_appendWindowEnd = &set_appendWindowEnd,
        .set_appendWindowStart = &set_appendWindowStart,
        .set_mode = &set_mode,
        .set_onabort = &set_onabort,
        .set_onerror = &set_onerror,
        .set_onupdate = &set_onupdate,
        .set_onupdateend = &set_onupdateend,
        .set_onupdatestart = &set_onupdatestart,
        .set_timestampOffset = &set_timestampOffset,

        .call_abort = &call_abort,
        .call_appendBuffer = &call_appendBuffer,
        .call_changeType = &call_changeType,
        .call_remove = &call_remove,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SourceBuffer has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SourceBufferImpl, "init") and @hasDecl(SourceBufferImpl, "initOwn")) @compileError("SourceBufferImpl defines both init and initOwn");
        if (comptime @hasDecl(SourceBufferImpl, "init")) return SourceBufferImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SourceBufferImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SourceBufferImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SourceBufferImpl, "init")) return false;
        if (comptime @hasDecl(SourceBufferImpl, "construction_args")) {
            inline for (SourceBufferImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(SourceBufferImpl, "deinit") and @hasDecl(SourceBufferImpl, "deinitOwn")) @compileError("SourceBufferImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SourceBufferImpl, "deinit")) return SourceBufferImpl.deinit(instance);
        if (comptime @hasDecl(SourceBufferImpl, "deinitOwn")) SourceBufferImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SourceBuffer")) {
            if (comptime @hasDecl(impls.SourceBuffer, "installHooks")) impls.SourceBuffer.installHooks();
        }
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!AppendMode {
        return try SourceBufferImpl.get_mode(instance);
    }

    pub fn set_mode(instance: *runtime.Instance, value: AppendMode) anyerror!void {
        try SourceBufferImpl.set_mode(instance, value);
    }

    pub fn get_updating(instance: *runtime.Instance) anyerror!bool {
        return try SourceBufferImpl.get_updating(instance);
    }

    pub fn get_buffered(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SourceBufferImpl.get_buffered(instance);
    }

    pub fn get_timestampOffset(instance: *runtime.Instance) anyerror!f64 {
        return try SourceBufferImpl.get_timestampOffset(instance);
    }

    pub fn set_timestampOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try SourceBufferImpl.set_timestampOffset(instance, value);
    }

    pub fn get_audioTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SourceBufferImpl.get_audioTracks(instance);
    }

    pub fn get_videoTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SourceBufferImpl.get_videoTracks(instance);
    }

    pub fn get_textTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SourceBufferImpl.get_textTracks(instance);
    }

    pub fn get_appendWindowStart(instance: *runtime.Instance) anyerror!f64 {
        return try SourceBufferImpl.get_appendWindowStart(instance);
    }

    pub fn set_appendWindowStart(instance: *runtime.Instance, value: f64) anyerror!void {
        try SourceBufferImpl.set_appendWindowStart(instance, value);
    }

    pub fn get_appendWindowEnd(instance: *runtime.Instance) anyerror!f64 {
        return try SourceBufferImpl.get_appendWindowEnd(instance);
    }

    pub fn set_appendWindowEnd(instance: *runtime.Instance, value: f64) anyerror!void {
        try SourceBufferImpl.set_appendWindowEnd(instance, value);
    }

    pub fn get_onupdatestart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onupdatestart(instance);
    }

    pub fn set_onupdatestart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onupdatestart(instance, value);
    }

    pub fn get_onupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onupdate(instance);
    }

    pub fn set_onupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onupdate(instance, value);
    }

    pub fn get_onupdateend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onupdateend(instance);
    }

    pub fn set_onupdateend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onupdateend(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onerror(instance, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onabort(instance, value);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try SourceBufferImpl.call_abort(instance);
    }

    pub fn call_appendBuffer(instance: *runtime.Instance, data: BufferSource) anyerror!void {
        return try SourceBufferImpl.call_appendBuffer(instance, data);
    }

    pub fn call_changeType(instance: *runtime.Instance, @"type": DOMString) anyerror!void {
        return try SourceBufferImpl.call_changeType(instance, @"type");
    }

    pub fn call_remove(instance: *runtime.Instance, start: f64, end: f64) anyerror!void {
        return try SourceBufferImpl.call_remove(instance, start, end);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_timestampOffset", 0b1 },
        .{ "set_appendWindowStart", 0b1 },
        .{ "call_remove", 0b1 },
    };
};
