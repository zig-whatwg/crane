//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBRequestImpl = @import("impls").IDBRequest;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IDBRequestReadyState = @import("enums").IDBRequestReadyState;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBTransaction = @import("interfaces").IDBTransaction;
const Observable = @import("interfaces").Observable;
const IDBCursor = @import("interfaces").IDBCursor;
const Event = @import("interfaces").Event;
const IDBObjectStore = @import("interfaces").IDBObjectStore;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMException = @import("interfaces").DOMException;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const IDBRequest = struct {
    pub const Meta = struct {
        pub const name = "IDBRequest";
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
            .{ "result", "get_result", null },
            .{ "error", "get_error", null },
            .{ "source", "get_source", null },
            .{ "transaction", "get_transaction", null },
            .{ "readyState", "get_readyState", null },
            .{ "onsuccess", "get_onsuccess", "set_onsuccess" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "result", "get_result", null },
            .{ "error", "get_error", null },
            .{ "source", "get_source", null },
            .{ "transaction", "get_transaction", null },
            .{ "readyState", "get_readyState", null },
            .{ "onsuccess", "get_onsuccess", "set_onsuccess" },
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
            result: *const anyopaque = undefined,
            @"error": ?*runtime.Instance = null,
            source: ?union(enum) {
                IDBObjectStore: IDBObjectStore,
                IDBIndex: IDBIndex,
                IDBCursor: IDBCursor,
            } = null,
            transaction: ?*runtime.Instance = null,
            readyState: IDBRequestReadyState = undefined,
            onsuccess: EventHandler = undefined,
            onerror: EventHandler = undefined,
            _internal: ?*IDBRequestImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_error = &get_error,
        .get_onerror = &get_onerror,
        .get_onsuccess = &get_onsuccess,
        .get_readyState = &get_readyState,
        .get_result = &get_result,
        .get_source = &get_source,
        .get_transaction = &get_transaction,

        .set_onerror = &set_onerror,
        .set_onsuccess = &set_onsuccess,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBRequestImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBRequestImpl.deinit(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBRequestImpl.get_result(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try IDBRequestImpl.get_error(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try IDBRequestImpl.get_source(instance);
    }

    pub fn get_transaction(instance: *runtime.Instance) anyerror!?*runtime.Instance {
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

};
