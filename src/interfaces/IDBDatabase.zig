//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBDatabaseImpl = @import("../impls/IDBDatabase.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        IDBDatabaseImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IDBDatabaseImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return IDBDatabaseImpl.get_name(state);
    }

    pub fn get_version(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return IDBDatabaseImpl.get_version(state);
    }

    pub fn get_objectStoreNames(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBDatabaseImpl.get_objectStoreNames(state);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBDatabaseImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBDatabaseImpl.set_onabort(state, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBDatabaseImpl.get_onclose(state);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBDatabaseImpl.set_onclose(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBDatabaseImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBDatabaseImpl.set_onerror(state, value);
    }

    pub fn get_onversionchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBDatabaseImpl.get_onversionchange(state);
    }

    pub fn set_onversionchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBDatabaseImpl.set_onversionchange(state, value);
    }

    pub fn call_deleteObjectStore(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return IDBDatabaseImpl.call_deleteObjectStore(state, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createObjectStore(instance: *runtime.Instance, name: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBDatabaseImpl.call_createObjectStore(state, name, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBDatabaseImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return IDBDatabaseImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [NewObject]
    pub fn call_transaction(instance: *runtime.Instance, storeNames: anyopaque, mode: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBDatabaseImpl.call_transaction(state, storeNames, mode, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBDatabaseImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBDatabaseImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBDatabaseImpl.call_removeEventListener(state, type_, callback, options);
    }

};
