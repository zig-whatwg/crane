//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBDatabaseImpl = @import("impls").IDBDatabase;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IDBTransactionOptions = @import("dictionaries").IDBTransactionOptions;
const IDBTransaction = @import("interfaces").IDBTransaction;
const IDBObjectStore = @import("interfaces").IDBObjectStore;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const DOMStringList = @import("interfaces").DOMStringList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const IDBObjectStoreParameters = @import("dictionaries").IDBObjectStoreParameters;
const IDBTransactionMode = @import("enums").IDBTransactionMode;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const IDBDatabase = struct {
    pub const Meta = struct {
        pub const name = "IDBDatabase";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "version", "get_version", null },
            .{ "objectStoreNames", "get_objectStoreNames", null },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onversionchange", "get_onversionchange", "set_onversionchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "transaction", "call_transaction", 1 },
            .{ "close", "call_close", 0 },
            .{ "createObjectStore", "call_createObjectStore", 1 },
            .{ "deleteObjectStore", "call_deleteObjectStore", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "transaction",
            "close",
            "createObjectStore",
            "deleteObjectStore",
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
            .{ "name", "get_name", null },
            .{ "version", "get_version", null },
            .{ "objectStoreNames", "get_objectStoreNames", null },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onversionchange", "get_onversionchange", "set_onversionchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.DOMString = undefined,
            version: u64 = undefined,
            objectStoreNames: *runtime.Instance = undefined,
            onabort: typedefs.EventHandler = undefined,
            onclose: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            onversionchange: typedefs.EventHandler = undefined,
            _internal: ?*IDBDatabaseImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_name = &get_name,
        .get_objectStoreNames = &get_objectStoreNames,
        .get_onabort = &get_onabort,
        .get_onclose = &get_onclose,
        .get_onerror = &get_onerror,
        .get_onversionchange = &get_onversionchange,
        .get_version = &get_version,

        .set_onabort = &set_onabort,
        .set_onclose = &set_onclose,
        .set_onerror = &set_onerror,
        .set_onversionchange = &set_onversionchange,

        .call_close = &call_close,
        .call_createObjectStore = &call_createObjectStore,
        .call_deleteObjectStore = &call_deleteObjectStore,
        .call_transaction = &call_transaction,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("IDBDatabase has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(IDBDatabaseImpl, "init") and @hasDecl(IDBDatabaseImpl, "initOwn")) @compileError("IDBDatabaseImpl defines both init and initOwn");
        if (comptime @hasDecl(IDBDatabaseImpl, "init")) return IDBDatabaseImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(IDBDatabaseImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try IDBDatabaseImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IDBDatabaseImpl, "init")) return false;
        if (comptime @hasDecl(IDBDatabaseImpl, "construction_args")) {
            inline for (IDBDatabaseImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IDBDatabaseImpl, "deinit") and @hasDecl(IDBDatabaseImpl, "deinitOwn")) @compileError("IDBDatabaseImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IDBDatabaseImpl, "deinit")) return IDBDatabaseImpl.deinit(instance);
        if (comptime @hasDecl(IDBDatabaseImpl, "deinitOwn")) IDBDatabaseImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IDBDatabase")) {
            if (comptime @hasDecl(impls.IDBDatabase, "installHooks")) impls.IDBDatabase.installHooks();
        }
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try IDBDatabaseImpl.get_name(instance);
    }

    pub fn get_version(instance: *runtime.Instance) anyerror!u64 {
        return try IDBDatabaseImpl.get_version(instance);
    }

    pub fn get_objectStoreNames(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IDBDatabaseImpl.get_objectStoreNames(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBDatabaseImpl, "get_onabort")) return try IDBDatabaseImpl.get_onabort(instance);
        return event_handlers.value(EventHandler, instance, "onabort");
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBDatabaseImpl, "set_onabort")) return try IDBDatabaseImpl.set_onabort(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onabort", value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBDatabaseImpl, "get_onclose")) return try IDBDatabaseImpl.get_onclose(instance);
        return event_handlers.value(EventHandler, instance, "onclose");
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBDatabaseImpl, "set_onclose")) return try IDBDatabaseImpl.set_onclose(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onclose", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBDatabaseImpl, "get_onerror")) return try IDBDatabaseImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBDatabaseImpl, "set_onerror")) return try IDBDatabaseImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_onversionchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBDatabaseImpl, "get_onversionchange")) return try IDBDatabaseImpl.get_onversionchange(instance);
        return event_handlers.value(EventHandler, instance, "onversionchange");
    }

    pub fn set_onversionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBDatabaseImpl, "set_onversionchange")) return try IDBDatabaseImpl.set_onversionchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onversionchange", value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createObjectStore(instance: *runtime.Instance, name: DOMString, options: webidl.Opt(IDBObjectStoreParameters)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBDatabaseImpl.call_createObjectStore(instance, name, options);
    }

    pub fn call_deleteObjectStore(instance: *runtime.Instance, name: DOMString) anyerror!void {
        return try IDBDatabaseImpl.call_deleteObjectStore(instance, name);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try IDBDatabaseImpl.call_close(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_transaction(instance: *runtime.Instance, storeNames: runtime.JSValue, mode: webidl.Opt(IDBTransactionMode), options: webidl.Opt(IDBTransactionOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try IDBDatabaseImpl.call_transaction(instance, storeNames, mode, options);
    }
};
