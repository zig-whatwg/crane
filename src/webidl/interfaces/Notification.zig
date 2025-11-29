//! Generated from: notifications.idl
//! Generated at: 2025-11-29T02:15:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NotificationImpl = @import("impls").Notification;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const NotificationAction = @import("dictionaries").NotificationAction;
const NotificationOptions = @import("dictionaries").NotificationOptions;
const unsignedlong = @import("interfaces").unsignedlong;
const USVString = @import("interfaces").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;
const NotificationPermissionCallback = @import("callbacks").NotificationPermissionCallback;
const NotificationDirection = @import("enums").NotificationDirection;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const NotificationPermission = @import("enums").NotificationPermission;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const Notification = struct {
    pub const Meta = struct {
        pub const name = "Notification";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "permission", "get_permission", null },
            .{ "maxActions", "get_maxActions", null },
            .{ "onclick", "get_onclick", "set_onclick" },
            .{ "onshow", "get_onshow", "set_onshow" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "title", "get_title", null },
            .{ "dir", "get_dir", null },
            .{ "lang", "get_lang", null },
            .{ "body", "get_body", null },
            .{ "navigate", "get_navigate", null },
            .{ "tag", "get_tag", null },
            .{ "image", "get_image", null },
            .{ "icon", "get_icon", null },
            .{ "badge", "get_badge", null },
            .{ "vibrate", "get_vibrate", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "renotify", "get_renotify", null },
            .{ "silent", "get_silent", null },
            .{ "requireInteraction", "get_requireInteraction", null },
            .{ "data", "get_data", null },
            .{ "actions", "get_actions", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "requestPermission", "call_requestPermission", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestPermission",
            "close",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "permission", "get_permission", null },
            .{ "maxActions", "get_maxActions", null },
            .{ "onclick", "get_onclick", "set_onclick" },
            .{ "onshow", "get_onshow", "set_onshow" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "title", "get_title", null },
            .{ "body", "get_body", null },
            .{ "navigate", "get_navigate", null },
            .{ "tag", "get_tag", null },
            .{ "image", "get_image", null },
            .{ "icon", "get_icon", null },
            .{ "badge", "get_badge", null },
            .{ "vibrate", "get_vibrate", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "renotify", "get_renotify", null },
            .{ "silent", "get_silent", null },
            .{ "requireInteraction", "get_requireInteraction", null },
            .{ "data", "get_data", null },
            .{ "actions", "get_actions", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "dir", "get_dir", null },
            .{ "lang", "get_lang", null },
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            vibrate: runtime.FrozenArray(unsignedlong) = undefined,
            timestamp: EpochTimeStamp = undefined,
            renotify: bool = undefined,
            silent: ?bool = null,
            requireInteraction: bool = undefined,
            data: *const anyopaque = undefined,
            actions: runtime.FrozenArray(NotificationAction) = undefined,
            cached_vibrate: ?runtime.FrozenArray(unsignedlong) = null,
            cached_data: ?*const anyopaque = null,
            cached_actions: ?runtime.FrozenArray(NotificationAction) = null,
            _internal: ?*NotificationImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .call_close = &call_close,
        .call_requestPermission = &call_requestPermission,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NotificationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NotificationImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, title: DOMString, options: webidl.Opt(NotificationOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NotificationImpl.call_constructor(allocator, ctx, title, options);
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
    pub fn get_vibrate(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_vibrate) |cached| {
            return cached;
        }
        const value = try NotificationImpl.get_vibrate(instance);
        state.own.cached_vibrate = value;
        return value;
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!EpochTimeStamp {
        return try NotificationImpl.get_timestamp(instance);
    }

    pub fn get_renotify(instance: *runtime.Instance) anyerror!bool {
        return try NotificationImpl.get_renotify(instance);
    }

    pub fn get_silent(instance: *runtime.Instance) anyerror!?bool {
        return try NotificationImpl.get_silent(instance);
    }

    pub fn get_requireInteraction(instance: *runtime.Instance) anyerror!bool {
        return try NotificationImpl.get_requireInteraction(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_data) |cached| {
            return cached;
        }
        const value = try NotificationImpl.get_data(instance);
        state.own.cached_data = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_actions(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_actions) |cached| {
            return cached;
        }
        const value = try NotificationImpl.get_actions(instance);
        state.own.cached_actions = value;
        return value;
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try NotificationImpl.call_close(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPermission(instance: *runtime.Instance, deprecatedCallback: webidl.Opt(NotificationPermissionCallback)) anyerror!*const anyopaque {
        
        return try NotificationImpl.call_requestPermission(instance, deprecatedCallback);
    }

};
