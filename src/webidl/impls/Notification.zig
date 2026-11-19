//! Implementation for the Notification interface
//!
//! Notifications API Standard: https://notifications.spec.whatwg.org/
//!
//! A Notification object represents a non-persistent notification (2.1): the
//! constructor runs "create a notification with a settings object" (2.2) and
//! the getters read the notification it made (3.4). Nothing displays one yet:
//! no host NotificationBackend from src/platform/ is wired into the browser,
//! so the notifications permission state is always its default ("prompt",
//! read as "default"), the constructor's in-parallel steps fire `error`
//! (3.2 step 5.1), the notification show steps never run, and the list of
//! notifications never holds one - so close() aborts at its first step.
//! TODO: ask the host's NotificationBackend for the permission state, and run
//! the show steps (fetch, display, `show`) through it, once the browser holds
//! one.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const Notification = interfaces.Notification;

pub const State = Notification.State;

pub const ImplError = error{
    NotImplemented,
};

/// The notification (2.1) this object represents, and the object's own
/// bookkeeping.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Title, body, language and tag: strings.
    title: []u8,
    body: []u8,
    language: []u8,
    tag: []u8,
    direction: enums.NotificationDirection,
    /// The navigation URL, image URL, icon URL and badge URL, serialized;
    /// null where the notification has none.
    navigation_url: ?[]u8 = null,
    image_url: ?[]u8 = null,
    icon_url: ?[]u8 = null,
    badge_url: ?[]u8 = null,
    /// The vibration pattern: a list of durations, validated and normalized.
    vibration_pattern: []u32,
    timestamp: typedefs.EpochTimeStamp,
    renotify: bool,
    silent: ?bool,
    require_interaction: bool,
    /// The data: StructuredSerializeForStorage of the options' data.
    data: []u8,
    /// The constructor's in-parallel steps (3.2 step 5) still hold this
    /// object, until their task fires `error` (or is dropped).
    kept_alive: bool = false,
    /// The [SameObject] attributes' values were made (and are traced from
    /// the object's wrapper).
    has_vibrate: bool = false,
    has_data: bool = false,
    has_actions: bool = false,

    fn deinit(self: *InternalState) void {
        const allocator = self.allocator;
        allocator.free(self.title);
        allocator.free(self.body);
        allocator.free(self.language);
        allocator.free(self.tag);
        if (self.navigation_url) |url| allocator.free(url);
        if (self.image_url) |url| allocator.free(url);
        if (self.icon_url) |url| allocator.free(url);
        if (self.badge_url) |url| allocator.free(url);
        allocator.free(self.vibration_pattern);
        allocator.free(self.data);
        allocator.destroy(self);
    }
};

const vibrate_slot: engine.TracedSlot = .{ .name = "vibrate" };
const data_slot: engine.TracedSlot = .{ .name = "data" };
const actions_slot: engine.TracedSlot = .{ .name = "actions" };

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return instance.getState(State).own._internal;
}

/// Notification's own teardown: the generated chain runs EventTarget's after
/// it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    // The [SameObject] values an object freed before it was wrapped still
    // waits to hand to its wrapper.
    if (internal.has_vibrate) engine.forgetTracedChild(instance, vibrate_slot);
    if (internal.has_data) engine.forgetTracedChild(instance, data_slot);
    if (internal.has_actions) engine.forgetTracedChild(instance, actions_slot);
    if (internal.kept_alive) {
        internal.kept_alive = false;
        engine.releasePlatformObject(instance);
    }
    internal.deinit();
    state.own._internal = null;
}

/// The getting the notifications permission state steps (2.10): the
/// permission state for "notifications", with "prompt" read as "default".
/// No host decides it yet (the module comment), so it is the permission's
/// default state, "prompt".
fn notificationsPermissionState() enums.NotificationPermission {
    return ._default_;
}

