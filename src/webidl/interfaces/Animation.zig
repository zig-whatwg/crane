//! Generated from: web-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationImpl = @import("impls").Animation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AnimationPlayState = @import("enums").AnimationPlayState;
const AnimationTrigger = @import("interfaces").AnimationTrigger;
const AnimationTimeline = @import("interfaces").AnimationTimeline;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const AnimationEffect = @import("interfaces").AnimationEffect;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AnimationReplaceState = @import("enums").AnimationReplaceState;
const EventListener = @import("interfaces").EventListener;
const CSSNumberish = @import("typedefs").CSSNumberish;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const Animation = struct {
    pub const Meta = struct {
        pub const name = "Animation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", "set_id" },
            .{ "effect", "get_effect", "set_effect" },
            .{ "timeline", "get_timeline", "set_timeline" },
            .{ "playbackRate", "get_playbackRate", "set_playbackRate" },
            .{ "playState", "get_playState", null },
            .{ "replaceState", "get_replaceState", null },
            .{ "pending", "get_pending", null },
            .{ "ready", "get_ready", null },
            .{ "finished", "get_finished", null },
            .{ "onfinish", "get_onfinish", "set_onfinish" },
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "onremove", "get_onremove", "set_onremove" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "currentTime", "get_currentTime", "set_currentTime" },
            .{ "trigger", "get_trigger", "set_trigger" },
            .{ "overallProgress", "get_overallProgress", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "cancel", "call_cancel", 0 },
            .{ "finish", "call_finish", 0 },
            .{ "play", "call_play", 0 },
            .{ "pause", "call_pause", 0 },
            .{ "updatePlaybackRate", "call_updatePlaybackRate", 1 },
            .{ "reverse", "call_reverse", 0 },
            .{ "persist", "call_persist", 0 },
            .{ "commitStyles", "call_commitStyles", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "cancel",
            "finish",
            "play",
            "pause",
            "updatePlaybackRate",
            "reverse",
            "persist",
            "commitStyles",
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
            .{ "id", "get_id", "set_id" },
            .{ "effect", "get_effect", "set_effect" },
            .{ "timeline", "get_timeline", "set_timeline" },
            .{ "playbackRate", "get_playbackRate", "set_playbackRate" },
            .{ "playState", "get_playState", null },
            .{ "replaceState", "get_replaceState", null },
            .{ "pending", "get_pending", null },
            .{ "ready", "get_ready", null },
            .{ "finished", "get_finished", null },
            .{ "onfinish", "get_onfinish", "set_onfinish" },
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "onremove", "get_onremove", "set_onremove" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "currentTime", "get_currentTime", "set_currentTime" },
            .{ "trigger", "get_trigger", "set_trigger" },
            .{ "overallProgress", "get_overallProgress", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "startTime", .{"Window"} },
            .{ "currentTime", .{"Window"} },
            .{ "trigger", .{"Window"} },
            .{ "overallProgress", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            effect: ?*runtime.Instance = null,
            timeline: ?*runtime.Instance = null,
            playbackRate: f64 = undefined,
            playState: enums.AnimationPlayState = undefined,
            replaceState: enums.AnimationReplaceState = undefined,
            pending: bool = undefined,
            ready: runtime.JSValue = undefined,
            finished: runtime.JSValue = undefined,
            onfinish: typedefs.EventHandler = undefined,
            oncancel: typedefs.EventHandler = undefined,
            onremove: typedefs.EventHandler = undefined,
            startTime: ?typedefs.CSSNumberish = null,
            currentTime: ?typedefs.CSSNumberish = null,
            trigger: ?*runtime.Instance = null,
            overallProgress: ?f64 = null,
            _internal: ?*AnimationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_currentTime = &get_currentTime,
        .get_effect = &get_effect,
        .get_finished = &get_finished,
        .get_id = &get_id,
        .get_oncancel = &get_oncancel,
        .get_onfinish = &get_onfinish,
        .get_onremove = &get_onremove,
        .get_overallProgress = &get_overallProgress,
        .get_pending = &get_pending,
        .get_playState = &get_playState,
        .get_playbackRate = &get_playbackRate,
        .get_ready = &get_ready,
        .get_replaceState = &get_replaceState,
        .get_startTime = &get_startTime,
        .get_timeline = &get_timeline,
        .get_trigger = &get_trigger,

        .set_currentTime = &set_currentTime,
        .set_effect = &set_effect,
        .set_id = &set_id,
        .set_oncancel = &set_oncancel,
        .set_onfinish = &set_onfinish,
        .set_onremove = &set_onremove,
        .set_playbackRate = &set_playbackRate,
        .set_startTime = &set_startTime,
        .set_timeline = &set_timeline,
        .set_trigger = &set_trigger,

        .call_cancel = &call_cancel,
        .call_commitStyles = &call_commitStyles,
        .call_finish = &call_finish,
        .call_pause = &call_pause,
        .call_persist = &call_persist,
        .call_play = &call_play,
        .call_reverse = &call_reverse,
        .call_updatePlaybackRate = &call_updatePlaybackRate,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("Animation has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(AnimationImpl, "init") and @hasDecl(AnimationImpl, "initOwn")) @compileError("AnimationImpl defines both init and initOwn");
        if (comptime @hasDecl(AnimationImpl, "init")) return AnimationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AnimationImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AnimationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AnimationImpl, "init")) return false;
        if (comptime @hasDecl(AnimationImpl, "construction_args")) {
            inline for (AnimationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AnimationImpl, "deinit") and @hasDecl(AnimationImpl, "deinitOwn")) @compileError("AnimationImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AnimationImpl, "deinit")) return AnimationImpl.deinit(instance);
        if (comptime @hasDecl(AnimationImpl, "deinitOwn")) AnimationImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Animation")) {
            if (comptime @hasDecl(impls.Animation, "installHooks")) impls.Animation.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, effect: webidl.Opt(?*runtime.Instance), timeline: webidl.Opt(?*runtime.Instance)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AnimationImpl.call_constructor(ctx, effect, timeline);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "AnimationEffect" },
        .{ "", 1, "AnimationTimeline" },
    };

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try AnimationImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try AnimationImpl.set_id(instance, value);
    }

    pub fn get_effect(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationImpl.get_effect(instance);
    }

    pub fn set_effect(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try AnimationImpl.set_effect(instance, value);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationImpl.get_timeline(instance);
    }

    pub fn set_timeline(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try AnimationImpl.set_timeline(instance, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
        return try AnimationImpl.get_playbackRate(instance);
    }

    pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
        try AnimationImpl.set_playbackRate(instance, value);
    }

    pub fn get_playState(instance: *runtime.Instance) anyerror!AnimationPlayState {
        return try AnimationImpl.get_playState(instance);
    }

    pub fn get_replaceState(instance: *runtime.Instance) anyerror!AnimationReplaceState {
        return try AnimationImpl.get_replaceState(instance);
    }

    pub fn get_pending(instance: *runtime.Instance) anyerror!bool {
        return try AnimationImpl.get_pending(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AnimationImpl.get_ready(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AnimationImpl.get_finished(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onfinish(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AnimationImpl, "get_onfinish")) return try AnimationImpl.get_onfinish(instance);
        return event_handlers.value(EventHandler, instance, "onfinish");
    }

    pub fn set_onfinish(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AnimationImpl, "set_onfinish")) return try AnimationImpl.set_onfinish(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onfinish", value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AnimationImpl, "get_oncancel")) return try AnimationImpl.get_oncancel(instance);
        return event_handlers.value(EventHandler, instance, "oncancel");
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AnimationImpl, "set_oncancel")) return try AnimationImpl.set_oncancel(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncancel", value);
    }

    pub fn get_onremove(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AnimationImpl, "get_onremove")) return try AnimationImpl.get_onremove(instance);
        return event_handlers.value(EventHandler, instance, "onremove");
    }

    pub fn set_onremove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AnimationImpl, "set_onremove")) return try AnimationImpl.set_onremove(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onremove", value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_startTime(instance: *runtime.Instance) anyerror!?CSSNumberish {
        return try AnimationImpl.get_startTime(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn set_startTime(instance: *runtime.Instance, value: ?CSSNumberish) anyerror!void {
        try AnimationImpl.set_startTime(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_currentTime(instance: *runtime.Instance) anyerror!?CSSNumberish {
        return try AnimationImpl.get_currentTime(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn set_currentTime(instance: *runtime.Instance, value: ?CSSNumberish) anyerror!void {
        try AnimationImpl.set_currentTime(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_trigger(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationImpl.get_trigger(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn set_trigger(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try AnimationImpl.set_trigger(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_overallProgress(instance: *runtime.Instance) anyerror!?f64 {
        return try AnimationImpl.get_overallProgress(instance);
    }

    pub fn call_finish(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_finish(instance);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_pause(instance);
    }

    pub fn call_persist(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_persist(instance);
    }

    pub fn call_play(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_play(instance);
    }

    pub fn call_reverse(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_reverse(instance);
    }

    pub fn call_updatePlaybackRate(instance: *runtime.Instance, playbackRate: f64) anyerror!void {
        return try AnimationImpl.call_updatePlaybackRate(instance, playbackRate);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_commitStyles(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try AnimationImpl.call_commitStyles(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_cancel(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onfinish", "set_oncancel", "set_onremove" };

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_playbackRate", 0b1 },
        .{ "call_updatePlaybackRate", 0b1 },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_effect", 0, "AnimationEffect" },
        .{ "set_timeline", 0, "AnimationTimeline" },
        .{ "set_trigger", 0, "AnimationTrigger" },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "call_commitStyles",
    };
};
