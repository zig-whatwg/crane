//! Generated from: notifications.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NotificationImpl = @import("impls").Notification;
const EventTarget = @import("interfaces").EventTarget;
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;
const NotificationPermissionCallback = @import("callbacks").NotificationPermissionCallback;
const NotificationDirection = @import("enums").NotificationDirection;
const FrozenArray<NotificationAction> = @import("interfaces").FrozenArray<NotificationAction>;
const NotificationOptions = @import("dictionaries").NotificationOptions;
const boolean = @import("interfaces").boolean;
const NotificationPermission = @import("enums").NotificationPermission;
const Promise<NotificationPermission> = @import("interfaces").Promise<NotificationPermission>;
const EventHandler = @import("typedefs").EventHandler;
const FrozenArray<unsignedlong> = @import("interfaces").FrozenArray<unsignedlong>;

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
        
        // Initialize the instance (Impl receives full instance)
        NotificationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NotificationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, title: DOMString, options: NotificationOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try NotificationImpl.constructor(instance, title, options);
        
        return instance;
    }

    pub fn get_permission(instance: *runtime.Instance) anyerror!NotificationPermission {
        return try NotificationImpl.get_permission(instance);
    }

    pub fn get_maxActions(instance: *runtime.Instance) anyerror!u32 {
        return try NotificationImpl.get_maxActions(instance);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try NotificationImpl.get_onclick(instance);
    }

    pub fn set_onclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NotificationImpl.set_onclick(instance, value);
    }

    pub fn get_onshow(instance: *runtime.Instance) anyerror!EventHandler {
        return try NotificationImpl.get_onshow(instance);
    }

    pub fn set_onshow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NotificationImpl.set_onshow(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try NotificationImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NotificationImpl.set_onerror(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try NotificationImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NotificationImpl.set_onclose(instance, value);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!DOMString {
        return try NotificationImpl.get_title(instance);
    }

    pub fn get_dir(instance: *runtime.Instance) anyerror!NotificationDirection {
        return try NotificationImpl.get_dir(instance);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!DOMString {
        return try NotificationImpl.get_lang(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!DOMString {
        return try NotificationImpl.get_body(instance);
    }

    pub fn get_navigate(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NotificationImpl.get_navigate(instance);
    }

    pub fn get_tag(instance: *runtime.Instance) anyerror!DOMString {
        return try NotificationImpl.get_tag(instance);
    }

    pub fn get_image(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NotificationImpl.get_image(instance);
    }

    pub fn get_icon(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NotificationImpl.get_icon(instance);
    }

    pub fn get_badge(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NotificationImpl.get_badge(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vibrate(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_vibrate) |cached| {
            return cached;
        }
        const value = try NotificationImpl.get_vibrate(instance);
        state.cached_vibrate = value;
        return value;
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!EpochTimeStamp {
        return try NotificationImpl.get_timestamp(instance);
    }

    pub fn get_renotify(instance: *runtime.Instance) anyerror!bool {
        return try NotificationImpl.get_renotify(instance);
    }

    pub fn get_silent(instance: *runtime.Instance) anyerror!anyopaque {
        return try NotificationImpl.get_silent(instance);
    }

    pub fn get_requireInteraction(instance: *runtime.Instance) anyerror!bool {
        return try NotificationImpl.get_requireInteraction(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_data(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_data) |cached| {
            return cached;
        }
        const value = try NotificationImpl.get_data(instance);
        state.cached_data = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_actions(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_actions) |cached| {
            return cached;
        }
        const value = try NotificationImpl.get_actions(instance);
        state.cached_actions = value;
        return value;
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try NotificationImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPermission(instance: *runtime.Instance, deprecatedCallback: NotificationPermissionCallback) anyerror!anyopaque {
        
        return try NotificationImpl.call_requestPermission(instance, deprecatedCallback);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try NotificationImpl.call_when(instance, type_, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try NotificationImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NotificationImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NotificationImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