/// `instance`'s relevant global object, from its realm record.
fn relevantGlobal(ctx: runtime.Context) ?*runtime.Instance {
    const record = ctx.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// The settings object's API base URL (HTML 8.1.3.1), owned by `ctx.allocator`:
/// a Window's is its document's base URL, read through the Document's
/// `baseURI`; a worker's is its script URL, which its realm records as its
/// document URL. The lookup WebSocket's constructor makes.
fn apiBaseURL(ctx: runtime.Context) ?[]u8 {
    if (relevantGlobal(ctx)) |global| {
        if (global.stateAs(interfaces.Window.State) != null) {
            if (interfaces.Window.get_document(global) catch null) |document| {
                if (interfaces.Node.get_baseURI(document) catch null) |base| {
                    if (base.len > 0) return @constCast(base);
                    document.ctx.allocator.free(base);
                }
            }
        }
    }
    if (ctx.documentUrl()) |document_url| {
        if (document_url.len > 0) return ctx.allocator.dupe(u8, document_url) catch null;
    }
    return null;
}

/// URL's "parse `text` using `base`": the result serialized, or null on
/// failure (the create-a-notification steps then leave the URL unset).
fn parseUrl(allocator: std.mem.Allocator, text: []const u8, base: ?[]const u8) !?[]u8 {
    const api_parser = @import("api_parser");
    var parsed_base: ?@import("url_record").URLRecord = null;
    defer if (parsed_base) |*b| b.deinit();
    if (base) |b| {
        if (api_parser.parseURL(allocator, b, null)) |record| {
            parsed_base = record;
        } else |err| if (err == error.OutOfMemory) return error.OutOfMemory;
    }
    var parsed = api_parser.parseURL(allocator, text, if (parsed_base) |*b| b else null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    defer parsed.deinit();
    return try @import("url_serializer").serialize(allocator, &parsed, false);
}

/// Vibration API "validate and normalize" a vibration pattern.
fn validateAndNormalize(allocator: std.mem.Allocator, pattern: typedefs.VibratePattern) ![]u32 {
    // 1. If pattern is a list, proceed to the next step. Otherwise let list
    //    be a list holding pattern, and set pattern to list.
    const single = switch (pattern) {
        .ulong => |value| [1]u32{value},
        .ulong_sequence => [1]u32{0},
    };
    const entries: []const u32 = switch (pattern) {
        .ulong => single[0..],
        .ulong_sequence => |list| list,
    };
    // 2-3. Let max length be 10; truncate pattern to its first max length
    //      entries.
    const max_length = 10;
    const kept = try allocator.dupe(u32, entries[0..@min(entries.len, max_length)]);
    // 4-5. Let max duration be 10000; an entry above it becomes max duration.
    const max_duration = 10000;
    for (kept) |*entry| entry.* = @min(entry.*, max_duration);
    // 6. Return pattern.
    return kept;
}

/// Whether the settings object of `ctx` has its cross-origin isolated
/// capability.
fn crossOriginIsolated(ctx: runtime.Context) bool {
    const global = relevantGlobal(ctx) orelse return false;
    const settings = @import("dom").global_settings.of(global) orelse return false;
    return settings.cross_origin_isolated(global);
}

/// "Create a notification with a settings object" (2.2), given title,
/// options and the settings object of `ctx`, then "create a notification":
/// the notification, owned by the caller.
fn createNotificationWithSettings(ctx: runtime.Context, title: []const u8, options: dictionaries.NotificationOptions) !*InternalState {
    const allocator = ctx.allocator;
    // 1. Let origin be settings's origin. (Kept by the object's realm: the
    //    show steps, which compare it, never run yet - the module comment.)
    // 2. Let baseURL be settings's API base URL.
    const base_url = apiBaseURL(ctx);
    defer if (base_url) |b| allocator.free(b);
    // 3. Let fallbackTimestamp be the number of milliseconds from the Unix
    //    epoch to settings's current wall time, rounded to the nearest
    //    integer. The current wall time is the wall clock's unsafe current
    //    time coarsened with settings's cross-origin isolated capability.
    const hr_time = @import("hr_time");
    const isolated = crossOriginIsolated(ctx);
    const wall = hr_time.coarsenTime(hr_time.WallClock.unsafeCurrentTime(), isolated);
    const fallback_timestamp: typedefs.EpochTimeStamp = @intFromFloat(@max(0, @round(hr_time.toMilliseconds(wall))));
    // 4. Return the result of creating a notification given title, options,
    //    origin, baseURL and fallbackTimestamp.
    return createNotification(allocator, ctx, title, options, base_url, fallback_timestamp);
}

/// A DOMString member's value: its default, the empty string, when absent.
fn domString(member: ?runtime.DOMString) []const u8 {
    return if (member) |value| value.asSlice() else "";
}

/// "Create a notification" (2.2): steps 1-21.
fn createNotification(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    title: []const u8,
    options: dictionaries.NotificationOptions,
    base_url: ?[]const u8,
    fallback_timestamp: typedefs.EpochTimeStamp,
) !*InternalState {
    // 2. If options["silent"] is true and options["vibrate"] exists, then
    //    throw a TypeError.
    if (options.silent orelse false) {
        if (options.vibrate != null) return error.TypeError;
    }
    // 3. If options["renotify"] is true and options["tag"] is the empty
    //    string, then throw a TypeError.
    if (options.renotify orelse false) {
        if (domString(options.tag).len == 0) return error.TypeError;
    }
    // 4. Set notification's data to StructuredSerializeForStorage(options
    //    ["data"]) - which throws a DataCloneError for what cannot be
    //    stored (a WebAssembly.Module, a SharedArrayBuffer). An absent data
    //    member is its default, null.
    const data = try engine.structuredSerializeForStorage(ctx, options.data orelse .null, allocator);
    errdefer allocator.free(data);

    // 1. Let notification be a new notification. (Made after the steps that
    //    throw, which create nothing observable.)
    const notification = try allocator.create(InternalState);
    errdefer allocator.destroy(notification);
    // 5. Set notification's title to title.
    const title_copy = try allocator.dupe(u8, title);
    errdefer allocator.free(title_copy);
    // 7. Set notification's language to options["lang"].
    const language = try allocator.dupe(u8, domString(options.lang));
    errdefer allocator.free(language);
    // 9. Set notification's body to options["body"].
    const body = try allocator.dupe(u8, domString(options.body));
    errdefer allocator.free(body);
    // 11. Set notification's tag to options["tag"].
    const tag = try allocator.dupe(u8, domString(options.tag));
    errdefer allocator.free(tag);
    // 15. If options["vibrate"] exists, then validate and normalize it and
    //     set notification's vibration pattern to the return value.
    const vibration_pattern: []u32 = if (options.vibrate) |pattern| try validateAndNormalize(allocator, pattern) else try allocator.alloc(u32, 0);
    errdefer allocator.free(vibration_pattern);

    notification.* = .{
        .allocator = allocator,
        .title = title_copy,
        .body = body,
        .language = language,
        .tag = tag,
        // 6. Set notification's direction to options["dir"].
        .direction = options.dir orelse ._auto_,
        .vibration_pattern = vibration_pattern,
        // 16. If options["timestamp"] exists, then set notification's
        //     timestamp to the value. Otherwise, set it to fallbackTimestamp.
        .timestamp = options.timestamp orelse fallback_timestamp,
        // 17. Set notification's renotify preference to options["renotify"].
        .renotify = options.renotify orelse false,
        // 18. Set notification's silent preference to options["silent"].
        .silent = options.silent,
        // 19. Set notification's require interaction preference to
        //     options["requireInteraction"].
        .require_interaction = options.requireInteraction orelse false,
        .data = data,
    };
    errdefer {
        if (notification.navigation_url) |url| allocator.free(url);
        if (notification.image_url) |url| allocator.free(url);
        if (notification.icon_url) |url| allocator.free(url);
        if (notification.badge_url) |url| allocator.free(url);
    }
    // 8. Set notification's origin to origin. (Step 1 of the settings-object
    //    steps: the object's realm's.)
    // 10. If options["navigate"] exists, then parse it using baseURL, and if
    //     that does not return failure, set notification's navigation URL to
    //     the return value.
    if (options.navigate) |text| notification.navigation_url = try parseUrl(allocator, text, base_url);
    // 12-14. The same for image, icon and badge.
    if (options.image) |text| notification.image_url = try parseUrl(allocator, text, base_url);
    if (options.icon) |text| notification.icon_url = try parseUrl(allocator, text, base_url);
    if (options.badge) |text| notification.badge_url = try parseUrl(allocator, text, base_url);
    // 20. Set notification's actions to « ».
    // 21. For each entry in options["actions"], up to the maximum number of
    //     actions supported (skip any excess entries): ... The maximum is 0
    //     (maxActions: nothing displays a notification), so every entry is
    //     skipped. The constructor has already thrown for a non-empty list
    //     (3.2 step 2); a persistent notification
    //     (ServiceWorkerRegistration.showNotification) is not made yet.
    //     TODO: the actions, once a host backend supports some.
    return notification;
}

/// The constructor steps' in-parallel steps (3.2 step 5): the permission is
/// not "granted" (the module comment), so a task fires `error` on the
/// object - which they hold until then.
const ErrorTask = struct {
    notification: *runtime.Instance,
    generation: u64,

    fn queue(notification: *runtime.Instance) void {
        const loop = notification.ctx.getOptionalEventLoop() orelse return release(notification);
        const self = std.heap.c_allocator.create(ErrorTask) catch return release(notification);
        self.* = .{ .notification = notification, .generation = runtime.SlabAllocator.generationOf(notification) };
        var task: runtime.EventLoopTask = .{ .callback = &run, .context = self, .drop = &drop };
        if (relevantGlobal(notification.ctx)) |global| if (global.stateAs(interfaces.Window.State) != null) {
            task.document = global;
            task.document_generation = runtime.SlabAllocator.generationOf(global);
        };
        loop.queueTask(task);
    }

    fn live(self: *const ErrorTask) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.notification) != self.generation) return null;
        return self.notification;
    }

    fn run(data: ?*anyopaque) void {
        const self: *ErrorTask = @ptrCast(@alignCast(data orelse return));
        defer std.heap.c_allocator.destroy(self);
        const notification = self.live() orelse return;
        engine.runTaskInRealm(notification.ctx, steps, self) catch {};
        // The object went with its realm while the task ran; otherwise the
        // in-parallel steps let it go.
        if (self.live()) |still| release(still);
    }

    fn steps(data: ?*anyopaque) void {
        const self: *ErrorTask = @ptrCast(@alignCast(data orelse return));
        const notification = self.live() orelse return;
        // 5.1 ... fire an event named error on this, and abort these steps.
        @import("dom").navigables.fireSimpleEvent(notification, "error");
    }

    /// Never run: its document or loop ended. No script.
    fn drop(data: ?*anyopaque) void {
        const self: *ErrorTask = @ptrCast(@alignCast(data orelse return));
        defer std.heap.c_allocator.destroy(self);
        if (self.live()) |notification| release(notification);
    }

    fn release(notification: *runtime.Instance) void {
        const internal = getInternal(notification) orelse return;
        if (!internal.kept_alive) return;
        internal.kept_alive = false;
        engine.releasePlatformObject(notification);
    }
};

