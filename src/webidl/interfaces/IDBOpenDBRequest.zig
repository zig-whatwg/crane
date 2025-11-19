//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBOpenDBRequestImpl = @import("impls").IDBOpenDBRequest;
const IDBRequest = @import("interfaces").IDBRequest;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IDBRequestReadyState = @import("enums").IDBRequestReadyState;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBTransaction = @import("interfaces").IDBTransaction;
const IDBObjectStore = @import("interfaces").IDBObjectStore;
const IDBCursor = @import("interfaces").IDBCursor;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMException = @import("interfaces").DOMException;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const IDBOpenDBRequest = struct {
    pub const Meta = struct {
        pub const name = "IDBOpenDBRequest";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *IDBRequest;
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
            onblocked: EventHandler = undefined,
            onupgradeneeded: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBOpenDBRequest, .{
        .deinit_fn = &deinit_wrapper,

        .get_error = &get_error,
        .get_onblocked = &get_onblocked,
        .get_onerror = &get_onerror,
        .get_onsuccess = &get_onsuccess,
        .get_onupgradeneeded = &get_onupgradeneeded,
        .get_readyState = &get_readyState,
        .get_result = &get_result,
        .get_source = &get_source,
        .get_transaction = &get_transaction,

        .set_onblocked = &set_onblocked,
        .set_onerror = &set_onerror,
        .set_onsuccess = &set_onsuccess,
        .set_onupgradeneeded = &set_onupgradeneeded,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return IDBOpenDBRequestImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBOpenDBRequestImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBOpenDBRequestImpl.get_result(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!DOMException {
        return try IDBOpenDBRequestImpl.get_error(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBOpenDBRequestImpl.get_source(instance);
    }

    pub fn get_transaction(instance: *runtime.Instance) anyerror!IDBTransaction {
        return try IDBOpenDBRequestImpl.get_transaction(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!IDBRequestReadyState {
        return try IDBOpenDBRequestImpl.get_readyState(instance);
    }

    pub fn get_onsuccess(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBOpenDBRequestImpl.get_onsuccess(instance);
    }

    pub fn set_onsuccess(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBOpenDBRequestImpl.set_onsuccess(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBOpenDBRequestImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBOpenDBRequestImpl.set_onerror(instance, value);
    }

    pub fn get_onblocked(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBOpenDBRequestImpl.get_onblocked(instance);
    }

    pub fn set_onblocked(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBOpenDBRequestImpl.set_onblocked(instance, value);
    }

    pub fn get_onupgradeneeded(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBOpenDBRequestImpl.get_onupgradeneeded(instance);
    }

    pub fn set_onupgradeneeded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBOpenDBRequestImpl.set_onupgradeneeded(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try IDBOpenDBRequestImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try IDBOpenDBRequestImpl.call_when(instance, @"type", options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try IDBOpenDBRequestImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try IDBOpenDBRequestImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
