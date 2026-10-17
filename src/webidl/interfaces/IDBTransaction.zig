//! Generated from: IndexedDB.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBTransactionImpl = @import("impls").IDBTransaction;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IDBDatabase = @import("interfaces").IDBDatabase;
const IDBTransactionDurability = @import("enums").IDBTransactionDurability;
const IDBObjectStore = @import("interfaces").IDBObjectStore;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const DOMStringList = @import("interfaces").DOMStringList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const IDBTransactionMode = @import("enums").IDBTransactionMode;
const DOMException = @import("interfaces").DOMException;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const IDBTransaction = struct {
    pub const Meta = struct {
        pub const name = "IDBTransaction";
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
            .{ "objectStoreNames", "get_objectStoreNames", null },
            .{ "mode", "get_mode", null },
            .{ "durability", "get_durability", null },
            .{ "db", "get_db", null },
            .{ "error", "get_error", null },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "oncomplete", "get_oncomplete", "set_oncomplete" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "objectStore", "call_objectStore", 1 },
            .{ "commit", "call_commit", 0 },
            .{ "abort", "call_abort", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "objectStore",
            "commit",
            "abort",
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
            .{ "objectStoreNames", "get_objectStoreNames", null },
            .{ "mode", "get_mode", null },
            .{ "durability", "get_durability", null },
            .{ "db", "get_db", null },
            .{ "error", "get_error", null },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "oncomplete", "get_oncomplete", "set_oncomplete" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            objectStoreNames: *runtime.Instance = undefined,
            mode: enums.IDBTransactionMode = undefined,
            durability: enums.IDBTransactionDurability = undefined,
            db: *runtime.Instance = undefined,
            @"error": ?*runtime.Instance = null,
            onabort: typedefs.EventHandler = undefined,
            oncomplete: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            cached_db: ?*runtime.Instance = null,
            _internal: ?*IDBTransactionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_db = &get_db,
        .get_durability = &get_durability,
        .get_error = &get_error,
        .get_mode = &get_mode,
        .get_objectStoreNames = &get_objectStoreNames,
        .get_onabort = &get_onabort,
        .get_oncomplete = &get_oncomplete,
        .get_onerror = &get_onerror,

        .set_onabort = &set_onabort,
        .set_oncomplete = &set_oncomplete,
        .set_onerror = &set_onerror,

        .call_abort = &call_abort,
        .call_commit = &call_commit,
        .call_objectStore = &call_objectStore,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("IDBTransaction has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(IDBTransactionImpl, "init") and @hasDecl(IDBTransactionImpl, "initOwn")) @compileError("IDBTransactionImpl defines both init and initOwn");
        if (comptime @hasDecl(IDBTransactionImpl, "init")) return IDBTransactionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(IDBTransactionImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try IDBTransactionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IDBTransactionImpl, "init")) return false;
        if (comptime @hasDecl(IDBTransactionImpl, "construction_args")) {
            inline for (IDBTransactionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IDBTransactionImpl, "deinit") and @hasDecl(IDBTransactionImpl, "deinitOwn")) @compileError("IDBTransactionImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(IDBTransactionImpl, "deinit")) return IDBTransactionImpl.deinit(instance);
        if (comptime @hasDecl(IDBTransactionImpl, "deinitOwn")) IDBTransactionImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IDBTransaction")) {
            if (comptime @hasDecl(impls.IDBTransaction, "installHooks")) impls.IDBTransaction.installHooks();
        }
    }

    pub fn get_objectStoreNames(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IDBTransactionImpl.get_objectStoreNames(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!IDBTransactionMode {
        return try IDBTransactionImpl.get_mode(instance);
    }

    pub fn get_durability(instance: *runtime.Instance) anyerror!IDBTransactionDurability {
        return try IDBTransactionImpl.get_durability(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_db(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_db) |cached| {
            return cached;
        }
        const value = try IDBTransactionImpl.get_db(instance);
        state.own.cached_db = value;
        @import("dom").same_object_cache.made(instance, value, "db");
        return value;
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try IDBTransactionImpl.get_error(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBTransactionImpl, "get_onabort")) return try IDBTransactionImpl.get_onabort(instance);
        return event_handlers.value(EventHandler, instance, "onabort");
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBTransactionImpl, "set_onabort")) return try IDBTransactionImpl.set_onabort(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onabort", value);
    }

    pub fn get_oncomplete(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBTransactionImpl, "get_oncomplete")) return try IDBTransactionImpl.get_oncomplete(instance);
        return event_handlers.value(EventHandler, instance, "oncomplete");
    }

    pub fn set_oncomplete(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBTransactionImpl, "set_oncomplete")) return try IDBTransactionImpl.set_oncomplete(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncomplete", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IDBTransactionImpl, "get_onerror")) return try IDBTransactionImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IDBTransactionImpl, "set_onerror")) return try IDBTransactionImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try IDBTransactionImpl.call_abort(instance);
    }

    pub fn call_objectStore(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*runtime.Instance {
        return try IDBTransactionImpl.call_objectStore(instance, name);
    }

    pub fn call_commit(instance: *runtime.Instance) anyerror!void {
        return try IDBTransactionImpl.call_commit(instance);
    }
};