/// Constructor: new Notification(title, options) (3.2)
/// https://notifications.spec.whatwg.org/#dom-notification-notification
pub fn call_constructor(ctx: runtime.Context, title: runtime.DOMString, options_arg: webidl.Opt(dictionaries.NotificationOptions)) !*runtime.Instance {
    const options: dictionaries.NotificationOptions = if (options_arg.was_passed) options_arg.value else .{};
    // 1. If this's relevant global object is a ServiceWorkerGlobalScope
    //    object, then throw a TypeError.
    if (relevantGlobal(ctx)) |global| {
        if (std.mem.eql(u8, global.vtable.name, "ServiceWorkerGlobalScope")) return error.TypeError;
    }
    // 2. If options["actions"] is not empty, then throw a TypeError.
    if (options.actions) |actions| {
        if (actions.len > 0) return error.TypeError;
    }
    // 3. Let notification be the result of creating a notification with a
    //    settings object given title, options, and this's relevant settings
    //    object.
    const notification = try createNotificationWithSettings(ctx, title.asSlice(), options);
    errdefer notification.deinit();

    // 4. Associate this with notification.
    const instance = try Notification.init(ctx.allocator, ctx);
    instance.getState(State).own._internal = notification;

    // 5. Run these steps in parallel:
    //    1. If the result of getting the notifications permission state is
    //       not "granted", then queue a task to fire an event named error on
    //       this, and abort these steps.
    //    2. Run the notification show steps for notification - never reached
    //       yet (the module comment).
    // The steps hold this until their task has run: a keep taken before the
    // object has a wrapper is the wrapper's when the binding makes it.
    if (notificationsPermissionState() != .granted) {
        engine.keepPlatformObjectAlive(instance);
        notification.kept_alive = true;
        ErrorTask.queue(instance);
    }
    return instance;
}

