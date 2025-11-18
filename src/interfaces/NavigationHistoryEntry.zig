//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationHistoryEntryImpl = @import("../impls/NavigationHistoryEntry.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        NavigationHistoryEntryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigationHistoryEntryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationHistoryEntryImpl.get_url(state);
    }

    pub fn get_key(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigationHistoryEntryImpl.get_key(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigationHistoryEntryImpl.get_id(state);
    }

    pub fn get_index(instance: *runtime.Instance) i64 {
        const state = instance.getState(State);
        return NavigationHistoryEntryImpl.get_index(state);
    }

    pub fn get_sameDocument(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigationHistoryEntryImpl.get_sameDocument(state);
    }

    pub fn get_ondispose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationHistoryEntryImpl.get_ondispose(state);
    }

    pub fn set_ondispose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NavigationHistoryEntryImpl.set_ondispose(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return NavigationHistoryEntryImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationHistoryEntryImpl.call_when(state, type_, options);
    }

    pub fn call_getState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationHistoryEntryImpl.call_getState(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationHistoryEntryImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationHistoryEntryImpl.call_removeEventListener(state, type_, callback, options);
    }

};
