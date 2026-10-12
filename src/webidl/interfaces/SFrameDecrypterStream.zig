//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameDecrypterStreamImpl = @import("impls").SFrameDecrypterStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const GenericTransformStream = @import("mixins").GenericTransformStream;
const SFrameKeyManagement = @import("mixins").SFrameKeyManagement;
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

pub const SFrameDecrypterStream = struct {
    pub const Meta = struct {
        pub const name = "SFrameDecrypterStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            GenericTransformStream,
            SFrameKeyManagement,
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
            .{ "setEncryptionKey", "call_setEncryptionKey", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setEncryptionKey",
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
            _internal: ?*SFrameDecrypterStreamImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onerror = &get_onerror,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onerror = &set_onerror,

        .call_setEncryptionKey = &call_setEncryptionKey,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SFrameDecrypterStream has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SFrameDecrypterStreamImpl, "init") and @hasDecl(SFrameDecrypterStreamImpl, "initOwn")) @compileError("SFrameDecrypterStreamImpl defines both init and initOwn");
        if (comptime @hasDecl(SFrameDecrypterStreamImpl, "init")) return SFrameDecrypterStreamImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SFrameDecrypterStreamImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SFrameDecrypterStreamImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SFrameDecrypterStreamImpl, "init")) return false;
        if (comptime @hasDecl(SFrameDecrypterStreamImpl, "construction_args")) {
            inline for (SFrameDecrypterStreamImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SFrameDecrypterStreamImpl, "deinit") and @hasDecl(SFrameDecrypterStreamImpl, "deinitOwn")) @compileError("SFrameDecrypterStreamImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SFrameDecrypterStreamImpl, "deinit")) return SFrameDecrypterStreamImpl.deinit(instance);
        if (comptime @hasDecl(SFrameDecrypterStreamImpl, "deinitOwn")) SFrameDecrypterStreamImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SFrameDecrypterStream")) {
            if (comptime @hasDecl(impls.SFrameDecrypterStream, "installHooks")) impls.SFrameDecrypterStream.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(SFrameTransformOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SFrameDecrypterStreamImpl.call_constructor(ctx, options);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SFrameDecrypterStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SFrameDecrypterStreamImpl.get_writable(instance);
    }

    pub const get_onerror = mixins.SFrameKeyManagement.get_onerror;
    pub const set_onerror = mixins.SFrameKeyManagement.set_onerror;

    pub const call_setEncryptionKey = mixins.SFrameKeyManagement.call_setEncryptionKey;

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_setEncryptionKey",
    };
};
