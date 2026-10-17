//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameDecryptorStreamImpl = @import("impls").SFrameDecryptorStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const GenericTransformStream = @import("mixins").GenericTransformStream;
const SFrameDecryptorManager = @import("mixins").SFrameDecryptorManager;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const ReadableStream = @import("interfaces").ReadableStream;
const SFrameTransformOptions = @import("dictionaries").SFrameTransformOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const WritableStream = @import("interfaces").WritableStream;
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SFrameDecryptorStream = struct {
    pub const Meta = struct {
        pub const name = "SFrameDecryptorStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            GenericTransformStream,
            SFrameDecryptorManager,
        };
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
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addDecryptionKey", "call_addDecryptionKey", 2 },
            .{ "removeDecryptionKey", "call_removeDecryptionKey", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addDecryptionKey",
            "removeDecryptionKey",
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
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            readable: *runtime.Instance = undefined,
            writable: *runtime.Instance = undefined,
            onerror: typedefs.EventHandler = undefined,
            _internal: ?*SFrameDecryptorStreamImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onerror = &get_onerror,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onerror = &set_onerror,

        .call_addDecryptionKey = &call_addDecryptionKey,
        .call_removeDecryptionKey = &call_removeDecryptionKey,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SFrameDecryptorStream has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "init") and @hasDecl(SFrameDecryptorStreamImpl, "initOwn")) @compileError("SFrameDecryptorStreamImpl defines both init and initOwn");
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "init")) return SFrameDecryptorStreamImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SFrameDecryptorStreamImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "init")) return false;
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "construction_args")) {
            inline for (SFrameDecryptorStreamImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "deinit") and @hasDecl(SFrameDecryptorStreamImpl, "deinitOwn")) @compileError("SFrameDecryptorStreamImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "deinit")) return SFrameDecryptorStreamImpl.deinit(instance);
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "deinitOwn")) SFrameDecryptorStreamImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SFrameDecryptorStream")) {
            if (comptime @hasDecl(impls.SFrameDecryptorStream, "installHooks")) impls.SFrameDecryptorStream.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: SFrameTransformOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SFrameDecryptorStreamImpl.call_constructor(ctx, options);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SFrameDecryptorStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SFrameDecryptorStreamImpl.get_writable(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "get_onerror")) return try SFrameDecryptorStreamImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SFrameDecryptorStreamImpl, "set_onerror")) return try SFrameDecryptorStreamImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn call_addDecryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
        return try SFrameDecryptorStreamImpl.call_addDecryptionKey(instance, key, keyId);
    }

    pub fn call_removeDecryptionKey(instance: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
        return try SFrameDecryptorStreamImpl.call_removeDecryptionKey(instance, keyId);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_addDecryptionKey", 0, "CryptoKey" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_addDecryptionKey",
        "call_removeDecryptionKey",
    };
};
