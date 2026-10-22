//! Generated from: mediacapture-streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaStreamTrackImpl = @import("impls").MediaStreamTrack;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CaptureHandle = @import("dictionaries").CaptureHandle;
const MediaTrackSettings = @import("dictionaries").MediaTrackSettings;
const MediaTrackConstraints = @import("dictionaries").MediaTrackConstraints;
const MediaStreamTrackState = @import("enums").MediaStreamTrackState;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const CaptureAction = @import("enums").CaptureAction;
const MediaStreamTrackVideoStats = @import("interfaces").MediaStreamTrackVideoStats;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MediaTrackCapabilities = @import("dictionaries").MediaTrackCapabilities;
const EventListener = @import("interfaces").EventListener;
const MediaStreamTrackAudioStats = @import("interfaces").MediaStreamTrackAudioStats;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const MediaStreamTrack = struct {
    pub const Meta = struct {
        pub const name = "MediaStreamTrack";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "Transferable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "kind", "get_kind", null },
            .{ "id", "get_id", null },
            .{ "label", "get_label", null },
            .{ "enabled", "get_enabled", "set_enabled" },
            .{ "muted", "get_muted", null },
            .{ "onmute", "get_onmute", "set_onmute" },
            .{ "onunmute", "get_onunmute", "set_onunmute" },
            .{ "readyState", "get_readyState", null },
            .{ "onended", "get_onended", "set_onended" },
            .{ "oncapturehandlechange", "get_oncapturehandlechange", "set_oncapturehandlechange" },
            .{ "stats", "get_stats", null },
            .{ "onconfigurationchange", "get_onconfigurationchange", "set_onconfigurationchange" },
            .{ "contentHint", "get_contentHint", "set_contentHint" },
            .{ "isolated", "get_isolated", null },
            .{ "onisolationchange", "get_onisolationchange", "set_onisolationchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clone", "call_clone", 0 },
            .{ "stop", "call_stop", 0 },
            .{ "getCapabilities", "call_getCapabilities", 0 },
            .{ "getConstraints", "call_getConstraints", 0 },
            .{ "getSettings", "call_getSettings", 0 },
            .{ "applyConstraints", "call_applyConstraints", 0 },
            .{ "getCaptureHandle", "call_getCaptureHandle", 0 },
            .{ "getSupportedCaptureActions", "call_getSupportedCaptureActions", 0 },
            .{ "sendCaptureAction", "call_sendCaptureAction", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clone",
            "stop",
            "getCapabilities",
            "getConstraints",
            "getSettings",
            "applyConstraints",
            "getCaptureHandle",
            "getSupportedCaptureActions",
            "sendCaptureAction",
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
            .{ "kind", "get_kind", null },
            .{ "id", "get_id", null },
            .{ "label", "get_label", null },
            .{ "enabled", "get_enabled", "set_enabled" },
            .{ "muted", "get_muted", null },
            .{ "onmute", "get_onmute", "set_onmute" },
            .{ "onunmute", "get_onunmute", "set_onunmute" },
            .{ "readyState", "get_readyState", null },
            .{ "onended", "get_onended", "set_onended" },
            .{ "oncapturehandlechange", "get_oncapturehandlechange", "set_oncapturehandlechange" },
            .{ "stats", "get_stats", null },
            .{ "onconfigurationchange", "get_onconfigurationchange", "set_onconfigurationchange" },
            .{ "contentHint", "get_contentHint", "set_contentHint" },
            .{ "isolated", "get_isolated", null },
            .{ "onisolationchange", "get_onisolationchange", "set_onisolationchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            kind: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            label: runtime.DOMString = undefined,
            enabled: bool = undefined,
            muted: bool = undefined,
            onmute: typedefs.EventHandler = undefined,
            onunmute: typedefs.EventHandler = undefined,
            readyState: enums.MediaStreamTrackState = undefined,
            onended: typedefs.EventHandler = undefined,
            oncapturehandlechange: typedefs.EventHandler = undefined,
            stats: ?union(enum) {
                MediaStreamTrackAudioStats: MediaStreamTrackAudioStats,
                MediaStreamTrackVideoStats: MediaStreamTrackVideoStats,
            } = null,
            onconfigurationchange: typedefs.EventHandler = undefined,
            contentHint: runtime.DOMString = undefined,
            isolated: bool = undefined,
            onisolationchange: typedefs.EventHandler = undefined,
            cached_stats: ?runtime.JSValue = null,
            _internal: ?*MediaStreamTrackImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_contentHint = &get_contentHint,
        .get_enabled = &get_enabled,
        .get_id = &get_id,
        .get_isolated = &get_isolated,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_muted = &get_muted,
        .get_oncapturehandlechange = &get_oncapturehandlechange,
        .get_onconfigurationchange = &get_onconfigurationchange,
        .get_onended = &get_onended,
        .get_onisolationchange = &get_onisolationchange,
        .get_onmute = &get_onmute,
        .get_onunmute = &get_onunmute,
        .get_readyState = &get_readyState,
        .get_stats = &get_stats,

        .set_contentHint = &set_contentHint,
        .set_enabled = &set_enabled,
        .set_oncapturehandlechange = &set_oncapturehandlechange,
        .set_onconfigurationchange = &set_onconfigurationchange,
        .set_onended = &set_onended,
        .set_onisolationchange = &set_onisolationchange,
        .set_onmute = &set_onmute,
        .set_onunmute = &set_onunmute,

        .call_applyConstraints = &call_applyConstraints,
        .call_clone = &call_clone,
        .call_getCapabilities = &call_getCapabilities,
        .call_getCaptureHandle = &call_getCaptureHandle,
        .call_getConstraints = &call_getConstraints,
        .call_getSettings = &call_getSettings,
        .call_getSupportedCaptureActions = &call_getSupportedCaptureActions,
        .call_sendCaptureAction = &call_sendCaptureAction,
        .call_stop = &call_stop,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MediaStreamTrack has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MediaStreamTrackImpl, "init") and @hasDecl(MediaStreamTrackImpl, "initOwn")) @compileError("MediaStreamTrackImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaStreamTrackImpl, "init")) return MediaStreamTrackImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MediaStreamTrackImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MediaStreamTrackImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaStreamTrackImpl, "init")) return false;
        if (comptime @hasDecl(MediaStreamTrackImpl, "construction_args")) {
            inline for (MediaStreamTrackImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaStreamTrackImpl, "deinit") and @hasDecl(MediaStreamTrackImpl, "deinitOwn")) @compileError("MediaStreamTrackImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(MediaStreamTrackImpl, "deinit")) return MediaStreamTrackImpl.deinit(instance);
        if (comptime @hasDecl(MediaStreamTrackImpl, "deinitOwn")) MediaStreamTrackImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaStreamTrack")) {
            if (comptime @hasDecl(impls.MediaStreamTrack, "installHooks")) impls.MediaStreamTrack.installHooks();
        }
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MediaStreamTrackImpl.get_kind(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MediaStreamTrackImpl.get_id(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MediaStreamTrackImpl.get_label(instance);
    }

    pub fn get_enabled(instance: *runtime.Instance) anyerror!bool {
        return try MediaStreamTrackImpl.get_enabled(instance);
    }

    pub fn set_enabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try MediaStreamTrackImpl.set_enabled(instance, value);
    }

    pub fn get_muted(instance: *runtime.Instance) anyerror!bool {
        return try MediaStreamTrackImpl.get_muted(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onmute(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaStreamTrackImpl, "get_onmute")) return try MediaStreamTrackImpl.get_onmute(instance);
        return event_handlers.value(EventHandler, instance, "onmute");
    }

    pub fn set_onmute(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaStreamTrackImpl, "set_onmute")) return try MediaStreamTrackImpl.set_onmute(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmute", value);
    }

    pub fn get_onunmute(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaStreamTrackImpl, "get_onunmute")) return try MediaStreamTrackImpl.get_onunmute(instance);
        return event_handlers.value(EventHandler, instance, "onunmute");
    }

    pub fn set_onunmute(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaStreamTrackImpl, "set_onunmute")) return try MediaStreamTrackImpl.set_onunmute(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onunmute", value);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!MediaStreamTrackState {
        return try MediaStreamTrackImpl.get_readyState(instance);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaStreamTrackImpl, "get_onended")) return try MediaStreamTrackImpl.get_onended(instance);
        return event_handlers.value(EventHandler, instance, "onended");
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaStreamTrackImpl, "set_onended")) return try MediaStreamTrackImpl.set_onended(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onended", value);
    }

    pub fn get_oncapturehandlechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaStreamTrackImpl, "get_oncapturehandlechange")) return try MediaStreamTrackImpl.get_oncapturehandlechange(instance);
        return event_handlers.value(EventHandler, instance, "oncapturehandlechange");
    }

    pub fn set_oncapturehandlechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaStreamTrackImpl, "set_oncapturehandlechange")) return try MediaStreamTrackImpl.set_oncapturehandlechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncapturehandlechange", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_stats(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try MediaStreamTrackImpl.get_stats(instance);
    }

    pub fn get_onconfigurationchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaStreamTrackImpl, "get_onconfigurationchange")) return try MediaStreamTrackImpl.get_onconfigurationchange(instance);
        return event_handlers.value(EventHandler, instance, "onconfigurationchange");
    }

    pub fn set_onconfigurationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaStreamTrackImpl, "set_onconfigurationchange")) return try MediaStreamTrackImpl.set_onconfigurationchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onconfigurationchange", value);
    }

    pub fn get_contentHint(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MediaStreamTrackImpl.get_contentHint(instance);
    }

    pub fn set_contentHint(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try MediaStreamTrackImpl.set_contentHint(instance, value);
    }

    pub fn get_isolated(instance: *runtime.Instance) anyerror!bool {
        return try MediaStreamTrackImpl.get_isolated(instance);
    }

    pub fn get_onisolationchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaStreamTrackImpl, "get_onisolationchange")) return try MediaStreamTrackImpl.get_onisolationchange(instance);
        return event_handlers.value(EventHandler, instance, "onisolationchange");
    }

    pub fn set_onisolationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaStreamTrackImpl, "set_onisolationchange")) return try MediaStreamTrackImpl.set_onisolationchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onisolationchange", value);
    }

    pub fn call_sendCaptureAction(instance: *runtime.Instance, action: CaptureAction) anyerror!runtime.JSValue {
        return try MediaStreamTrackImpl.call_sendCaptureAction(instance, action);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance) anyerror!MediaTrackCapabilities {
        return try MediaStreamTrackImpl.call_getCapabilities(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try MediaStreamTrackImpl.call_stop(instance);
    }

    pub fn call_getSettings(instance: *runtime.Instance) anyerror!MediaTrackSettings {
        return try MediaStreamTrackImpl.call_getSettings(instance);
    }

    pub fn call_applyConstraints(instance: *runtime.Instance, constraints: webidl.Opt(MediaTrackConstraints)) anyerror!runtime.JSValue {
        return try MediaStreamTrackImpl.call_applyConstraints(instance, constraints);
    }

    pub fn call_getCaptureHandle(instance: *runtime.Instance) anyerror!?CaptureHandle {
        return try MediaStreamTrackImpl.call_getCaptureHandle(instance);
    }

    pub fn call_getSupportedCaptureActions(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaStreamTrackImpl.call_getSupportedCaptureActions(instance);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaStreamTrackImpl.call_clone(instance);
    }

    pub fn call_getConstraints(instance: *runtime.Instance) anyerror!MediaTrackConstraints {
        return try MediaStreamTrackImpl.call_getConstraints(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onmute", "set_onunmute", "set_onended", "set_oncapturehandlechange", "set_onconfigurationchange", "set_onisolationchange" };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_sendCaptureAction",
        "call_applyConstraints",
    };
};
