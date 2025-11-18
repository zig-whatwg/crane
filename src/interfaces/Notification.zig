//! Generated from: notifications.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NotificationImpl = @import("../impls/Notification.zig");
const EventTarget = @import("EventTarget.zig");

pub const Notification = struct {
    pub const Meta = struct {
        pub const name = "Notification";
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
            onclick: EventHandler = undefined,
            onshow: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onclose: EventHandler = undefined,
            title: runtime.DOMString = undefined,
            dir: NotificationDirection = undefined,
            lang: runtime.DOMString = undefined,
            body: runtime.DOMString = undefined,
            navigate: runtime.USVString = undefined,
            tag: runtime.DOMString = undefined,
            image: runtime.USVString = undefined,
            icon: runtime.USVString = undefined,
            badge: runtime.USVString = undefined,
            vibrate: FrozenArray<unsignedlong> = undefined,
            timestamp: EpochTimeStamp = undefined,
            renotify: bool = undefined,
            silent: ?bool = null,
            requireInteraction: bool = undefined,
            data: anyopaque = undefined,
            actions: FrozenArray<NotificationAction> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Notification, .{
        .deinit_fn = &deinit_wrapper,

        .get_actions = &get_actions,
        .get_badge = &get_badge,
        .get_body = &get_body,
        .get_data = &get_data,
        .get_dir = &get_dir,
        .get_icon = &get_icon,
        .get_image = &get_image,
        .get_lang = &get_lang,
        .get_maxActions = &get_maxActions,
        .get_navigate = &get_navigate,
        .get_onclick = &get_onclick,
        .get_onclose = &get_onclose,
        .get_onerror = &get_onerror,
        .get_onshow = &get_onshow,
        .get_permission = &get_permission,
        .get_renotify = &get_renotify,
        .get_requireInteraction = &get_requireInteraction,
        .get_silent = &get_silent,
        .get_tag = &get_tag,
        .get_timestamp = &get_timestamp,
        .get_title = &get_title,
        .get_vibrate = &get_vibrate,

        .set_onclick = &set_onclick,
        .set_onclose = &set_onclose,
        .set_onerror = &set_onerror,
        .set_onshow = &set_onshow,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestPermission = &call_requestPermission,
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
        NotificationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NotificationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, title: runtime.DOMString, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try NotificationImpl.constructor(state, title, options);
        
        return instance;
    }

    pub fn get_permission(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.get_permission(state);
    }

    pub fn get_maxActions(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return NotificationImpl.get_maxActions(state);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.get_onclick(state);
    }

    pub fn set_onclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NotificationImpl.set_onclick(state, value);
    }

    pub fn get_onshow(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.get_onshow(state);
    }

    pub fn set_onshow(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NotificationImpl.set_onshow(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NotificationImpl.set_onerror(state, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.get_onclose(state);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NotificationImpl.set_onclose(state, value);
    }

    pub fn get_title(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NotificationImpl.get_title(state);
    }

    pub fn get_dir(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.get_dir(state);
    }

    pub fn get_lang(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NotificationImpl.get_lang(state);
    }

    pub fn get_body(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NotificationImpl.get_body(state);
    }

    pub fn get_navigate(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return NotificationImpl.get_navigate(state);
    }

    pub fn get_tag(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NotificationImpl.get_tag(state);
    }

    pub fn get_image(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return NotificationImpl.get_image(state);
    }

    pub fn get_icon(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return NotificationImpl.get_icon(state);
    }

    pub fn get_badge(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return NotificationImpl.get_badge(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vibrate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_vibrate) |cached| {
            return cached;
        }
        const value = NotificationImpl.get_vibrate(state);
        state.cached_vibrate = value;
        return value;
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.get_timestamp(state);
    }

    pub fn get_renotify(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NotificationImpl.get_renotify(state);
    }

    pub fn get_silent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.get_silent(state);
    }

    pub fn get_requireInteraction(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NotificationImpl.get_requireInteraction(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_data(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_data) |cached| {
            return cached;
        }
        const value = NotificationImpl.get_data(state);
        state.cached_data = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_actions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_actions) |cached| {
            return cached;
        }
        const value = NotificationImpl.get_actions(state);
        state.cached_actions = value;
        return value;
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return NotificationImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPermission(instance: *runtime.Instance, deprecatedCallback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NotificationImpl.call_requestPermission(state, deprecatedCallback);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NotificationImpl.call_when(state, type_, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NotificationImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NotificationImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NotificationImpl.call_removeEventListener(state, type_, callback, options);
    }

};
