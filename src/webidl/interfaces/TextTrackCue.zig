//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextTrackCueImpl = @import("impls").TextTrackCue;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const TextTrack = @import("interfaces").TextTrack;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const TextTrackCue = struct {
    pub const Meta = struct {
        pub const name = "TextTrackCue";
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
            .{ "track", "get_track", null },
            .{ "id", "get_id", "set_id" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "endTime", "get_endTime", "set_endTime" },
            .{ "pauseOnExit", "get_pauseOnExit", "set_pauseOnExit" },
            .{ "onenter", "get_onenter", "set_onenter" },
            .{ "onexit", "get_onexit", "set_onexit" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "track", "get_track", null },
            .{ "id", "get_id", "set_id" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "endTime", "get_endTime", "set_endTime" },
            .{ "pauseOnExit", "get_pauseOnExit", "set_pauseOnExit" },
            .{ "onenter", "get_onenter", "set_onenter" },
            .{ "onexit", "get_onexit", "set_onexit" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            track: ?*runtime.Instance = null,
            id: runtime.DOMString = undefined,
            startTime: f64 = undefined,
            endTime: f64 = undefined,
            pauseOnExit: bool = undefined,
            onenter: typedefs.EventHandler = undefined,
            onexit: typedefs.EventHandler = undefined,
            _internal: ?*TextTrackCueImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_endTime = &get_endTime,
        .get_id = &get_id,
        .get_onenter = &get_onenter,
        .get_onexit = &get_onexit,
        .get_pauseOnExit = &get_pauseOnExit,
        .get_startTime = &get_startTime,
        .get_track = &get_track,

        .set_endTime = &set_endTime,
        .set_id = &set_id,
        .set_onenter = &set_onenter,
        .set_onexit = &set_onexit,
        .set_pauseOnExit = &set_pauseOnExit,
        .set_startTime = &set_startTime,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("TextTrackCue has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(TextTrackCueImpl, "init") and @hasDecl(TextTrackCueImpl, "initOwn")) @compileError("TextTrackCueImpl defines both init and initOwn");
        if (comptime @hasDecl(TextTrackCueImpl, "init")) return TextTrackCueImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(TextTrackCueImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try TextTrackCueImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TextTrackCueImpl, "init")) return false;
        if (comptime @hasDecl(TextTrackCueImpl, "construction_args")) {
            inline for (TextTrackCueImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TextTrackCueImpl, "deinit") and @hasDecl(TextTrackCueImpl, "deinitOwn")) @compileError("TextTrackCueImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TextTrackCueImpl, "deinit")) return TextTrackCueImpl.deinit(instance);
        if (comptime @hasDecl(TextTrackCueImpl, "deinitOwn")) TextTrackCueImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TextTrackCue")) {
            if (comptime @hasDecl(impls.TextTrackCue, "installHooks")) impls.TextTrackCue.installHooks();
        }
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextTrackCueImpl.get_track(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TextTrackCueImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try TextTrackCueImpl.set_id(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try TextTrackCueImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try TextTrackCueImpl.set_startTime(instance, value);
    }

    pub fn get_endTime(instance: *runtime.Instance) anyerror!f64 {
        return try TextTrackCueImpl.get_endTime(instance);
    }

    pub fn set_endTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try TextTrackCueImpl.set_endTime(instance, value);
    }

    pub fn get_pauseOnExit(instance: *runtime.Instance) anyerror!bool {
        return try TextTrackCueImpl.get_pauseOnExit(instance);
    }

    pub fn set_pauseOnExit(instance: *runtime.Instance, value: bool) anyerror!void {
        try TextTrackCueImpl.set_pauseOnExit(instance, value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onenter(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(TextTrackCueImpl, "get_onenter")) return try TextTrackCueImpl.get_onenter(instance);
        return event_handlers.value(EventHandler, instance, "onenter");
    }

    pub fn set_onenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(TextTrackCueImpl, "set_onenter")) return try TextTrackCueImpl.set_onenter(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onenter", value);
    }

    pub fn get_onexit(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(TextTrackCueImpl, "get_onexit")) return try TextTrackCueImpl.get_onexit(instance);
        return event_handlers.value(EventHandler, instance, "onexit");
    }

    pub fn set_onexit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(TextTrackCueImpl, "set_onexit")) return try TextTrackCueImpl.set_onexit(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onexit", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onenter", "set_onexit" };

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_startTime", 0b1 },
    };
};
