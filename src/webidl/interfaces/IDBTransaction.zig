//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-28T18:57:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBTransactionImpl = @import("impls").IDBTransaction;
const mixins = @import("mixins");
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
        pub const BaseType = *EventTarget;
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            objectStoreNames: *runtime.Instance = undefined,
            mode: IDBTransactionMode = undefined,
            durability: IDBTransactionDurability = undefined,
            db: *runtime.Instance = undefined,
            @"error": ?*runtime.Instance = null,
            onabort: EventHandler = undefined,
            oncomplete: EventHandler = undefined,
            onerror: EventHandler = undefined,
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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBTransactionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBTransactionImpl.deinit(instance);
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
        return value;
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try IDBTransactionImpl.get_error(instance);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBTransactionImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBTransactionImpl.set_onabort(instance, value);
    }

    pub fn get_oncomplete(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBTransactionImpl.get_oncomplete(instance);
    }

    pub fn set_oncomplete(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBTransactionImpl.set_oncomplete(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBTransactionImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBTransactionImpl.set_onerror(instance, value);
    }

    pub fn call_objectStore(instance: *runtime.Instance, name: DOMString) anyerror!*runtime.Instance {
        
        return try IDBTransactionImpl.call_objectStore(instance, name);
    }

    pub fn call_commit(instance: *runtime.Instance) anyerror!void {
        return try IDBTransactionImpl.call_commit(instance);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try IDBTransactionImpl.call_abort(instance);
    }

};
