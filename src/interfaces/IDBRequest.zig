//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBRequestImpl = @import("../impls/IDBRequest.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        IDBRequestImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IDBRequestImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRequestImpl.get_result(state);
    }

    pub fn get_error(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRequestImpl.get_error(state);
    }

    pub fn get_source(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRequestImpl.get_source(state);
    }

    pub fn get_transaction(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRequestImpl.get_transaction(state);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRequestImpl.get_readyState(state);
    }

    pub fn get_onsuccess(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRequestImpl.get_onsuccess(state);
    }

    pub fn set_onsuccess(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBRequestImpl.set_onsuccess(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRequestImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBRequestImpl.set_onerror(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return IDBRequestImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBRequestImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBRequestImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBRequestImpl.call_removeEventListener(state, type_, callback, options);
    }

};
