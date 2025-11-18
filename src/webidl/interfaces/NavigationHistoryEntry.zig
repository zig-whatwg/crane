//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationHistoryEntryImpl = @import("impls").NavigationHistoryEntry;
const EventTarget = @import("interfaces").EventTarget;
const USVString = @import("interfaces").USVString;
const EventHandler = @import("typedefs").EventHandler;

pub const NavigationHistoryEntry = struct {
    pub const Meta = struct {
        pub const name = "NavigationHistoryEntry";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            url: ?runtime.USVString = null,
            key: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            index: i64 = undefined,
            sameDocument: bool = undefined,
            ondispose: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigationHistoryEntry, .{
        .deinit_fn = &deinit_wrapper,

        .get_id = &get_id,
        .get_index = &get_index,
        .get_key = &get_key,
        .get_ondispose = &get_ondispose,
        .get_sameDocument = &get_sameDocument,
        .get_url = &get_url,

        .set_ondispose = &set_ondispose,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getState = &call_getState,
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
        NavigationHistoryEntryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationHistoryEntryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationHistoryEntryImpl.get_url(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigationHistoryEntryImpl.get_key(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigationHistoryEntryImpl.get_id(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
        return try NavigationHistoryEntryImpl.get_index(instance);
    }

    pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
        return try NavigationHistoryEntryImpl.get_sameDocument(instance);
    }

    pub fn get_ondispose(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigationHistoryEntryImpl.get_ondispose(instance);
    }

    pub fn set_ondispose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigationHistoryEntryImpl.set_ondispose(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try NavigationHistoryEntryImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try NavigationHistoryEntryImpl.call_when(instance, type_, options);
    }

    pub fn call_getState(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationHistoryEntryImpl.call_getState(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NavigationHistoryEntryImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NavigationHistoryEntryImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
