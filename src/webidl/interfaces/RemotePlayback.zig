//! Generated from: remote-playback.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RemotePlaybackImpl = @import("impls").RemotePlayback;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const RemotePlaybackState = @import("enums").RemotePlaybackState;
const RemotePlaybackAvailabilityCallback = @import("callbacks").RemotePlaybackAvailabilityCallback;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const RemotePlayback = struct {
    pub const Meta = struct {
        pub const name = "RemotePlayback";
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
            .{ "state", "get_state", null },
            .{ "onconnecting", "get_onconnecting", "set_onconnecting" },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "watchAvailability", "call_watchAvailability", 1 },
            .{ "cancelWatchAvailability", "call_cancelWatchAvailability", 0 },
            .{ "prompt", "call_prompt", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "watchAvailability",
            "cancelWatchAvailability",
            "prompt",
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
            .{ "state", "get_state", null },
            .{ "onconnecting", "get_onconnecting", "set_onconnecting" },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            state: enums.RemotePlaybackState = undefined,
            onconnecting: typedefs.EventHandler = undefined,
            onconnect: typedefs.EventHandler = undefined,
            ondisconnect: typedefs.EventHandler = undefined,
            _internal: ?*RemotePlaybackImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onconnect = &get_onconnect,
        .get_onconnecting = &get_onconnecting,
        .get_ondisconnect = &get_ondisconnect,
        .get_state = &get_state,

        .set_onconnect = &set_onconnect,
        .set_onconnecting = &set_onconnecting,
        .set_ondisconnect = &set_ondisconnect,

        .call_cancelWatchAvailability = &call_cancelWatchAvailability,
        .call_prompt = &call_prompt,
        .call_watchAvailability = &call_watchAvailability,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("RemotePlayback has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RemotePlaybackImpl, "init") and @hasDecl(RemotePlaybackImpl, "initOwn")) @compileError("RemotePlaybackImpl defines both init and initOwn");
        if (comptime @hasDecl(RemotePlaybackImpl, "init")) return RemotePlaybackImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(RemotePlaybackImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try RemotePlaybackImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RemotePlaybackImpl, "init")) return false;
        if (comptime @hasDecl(RemotePlaybackImpl, "construction_args")) {
            inline for (RemotePlaybackImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RemotePlaybackImpl, "deinit") and @hasDecl(RemotePlaybackImpl, "deinitOwn")) @compileError("RemotePlaybackImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RemotePlaybackImpl, "deinit")) return RemotePlaybackImpl.deinit(instance);
        if (comptime @hasDecl(RemotePlaybackImpl, "deinitOwn")) RemotePlaybackImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RemotePlayback")) {
            if (comptime @hasDecl(impls.RemotePlayback, "installHooks")) impls.RemotePlayback.installHooks();
        }
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RemotePlaybackState {
        return try RemotePlaybackImpl.get_state(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onconnecting(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RemotePlaybackImpl, "get_onconnecting")) return try RemotePlaybackImpl.get_onconnecting(instance);
        return event_handlers.value(EventHandler, instance, "onconnecting");
    }

    pub fn set_onconnecting(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RemotePlaybackImpl, "set_onconnecting")) return try RemotePlaybackImpl.set_onconnecting(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onconnecting", value);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RemotePlaybackImpl, "get_onconnect")) return try RemotePlaybackImpl.get_onconnect(instance);
        return event_handlers.value(EventHandler, instance, "onconnect");
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RemotePlaybackImpl, "set_onconnect")) return try RemotePlaybackImpl.set_onconnect(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onconnect", value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RemotePlaybackImpl, "get_ondisconnect")) return try RemotePlaybackImpl.get_ondisconnect(instance);
        return event_handlers.value(EventHandler, instance, "ondisconnect");
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RemotePlaybackImpl, "set_ondisconnect")) return try RemotePlaybackImpl.set_ondisconnect(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondisconnect", value);
    }

    pub fn call_cancelWatchAvailability(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!runtime.JSValue {
        return try RemotePlaybackImpl.call_cancelWatchAvailability(instance, id);
    }

    pub fn call_watchAvailability(instance: *runtime.Instance, callback: RemotePlaybackAvailabilityCallback) anyerror!runtime.JSValue {
        return try RemotePlaybackImpl.call_watchAvailability(instance, callback);
    }

    pub fn call_prompt(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RemotePlaybackImpl.call_prompt(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_cancelWatchAvailability",
        "call_watchAvailability",
        "call_prompt",
    };
};
