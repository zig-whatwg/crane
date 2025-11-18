//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EventSourceImpl = @import("impls").EventSource;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const EventSourceInit = @import("dictionaries").EventSourceInit;

pub const EventSource = struct {
    pub const Meta = struct {
        pub const name = "EventSource";
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
            url: runtime.USVString = undefined,
            withCredentials: bool = undefined,
            readyState: u16 = undefined,
            onopen: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short CONNECTING = 0;
    pub fn get_CONNECTING() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short OPEN = 1;
    pub fn get_OPEN() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CLOSED = 2;
    pub fn get_CLOSED() u16 {
        return 2;
    }

    pub const vtable = runtime.buildVTable(EventSource, .{
        .deinit_fn = &deinit_wrapper,

        .get_CLOSED = &get_CLOSED,
        .get_CONNECTING = &get_CONNECTING,
        .get_OPEN = &get_OPEN,
        .get_onerror = &get_onerror,
        .get_onmessage = &get_onmessage,
        .get_onopen = &get_onopen,
        .get_readyState = &get_readyState,
        .get_url = &get_url,
        .get_withCredentials = &get_withCredentials,

        .set_onerror = &set_onerror,
        .set_onmessage = &set_onmessage,
        .set_onopen = &set_onopen,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
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
        EventSourceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EventSourceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString, eventSourceInitDict: EventSourceInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try EventSourceImpl.constructor(instance, url, eventSourceInitDict);
        
        return instance;
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try EventSourceImpl.get_url(instance);
    }

    pub fn get_withCredentials(instance: *runtime.Instance) anyerror!bool {
        return try EventSourceImpl.get_withCredentials(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
        return try EventSourceImpl.get_readyState(instance);
    }

    pub fn get_onopen(instance: *runtime.Instance) anyerror!EventHandler {
        return try EventSourceImpl.get_onopen(instance);
    }

    pub fn set_onopen(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EventSourceImpl.set_onopen(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try EventSourceImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EventSourceImpl.set_onmessage(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try EventSourceImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EventSourceImpl.set_onerror(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try EventSourceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try EventSourceImpl.call_when(instance, type_, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try EventSourceImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try EventSourceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try EventSourceImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
