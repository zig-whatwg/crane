//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioDecoderImpl = @import("impls").AudioDecoder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const CodecState = @import("enums").CodecState;
const AudioDecoderConfig = @import("dictionaries").AudioDecoderConfig;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const AudioDecoderInit = @import("dictionaries").AudioDecoderInit;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EncodedAudioChunk = @import("interfaces").EncodedAudioChunk;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const AudioDecoderSupport = @import("dictionaries").AudioDecoderSupport;

pub const AudioDecoder = struct {
    pub const Meta = struct {
        pub const name = "AudioDecoder";
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
            .{ "decodeQueueSize", "get_decodeQueueSize", null },
            .{ "ondequeue", "get_ondequeue", "set_ondequeue" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "configure", "call_configure", 1 },
            .{ "decode", "call_decode", 1 },
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
            "decode",
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
            .{ "decodeQueueSize", "get_decodeQueueSize", null },
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
            decodeQueueSize: u32 = undefined,
            ondequeue: typedefs.EventHandler = undefined,
            _internal: ?*AudioDecoderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_decodeQueueSize = &get_decodeQueueSize,
        .get_ondequeue = &get_ondequeue,
        .get_state = &get_state,

        .set_ondequeue = &set_ondequeue,

        .call_close = &call_close,
        .call_configure = &call_configure,
        .call_decode = &call_decode,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioDecoder has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AudioDecoderImpl, "init") and @hasDecl(AudioDecoderImpl, "initOwn")) @compileError("AudioDecoderImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioDecoderImpl, "init")) return AudioDecoderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AudioDecoderImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AudioDecoderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioDecoderImpl, "init")) return false;
        if (comptime @hasDecl(AudioDecoderImpl, "construction_args")) {
            inline for (AudioDecoderImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioDecoderImpl, "deinit") and @hasDecl(AudioDecoderImpl, "deinitOwn")) @compileError("AudioDecoderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioDecoderImpl, "deinit")) return AudioDecoderImpl.deinit(instance);
        if (comptime @hasDecl(AudioDecoderImpl, "deinitOwn")) AudioDecoderImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioDecoder")) {
            if (comptime @hasDecl(impls.AudioDecoder, "installHooks")) impls.AudioDecoder.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: AudioDecoderInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioDecoderImpl.call_constructor(ctx, init_data);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!CodecState {
        return try AudioDecoderImpl.get_state(instance);
    }

    pub fn get_decodeQueueSize(instance: *runtime.Instance) anyerror!u32 {
        return try AudioDecoderImpl.get_decodeQueueSize(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_ondequeue(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AudioDecoderImpl, "get_ondequeue")) return try AudioDecoderImpl.get_ondequeue(instance);
        return event_handlers.value(EventHandler, instance, "ondequeue");
    }

    pub fn set_ondequeue(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AudioDecoderImpl, "set_ondequeue")) return try AudioDecoderImpl.set_ondequeue(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondequeue", value);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try AudioDecoderImpl.call_reset(instance);
    }

    pub fn call_configure(instance: *runtime.Instance, config: AudioDecoderConfig) anyerror!void {
        return try AudioDecoderImpl.call_configure(instance, config);
    }

    pub fn call_decode(instance: *runtime.Instance, chunk: *runtime.Instance) anyerror!void {
        return try AudioDecoderImpl.call_decode(instance, chunk);
    }

    pub fn call_flush(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AudioDecoderImpl.call_flush(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try AudioDecoderImpl.call_close(instance);
    }

    pub fn call_static_isConfigSupported(instance: *runtime.Instance, config: AudioDecoderConfig) anyerror!runtime.JSValue {
        return try AudioDecoderImpl.call_static_isConfigSupported(instance, config);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_flush",
        "call_static_isConfigSupported",
    };
};
