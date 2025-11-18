//! Generated from: cookiestore.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CookieStoreImpl = @import("impls").CookieStore;
const EventTarget = @import("interfaces").EventTarget;
const Promise<CookieListItem?> = @import("interfaces").Promise<CookieListItem?>;
const CookieStoreGetOptions = @import("dictionaries").CookieStoreGetOptions;
const CookieStoreDeleteOptions = @import("dictionaries").CookieStoreDeleteOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const CookieInit = @import("dictionaries").CookieInit;
const Promise<CookieList> = @import("interfaces").Promise<CookieList>;
const EventHandler = @import("typedefs").EventHandler;

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
        .call_dispatchEvent = &call_dispatchEvent,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_removeEventListener = &call_removeEventListener,
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
        
        // Initialize the instance (Impl receives full instance)
        CookieStoreImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CookieStoreImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try CookieStoreImpl.get_onchange(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CookieStoreImpl.set_onchange(instance, value);
    }

    /// Arguments for delete (WebIDL overloading)
    pub const DeleteArgs = union(enum) {
        /// delete(name)
        USVString: runtime.USVString,
        /// delete(options)
        CookieStoreDeleteOptions: CookieStoreDeleteOptions,
    };

    pub fn call_delete(instance: *runtime.Instance, args: DeleteArgs) anyerror!anyopaque {
        switch (args) {
            .USVString => |arg| return try CookieStoreImpl.USVString(instance, arg),
            .CookieStoreDeleteOptions => |arg| return try CookieStoreImpl.CookieStoreDeleteOptions(instance, arg),
        }
    }

    /// Arguments for getAll (WebIDL overloading)
    pub const GetAllArgs = union(enum) {
        /// getAll(name)
        USVString: runtime.USVString,
        /// getAll(options)
        CookieStoreGetOptions: CookieStoreGetOptions,
    };

    pub fn call_getAll(instance: *runtime.Instance, args: GetAllArgs) anyerror!anyopaque {
        switch (args) {
            .USVString => |arg| return try CookieStoreImpl.USVString(instance, arg),
            .CookieStoreGetOptions => |arg| return try CookieStoreImpl.CookieStoreGetOptions(instance, arg),
        }
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try CookieStoreImpl.call_when(instance, type_, options);
    }

    /// Arguments for set (WebIDL overloading)
    pub const SetArgs = union(enum) {
        /// set(name, value)
        USVString_USVString: struct {
            name: runtime.USVString,
            value: runtime.USVString,
        },
        /// set(options)
        CookieInit: CookieInit,
    };

    pub fn call_set(instance: *runtime.Instance, args: SetArgs) anyerror!anyopaque {
        switch (args) {
            .USVString_USVString => |a| return try CookieStoreImpl.USVString_USVString(instance, a.name, a.value),
            .CookieInit => |arg| return try CookieStoreImpl.CookieInit(instance, arg),
        }
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try CookieStoreImpl.call_dispatchEvent(instance, event);
    }

    /// Arguments for get (WebIDL overloading)
    pub const GetArgs = union(enum) {
        /// get(name)
        USVString: runtime.USVString,
        /// get(options)
        CookieStoreGetOptions: CookieStoreGetOptions,
    };

    pub fn call_get(instance: *runtime.Instance, args: GetArgs) anyerror!anyopaque {
        switch (args) {
            .USVString => |arg| return try CookieStoreImpl.USVString(instance, arg),
            .CookieStoreGetOptions => |arg| return try CookieStoreImpl.CookieStoreGetOptions(instance, arg),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try CookieStoreImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try CookieStoreImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
