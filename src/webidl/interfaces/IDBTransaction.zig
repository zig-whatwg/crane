//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBTransactionImpl = @import("impls").IDBTransaction;
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
            objectStoreNames: DOMStringList = undefined,
            mode: IDBTransactionMode = undefined,
            durability: IDBTransactionDurability = undefined,
            db: IDBDatabase = undefined,
            @"error": ?DOMException = null,
            onabort: EventHandler = undefined,
            oncomplete: EventHandler = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBTransaction, .{
        .deinit_fn = &deinit_wrapper,

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
        .call_addEventListener = &call_addEventListener,
        .call_commit = &call_commit,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_objectStore = &call_objectStore,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return IDBTransactionImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBTransactionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_objectStoreNames(instance: *runtime.Instance) anyerror!DOMStringList {
        return try IDBTransactionImpl.get_objectStoreNames(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!IDBTransactionMode {
        return try IDBTransactionImpl.get_mode(instance);
    }

    pub fn get_durability(instance: *runtime.Instance) anyerror!IDBTransactionDurability {
        return try IDBTransactionImpl.get_durability(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_db(instance: *runtime.Instance) anyerror!IDBDatabase {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_db) |cached| {
            return cached;
        }
        const value = try IDBTransactionImpl.get_db(instance);
        state.cached_db = value;
        return value;
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!DOMException {
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

    pub fn call_objectStore(instance: *runtime.Instance, name: DOMString) anyerror!IDBObjectStore {
        
        return try IDBTransactionImpl.call_objectStore(instance, name);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try IDBTransactionImpl.call_when(instance, @"type", options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try IDBTransactionImpl.call_abort(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try IDBTransactionImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_commit(instance: *runtime.Instance) anyerror!void {
        return try IDBTransactionImpl.call_commit(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try IDBTransactionImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try IDBTransactionImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
