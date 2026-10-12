//! Generated from: audio-session.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioSessionImpl = @import("impls").AudioSession;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const AudioSessionState = @import("enums").AudioSessionState;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const Event = @import("interfaces").Event;
const EventListener = @import("interfaces").EventListener;
const AudioSessionType = @import("enums").AudioSessionType;
const Observable = @import("interfaces").Observable;

pub const AudioSession = struct {
    pub const Meta = struct {
        pub const name = "AudioSession";
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
            .{ "type", "get_type", "set_type" },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
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
            .{ "type", "get_type", "set_type" },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: enums.AudioSessionType = undefined,
            state: enums.AudioSessionState = undefined,
            onstatechange: typedefs.EventHandler = undefined,
            _internal: ?*AudioSessionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_type = &get_type,

        .set_onstatechange = &set_onstatechange,
        .set_type = &set_type,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioSession has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AudioSessionImpl, "init") and @hasDecl(AudioSessionImpl, "initOwn")) @compileError("AudioSessionImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioSessionImpl, "init")) return AudioSessionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AudioSessionImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AudioSessionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioSessionImpl, "init")) return false;
        if (comptime @hasDecl(AudioSessionImpl, "construction_args")) {
            inline for (AudioSessionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioSessionImpl, "deinit") and @hasDecl(AudioSessionImpl, "deinitOwn")) @compileError("AudioSessionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioSessionImpl, "deinit")) return AudioSessionImpl.deinit(instance);
        if (comptime @hasDecl(AudioSessionImpl, "deinitOwn")) AudioSessionImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioSession")) {
            if (comptime @hasDecl(impls.AudioSession, "installHooks")) impls.AudioSession.installHooks();
        }
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!AudioSessionType {
        return try AudioSessionImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: AudioSessionType) anyerror!void {
        try AudioSessionImpl.set_type(instance, value);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!AudioSessionState {
        return try AudioSessionImpl.get_state(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AudioSessionImpl, "get_onstatechange")) return try AudioSessionImpl.get_onstatechange(instance);
        return event_handlers.value(EventHandler, instance, "onstatechange");
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AudioSessionImpl, "set_onstatechange")) return try AudioSessionImpl.set_onstatechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstatechange", value);
    }
};
