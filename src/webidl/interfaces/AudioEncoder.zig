//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioEncoderImpl = @import("impls").AudioEncoder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AudioEncoderSupport = @import("dictionaries").AudioEncoderSupport;
const CodecState = @import("enums").CodecState;
const Event = @import("interfaces").Event;
const AudioEncoderInit = @import("dictionaries").AudioEncoderInit;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const AudioData = @import("interfaces").AudioData;
const AudioEncoderConfig = @import("dictionaries").AudioEncoderConfig;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const AudioEncoder = struct {
    pub const Meta = struct {
        pub const name = "AudioEncoder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "state", "get_state", null },
            .{ "encodeQueueSize", "get_encodeQueueSize", null },
            .{ "ondequeue", "get_ondequeue", "set_ondequeue" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "configure", "call_configure", 1 },
            .{ "encode", "call_encode", 1 },
            .{ "flush", "call_flush", 0 },
            .{ "reset", "call_reset", 0 },
            .{ "close", "call_close", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isConfigSupported", "call_static_isConfigSupported", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "configure",
            "encode",
            "flush",
            "reset",
            "close",
            "isConfigSupported",
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
            .{ "encodeQueueSize", "get_encodeQueueSize", null },
            .{ "ondequeue", "get_ondequeue", "set_ondequeue" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            state: enums.CodecState = undefined,
            encodeQueueSize: u32 = undefined,
            ondequeue: typedefs.EventHandler = undefined,
            _internal: ?*AudioEncoderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_encodeQueueSize = &get_encodeQueueSize,
        .get_ondequeue = &get_ondequeue,
        .get_state = &get_state,

        .set_ondequeue = &set_ondequeue,

        .call_close = &call_close,
        .call_configure = &call_configure,
        .call_encode = &call_encode,
        .call_flush = &call_flush,
        .call_reset = &call_reset,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioEncoder has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AudioEncoderImpl, "init") and @hasDecl(AudioEncoderImpl, "initOwn")) @compileError("AudioEncoderImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioEncoderImpl, "init")) return AudioEncoderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AudioEncoderImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AudioEncoderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioEncoderImpl, "init")) return false;
        if (comptime @hasDecl(AudioEncoderImpl, "construction_args")) {
            inline for (AudioEncoderImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioEncoderImpl, "deinit") and @hasDecl(AudioEncoderImpl, "deinitOwn")) @compileError("AudioEncoderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioEncoderImpl, "deinit")) return AudioEncoderImpl.deinit(instance);
        if (comptime @hasDecl(AudioEncoderImpl, "deinitOwn")) AudioEncoderImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioEncoder")) {
            if (comptime @hasDecl(impls.AudioEncoder, "installHooks")) impls.AudioEncoder.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: AudioEncoderInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioEncoderImpl.call_constructor(ctx, init_data);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!CodecState {
        return try AudioEncoderImpl.get_state(instance);
    }

    pub fn get_encodeQueueSize(instance: *runtime.Instance) anyerror!u32 {
        return try AudioEncoderImpl.get_encodeQueueSize(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_ondequeue(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AudioEncoderImpl, "get_ondequeue")) return try AudioEncoderImpl.get_ondequeue(instance);
        return event_handlers.value(EventHandler, instance, "ondequeue");
    }

    pub fn set_ondequeue(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AudioEncoderImpl, "set_ondequeue")) return try AudioEncoderImpl.set_ondequeue(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondequeue", value);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try AudioEncoderImpl.call_reset(instance);
    }

    pub fn call_configure(instance: *runtime.Instance, config: AudioEncoderConfig) anyerror!void {
        return try AudioEncoderImpl.call_configure(instance, config);
    }

    pub fn call_encode(instance: *runtime.Instance, data: *runtime.Instance) anyerror!void {
        return try AudioEncoderImpl.call_encode(instance, data);
    }

    pub fn call_flush(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AudioEncoderImpl.call_flush(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try AudioEncoderImpl.call_close(instance);
    }

    pub fn call_static_isConfigSupported(instance: *runtime.Instance, config: AudioEncoderConfig) anyerror!runtime.JSValue {
        return try AudioEncoderImpl.call_static_isConfigSupported(instance, config);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_ondequeue"};

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_encode", 0, "AudioData" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_flush",
        "call_static_isConfigSupported",
    };
};
