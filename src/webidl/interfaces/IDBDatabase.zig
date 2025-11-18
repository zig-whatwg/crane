//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBDatabaseImpl = @import("impls").IDBDatabase;
const EventTarget = @import("interfaces").EventTarget;
const DOMStringList = @import("interfaces").DOMStringList;
const (DOMString or sequence) = @import("interfaces").(DOMString or sequence);
const IDBTransactionOptions = @import("dictionaries").IDBTransactionOptions;
const IDBTransactionMode = @import("enums").IDBTransactionMode;
const IDBObjectStoreParameters = @import("dictionaries").IDBObjectStoreParameters;
const IDBTransaction = @import("interfaces").IDBTransaction;
const EventHandler = @import("typedefs").EventHandler;
const IDBObjectStore = @import("interfaces").IDBObjectStore;

pub const IDBDatabase = struct {
    pub const Meta = struct {
        pub const name = "IDBDatabase";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
            version: u64 = undefined,
            objectStoreNames: DOMStringList = undefined,
            onabort: EventHandler = undefined,
            onclose: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onversionchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBDatabase, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_createObjectStore = &call_createObjectStore,
        .call_deleteObjectStore = &call_deleteObjectStore,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_transaction = &call_transaction,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        IDBDatabaseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBDatabaseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try IDBDatabaseImpl.get_name(instance);
    }

    pub fn get_version(instance: *runtime.Instance) anyerror!u64 {
        return try IDBDatabaseImpl.get_version(instance);
    }

    pub fn get_objectStoreNames(instance: *runtime.Instance) anyerror!DOMStringList {
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

    pub fn call_deleteObjectStore(instance: *runtime.Instance, name: DOMString) anyerror!void {
        
        return try IDBDatabaseImpl.call_deleteObjectStore(instance, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createObjectStore(instance: *runtime.Instance, name: DOMString, options: IDBObjectStoreParameters) anyerror!IDBObjectStore {
        // [NewObject] - Caller owns the returned object
        
        return try IDBDatabaseImpl.call_createObjectStore(instance, name, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try IDBDatabaseImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try IDBDatabaseImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [NewObject]
    pub fn call_transaction(instance: *runtime.Instance, storeNames: anyopaque, mode: IDBTransactionMode, options: IDBTransactionOptions) anyerror!IDBTransaction {
        // [NewObject] - Caller owns the returned object
        
        return try IDBDatabaseImpl.call_transaction(instance, storeNames, mode, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try IDBDatabaseImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try IDBDatabaseImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try IDBDatabaseImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
