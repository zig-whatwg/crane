//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBRequestImpl = @import("impls").IDBRequest;
const EventTarget = @import("interfaces").EventTarget;
const (IDBObjectStore or IDBIndex or IDBCursor) = @import("interfaces").(IDBObjectStore or IDBIndex or IDBCursor);
const IDBRequestReadyState = @import("enums").IDBRequestReadyState;
const DOMException = @import("interfaces").DOMException;
const IDBTransaction = @import("interfaces").IDBTransaction;
const EventHandler = @import("typedefs").EventHandler;

pub const IDBRequest = struct {
    pub const Meta = struct {
        pub const name = "IDBRequest";
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
            result: anyopaque = undefined,
            error: ?DOMException = null,
            source: ?(IDBObjectStore or IDBIndex or IDBCursor) = null,
            transaction: ?IDBTransaction = null,
            readyState: IDBRequestReadyState = undefined,
            onsuccess: EventHandler = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBRequest, .{
        .deinit_fn = &deinit_wrapper,

        .get_error = &get_error,
        .get_onerror = &get_onerror,
        .get_onsuccess = &get_onsuccess,
        .get_readyState = &get_readyState,
        .get_result = &get_result,
        .get_source = &get_source,
        .get_transaction = &get_transaction,

        .set_onerror = &set_onerror,
        .set_onsuccess = &set_onsuccess,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
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
        IDBRequestImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBRequestImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBRequestImpl.get_result(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBRequestImpl.get_error(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBRequestImpl.get_source(instance);
    }

    pub fn get_transaction(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBRequestImpl.get_transaction(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!IDBRequestReadyState {
        return try IDBRequestImpl.get_readyState(instance);
    }

    pub fn get_onsuccess(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBRequestImpl.get_onsuccess(instance);
    }

    pub fn set_onsuccess(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBRequestImpl.set_onsuccess(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try IDBRequestImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IDBRequestImpl.set_onerror(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try IDBRequestImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try IDBRequestImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try IDBRequestImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try IDBRequestImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