/// Static getter for permission
/// Spec: https://notifications.spec.whatwg.org/#dom-notification-permission
///
/// "The static permission getter steps are to return the result of getting
/// the notifications permission state" - the current permission state for
/// "notifications", with "prompt" answered as "default" (the module comment).
pub fn get_static_permission(instance: *runtime.Instance) anyerror!enums.NotificationPermission {
    _ = instance;
    return notificationsPermissionState();
}

/// Static getter for maxActions
/// Spec: https://notifications.spec.whatwg.org/#dom-notification-maxactions
///
/// "The static maxActions getter steps are to return the maximum number of
/// actions supported." With no host NotificationBackend wired in, nothing can
/// display a notification, so none are. TODO: ask the host's backend
/// (getMaxActions) once the browser holds one.
pub fn get_static_maxActions(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return 0;
}

// onclick, onshow, onerror and onclose are the generated layer's: EventTarget's
// event handler storage (dom.event_handlers).

/// The title getter steps are to return this's notification's title.
pub fn get_title(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.title);
}

/// The dir getter steps are to return this's notification's direction.
pub fn get_dir(instance: *runtime.Instance) anyerror!enums.NotificationDirection {
    const internal = getInternal(instance) orelse return ._auto_;
    return internal.direction;
}

/// The lang getter steps are to return this's notification's language.
pub fn get_lang(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.language);
}

