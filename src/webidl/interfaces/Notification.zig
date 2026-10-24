//! Generated from: notifications.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NotificationImpl = @import("impls").Notification;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const NotificationAction = @import("dictionaries").NotificationAction;
const NotificationOptions = @import("dictionaries").NotificationOptions;
const USVString = @import("typedefs").USVString;
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
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
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
            .{ "requestPermission", "call_static_requestPermission", 0 },
        };

        /// Static attribute binding hints for V8Interface (JS name, getter fn name, setter fn name or null)
        pub const static_properties = .{
            .{ "permission", "get_static_permission", null },
            .{ "maxActions", "get_static_maxActions", null },
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

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_static_members = .{
            .{ "requestPermission", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onclick: typedefs.EventHandler = undefined,
            onshow: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            onclose: typedefs.EventHandler = undefined,
            title: runtime.DOMString = undefined,
            dir: enums.NotificationDirection = undefined,
            lang: runtime.DOMString = undefined,
            body: runtime.DOMString = undefined,
            navigate: runtime.USVString = undefined,
            tag: runtime.DOMString = undefined,
            image: runtime.USVString = undefined,
            icon: runtime.USVString = undefined,
            badge: runtime.USVString = undefined,
            vibrate: runtime.JSValue = undefined,
            timestamp: typedefs.EpochTimeStamp = undefined,
            renotify: bool = undefined,
            silent: ?bool = null,
            requireInteraction: bool = undefined,
            data: runtime.JSValue = undefined,
            actions: runtime.JSValue = undefined,
            cached_vibrate: ?runtime.JSValue = null,
            cached_data: ?runtime.JSValue = null,
            cached_actions: ?runtime.JSValue = null,
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
        .get_navigate = &get_navigate,
        .get_onclick = &get_onclick,
        .get_onclose = &get_onclose,
        .get_onerror = &get_onerror,
        .get_onshow = &get_onshow,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("Notification has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(NotificationImpl, "init") and @hasDecl(NotificationImpl, "initOwn")) @compileError("NotificationImpl defines both init and initOwn");
        if (comptime @hasDecl(NotificationImpl, "init")) return NotificationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(NotificationImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try NotificationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NotificationImpl, "init")) return false;
        if (comptime @hasDecl(NotificationImpl, "construction_args")) {
            inline for (NotificationImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(NotificationImpl, "deinit") and @hasDecl(NotificationImpl, "deinitOwn")) @compileError("NotificationImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(NotificationImpl, "deinit")) return NotificationImpl.deinit(instance);
        if (comptime @hasDecl(NotificationImpl, "deinitOwn")) NotificationImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Notification")) {
            if (comptime @hasDecl(impls.Notification, "installHooks")) impls.Notification.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, title: runtime.DOMString, options: webidl.Opt(NotificationOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NotificationImpl.call_constructor(ctx, title, options);
    }

    pub fn get_static_permission(instance: *runtime.Instance) anyerror!NotificationPermission {
        return try NotificationImpl.get_static_permission(instance);
    }

    pub fn get_static_maxActions(instance: *runtime.Instance) anyerror!u32 {
        return try NotificationImpl.get_static_maxActions(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onclick(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NotificationImpl, "get_onclick")) return try NotificationImpl.get_onclick(instance);
        return event_handlers.value(EventHandler, instance, "onclick");
    }

    pub fn set_onclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NotificationImpl, "set_onclick")) return try NotificationImpl.set_onclick(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onclick", value);
    }

    pub fn get_onshow(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NotificationImpl, "get_onshow")) return try NotificationImpl.get_onshow(instance);
        return event_handlers.value(EventHandler, instance, "onshow");
    }

    pub fn set_onshow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NotificationImpl, "set_onshow")) return try NotificationImpl.set_onshow(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onshow", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NotificationImpl, "get_onerror")) return try NotificationImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NotificationImpl, "set_onerror")) return try NotificationImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NotificationImpl, "get_onclose")) return try NotificationImpl.get_onclose(instance);
        return event_handlers.value(EventHandler, instance, "onclose");
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NotificationImpl, "set_onclose")) return try NotificationImpl.set_onclose(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onclose", value);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NotificationImpl.get_title(instance);
    }

    pub fn get_dir(instance: *runtime.Instance) anyerror!NotificationDirection {
        return try NotificationImpl.get_dir(instance);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NotificationImpl.get_lang(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try NotificationImpl.get_body(instance);
    }

    pub fn get_navigate(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NotificationImpl.get_navigate(instance);
    }

    pub fn get_tag(instance: *runtime.Instance) anyerror!runtime.DOMString {
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
    pub fn get_vibrate(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NotificationImpl.get_vibrate(instance);
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
    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NotificationImpl.get_data(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_actions(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NotificationImpl.get_actions(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_static_requestPermission(instance: *runtime.Instance, deprecatedCallback: webidl.Opt(NotificationPermissionCallback)) anyerror!runtime.JSValue {
        return try NotificationImpl.call_static_requestPermission(instance, deprecatedCallback);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try NotificationImpl.call_close(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onclick", "set_onshow", "set_onerror", "set_onclose" };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_static_requestPermission",
    };
};
