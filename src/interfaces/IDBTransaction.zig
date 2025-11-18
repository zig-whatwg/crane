//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBTransactionImpl = @import("../impls/IDBTransaction.zig");
const EventTarget = @import("EventTarget.zig");

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
            error: ?DOMException = null,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IDBTransactionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IDBTransactionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_objectStoreNames(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.get_objectStoreNames(state);
    }

    pub fn get_mode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.get_mode(state);
    }

    pub fn get_durability(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.get_durability(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_db(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_db) |cached| {
            return cached;
        }
        const value = IDBTransactionImpl.get_db(state);
        state.cached_db = value;
        return value;
    }

    pub fn get_error(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.get_error(state);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBTransactionImpl.set_onabort(state, value);
    }

    pub fn get_oncomplete(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.get_oncomplete(state);
    }

    pub fn set_oncomplete(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBTransactionImpl.set_oncomplete(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IDBTransactionImpl.set_onerror(state, value);
    }

    pub fn call_objectStore(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return IDBTransactionImpl.call_objectStore(state, name);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBTransactionImpl.call_when(state, type_, options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.call_abort(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return IDBTransactionImpl.call_dispatchEvent(state, event);
    }

    pub fn call_commit(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBTransactionImpl.call_commit(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBTransactionImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IDBTransactionImpl.call_removeEventListener(state, type_, callback, options);
    }

};