/// The body getter steps are to return this's notification's body.
pub fn get_body(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.body);
}

/// A URL getter's steps: the empty string when the notification has no such
/// URL, otherwise the URL, serialized.
fn urlAttribute(instance: *runtime.Instance, url: ?[]const u8) ![]const u8 {
    return instance.ctx.allocator.dupe(u8, url orelse "");
}

/// The navigate getter steps (3.4).
pub fn get_navigate(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return urlAttribute(instance, null);
    return urlAttribute(instance, internal.navigation_url);
}

/// The tag getter steps are to return this's notification's tag.
pub fn get_tag(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.tag);
}

/// The image getter steps (3.4).
pub fn get_image(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return urlAttribute(instance, null);
    return urlAttribute(instance, internal.image_url);
}

/// The icon getter steps (3.4).
pub fn get_icon(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return urlAttribute(instance, null);
    return urlAttribute(instance, internal.icon_url);
}

/// The badge getter steps (3.4).
pub fn get_badge(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return urlAttribute(instance, null);
    return urlAttribute(instance, internal.badge_url);
}

/// A [SameObject] attribute's value made on this read: `slot` keeps it from
/// now on, traced from this object's wrapper, and the binding gets a hold of
/// its own (CookieChangeEvent's frozen lists do the same).
fn keepSameObject(instance: *runtime.Instance, slot: engine.TracedSlot, made: *bool, value: engine.Owned) runtime.JSValue {
    engine.traceValue(instance, value.value, slot);
    made.* = true;
    return value.take();
}

