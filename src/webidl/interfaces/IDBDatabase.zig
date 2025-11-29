//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-29T02:15:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBDatabaseImpl = @import("impls").IDBDatabase;
const mixins = @import("mixins");
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
const sequence = @import("interfaces").sequence;
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: runtime.DOMString = undefined,
            version: u64 = undefined,
            objectStoreNames: *runtime.Instance = undefined,
            onabort: EventHandler = undefined,
            onclose: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onversionchange: EventHandler = undefined,
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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBDatabaseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBDatabaseImpl.deinit(instance);
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

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBDatabaseImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBDatabaseImpl.set_onabort(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBDatabaseImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBDatabaseImpl.set_onclose(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBDatabaseImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBDatabaseImpl.set_onerror(instance, value);
    }

    pub fn get_onversionchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBDatabaseImpl.get_onversionchange(instance);
    }

    pub fn set_onversionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBDatabaseImpl.set_onversionchange(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_transaction(instance: *runtime.Instance, storeNames: *const anyopaque, mode: webidl.Opt(IDBTransactionMode), options: webidl.Opt(IDBTransactionOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBDatabaseImpl.call_transaction(instance, storeNames, mode, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createObjectStore(instance: *runtime.Instance, name: DOMString, options: webidl.Opt(IDBObjectStoreParameters)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBDatabaseImpl.call_createObjectStore(instance, name, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try IDBDatabaseImpl.call_close(instance);
    }

    pub fn call_deleteObjectStore(instance: *runtime.Instance, name: DOMString) anyerror!void {
        
        return try IDBDatabaseImpl.call_deleteObjectStore(instance, name);
    }

};
