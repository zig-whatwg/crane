//! Generated from: cookiestore.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CookieStoreImpl = @import("../impls/CookieStore.zig");
const EventTarget = @import("EventTarget.zig");

pub const CookieStore = struct {
    pub const Meta = struct {
        pub const name = "CookieStore";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "ServiceWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .ServiceWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CookieStore, .{
        .deinit_fn = &deinit_wrapper,

        .get_onchange = &get_onchange,

        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_delete = &call_delete,
        .call_delete = &call_delete,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_get = &call_get,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_getAll = &call_getAll,
        .call_removeEventListener = &call_removeEventListener,
        .call_set = &call_set,
        .call_set = &call_set,
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
        CookieStoreImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CookieStoreImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CookieStoreImpl.get_onchange(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CookieStoreImpl.set_onchange(state, value);
    }

    /// Arguments for delete (WebIDL overloading)
    pub const DeleteArgs = union(enum) {
        /// delete(name)
        USVString: runtime.USVString,
        /// delete(options)
        CookieStoreDeleteOptions: anyopaque,
    };

    pub fn call_delete(instance: *runtime.Instance, args: DeleteArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .USVString => |arg| return CookieStoreImpl.USVString(state, arg),
            .CookieStoreDeleteOptions => |arg| return CookieStoreImpl.CookieStoreDeleteOptions(state, arg),
        }
    }

    /// Arguments for getAll (WebIDL overloading)
    pub const GetAllArgs = union(enum) {
        /// getAll(name)
        USVString: runtime.USVString,
        /// getAll(options)
        CookieStoreGetOptions: anyopaque,
    };

    pub fn call_getAll(instance: *runtime.Instance, args: GetAllArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .USVString => |arg| return CookieStoreImpl.USVString(state, arg),
            .CookieStoreGetOptions => |arg| return CookieStoreImpl.CookieStoreGetOptions(state, arg),
        }
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CookieStoreImpl.call_when(state, type_, options);
    }

    /// Arguments for set (WebIDL overloading)
    pub const SetArgs = union(enum) {
        /// set(name, value)
        USVString_USVString: struct {
            name: runtime.USVString,
            value: runtime.USVString,
        },
        /// set(options)
        CookieInit: anyopaque,
    };

    pub fn call_set(instance: *runtime.Instance, args: SetArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .USVString_USVString => |a| return CookieStoreImpl.USVString_USVString(state, a.name, a.value),
            .CookieInit => |arg| return CookieStoreImpl.CookieInit(state, arg),
        }
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return CookieStoreImpl.call_dispatchEvent(state, event);
    }

    /// Arguments for get (WebIDL overloading)
    pub const GetArgs = union(enum) {
        /// get(name)
        USVString: runtime.USVString,
        /// get(options)
        CookieStoreGetOptions: anyopaque,
    };

    pub fn call_get(instance: *runtime.Instance, args: GetArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .USVString => |arg| return CookieStoreImpl.USVString(state, arg),
            .CookieStoreGetOptions => |arg| return CookieStoreImpl.CookieStoreGetOptions(state, arg),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CookieStoreImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CookieStoreImpl.call_removeEventListener(state, type_, callback, options);
    }

};