fn frozenNumbers(ctx: runtime.Context, numbers: []const u32) !engine.Owned {
    const values = try ctx.allocator.alloc(runtime.JSValue, numbers.len);
    defer ctx.allocator.free(values);
    for (numbers, values) |number, *value| value.* = .{ .number = @floatFromInt(number) };
    return engine.createFrozenArray(ctx, values);
}

/// The vibrate getter steps are to return this's notification's vibration
/// pattern: a [SameObject] FrozenArray<unsigned long>.
pub fn get_vibrate(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.NotImplemented;
    if (internal.has_vibrate) {
        if (engine.tracedValue(instance, vibrate_slot)) |value| return value.take();
    }
    return keepSameObject(instance, vibrate_slot, &internal.has_vibrate, try frozenNumbers(instance.ctx, internal.vibration_pattern));
}

/// The timestamp getter steps are to return this's notification's
/// timestamp.
pub fn get_timestamp(instance: *runtime.Instance) anyerror!typedefs.EpochTimeStamp {
    const internal = getInternal(instance) orelse return 0;
    return internal.timestamp;
}

/// The renotify getter steps are to return this's notification's renotify
/// preference.
pub fn get_renotify(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.renotify;
}

/// The silent getter steps are to return this's notification's silent
/// preference.
pub fn get_silent(instance: *runtime.Instance) anyerror!?bool {
    const internal = getInternal(instance) orelse return null;
    return internal.silent;
}

/// The requireInteraction getter steps are to return this's notification's
/// require interaction preference.
pub fn get_requireInteraction(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.require_interaction;
}

/// The data getter steps are to return StructuredDeserialize(this's
/// notification's data, this's relevant Realm). If this throws an exception,
/// then return null. [SameObject]: deserialized once, on the first read.
pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return .null;
    if (internal.has_data) {
        if (engine.tracedValue(instance, data_slot)) |value| return value.take();
    }
    const value = engine.structuredDeserialize(instance.ctx, internal.data) catch return .null;
    return keepSameObject(instance, data_slot, &internal.has_data, value);
}

/// The actions getter steps (3.4): a frozen array of a frozen
/// NotificationAction per entry of this's notification's actions - always
/// empty for a notification the constructor made (3.2 step 2).
pub fn get_actions(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.NotImplemented;
    // 1. Let frozenActions be an empty list. 2. For each entry of this's
    //    notification's actions: none (createNotification step 21).
    // 3. Return the result of create a frozen array from frozenActions.
    if (internal.has_actions) {
        if (engine.tracedValue(instance, actions_slot)) |value| return value.take();
    }
    return keepSameObject(instance, actions_slot, &internal.has_actions, try engine.createFrozenArray(instance.ctx, &.{}));
}

/// The close() method steps are to run the close steps for this's
/// notification (2.8): 1. If the list of notifications does not contain
/// notification, then abort these steps - it never does yet, as the show
/// steps that append to it never run (the module comment).
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    _ = instance;
}

/// Operation: requestPermission
pub fn call_static_requestPermission(instance: *runtime.Instance, deprecatedCallback: webidl.Opt(callbacks.NotificationPermissionCallback)) anyerror!runtime.JSValue {
    _ = instance;
    _ = deprecatedCallback;
    return error.NotImplemented;
}
