//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioScheduledSourceNodeImpl = @import("impls").AudioScheduledSourceNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioParam = @import("interfaces").AudioParam;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const AudioScheduledSourceNode = struct {
    pub const Meta = struct {
        pub const name = "AudioScheduledSourceNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AudioNode.State;
        pub const ParentInterface = AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onended", "get_onended", "set_onended" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onended", "get_onended", "set_onended" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onended: typedefs.EventHandler = undefined,
            _internal: ?*AudioScheduledSourceNodeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onended = &get_onended,

        .set_onended = &set_onended,

        .call_start = &call_start,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("AudioScheduledSourceNode has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "init") and @hasDecl(AudioScheduledSourceNodeImpl, "initOwn")) @compileError("AudioScheduledSourceNodeImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "init")) return AudioScheduledSourceNodeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AudioScheduledSourceNodeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "init")) return false;
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "construction_args")) {
            inline for (AudioScheduledSourceNodeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "deinit") and @hasDecl(AudioScheduledSourceNodeImpl, "deinitOwn")) @compileError("AudioScheduledSourceNodeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "deinit")) return AudioScheduledSourceNodeImpl.deinit(instance);
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "deinitOwn")) AudioScheduledSourceNodeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioScheduledSourceNode")) {
            if (comptime @hasDecl(impls.AudioScheduledSourceNode, "installHooks")) impls.AudioScheduledSourceNode.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "get_onended")) return try AudioScheduledSourceNodeImpl.get_onended(instance);
        return event_handlers.value(EventHandler, instance, "onended");
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AudioScheduledSourceNodeImpl, "set_onended")) return try AudioScheduledSourceNodeImpl.set_onended(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onended", value);
    }

    pub fn call_start(instance: *runtime.Instance, when: webidl.Opt(f64)) anyerror!void {
        return try AudioScheduledSourceNodeImpl.call_start(instance, when);
    }

    pub fn call_stop(instance: *runtime.Instance, when: webidl.Opt(f64)) anyerror!void {
        return try AudioScheduledSourceNodeImpl.call_stop(instance, when);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onended"};

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_start", 0b1 },
        .{ "call_stop", 0b1 },
    };
};
