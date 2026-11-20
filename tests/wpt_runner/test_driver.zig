//! testdriver.js's automation backend: the WebDriver remote end the WPT
//! runner plays for the page.
//!
//! testdriver.js calls `test_driver_internal`, which a vendor file points at
//! an automation backend (resources/testdriver-vendor.js, served in place of
//! the upstream empty hook). Its commands are the natives this file defines
//! on each test realm - the test document's and every frame's or popup's
//! that loads the vendor file:
//!
//!   click(element)                WebDriver 12.5.1 Element Click
//!   send_keys(element, keys)      WebDriver 12.5.3 Element Send Keys
//!   action_sequence(actions, ctx) WebDriver 15.7 Perform Actions (15.5-15.6)
//!   minimize_window(ctx)          WebDriver 11.8.4 Minimize Window
//!   set_window_rect(rect, ctx)    WebDriver 11.8.2 Set Window Rect (restores)
//!   get_window_rect(ctx)          WebDriver 11.8.1 Get Window Rect
//!   get_all_cookies(ctx)          WebDriver 14.1 Get All Cookies
//!   get_named_cookie(name, ctx)   WebDriver 14.2 Get Named Cookie
//!   delete_all_cookies(ctx)       WebDriver 14.5 Delete All Cookies
//!   get_computed_role(element)    WebDriver 12.4.9 Get Computed Role
//!   get_computed_label(element)   WebDriver 12.4.10 Get Computed Label
//!   bidi_log_subscribe(emit, global, contexts...)
//!                                 WebDriver BiDi session.subscribe for log.entryAdded
//!   bidi_log_unsubscribe(id)      WebDriver BiDi session.unsubscribe
//!
//! Each returns a promise and runs as tasks: the command's first step is a
//! task queued on the page's event loop - a command reaches the page from
//! outside it, after the tasks the page queued before it asked - and its
//! later steps run from a timer, a tick of actions per timer, each tick
//! waiting its duration before the next; the promise settles after the
//! last tick's events were dispatched. The events themselves - and every
//! default action they have - are the engine's (src/html/user_input.zig,
//! focus.zig, user_activation.zig): the remote end decides which input a
//! command is, the user agent what that input does.
//!
//! Pointer input sources (WebDriver 15.2.3): every mouse source moves the one
//! mouse; each pen or touch source is a pointer of its own (`PointerSource`,
//! its pointerId from "get a pointer id"). A tick's touch actions are one
//! touch frame (user_input.touchFrame), as a platform reports all of a touch
//! screen's contacts in one event.
//!
//! This runner has no layout. By the user's 2026-10-27 ruling, a viewport
//! pointerMove targets the document root at every coordinate. Real hosts
//! hit-test through their layout backend. Element-origin moves retain their
//! existing target/image-map handling; pointer-origin moves require zero
//! offsets.
//!
//! Lifetimes. Input commands hold elements weakly (their generation): a
//! listener can remove or collect them. Computed-name and computed-role
//! commands own their pending argument and keep the weak teardown guard.
//! Every armed timer belongs to a command in `commands`; `endTest` - run when a
//! test ends, before its page goes, and at shutdown - cancels them and gives
//! back every promise still pending.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const html = @import("html_full");
const html_core = @import("html");
const keys = @import("webdriver_keys.zig");
const cookiestore = @import("cookiestore");
const permissions = @import("permissions");

const Instance = runtime.Instance;
const JSValue = runtime.JSValue;
const user_input = html.user_input;
const focus = html.focus;
const Weak = user_input.Weak;
const BrowsingContext = html_core.window.BrowsingContext;
const browser_state = @import("dom").browser_state;
const dom = @import("dom");
const clock = @import("clock");
const log = std.log.scoped(.test_driver);

/// The vendor file, served for /resources/testdriver-vendor.js.
pub const vendor_js = @embedFile("resources/testdriver-vendor.js");

/// The URL the vendor file is served at.
pub const vendor_path = "/resources/testdriver-vendor.js";

// ============================================================================
// The driver: its natives, its commands, the session's input state
// ============================================================================

const Native = enum { click, send_keys, action_sequence, minimize_window, set_window_rect, get_window_rect, get_all_cookies, get_named_cookie, delete_all_cookies, set_permission, get_computed_role, get_computed_label, bidi_log_subscribe, bidi_log_unsubscribe };

fn nativeName(comptime native: Native) []const u8 {
    return "__crane_test_driver_" ++ @tagName(native);
}

/// A key input source's state (WebDriver 15.2.2).
const KeySource = struct {
    id: []u8,
    pressed: std.ArrayListUnmanaged([]u8) = .empty,
    alt: bool = false,
    shift: bool = false,
    ctrl: bool = false,
    meta: bool = false,

    fn deinit(self: *KeySource, allocator: std.mem.Allocator) void {
        for (self.pressed.items) |key| allocator.free(key);
        self.pressed.deinit(allocator);
        allocator.free(self.id);
    }

    fn isPressed(self: *const KeySource, key: []const u8) ?usize {
        for (self.pressed.items, 0..) |pressed, i| if (std.mem.eql(u8, pressed, key)) return i;
        return null;
    }
};

/// A pen or touch pointer input source (WebDriver 15.2.3): its id, and the
/// pointer it drives - its subtype (pointer_type), its pointerId and the
/// device's state. Self-contained, for the move of these commands into
/// src/webdriver (lane wptcfg batch 2: the runner as an in-process WebDriver
/// client) to lift as it is.
pub const PointerSource = struct {
    id: []u8,
    pointer: user_input.Pointer,

    fn destroy(self: *PointerSource, allocator: std.mem.Allocator) void {
        user_input.pointerGone(&self.pointer);
        allocator.free(self.id);
        allocator.destroy(self);
    }
};

pub const TestDriver = struct {
    allocator: std.mem.Allocator,
    builtins: [std.enums.values(Native).len]runtime.BuiltinFunction,
    commands: std.ArrayListUnmanaged(*Command) = .empty,
    /// WebDriver's input state for the test's session: every mouse source
    /// moves the one mouse (a page has one), each pen and touch source drives
    /// a pointer of its own, each key source keeps its keys.
    mouse: user_input.Pointer = .{},
    pointer_sources: std.ArrayListUnmanaged(*PointerSource) = .empty,
    keyboard: user_input.Keyboard = .{},
    key_sources: std.ArrayListUnmanaged(KeySource) = .empty,
    /// The test's BiDi session's log.entryAdded subscription, if it has one.
    log_subscription: ?*LogSubscription = null,
    next_subscription_id: u32 = 0,

    pub fn create(allocator: std.mem.Allocator) !*TestDriver {
        const self = try allocator.create(TestDriver);
        self.* = .{ .allocator = allocator, .builtins = undefined };
        inline for (comptime std.enums.values(Native), 0..) |native, i| {
            self.builtins[i] = .{ .steps = nativeSteps(native), .data = self };
        }
        return self;
    }

    pub fn destroy(self: *TestDriver) void {
        self.endTest();
        self.commands.deinit(self.allocator);
        self.key_sources.deinit(self.allocator);
        self.pointer_sources.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Define the natives on `realm`'s global, for the vendor file there.
    pub fn defineNatives(self: *TestDriver, realm: runtime.Context) void {
        inline for (comptime std.enums.values(Native), 0..) |native, i| {
            engine.defineBuiltinFunction(realm, nativeName(native), 1, &self.builtins[i]) catch |err| {
                log.warn("{s} not defined: {}", .{ nativeName(native), err });
            };
        }
    }

    /// The test is over: cancel every armed timer, give back every pending
    /// promise, and forget the session's input state. Run while the test's
    /// realms still exist.
    pub fn endTest(self: *TestDriver) void {
        if (self.log_subscription) |subscription| subscription.end();
        for (self.commands.items) |command| command.cancel();
        // A worker's queued delivery owns its own batch share and may end
        // after this command. Abandon only the command's share here.
        for (self.commands.items) |command| command.releasePermissionBatch();
        for (self.commands.items) |command| command.free();
        self.commands.clearRetainingCapacity();
        for (self.key_sources.items) |*source| source.deinit(self.allocator);
        self.key_sources.clearRetainingCapacity();
        for (self.pointer_sources.items) |source| source.destroy(self.allocator);
        self.pointer_sources.clearRetainingCapacity();
        user_input.pointerGone(&self.mouse);
        self.mouse = .{};
        self.keyboard = .{};
    }

    /// The pen or touch source `id`, made with the next free pointerId when
    /// it is new (WebDriver "get a pointer id": the smallest id >= 2 no
    /// source has; 0 and 1 are the mouse's). Null: out of memory.
    fn pointerSource(self: *TestDriver, id: []const u8, kind: user_input.PointerType) ?*PointerSource {
        for (self.pointer_sources.items) |source| if (std.mem.eql(u8, source.id, id)) return source;
        var pointer_id: i32 = 2;
        while (true) : (pointer_id += 1) {
            const taken = for (self.pointer_sources.items) |source| {
                if (source.pointer.pointer_id == pointer_id) break true;
            } else false;
            if (!taken) break;
        }
        const source = self.allocator.create(PointerSource) catch return null;
        source.* = .{
            .id = self.allocator.dupe(u8, id) catch {
                self.allocator.destroy(source);
                return null;
            },
            .pointer = .{ .pointer_id = pointer_id, .pointer_type = kind },
        };
        self.pointer_sources.append(self.allocator, source) catch {
            source.destroy(self.allocator);
            return null;
        };
        return source;
    }

    fn existingPointerSource(self: *TestDriver, id: []const u8) ?*PointerSource {
        for (self.pointer_sources.items) |source| if (std.mem.eql(u8, source.id, id)) return source;
        return null;
    }

    /// The automation's permission reset before a test: every override a
    /// set_permission made is dropped, and every status it changed told so.
    /// wptrunner's Chrome executor sends CDP Browser.resetPermissions before
    /// every test (ChromeDriverTestharnessProtocolPart.reset_browser_state,
    /// tools/wptrunner/wptrunner/executors/executorchrome.py), which Chromium
    /// implements as PermissionControllerImpl::ResetPermissionOverrides. One
    /// Browser serves every file of a runner process, so without it an
    /// override outlived the file that set it (permissions/event-model.
    /// https.html leaves geolocation "granted": a later permissions-cg.https.
    /// html in the process heard no change and timed out). As the CDP command
    /// answers once the overrides are gone, this does not wait for the
    /// notifications, which go to the documents of the test that ended.
    pub fn resetPermissions(scope: *runtime.BrowserScope) void {
        const store = scope.existing(permissions.BrowserStore) orelse return;
        const batch = store.resetOverrides() catch |err| {
            log.warn("the permission overrides were not reset: {}", .{err});
            return;
        };
        batch.release();
    }

    fn keySource(self: *TestDriver, id: []const u8) ?*KeySource {
        for (self.key_sources.items) |*source| if (std.mem.eql(u8, source.id, id)) return source;
        const copy = self.allocator.dupe(u8, id) catch return null;
        self.key_sources.append(self.allocator, .{ .id = copy }) catch {
            self.allocator.free(copy);
            return null;
        };
        return &self.key_sources.items[self.key_sources.items.len - 1];
    }

    fn removeKeySource(self: *TestDriver, id: []const u8) void {
        for (self.key_sources.items, 0..) |*source, i| {
            if (!std.mem.eql(u8, source.id, id)) continue;
            source.deinit(self.allocator);
            _ = self.key_sources.orderedRemove(i);
            return;
        }
    }

    /// WebDriver "get the global key state": every key source's modifiers.
    fn globalModifiers(self: *const TestDriver) user_input.Modifiers {
        var modifiers: user_input.Modifiers = .{};
        for (self.key_sources.items) |source| {
            modifiers.alt = modifiers.alt or source.alt;
            modifiers.shift = modifiers.shift or source.shift;
            modifiers.ctrl = modifiers.ctrl or source.ctrl;
            modifiers.meta = modifiers.meta or source.meta;
        }
        return modifiers;
    }

    fn removeCommand(self: *TestDriver, command: *Command) void {
        for (self.commands.items, 0..) |c, i| {
            if (c != command) continue;
            _ = self.commands.swapRemove(i);
            return;
        }
    }
};

// ============================================================================
// WebDriver BiDi: the log module's log.entryAdded (7.8.3.1)
// ============================================================================

/// The test session's subscription to log.entryAdded (WebDriver BiDi
/// session.subscribe, events ["log.entryAdded"], with contexts or globally),
/// and the console steps' entries waiting for delivery.
///
/// The remote end hears what a page prints the way a browser's does: the
/// Console Standard's Printer output reaches its Browser's developer console
/// (dom.developer_console, as Chrome's reaches the DevTools protocol's
/// Runtime.consoleAPICalled, which chromium-bidi turns into log.entryAdded).
/// The subscription attaches a host to it; the host keeps each message of a
/// subscribed context's realm as a log.ConsoleLogEntry and queues a task on
/// the subscriber's event loop, which emits it - testdriver's
/// `test_driver_internal.bidi.log.entry_added` listeners get the event object
/// (resources/testdriver-vendor.js parses the JSON this sends).
///
/// Deviations, stated: the entry's `args` carry primitives' values and other
/// values' types alone (`writeRemoteValue`); its `text` is what the Printer
/// printed, which equals the console steps' text (the arguments, formatted,
/// joined with spaces) outside console.group's indentation; only the
/// subscribed contexts' realms are heard (a global subscription: the realms
/// of the subscriber's agent); and no log event from before the
/// subscription is buffered.
const LogSubscription = struct {
    driver: *TestDriver,
    /// The subscriber's realm, where `emit` is called, and its window.
    realm: runtime.Context,
    window: ?Weak,
    /// testdriver-vendor.js's emitter: called with one log.Entry as JSON.
    emit: engine.CallbackFunction,
    /// The Browser whose developer console the host is attached to.
    scope: *runtime.BrowserScope,
    /// The subscribed contexts' realms; null: every realm (global).
    contexts: ?[]runtime.Context,
    /// Entries waiting for the emitting task (JSON, OWNED by the driver's
    /// allocator). Written by `report`, on the subscribed realms' thread,
    /// read by `deliver` on the same thread.
    pending: std.ArrayListUnmanaged([]u8) = .empty,
    /// The subscriber realm's timers: the emitting step is a 0 ms timer
    /// task there, cancelled when the subscription ends first.
    timer: ?runtime.TimerInterface,
    timer_id: ?runtime.TimerId = null,
    /// The subscription's id, which session.unsubscribe names.
    id: u32,

    fn host(self: *LogSubscription) dom.developer_console.Host {
        return .{ .context = self, .report = &report };
    }

    fn matches(self: *const LogSubscription, realm: runtime.Context) bool {
        // Global: the subscriber's agent's realms - its own and its frames',
        // on its thread (a worker's messages, on another, are not read).
        const contexts = self.contexts orelse return realm == self.realm or (realm.agent != null and realm.agent == self.realm.agent);
        for (contexts) |context| if (context == realm) return true;
        return false;
    }

    /// The developer console host's report, on the message's realm's thread
    /// with the console's lock held: runs no script, keeps the entry and
    /// queues the task that emits it.
    fn report(context: *anyopaque, message: *const dom.developer_console.Message) void {
        const self: *LogSubscription = @ptrCast(@alignCast(context));
        if (message.kind != .console) return;
        if (!self.matches(message.realm)) return;
        const json = consoleEntryJson(self.driver.allocator, message) catch return;
        self.pending.append(self.driver.allocator, json) catch {
            self.driver.allocator.free(json);
            return;
        };
        if (self.timer_id != null) return;
        const timer = self.timer orelse return;
        self.timer_id = timer.setTimeout(0, &fire, self);
    }

    fn fire(data: ?*anyopaque) void {
        const self: *LogSubscription = @ptrCast(@alignCast(data orelse return));
        self.timer_id = null;
        self.deliver();
    }

    /// "Emit an event" for each entry kept, in order: the emitter is called
    /// in the subscriber's realm with the entry's JSON.
    fn deliver(self: *LogSubscription) void {
        const allocator = self.driver.allocator;
        const driver = self.driver;
        // The entries to emit now, taken: a listener may print (more entries,
        // for the next step) or unsubscribe (which frees `self`).
        var batch = self.pending;
        self.pending = .empty;
        defer {
            for (batch.items) |json| allocator.free(json);
            batch.deinit(allocator);
        }
        for (batch.items) |json| {
            // The subscription ended by a listener, or its window gone:
            // nothing more is emitted.
            if (driver.log_subscription != self) return;
            if (self.window) |window| if (window.get() == null) return;
            const completion = engine.invokeCallbackFunction(self.realm, &self.emit, .undefined, &.{JSValue.fromStringRef(json)}, .rethrow) catch continue;
            switch (completion) {
                inline else => |value| value.release(),
            }
        }
    }

    /// session.unsubscribe, or the test's end: the host is detached first -
    /// once that returns no report runs - then everything is given back.
    fn end(self: *LogSubscription) void {
        const driver = self.driver;
        dom.developer_console.detach(self.scope);
        if (driver.log_subscription == self) driver.log_subscription = null;
        // The emitting step, if armed, never runs: its context is freed here.
        if (self.timer_id) |id| {
            self.timer_id = null;
            if (self.timer) |timer| _ = timer.clearTimeout(id);
        }
        for (self.pending.items) |json| driver.allocator.free(json);
        self.pending.deinit(driver.allocator);
        if (self.contexts) |contexts| driver.allocator.free(contexts);
        self.emit.release();
        driver.allocator.destroy(self);
    }
};

/// WebDriver BiDi's console steps for one Printer call: a log.EntryAdded's
/// params, a log.ConsoleLogEntry, as JSON. OWNED.
fn consoleEntryJson(allocator: std.mem.Allocator, message: *const dom.developer_console.Message) ![]u8 {
    const method = @tagName(message.level);
    // Step 1.1: the level.
    const level: []const u8 = switch (message.level) {
        .@"error", .assert => "error",
        .debug, .trace => "debug",
        .warn => "warn",
        else => "info",
    };
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    const w = &out.writer;
    try w.writeAll("{\"type\":\"console\",\"method\":");
    try writeJsonString(w, method);
    try w.writeAll(",\"level\":");
    try writeJsonString(w, level);
    try w.writeAll(",\"text\":");
    try writeJsonString(w, message.text);
    try w.print(",\"timestamp\":{d},\"source\":{{\"realm\":\"{x}\"}},\"args\":[", .{ clock.wallMillis(), @intFromPtr(message.realm) });
    // Steps 7-9: each argument serialized as a remote value.
    for (message.args, 0..) |arg, i| {
        if (i > 0) try w.writeByte(',');
        try writeRemoteValue(w, allocator, message.realm, arg);
    }
    try w.writeAll("]}");
    return out.toOwnedSlice();
}

/// WebDriver BiDi "serialize as a remote value" (7.6.3.2) for a console
/// argument, as far as the remote end can without running script (the
/// developer console's host runs none): a primitive's type and value
/// (script.PrimitiveProtocolValue), and for a symbol, a bigint or an object
/// its type alone - no handle, no properties (a stated deviation).
fn writeRemoteValue(w: *std.Io.Writer, allocator: std.mem.Allocator, realm: runtime.Context, value: JSValue) !void {
    switch (value) {
        .undefined => return w.writeAll("{\"type\":\"undefined\"}"),
        .null => return w.writeAll("{\"type\":\"null\"}"),
        .boolean => |b| return w.print("{{\"type\":\"boolean\",\"value\":{}}}", .{b}),
        .number => |n| return writeNumberValue(w, n),
        .string => |text| {
            try w.writeAll("{\"type\":\"string\",\"value\":");
            try writeJsonString(w, text.data);
            return w.writeByte('}');
        },
        .instance => return w.writeAll("{\"type\":\"object\"}"),
        .handle => {},
    }
    switch (engine.typeOf(realm, value)) {
        .undefined => try w.writeAll("{\"type\":\"undefined\"}"),
        .null => try w.writeAll("{\"type\":\"null\"}"),
        .string => {
            // A string primitive converts with no script.
            const text = engine.convertToDOMString(realm, value, allocator) catch return w.writeAll("{\"type\":\"string\"}");
            defer allocator.free(text);
            try w.writeAll("{\"type\":\"string\",\"value\":");
            try writeJsonString(w, text);
            try w.writeByte('}');
        },
        .symbol => try w.writeAll("{\"type\":\"symbol\"}"),
        .bigint => try w.writeAll("{\"type\":\"bigint\"}"),
        .boolean => try w.writeAll("{\"type\":\"boolean\"}"),
        .number => try w.writeAll("{\"type\":\"number\"}"),
        .object => try w.writeAll(if (engine.isCallable(realm, value)) "{\"type\":\"function\"}" else "{\"type\":\"object\"}"),
    }
}

/// A number's remote value: NaN, -0 and the infinities as their special
/// strings (script.SpecialNumber), every other value as a JSON number.
fn writeNumberValue(w: *std.Io.Writer, n: f64) !void {
    try w.writeAll("{\"type\":\"number\",\"value\":");
    if (std.math.isNan(n)) {
        try w.writeAll("\"NaN\"");
    } else if (std.math.isInf(n)) {
        try w.writeAll(if (n > 0) "\"Infinity\"" else "\"-Infinity\"");
    } else if (n == 0 and std.math.signbit(n)) {
        try w.writeAll("\"-0\"");
    } else {
        try w.print("{d}", .{n});
    }
    try w.writeByte('}');
}

fn writeJsonString(w: *std.Io.Writer, text: []const u8) !void {
    try w.writeByte('"');
    for (text) |c| switch (c) {
        '"' => try w.writeAll("\\\""),
        '\\' => try w.writeAll("\\\\"),
        '\n' => try w.writeAll("\\n"),
        '\r' => try w.writeAll("\\r"),
        '\t' => try w.writeAll("\\t"),
        0...0x08, 0x0b, 0x0c, 0x0e...0x1f => try w.print("\\u{x:0>4}", .{c}),
        else => try w.writeByte(c),
    };
    try w.writeByte('"');
}

/// session.subscribe for log.entryAdded: `args` are the emitter, whether the
/// subscription is global, and the contexts (WindowProxies). Returns the
/// subscription's id. One subscription per test session: a second replaces
/// the first.
fn logSubscribe(driver: *TestDriver, realm: runtime.Context, args: []const JSValue) runtime.EngineError!JSValue {
    const allocator = driver.allocator;
    const scope = realm.browserScope() orelse return error.OperationFailed;
    const emit_value = argument(args, 0);
    if (!engine.isCallable(realm, emit_value)) return error.TypeError;
    const global = switch (argument(args, 1)) {
        .boolean => |b| b,
        else => false,
    };
    var contexts: ?[]runtime.Context = null;
    if (!global) {
        const list = allocator.alloc(runtime.Context, if (args.len > 2) args.len - 2 else 0) catch return error.OperationFailed;
        for (args[@min(args.len, 2)..], 0..) |value, i| {
            // "invalid argument" for anything that is no browsing context.
            const window = windowArgument(realm, value) orelse {
                allocator.free(list);
                return error.TypeError;
            };
            list[i] = window.ctx;
        }
        contexts = list;
    }
    const emit = engine.retainValue(realm, emit_value) catch {
        if (contexts) |list| allocator.free(list);
        return error.OperationFailed;
    };
    const subscription = allocator.create(LogSubscription) catch {
        emit.release();
        if (contexts) |list| allocator.free(list);
        return error.OperationFailed;
    };
    if (driver.log_subscription) |previous| previous.end();
    driver.next_subscription_id +%= 1;
    subscription.* = .{
        .driver = driver,
        .realm = realm,
        .window = if (windowOfRealm(realm)) |w| Weak.of(w) else null,
        .emit = .{ .function = emit, .context = null },
        .scope = scope,
        .contexts = contexts,
        .timer = realm.getOptionalTimer(),
        .id = driver.next_subscription_id,
    };
    driver.log_subscription = subscription;
    dom.developer_console.attach(scope, subscription.host()) catch {
        subscription.end();
        return error.OperationFailed;
    };
    return .{ .number = @floatFromInt(subscription.id) };
}

/// session.unsubscribe of the subscription `args[0]` names.
fn logUnsubscribe(driver: *TestDriver, args: []const JSValue) runtime.EngineError!JSValue {
    const subscription = driver.log_subscription orelse return JSValue.jsUndefined;
    const id: u32 = switch (argument(args, 0)) {
        .number => |n| if (n >= 0 and n <= std.math.maxInt(u32)) @intFromFloat(n) else 0,
        else => 0,
    };
    if (id == subscription.id) subscription.end();
    return JSValue.jsUndefined;
}

// ============================================================================
// Actions (WebDriver 15.5 "Processing actions")
// ============================================================================

const SourceType = enum { none, key, pointer };
const Subtype = enum { pause, key_down, key_up, pointer_down, pointer_up, pointer_move, pointer_cancel };

/// A pointer action's properties (WebDriver 15.5 "process a pointer up or
/// pointer down action" steps 4-30, "process a pointer move action"): null
/// where the action has none.
const PointerProperties = struct {
    width: ?f64 = null,
    height: ?f64 = null,
    pressure: ?f64 = null,
    tangential_pressure: ?f64 = null,
    tilt_x: ?i32 = null,
    tilt_y: ?i32 = null,
    twist: ?i32 = null,
    altitude_angle: ?f64 = null,
    azimuth_angle: ?f64 = null,
};

const Origin = union(enum) {
    viewport,
    pointer,
    element: Weak,
};

const Action = struct {
    source_type: SourceType,
    /// The input source's id. OWNED.
    source_id: []u8,
    subtype: Subtype,
    /// A key action's raw key, one code point, UTF-8. OWNED.
    value: []u8 = &.{},
    button: u3 = 0,
    origin: Origin = .viewport,
    x: f64 = 0,
    y: f64 = 0,
    duration: ?f64 = null,
    /// A pointer action's source's subtype ("pointerType").
    pointer_type: user_input.PointerType = .mouse,
    properties: PointerProperties = .{},

    fn deinit(self: *Action, allocator: std.mem.Allocator) void {
        allocator.free(self.source_id);
        allocator.free(self.value);
    }
};

const Tick = struct {
    actions: std.ArrayListUnmanaged(Action) = .empty,

    fn deinit(self: *Tick, allocator: std.mem.Allocator) void {
        for (self.actions.items) |*action| action.deinit(allocator);
        self.actions.deinit(allocator);
    }

    /// WebDriver "compute the tick duration".
    fn duration(self: *const Tick) f64 {
        var max: f64 = 0;
        for (self.actions.items) |action| {
            const counts = action.subtype == .pause or action.subtype == .pointer_move;
            if (counts) {
                if (action.duration) |d| max = @max(max, d);
            }
        }
        return max;
    }
};

const Failure = struct {
    /// The WebDriver error code ("invalid argument").
    code: []const u8,
    message: []const u8,
};

// ============================================================================
// Commands
// ============================================================================

/// A command's queued first step. It never owns the command: `endTest` and
/// the command's own end clear `command` (Command.cancelStart), and the task
/// frees only itself - when it runs, or when its loop drops it unrun. So a
/// command freed with its test, or a driver destroyed, leaves nothing the
/// task could reach.
const StartTask = struct {
    allocator: std.mem.Allocator,
    command: ?*Command,

    fn run(context: ?*anyopaque) void {
        const self: *StartTask = @ptrCast(@alignCast(context.?));
        const command = self.command;
        self.allocator.destroy(self);
        const owner = command orelse return;
        owner.start_task = null;
        Command.fire(owner);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *StartTask = @ptrCast(@alignCast(context.?));
        if (self.command) |owner| owner.start_task = null;
        self.allocator.destroy(self);
    }
};

const Kind = enum { click, send_keys, actions, minimize, restore, get_rect, get_cookies, get_named_cookie, delete_cookies, set_permission, computed_role, computed_label };

const Command = struct {
    driver: *TestDriver,
    kind: Kind,
    /// The realm the promise is in: the caller's.
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    /// The caller's window, weakly: a command whose window closed is dropped.
    window: ?Weak,
    /// The element an input or computed-accessibility command acts on.
    element: ?Weak = null,
    /// Only computed commands retain their argument until completion.
    pending_element: ?engine.Owned = null,
    /// send_keys's text, or get_named_cookie's name. OWNED.
    text: []u8 = &.{},
    /// Where key actions go: this document's top-level traversable.
    key_document: ?Weak = null,
    /// The window a window command acts on.
    target_window: ?Weak = null,
    ticks: std.ArrayListUnmanaged(Tick) = .empty,
    next_tick: usize = 0,
    started: bool = false,
    timer: ?runtime.TimerInterface = null,
    timer_id: ?runtime.TimerId = null,
    /// send_keys's input source: removed when the command ends.
    own_key_source: ?[]u8 = null,
    permission_descriptor: ?permissions.PermissionDescriptor = null,
    permission_state: permissions.PermissionState = .prompt,
    permission_batch: ?*permissions.ChangeBatch = null,
    /// The queued task of the command's first step, until it runs.
    start_task: ?*StartTask = null,

    /// Queue the command's first step as a task on its realm's event loop.
    /// A WebDriver command reaches the page from outside it: wptrunner's
    /// testdriver posts it to the harness window, whose WebDriver client
    /// sends it to the remote end (testdriver-extra.js, the executor's
    /// message loop), so every task the page queued before it asked has run
    /// when the command's steps start - a native timer of the same turn ran
    /// ahead of them (permissions/permissions-garbage-collect.https.html:
    /// its query task made the status after the override, so the status
    /// heard no change). With no event loop, a timer as before.
    fn queueStart(self: *Command) bool {
        const loop = self.realm.getOptionalEventLoop() orelse return self.arm(0);
        const task = self.driver.allocator.create(StartTask) catch return false;
        task.* = .{ .allocator = self.driver.allocator, .command = self };
        self.start_task = task;
        loop.queueTask(.{ .callback = StartTask.run, .context = task, .drop = StartTask.drop });
        return true;
    }

    /// Forget the queued first step: the task, when it runs or is dropped,
    /// finds no command and frees itself.
    fn cancelStart(self: *Command) void {
        const task = self.start_task orelse return;
        self.start_task = null;
        task.command = null;
    }

    /// Arm the command's next step after `delay_ms`.
    fn arm(self: *Command, delay_ms: f64) bool {
        const timer = self.timer orelse return false;
        const ms: u64 = if (delay_ms <= 0) 0 else @intFromFloat(@ceil(delay_ms));
        self.timer_id = timer.setTimeout(ms, &fire, self);
        return true;
    }

    /// Cancel the armed or queued step, if any.
    fn cancel(self: *Command) void {
        self.cancelStart();
        const id = self.timer_id orelse return;
        self.timer_id = null;
        if (self.timer) |timer| _ = timer.clearTimeout(id);
    }

    /// Give the promise back unsettled and free the command. Its timer is
    /// not armed (it fired, or `cancel` ran).
    fn free(self: *Command) void {
        const allocator = self.driver.allocator;
        self.cancelStart();
        self.releasePermissionBatch();
        engine.releasePromiseCapability(&self.capability);
        if (self.pending_element) |element| element.release();
        if (self.own_key_source) |id| {
            self.driver.removeKeySource(id);
            allocator.free(id);
        }
        for (self.ticks.items) |*tick| tick.deinit(allocator);
        self.ticks.deinit(allocator);
        allocator.free(self.text);
        allocator.destroy(self);
    }

    fn releasePermissionBatch(self: *Command) void {
        const batch = self.permission_batch orelse return;
        self.permission_batch = null;
        batch.release();
    }

    /// Whether the window that asked is still some browsing context's active
    /// window: HTML's "no longer open" check, done each step.
    fn windowOpen(self: *Command) bool {
        const weak = self.window orelse return true;
        const window = weak.get() orelse return false;
        const context = browser_state.browsingContextOf(window) orelse return false;
        return !context.is_closed;
    }

    fn resolve(self: *Command, value: JSValue) void {
        engine.resolvePromise(&self.capability, value) catch |err| log.debug("resolve: {}", .{err});
        self.finish();
    }

    fn reject(self: *Command, failure: Failure) void {
        var buffer: [256]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, "{s}: {s}", .{ failure.code, failure.message }) catch failure.code;
        engine.rejectPromise(&self.capability, JSValue.fromStringRef(message)) catch |err| log.debug("reject: {}", .{err});
        self.finish();
    }

    fn finish(self: *Command) void {
        self.driver.removeCommand(self);
        self.free();
    }

    /// The timer's callback (and the first step's task): the command's next
    /// step, as a task.
    fn fire(user_data: ?*anyopaque) void {
        const self: *Command = @ptrCast(@alignCast(user_data orelse return));
        self.timer_id = null;
        if (!self.windowOpen()) {
            // The caller's window went: there is no one to tell.
            self.finish();
            return;
        }
        if (!self.started) {
            self.started = true;
            if (self.start()) |failure| return self.reject(failure);
            switch (self.kind) {
                .minimize, .restore, .get_rect => return self.resolveWindowRect(),
                .get_cookies, .get_named_cookie, .delete_cookies => return self.resolveCookies(),
                .computed_role, .computed_label => return self.resolveAccessibility(),
                else => {},
            }
        }
        if (self.kind == .set_permission) {
            // Permissions B step 7: wait for every target task to run or
            // be dropped. endTest cancels this existing timer and releases
            // the command's independent share, so no worker owns a Command.
            if (self.permission_batch) |batch| if (!batch.isDone()) {
                if (!self.arm(1)) self.reject(.{ .code = "unknown error", .message = "the realm has no timers" });
                return;
            };
            return self.resolve(JSValue.jsNull);
        }
        if (self.next_tick < self.ticks.items.len) {
            const tick = &self.ticks.items[self.next_tick];
            self.next_tick += 1;
            if (self.dispatchTick(tick)) |failure| return self.reject(failure);
            // "Wait until ... at least tick duration milliseconds have
            // passed", then the next tick - or the end - as a new task.
            if (!self.arm(tick.duration())) self.resolve(JSValue.jsUndefined);
            return;
        }
        self.resolve(JSValue.jsUndefined);
    }

    /// The command's own steps before its actions; a failure, or null.
    fn start(self: *Command) ?Failure {
        return switch (self.kind) {
            .click => self.startElementClick(),
            .send_keys => self.startElementSendKeys(),
            .actions => null,
            .minimize => self.setSystemVisibility(.hidden),
            .restore => self.setSystemVisibility(.visible),
            .get_rect, .get_cookies, .get_named_cookie, .delete_cookies, .computed_role, .computed_label => null,
            .set_permission => self.startSetPermission(),
        };
    }

    /// WebDriver 12.4.9/10's semantic computation, with the testdriver
    /// compatibility rule below. No accessibility tree is retained.
    fn resolveAccessibility(self: *Command) void {
        const weak = self.element orelse return self.reject(staleElement());
        const element = weak.get() orelse return self.reject(staleElement());
        // Harness compatibility: WPT's selector transport sends :scope for
        // an id-less detached argument, querying the document root. Instead
        // of that artifact or WebDriver's stale rejection, compute THIS node's
        // own semantics. aria-element-reflection-labelledby then checks that
        // an out-of-scope explicit label is filtered while detached.
        if (interfaces.Node.get_isConnected(element) catch false) {
            _ = knownElement(self.element) orelse return self.reject(staleElement());
        }
        const accessibility = @import("dom").accessibility;
        const options: accessibility.Options = .{ .is_focusable = html.focus.isFocusableArea };
        const allocator = self.driver.allocator;
        if (self.kind == .computed_role) {
            const value = accessibility.computedRole(allocator, element, options) catch return self.reject(outOfMemory());
            return self.resolve(JSValue.fromStringRef(value));
        }
        const value = accessibility.computedName(allocator, element, options) catch return self.reject(outOfMemory());
        defer allocator.free(value);
        self.resolve(JSValue.fromStringRef(value));
    }

    /// Permissions B.1.1 steps 5-6, after argument conversion: the target
    /// realm's Browser owns the store; the native never changes process state.
    fn startSetPermission(self: *Command) ?Failure {
        const target = (self.target_window orelse return noSuchWindow()).get() orelse return noSuchWindow();
        const descriptor = self.permission_descriptor orelse return invalid("missing permission descriptor");
        const key = permissionKeyForWindow(target, descriptor) catch return outOfMemory();
        defer if (key) |owned| target.ctx.allocator.free(owned);
        const permission_key = key orelse return invalid("the target has no permission key");
        const scope = target.ctx.browser_scope orelse return noSuchWindow();
        const store = scope.of(permissions.BrowserStore) catch return outOfMemory();
        self.permission_batch = store.set(permission_key, descriptor, self.permission_state) catch return outOfMemory();
        return null;
    }

    // ------------------------------------------------------------------------
    // Element Click (12.5.1)
    // ------------------------------------------------------------------------

    fn startElementClick(self: *Command) ?Failure {
        // Step 3: "get a known element".
        const element = knownElement(self.element) orelse return staleElement();
        // Step 4: an input in the File Upload state: invalid argument.
        if (html.form_associated.isInput(element)) {
            var buffer: [16]u8 = undefined;
            if (std.mem.eql(u8, html.form_associated.inputType(element, &buffer), "file")) {
                return .{ .code = "invalid argument", .message = "a file input cannot be clicked" };
            }
        }
        // Step 5: "Scroll into view the element's container" - the
        // element's scrollIntoView, which reads its box: in a browser that
        // updates style and layout first, and in Crane the style half
        // (Element.scrollIntoView). A style change script makes in the
        // click's handlers transitions from the style this read saw, as it
        // does from the one a browser's driver reads
        // (fullscreen/rendering/fullscreen-css-transition.html).
        _ = interfaces.Element.call_scrollIntoView(element, .notPassed()) catch {};
        // Steps 6-7: in view and not obscured - without layout, a connected
        // element is both.
        // Step 8, an option element: its container is what is clicked.
        if (html.form_associated.isElementNamed(element, "option")) return self.clickOption(element);
        // Step 8, otherwise: pointerMove to the element, pointerDown and
        // pointerUp with button 0, as one tick of a new pointer source.
        const tick = self.ticks.addOne(self.driver.allocator) catch return outOfMemory();
        tick.* = .{};
        const actions = [_]Action{
            .{ .source_type = .pointer, .source_id = &.{}, .subtype = .pointer_move, .origin = .{ .element = Weak.of(element) } },
            .{ .source_type = .pointer, .source_id = &.{}, .subtype = .pointer_down },
            .{ .source_type = .pointer, .source_id = &.{}, .subtype = .pointer_up },
        };
        for (actions) |action| {
            var copy = action;
            copy.source_id = self.driver.allocator.dupe(u8, "__click") catch return outOfMemory();
            tick.actions.append(self.driver.allocator, copy) catch {
                self.driver.allocator.free(copy.source_id);
                return outOfMemory();
            };
        }
        return null;
    }

    /// Element Click step 8 for an option element.
    fn clickOption(self: *Command, option: *Instance) ?Failure {
        const modifiers = self.driver.globalModifiers();
        // 8.1: "Let parent node be the element's container": its select.
        var container = html.form_associated.parentOf(option) orelse return null;
        if (html.form_associated.isElementNamed(container, "optgroup")) container = html.form_associated.parentOf(container) orelse return null;
        // 8.2-8.5: mouseOver, mouseMove and mouseDown at it, then the focusing steps.
        _ = user_input.fireMouseEvent(container, "mouseover", modifiers, 0, 0, 0, null);
        _ = user_input.fireMouseEvent(container, "mousemove", modifiers, 0, 0, 0, null);
        _ = user_input.fireMouseEvent(container, "mousedown", modifiers, 0, 1, 1, null);
        focus.focusingSteps(container, null, .click);
        // 8.6: "If element is not disabled": input, the selectedness, change.
        if (!(interfaces.HTMLOptionElement.get_disabled(option) catch true)) {
            html.form_associated.fireSimpleEvent(container, "input", .{ .bubbles = true, .composed = true }) catch {};
            const previous = interfaces.HTMLOptionElement.get_selected(option) catch false;
            const multiple = html.form_associated.isSelect(container) and (interfaces.HTMLSelectElement.get_multiple(container) catch false);
            interfaces.HTMLOptionElement.set_selected(option, if (multiple) !previous else true) catch {};
            if (!previous) html.form_associated.fireSimpleEvent(container, "change", .{ .bubbles = true }) catch {};
        }
        // 8.7-8.8: mouseUp and click at it.
        _ = user_input.fireMouseEvent(container, "mouseup", modifiers, 0, 0, 1, null);
        _ = user_input.fireMouseEvent(container, "click", modifiers, 0, 0, 1, null);
        return null;
    }

    // ------------------------------------------------------------------------
    // Element Send Keys (12.5.3)
    // ------------------------------------------------------------------------

    fn startElementSendKeys(self: *Command) ?Failure {
        const allocator = self.driver.allocator;
        // Step 5: "get a known element".
        const element = knownElement(self.element) orelse return staleElement();
        const document = nodeDocumentOf(element) orelse return staleElement();
        self.key_document = Weak.of(document);
        // Step 6: "Let file be true if element is input element in the file
        // upload state". With strict file interactability false (the
        // default), step 7 is skipped for it and step 8 selects the files.
        if (html.form_associated.isInput(element)) {
            var buffer: [16]u8 = undefined;
            if (std.mem.eql(u8, html.form_associated.inputType(element, &buffer), "file")) {
                return self.selectFiles(element);
            }
        }
        // Step 7.6: "If element is not keyboard-interactable": an element
        // with a focusable area, the body element, or the document element.
        const keyboard_interactable = focus.isFocusableArea(element) or
            element == (interfaces.Document.get_body(document) catch null) or
            element == (interfaces.Document.get_documentElement(document) catch null);
        if (!keyboard_interactable) return .{ .code = "element not interactable", .message = "the element cannot take keyboard input" };
        // Step 7.7: "If element is not the active element run the focusing
        // steps for the element." Step 8, otherwise: "If element does not
        // currently have focus", the caret goes to the end of its value.
        const was_focused = focus.currentlyFocusedArea(document) == element;
        if (!was_focused) focus.focusingSteps(element, null, .other);
        if (!was_focused) moveCaretToEnd(element);
        // Steps 9-13: a new key source, and "dispatch actions for a string".
        const id = allocator.dupe(u8, "__send_keys") catch return outOfMemory();
        self.own_key_source = id;
        return self.dispatchActionsForString(id);
    }

    /// Element Send Keys step 8, "file is true": the files `text` names - on
    /// this host, where the runner and the WPT server run, as the server's
    /// fs_path() substitution gives them - become `element`'s selected files.
    fn selectFiles(self: *Command, element: *Instance) ?Failure {
        const allocator = self.driver.allocator;
        const host = @import("host");
        // 8.1. "Let files be the result of splitting text on the newline
        // (\n) character."
        var paths: std.ArrayListUnmanaged([]const u8) = .empty;
        defer paths.deinit(allocator);
        var split = std.mem.splitScalar(u8, self.text, '\n');
        while (split.next()) |path| paths.append(allocator, path) catch return outOfMemory();
        // 8.2. "If files is of 0 length, return an error with error code
        // invalid argument."
        if (paths.items.len == 0) return .{ .code = "invalid argument", .message = "no file was named" };
        // 8.3-8.4. Without a multiple attribute, exactly one file.
        const multiple = interfaces.Element.call_hasAttribute(element, runtime.DOMString.initInterned("multiple")) catch false;
        if (!multiple and paths.items.len != 1) return .{ .code = "invalid argument", .message = "the input takes one file" };
        // 8.5. "Verify that each file given by the user exists": each is read
        // whole now, before any is selected.
        const contents = allocator.alloc([]u8, paths.items.len) catch return outOfMemory();
        var read: usize = 0;
        defer {
            for (contents[0..read]) |bytes| allocator.free(bytes);
            allocator.free(contents);
        }
        for (paths.items, contents) |path, *bytes| {
            if (path.len == 0 or !std.fs.path.isAbsolute(path)) return .{ .code = "invalid argument", .message = "a file path must be absolute" };
            bytes.* = host.cwd().readFileAlloc(host.io(), path, allocator, .limited(256 * 1024 * 1024)) catch |err| switch (err) {
                error.OutOfMemory => return outOfMemory(),
                else => return .{ .code = "invalid argument", .message = "a named file does not exist" },
            };
            read += 1;
        }
        // 8.6. "Complete implementation specific steps equivalent to setting
        // the selected files on the input element. If multiple is true files
        // are be appended to element's selected files." Each is a File named
        // by its path's last component, of the type "" (no platform MIME
        // mapping is consulted), in the input's realm.
        const realm = element.ctx;
        const list = (interfaces.HTMLInputElement.get_files(element) catch return outOfMemory()) orelse
            return .{ .code = "invalid argument", .message = "the input has no selected files list" };
        if (!multiple) dom.file_lists.clear(list) catch return .{ .code = "unknown error", .message = "FileList is not installed" };
        for (paths.items, contents) |path, bytes| {
            const buffer = engine.createArrayBuffer(realm, bytes) catch return outOfMemory();
            defer buffer.release();
            const parts = engine.createSequenceOfValues(realm, &.{buffer.value}) catch return outOfMemory();
            defer parts.release();
            const file = interfaces.File.call_constructor(realm, parts.value, std.fs.path.basename(path), .notPassed()) catch return outOfMemory();
            const generation = runtime.SlabAllocator.generationOf(file);
            defer file.releaseIfUnwrapped(generation);
            dom.file_lists.append(list, file) catch return outOfMemory();
        }
        // 8.7. "Fire these events in order on element: input, change" - as
        // the user agent's file selection does (HTML 4.10.5.1.18: input
        // bubbles and is composed, change bubbles).
        html.form_associated.fireSimpleEvent(element, "input", .{ .bubbles = true, .composed = true }) catch {};
        html.form_associated.fireSimpleEvent(element, "change", .{ .bubbles = true }) catch {};
        // 8.8. "Return success with data null."
        return null;
    }

    /// WebDriver "dispatch actions for a string", as ticks: the typeable
    /// characters as keyDown/keyUp pairs, Shift pressed around shifted ones,
    /// a modifier key held until the null key or the end.
    fn dispatchActionsForString(self: *Command, source_id: []const u8) ?Failure {
        var undo: std.ArrayListUnmanaged(u21) = .empty;
        defer undo.deinit(self.driver.allocator);
        var shifted = false;
        var view = std.unicode.Utf8View.init(self.text) catch return .{ .code = "invalid argument", .message = "keys is not valid UTF-8" };
        var it = view.iterator();
        while (it.nextCodepoint()) |cp| {
            if (cp == 0xE000) {
                // The null key: release the modifiers held so far.
                if (shifted) {
                    if (self.keyTick(source_id, &.{.{ .up = 0xE008 }})) |f| return f;
                    shifted = false;
                }
                for (undo.items) |modifier| if (self.keyTick(source_id, &.{.{ .up = modifier }})) |f| return f;
                undo.clearRetainingCapacity();
            } else if (keys.isModifier(cp)) {
                if (self.keyTick(source_id, &.{.{ .down = cp }})) |f| return f;
                undo.append(self.driver.allocator, cp) catch return outOfMemory();
            } else {
                // "Dispatch the events for a typeable string", a character
                // at a time (a character with no code is typed the same way:
                // Crane has no input method to compose it with).
                if (keys.isShifted(cp) and !shifted) {
                    if (self.keyTick(source_id, &.{.{ .down = 0xE008 }})) |f| return f;
                    shifted = true;
                } else if (!keys.isShifted(cp) and shifted) {
                    if (self.keyTick(source_id, &.{.{ .up = 0xE008 }})) |f| return f;
                    shifted = false;
                }
                if (self.keyTick(source_id, &.{ .{ .down = cp }, .{ .up = cp } })) |f| return f;
            }
        }
        if (shifted) {
            if (self.keyTick(source_id, &.{.{ .up = 0xE008 }})) |f| return f;
        }
        // "Clear the modifier key state": the undo actions, sorted by key.
        std.sort.pdq(u21, undo.items, {}, std.sort.asc(u21));
        for (undo.items) |modifier| if (self.keyTick(source_id, &.{.{ .up = modifier }})) |f| return f;
        return null;
    }

    const KeyStep = union(enum) { down: u21, up: u21 };

    /// One "dispatch a list of actions": a tick of key actions.
    fn keyTick(self: *Command, source_id: []const u8, steps: []const KeyStep) ?Failure {
        const allocator = self.driver.allocator;
        const tick = self.ticks.addOne(allocator) catch return outOfMemory();
        tick.* = .{};
        for (steps) |step| {
            const cp = switch (step) {
                .down, .up => |c| c,
            };
            var buffer: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(cp, &buffer) catch return .{ .code = "invalid argument", .message = "not a code point" };
            const value = allocator.dupe(u8, buffer[0..len]) catch return outOfMemory();
            const id = allocator.dupe(u8, source_id) catch {
                allocator.free(value);
                return outOfMemory();
            };
            tick.actions.append(allocator, .{
                .source_type = .key,
                .source_id = id,
                .subtype = if (step == .down) .key_down else .key_up,
                .value = value,
            }) catch {
                allocator.free(value);
                allocator.free(id);
                return outOfMemory();
            };
        }
        return null;
    }

    // ------------------------------------------------------------------------
    // Dispatching a tick (15.6)
    // ------------------------------------------------------------------------

    fn dispatchTick(self: *Command, tick: *Tick) ?Failure {
        var touched = false;
        for (tick.actions.items) |*action| {
            if (action.source_type == .pointer and action.pointer_type == .touch) {
                if (self.touchAction(action)) |failure| return failure;
                touched = true;
                continue;
            }
            if (self.dispatchAction(action)) |failure| return failure;
        }
        // The tick's touch actions happen at one moment: one touch frame,
        // every touch source's contact in it, as a touch screen reports them
        // (one platform touch event; WebDriver dispatches a tick's actions
        // together).
        if (touched) self.deliverTouchFrame();
        return null;
    }

    /// The pointer a pointer action of a mouse or pen source drives.
    fn actionPointer(self: *Command, action: *const Action) ?*user_input.Pointer {
        if (action.pointer_type == .mouse) return &self.driver.mouse;
        const source = self.driver.existingPointerSource(action.source_id) orelse return null;
        return &source.pointer;
    }

    /// The element a pointerMove action's origin and offset put the pointer
    /// over, or null to stay where it is (a pointer origin with no offset).
    fn moveTarget(self: *Command, action: *const Action) union(enum) { target: *Instance, stay, failure: Failure } {
        switch (action.origin) {
            .element => |weak| {
                // "Get a WebElement origin": a stale one is an error.
                const element = knownElement(weak) orelse return .{ .failure = staleElement() };
                // The element at the origin's in-view centre plus the
                // offset: the origin itself, or an image map's area.
                return .{ .target = user_input.hitTest(element, action.x, action.y) };
            },
            .pointer => {
                if (action.x != 0 or action.y != 0) return .{ .failure = unsupportedMove() };
                return .stay;
            },
            .viewport => {
                // User ruling, 2026-10-27: the WPT runner's explicit
                // no-layout hit test is documentElement at ANY point.
                // Reuse the action context and ordinary pointer path.
                const document = self.keyDocument() orelse return .{ .failure = noSuchWindow() };
                const root = (interfaces.Document.get_documentElement(document) catch return .{ .failure = outOfMemory() }) orelse
                    return .{ .failure = .{ .code = "no such element", .message = "the document has no root element" } };
                return .{ .target = root };
            },
        }
    }

    fn dispatchAction(self: *Command, action: *Action) ?Failure {
        const driver = self.driver;
        switch (action.subtype) {
            .pause => return null,
            .pointer_move => {
                const pointer = self.actionPointer(action) orelse return outOfMemory();
                if (action.pointer_type != .mouse) applyProperties(pointer, action.properties);
                switch (self.moveTarget(action)) {
                    .target => |target| user_input.pointerMove(pointer, target, driver.globalModifiers()),
                    .stay => {},
                    .failure => |failure| return failure,
                }
                return null;
            },
            .pointer_down => {
                const pointer = self.actionPointer(action) orelse return outOfMemory();
                if (pointer.currentTarget() == null) return unsupportedMove();
                if (action.pointer_type != .mouse) applyProperties(pointer, action.properties);
                user_input.pointerDown(pointer, action.button, driver.globalModifiers());
                return null;
            },
            .pointer_up => {
                const pointer = self.actionPointer(action) orelse return outOfMemory();
                user_input.pointerUp(pointer, action.button, driver.globalModifiers());
                return null;
            },
            // A mouse or a hovering pen has no contact to cancel: the
            // pointerCancel of a source that is not touch changes nothing
            // here (WebDriver leaves "cancelling any action of the pointer"
            // to the implementation).
            .pointer_cancel => return null,
            .key_down, .key_up => return self.dispatchKeyAction(action),
        }
    }

    /// A touch source's action in this tick: its contact's change in the
    /// tick's touch frame (`deliverTouchFrame`), and the element under it.
    fn touchAction(self: *Command, action: *Action) ?Failure {
        const source = self.driver.existingPointerSource(action.source_id) orelse return outOfMemory();
        const pointer = &source.pointer;
        switch (action.subtype) {
            .pause, .key_down, .key_up => {},
            .pointer_move => {
                applyProperties(pointer, action.properties);
                switch (self.moveTarget(action)) {
                    .target => |target| pointer.touch_hit = Weak.of(target),
                    .stay => {},
                    .failure => |failure| return failure,
                }
                // A touch out of contact has no hover: moving it only says
                // where it will touch.
                if (pointer.in_contact) pointer.touch_change = .moved;
            },
            .pointer_down => {
                // "If the source's pressed property contains button": a
                // touch already in contact.
                if (pointer.in_contact) return null;
                const hit = if (pointer.touch_hit) |weak| weak.get() else null;
                if (hit == null) return unsupportedMove();
                applyProperties(pointer, action.properties);
                pointer.touch_change = .pressed;
            },
            .pointer_up => {
                if (!pointer.in_contact) return null;
                pointer.touch_change = .released;
            },
            .pointer_cancel => {
                if (!pointer.in_contact) return null;
                pointer.touch_change = .cancelled;
            },
        }
        return null;
    }

    /// Deliver the tick's touch frame: every touch source's contact.
    fn deliverTouchFrame(self: *Command) void {
        var points: [user_input_touch_points]*user_input.Pointer = undefined;
        var count: usize = 0;
        for (self.driver.pointer_sources.items) |source| {
            if (source.pointer.pointer_type != .touch or count == points.len) continue;
            points[count] = &source.pointer;
            count += 1;
        }
        user_input.touchFrame(points[0..count], self.driver.globalModifiers());
    }

    /// WebDriver "dispatch a keyDown action" / "dispatch a keyUp action".
    fn dispatchKeyAction(self: *Command, action: *Action) ?Failure {
        const driver = self.driver;
        const source = driver.keySource(action.source_id) orelse return outOfMemory();
        const raw = firstCodePoint(action.value) orelse return .{ .code = "invalid argument", .message = "a key value is one code point" };
        // Steps 1-2: the normalized key.
        const key = keys.normalizedKey(raw, action.value);
        const down = action.subtype == .key_down;
        // Keyup step 3: "If the source's pressed item does not contain key,
        // return."
        const pressed_index = source.isPressed(key);
        if (!down and pressed_index == null) return null;
        // Keydown step 3: repeat.
        const repeat = down and pressed_index != null;
        // Steps 4-6: code, location, keyCode.
        const code = keys.code(raw);
        const location = keys.location(raw);
        const key_code = keys.keyCode(key, code);
        // Steps 7-10: the modifiers.
        const state = down;
        if (std.mem.eql(u8, key, "Alt")) source.alt = state;
        if (std.mem.eql(u8, key, "Shift")) source.shift = state;
        if (std.mem.eql(u8, key, "Control")) source.ctrl = state;
        if (std.mem.eql(u8, key, "Meta")) source.meta = state;
        // Step 11: pressed.
        if (down) {
            if (pressed_index == null) {
                const copy = driver.allocator.dupe(u8, key) catch return outOfMemory();
                source.pressed.append(driver.allocator, copy) catch {
                    driver.allocator.free(copy);
                    return outOfMemory();
                };
            }
        } else if (pressed_index) |i| {
            driver.allocator.free(source.pressed.orderedRemove(i));
        }
        // Step 12: the events, where key events are routed.
        const document = self.keyDocument() orelse return .{ .code = "no such window", .message = "the document to type into is gone" };
        const is_character = std.unicode.utf8CountCodepoints(key) catch 0;
        const input_key: user_input.Key = .{
            .key = key,
            .code = code orelse "",
            .location = location,
            .key_code = key_code,
            .text = if (is_character == 1) key else null,
            .repeat = repeat,
        };
        if (down) {
            user_input.keyDown(&driver.keyboard, document, input_key, driver.globalModifiers());
        } else {
            user_input.keyUp(&driver.keyboard, document, input_key, driver.globalModifiers());
        }
        return null;
    }

    /// The document whose top-level traversable key events are routed in.
    fn keyDocument(self: *Command) ?*Instance {
        if (self.key_document) |weak| return weak.get();
        const window = (self.window orelse return null).get() orelse return null;
        return interfaces.Window.get_document(window) catch null;
    }

    // ------------------------------------------------------------------------
    // Window commands (11.8)
    // ------------------------------------------------------------------------

    /// "Iconify the window" (hidden) or "restore the window" (visible): the
    /// top-level traversable's system visibility state changes, and HTML 6.2
    /// updates the visibility state of the active document of each of its
    /// inclusive descendant navigables.
    fn setSystemVisibility(self: *Command, state: VisibilityState) ?Failure {
        const window = (self.target_window orelse return noSuchWindow()).get() orelse return noSuchWindow();
        const context = browser_state.browsingContextOf(window) orelse return noSuchWindow();
        var navigables: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer navigables.deinit(self.driver.allocator);
        context.getTop().collectDescendants(self.driver.allocator, &navigables) catch return outOfMemory();
        for (navigables.items) |navigable| {
            if (navigable.orphaned) continue;
            const document = navigable.getActiveDocument() orelse continue;
            dom_visibility.update(@ptrCast(@alignCast(document)), state);
        }
        return null;
    }

    /// Resolve with the window's rect (WebDriver "window rect": its outer
    /// position and size).
    fn resolveWindowRect(self: *Command) void {
        const window = (self.target_window orelse return self.reject(noSuchWindow())).get() orelse return self.reject(noSuchWindow());
        const members = [_]engine.DictionaryMember{
            .{ .name = "x", .value = .{ .number = @floatFromInt(interfaces.Window.get_screenX(window) catch 0) } },
            .{ .name = "y", .value = .{ .number = @floatFromInt(interfaces.Window.get_screenY(window) catch 0) } },
            .{ .name = "width", .value = .{ .number = @floatFromInt(interfaces.Window.get_outerWidth(window) catch 0) } },
            .{ .name = "height", .value = .{ .number = @floatFromInt(interfaces.Window.get_outerHeight(window) catch 0) } },
        };
        const rect = engine.createDictionaryObject(self.realm, &members) catch return self.resolve(JSValue.jsUndefined);
        defer rect.release();
        self.resolve(rect.borrow());
    }

    // ------------------------------------------------------------------------
    // Cookies (14): "all associated cookies" of the window's active document,
    // in the Browser's cookie store (the jar its browsing context shares)
    // ------------------------------------------------------------------------

    fn resolveCookies(self: *Command) void {
        // Step 1: the current browsing context no longer open: no such window.
        const window = (self.target_window orelse return self.reject(noSuchWindow())).get() orelse return self.reject(noSuchWindow());
        const context = browser_state.browsingContextOf(window) orelse return self.reject(noSuchWindow());
        if (context.is_closed) return self.reject(noSuchWindow());
        // "The current browsing context's active document": the browsing
        // context's, not Window.document's - that getter is script's, and
        // checks its accessor's origin against the window's, so it refused a
        // cross-origin popup's document to the remote end.
        const document: *Instance = @ptrCast(@alignCast(context.getActiveDocument() orelse return self.reject(noSuchWindow())));
        const url = interfaces.Document.get_URL(document) catch return self.reject(outOfMemory());
        defer document.ctx.allocator.free(url);
        // The user agent's store as this context reaches it: a frame's is its
        // top-level context's (`cookie_jar` is set on top-level contexts only).
        const jar = context.cookieJar() orelse {
            // No store: a document no cookie can be associated with.
            return switch (self.kind) {
                .get_cookies => self.resolveCookieList(&.{}),
                else => self.resolve(JSValue.jsNull),
            };
        };
        switch (self.kind) {
            // 14.5 step 3: delete cookies, no filter.
            .delete_cookies => {
                _ = cookiestore.webdriverDeleteCookies(jar, url, null);
                self.resolve(JSValue.jsNull);
            },
            .get_cookies, .get_named_cookie => {
                const name: ?[]const u8 = if (self.kind == .get_named_cookie) self.text else null;
                var cookies = cookiestore.webdriverAssociatedCookies(jar, url, name) catch return self.reject(outOfMemory());
                defer {
                    for (cookies.items) |*c| c.deinit();
                    cookies.deinit(jar.allocator);
                }
                if (self.kind == .get_cookies) return self.resolveCookieList(cookies.items);
                // 14.2 step 3: the serialized cookie, or "no such cookie" -
                // testdriver.js's get_named_cookie throws that itself when the
                // vendor's answer is null.
                if (cookies.items.len == 0) return self.resolve(JSValue.jsNull);
                const object = serializedCookie(self.realm, &cookies.items[0]) catch return self.reject(outOfMemory());
                defer object.release();
                self.resolve(object.borrow());
            },
            else => unreachable,
        }
    }

    fn resolveCookieList(self: *Command, cookies: []const cookiestore.Cookie) void {
        const allocator = self.driver.allocator;
        var owned: std.ArrayListUnmanaged(engine.Owned) = .empty;
        defer {
            for (owned.items) |o| o.release();
            owned.deinit(allocator);
        }
        var values: std.ArrayListUnmanaged(JSValue) = .empty;
        defer values.deinit(allocator);
        for (cookies) |*cookie| {
            const object = serializedCookie(self.realm, cookie) catch return self.reject(outOfMemory());
            owned.append(allocator, object) catch {
                object.release();
                return self.reject(outOfMemory());
            };
            values.append(allocator, object.borrow()) catch return self.reject(outOfMemory());
        }
        const list = engine.createSequenceOfValues(self.realm, values.items) catch return self.reject(outOfMemory());
        defer list.release();
        self.resolve(list.borrow());
    }
};

/// WebDriver 14 "serialized cookie": the table for cookie conversion's JSON
/// keys. `expiry` (seconds since the epoch) only for a cookie that has one;
/// a cookie with no SameSite attribute reads as "Lax" - RFC 6265bis enforces
/// it as Lax by default, and browsers report it so (cookies/samesite/
/// get_named_cookie-default-samesite.html). OWNED.
fn serializedCookie(realm: runtime.Context, cookie: *const cookiestore.Cookie) engine.Error!engine.Owned {
    var members: [8]engine.DictionaryMember = undefined;
    var n: usize = 0;
    members[n] = .{ .name = "name", .value = JSValue.fromStringRef(cookie.name) };
    n += 1;
    members[n] = .{ .name = "value", .value = JSValue.fromStringRef(cookie.value) };
    n += 1;
    members[n] = .{ .name = "path", .value = JSValue.fromStringRef(cookie.path) };
    n += 1;
    members[n] = .{ .name = "domain", .value = JSValue.fromStringRef(cookie.domain orelse "") };
    n += 1;
    members[n] = .{ .name = "secure", .value = JSValue.fromBoolean(cookie.secure) };
    n += 1;
    members[n] = .{ .name = "httpOnly", .value = JSValue.fromBoolean(cookie.http_only) };
    n += 1;
    if (cookie.expiry_time) |ms| {
        members[n] = .{ .name = "expiry", .value = JSValue.fromNumber(@floatFromInt(@divFloor(ms, 1000))) };
        n += 1;
    }
    members[n] = .{ .name = "sameSite", .value = JSValue.fromStringRef(switch (cookie.same_site) {
        .strict => "Strict",
        .lax, .unset => "Lax",
        .none => "None",
    }) };
    n += 1;
    return engine.createDictionaryObject(realm, members[0..n]);
}

/// The touch sources one touch frame carries (a touch screen's contacts).
const user_input_touch_points = 16;

/// A pen's or touch's pointer properties from the action that moves or
/// presses it (WebDriver 15.6 "dispatch a pointerDown action" steps 7-15,
/// "dispatch a pointerMove action"): each the action's, or "the default
/// value specified for hardware that doesn't support that property".
fn applyProperties(pointer: *user_input.Pointer, properties: PointerProperties) void {
    pointer.width = properties.width orelse 1;
    pointer.height = properties.height orelse 1;
    pointer.pressure = if (properties.pressure) |p| @floatCast(p) else null;
    pointer.tangential_pressure = if (properties.tangential_pressure) |p| @floatCast(p) else 0;
    pointer.tilt_x = properties.tilt_x;
    pointer.tilt_y = properties.tilt_y;
    pointer.twist = properties.twist orelse 0;
    pointer.altitude_angle = properties.altitude_angle;
    pointer.azimuth_angle = properties.azimuth_angle;
}

const dom_visibility = @import("dom").visibility_state;
const VisibilityState = dom_visibility.State;

fn staleElement() Failure {
    return .{ .code = "stale element reference", .message = "the element is not connected to its document" };
}

fn unsupportedMove() Failure {
    return .{ .code = "unsupported operation", .message = "Crane has no layout: relative pointer offsets and actions without a target are unsupported" };
}

fn noSuchWindow() Failure {
    return .{ .code = "no such window", .message = "the window is gone" };
}

fn outOfMemory() Failure {
    return .{ .code = "unknown error", .message = "out of memory" };
}

fn firstCodePoint(text: []const u8) ?u21 {
    if (text.len == 0) return null;
    var view = std.unicode.Utf8View.init(text) catch return null;
    var it = view.iterator();
    const cp = it.nextCodepoint() orelse return null;
    if (it.nextCodepoint() != null) return null;
    return cp;
}

fn nodeDocumentOf(node: *Instance) ?*Instance {
    return interfaces.Node.get_ownerDocument(node) catch null;
}

/// WebDriver "get a known element", without a session's element store: the
/// element, while it is alive, connected, and in a document that is some
/// browsing context's active document.
fn knownElement(weak_in: ?Weak) ?*Instance {
    const weak = weak_in orelse return null;
    const element = weak.get() orelse return null;
    if (!(interfaces.Node.get_isConnected(element) catch false)) return null;
    const document = nodeDocumentOf(element) orelse return null;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return null;
    if (browser_state.browsingContextOf(window) == null) return null;
    return element;
}

/// Element Send Keys step 8: the caret at the end of the API value, for a
/// control whose selection applies.
fn moveCaretToEnd(element: *Instance) void {
    if (html.form_associated.isTextArea(element)) {
        var value = interfaces.HTMLTextAreaElement.get_value(element) catch return;
        defer value.deinit(element.ctx.allocator);
        const end = html.form_associated.utf16Length(value.asSlice());
        interfaces.HTMLTextAreaElement.call_setSelectionRange(element, end, end, .notPassed()) catch {};
    } else if (html.form_associated.isInput(element)) {
        if ((interfaces.HTMLInputElement.get_selectionStart(element) catch null) == null) return;
        var value = interfaces.HTMLInputElement.get_value(element) catch return;
        defer value.deinit(element.ctx.allocator);
        const end = html.form_associated.utf16Length(value.asSlice());
        interfaces.HTMLInputElement.call_setSelectionRange(element, end, end, .notPassed()) catch {};
    }
}

// ============================================================================
// The natives
// ============================================================================

fn nativeSteps(comptime native: Native) runtime.BuiltinSteps {
    return &struct {
        fn steps(data: ?*anyopaque, args: []const JSValue) runtime.EngineError!JSValue {
            const driver: *TestDriver = @ptrCast(@alignCast(data orelse return error.OperationFailed));
            const realm = engine.currentRealm() orelse return error.OperationFailed;
            return switch (native) {
                .bidi_log_subscribe => logSubscribe(driver, realm, args),
                .bidi_log_unsubscribe => logUnsubscribe(driver, args),
                else => startCommand(driver, realm, native, args),
            };
        }
    }.steps;
}

/// The window of `realm`: the active window of the browsing context whose
/// window is in it.
fn windowOfRealm(realm: runtime.Context) ?*Instance {
    const navigables = browser_state.navigablesOf(realm) orelse return null;
    for (navigables.contexts()) |context| {
        if (context.orphaned) continue;
        const window_ptr = context.getActiveWindow() orelse continue;
        const window: *Instance = @ptrCast(@alignCast(window_ptr));
        if (window.ctx == realm) return window;
    }
    return null;
}

fn argument(args: []const JSValue, index: usize) JSValue {
    return if (index < args.len) args[index] else JSValue.jsUndefined;
}

/// A WindowProxy argument (a `context`), or null for null/undefined.
fn windowArgument(realm: runtime.Context, value: JSValue) ?*Instance {
    if (value.isNullOrUndefined()) return null;
    const instance = engine.convertToPlatformObject(realm, value) orelse return null;
    if (instance.stateAs(interfaces.Window.State) == null) return null;
    return instance;
}

fn isElement(instance: *Instance) bool {
    return html.form_associated.isElement(instance);
}

/// A native call: a command with a promise, its steps queued as a task.
fn startCommand(driver: *TestDriver, realm: runtime.Context, native: Native, args: []const JSValue) runtime.EngineError!JSValue {
    const allocator = driver.allocator;
    const caller = windowOfRealm(realm);
    const command = allocator.create(Command) catch return error.OperationFailed;
    command.* = .{
        .driver = driver,
        .kind = undefined,
        .realm = realm,
        .capability = engine.createPromise(realm) catch {
            allocator.destroy(command);
            return error.OperationFailed;
        },
        .window = if (caller) |w| Weak.of(w) else null,
        .timer = realm.getOptionalTimer(),
    };
    const promise = engine.retainValue(realm, command.capability.promise) catch {
        command.free();
        return error.OperationFailed;
    };
    const failure: ?Failure = switch (native) {
        .get_computed_role, .get_computed_label => blk: {
            command.kind = if (native == .get_computed_role) .computed_role else .computed_label;
            const element = engine.convertToPlatformObject(realm, argument(args, 0));
            if (element == null or !isElement(element.?)) break :blk invalid("computed accessibility takes an element");
            command.element = Weak.of(element.?);
            command.pending_element = engine.retainValue(element.?.ctx, .{ .instance = element.? }) catch break :blk outOfMemory();
            break :blk null;
        },
        .click => blk: {
            command.kind = .click;
            const element = engine.convertToPlatformObject(realm, argument(args, 0));
            if (element == null or !isElement(element.?)) break :blk .{ .code = "invalid argument", .message = "click takes an element" };
            command.element = Weak.of(element.?);
            break :blk null;
        },
        .send_keys => blk: {
            command.kind = .send_keys;
            const element = engine.convertToPlatformObject(realm, argument(args, 0));
            if (element == null or !isElement(element.?)) break :blk .{ .code = "invalid argument", .message = "send_keys takes an element" };
            command.element = Weak.of(element.?);
            command.text = engine.convertToDOMString(realm, argument(args, 1), allocator) catch break :blk .{ .code = "invalid argument", .message = "keys is not a string" };
            break :blk null;
        },
        .action_sequence => blk: {
            command.kind = .actions;
            if (windowArgument(realm, argument(args, 1))) |context| {
                command.key_document = if (interfaces.Window.get_document(context) catch null) |d| Weak.of(d) else null;
            }
            break :blk parseActions(command, realm, argument(args, 0));
        },
        .minimize_window, .set_window_rect, .get_window_rect => blk: {
            command.kind = switch (native) {
                .minimize_window => .minimize,
                .set_window_rect => .restore,
                else => .get_rect,
            };
            const context_index: usize = if (native == .set_window_rect) 1 else 0;
            const target = windowArgument(realm, argument(args, context_index)) orelse caller;
            command.target_window = if (target) |w| Weak.of(w) else null;
            break :blk null;
        },
        .get_all_cookies, .delete_all_cookies => blk: {
            command.kind = if (native == .get_all_cookies) .get_cookies else .delete_cookies;
            const target = windowArgument(realm, argument(args, 0)) orelse caller;
            command.target_window = if (target) |w| Weak.of(w) else null;
            break :blk null;
        },
        .get_named_cookie => blk: {
            command.kind = .get_named_cookie;
            command.text = engine.convertToDOMString(realm, argument(args, 0), allocator) catch break :blk .{ .code = "invalid argument", .message = "name is not a string" };
            const target = windowArgument(realm, argument(args, 1)) orelse caller;
            command.target_window = if (target) |w| Weak.of(w) else null;
            break :blk null;
        },
        .set_permission => blk: {
            command.kind = .set_permission;
            const context_arg = argument(args, 1);
            const target = if (context_arg.isNullOrUndefined()) caller else windowArgument(realm, context_arg);
            command.target_window = if (target) |window| Weak.of(window) else null;
            if (target == null) break :blk noSuchWindow();
            var parsed = PermissionParameters{ .realm = realm, .input = argument(args, 0) };
            const exception = engine.completionOf(realm, PermissionParameters.convert, &parsed) catch break :blk invalid("invalid permission parameters");
            if (exception) |held| {
                held.release();
                break :blk invalid("invalid permission parameters");
            }
            command.permission_descriptor = parsed.descriptor;
            command.permission_state = parsed.state;
            break :blk null;
        },
        // Answered by `nativeSteps` itself: no command.
        .bidi_log_subscribe, .bidi_log_unsubscribe => unreachable,
    };
    driver.commands.append(allocator, command) catch {
        command.free();
        promise.release();
        return error.OperationFailed;
    };
    if (failure) |f| {
        command.reject(f);
    } else if (!command.queueStart()) {
        command.reject(.{ .code = "unknown error", .message = "the realm has no timers" });
    }
    return promise.take();
}

/// Permissions B.1.1 steps 1-4. No script object or borrowed value survives
/// this conversion: the queued command stores the native descriptor/state.
const PermissionParameters = struct {
    realm: runtime.Context,
    input: JSValue,
    descriptor: ?permissions.PermissionDescriptor = null,
    state: permissions.PermissionState = .prompt,

    fn convert(data: ?*anyopaque) engine.Error!void {
        const self: *PermissionParameters = @ptrCast(@alignCast(data.?));
        if (engine.typeOf(self.realm, self.input) != .object) return error.TypeError;
        const descriptor = try engine.getProperty(self.realm, self.input, "descriptor");
        defer descriptor.release();
        if (engine.typeOf(self.realm, descriptor.borrow()) != .object) return error.TypeError;
        const state_value = try engine.getProperty(self.realm, self.input, "state");
        defer state_value.release();
        const state_name = try engine.convertToDOMString(self.realm, state_value.borrow(), self.realm.allocator);
        defer self.realm.allocator.free(state_name);
        self.state = permissions.PermissionState.fromString(state_name) orelse return error.TypeError;
        // Step 4 chooses the descriptor type with Get(name), then performs
        // that dictionary's conversion (including its inherited name).
        const name = try self.nameOf(descriptor.borrow());
        _ = try self.nameOf(descriptor.borrow());
        self.descriptor = switch (name) {
            .midi => permissions.PermissionDescriptor.midi(try self.boolean(descriptor.borrow(), "sysex")),
            .camera => permissions.PermissionDescriptor.camera(try self.boolean(descriptor.borrow(), "panTiltZoom")),
            .push => permissions.PermissionDescriptor.push(try self.boolean(descriptor.borrow(), "userVisibleOnly")),
            else => permissions.PermissionDescriptor.simple(name),
        };
    }

    fn nameOf(self: *PermissionParameters, object: JSValue) engine.Error!permissions.PermissionName {
        const value = try engine.getProperty(self.realm, object, "name");
        defer value.release();
        // An Owned value is a handle: engine.typeOf says whether it is
        // undefined (isUndefined() is false for every handle).
        if (engine.typeOf(self.realm, value.borrow()) == .undefined) return error.TypeError;
        const name = try engine.convertToDOMString(self.realm, value.borrow(), self.realm.allocator);
        defer self.realm.allocator.free(name);
        return permissions.query.supportedName(name) orelse error.TypeError;
    }

    fn boolean(self: *PermissionParameters, object: JSValue, member: []const u8) engine.Error!bool {
        const value = try engine.getProperty(self.realm, object, member);
        defer value.release();
        return engine.toBoolean(self.realm, value.borrow());
    }
};

fn permissionKeyForWindow(window: *Instance, descriptor: permissions.PermissionDescriptor) error{OutOfMemory}!?[]u8 {
    const global_settings = @import("dom").global_settings;
    const allocator = window.ctx.allocator;
    const top = (try global_settings.topLevelOriginOf(window)) orelse return null;
    if (descriptor.name != .storage_access) return top;
    defer allocator.free(top);
    // Storage Access 4 has its own key: (top-level site, requester site).
    const settings = global_settings.of(window) orelse return null;
    const origin = settings.origin(window) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else null;
    defer allocator.free(origin);
    const top_site = html.agent_clusters.siteOf(allocator, top) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else null;
    defer allocator.free(top_site);
    const requester_site = html.agent_clusters.siteOf(allocator, origin) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else null;
    defer allocator.free(requester_site);
    return try std.mem.concat(allocator, u8, &.{ top_site, "\x00", requester_site });
}

// ============================================================================
// Parsing an action sequence (15.5 "extract an action sequence")
// ============================================================================

fn invalid(message: []const u8) Failure {
    return .{ .code = "invalid argument", .message = message };
}

/// A string property of `object`, OWNED by `allocator`, or null when it is
/// absent (undefined).
fn stringProperty(realm: runtime.Context, object: JSValue, name: []const u8, allocator: std.mem.Allocator) ?[]u8 {
    const value = engine.getProperty(realm, object, name) catch return null;
    defer value.release();
    // An absent property is undefined, which is no string either.
    if (engine.typeOf(realm, value.value) != .string) return null;
    return engine.convertToDOMString(realm, value.borrow(), allocator) catch null;
}

fn numberProperty(realm: runtime.Context, object: JSValue, name: []const u8) ?f64 {
    const value = engine.getProperty(realm, object, name) catch return null;
    defer value.release();
    if (engine.typeOf(realm, value.value) != .number) return null;
    return engine.convertToUnrestrictedDouble(realm, value.borrow()) catch null;
}

fn parseActions(command: *Command, realm: runtime.Context, value: JSValue) ?Failure {
    const allocator = command.driver.allocator;
    // "If actions is not a list, return error with error code invalid argument."
    const sources = engine.convertToSequenceOfObjects(realm, value, allocator) catch return invalid("actions is not a list");
    defer {
        for (sources) |source| source.release();
        allocator.free(sources);
    }
    for (sources) |source| {
        // "Process an input source action sequence".
        const source_type_name = stringProperty(realm, source.value, "type", allocator) orelse return invalid("an input source has no type");
        defer allocator.free(source_type_name);
        const source_type: SourceType = if (std.mem.eql(u8, source_type_name, "none"))
            .none
        else if (std.mem.eql(u8, source_type_name, "key"))
            .key
        else if (std.mem.eql(u8, source_type_name, "pointer"))
            .pointer
        else if (std.mem.eql(u8, source_type_name, "wheel"))
            .none // a wheel source's pauses are pauses; a scroll is rejected below
        else
            return invalid("unknown input source type");
        const is_wheel = std.mem.eql(u8, source_type_name, "wheel");
        const id = stringProperty(realm, source.value, "id", allocator) orelse return invalid("an input source has no id");
        defer allocator.free(id);
        var pointer_type: user_input.PointerType = .mouse;
        if (source_type == .pointer and !is_wheel) {
            // "Process pointer parameters": "pointerType" is mouse (the
            // default), pen or touch.
            const parameters = engine.getProperty(realm, source.value, "parameters") catch return invalid("bad parameters");
            defer parameters.release();
            if (engine.typeOf(realm, parameters.value) == .object) {
                if (stringProperty(realm, parameters.borrow(), "pointerType", allocator)) |name| {
                    defer allocator.free(name);
                    pointer_type = std.meta.stringToEnum(user_input.PointerType, name) orelse return invalid("pointerType is not mouse, pen or touch");
                }
            } else if (engine.typeOf(realm, parameters.value) != .undefined) return invalid("parameters is not an object");
            // "Get or create an input source": a source this session has
            // with the same id must have the same subtype.
            if (pointer_type == .mouse) {
                if (command.driver.existingPointerSource(id) != null) return invalid("an input source changed its pointerType");
            } else {
                const pointer_source = command.driver.pointerSource(id, pointer_type) orelse return outOfMemory();
                if (pointer_source.pointer.pointer_type != pointer_type) return invalid("an input source changed its pointerType");
            }
        }
        const actions_value = engine.getProperty(realm, source.value, "actions") catch return invalid("an input source has no actions");
        defer actions_value.release();
        const items = engine.convertToSequenceOfObjects(realm, actions_value.borrow(), allocator) catch return invalid("actions is not a list");
        defer {
            for (items) |item| item.release();
            allocator.free(items);
        }
        for (items, 0..) |item, index| {
            while (command.ticks.items.len <= index) {
                const tick = command.ticks.addOne(allocator) catch return outOfMemory();
                tick.* = .{};
            }
            var action = parseAction(realm, item.value, source_type, is_wheel, id, allocator) catch |err| switch (err) {
                error.Invalid => return invalid("an action is not well formed"),
                error.Unsupported => return .{ .code = "unsupported operation", .message = "wheel actions are not supported" },
                error.OutOfMemory => return outOfMemory(),
            };
            action.pointer_type = pointer_type;
            command.ticks.items[index].actions.append(allocator, action) catch {
                action.deinit(allocator);
                return outOfMemory();
            };
        }
    }
    return null;
}

fn parseAction(realm: runtime.Context, object: JSValue, source_type: SourceType, is_wheel: bool, id: []const u8, allocator: std.mem.Allocator) error{ Invalid, Unsupported, OutOfMemory }!Action {
    const subtype_name = stringProperty(realm, object, "type", allocator) orelse return error.Invalid;
    defer allocator.free(subtype_name);
    const Name = struct { []const u8, Subtype };
    const names = [_]Name{
        .{ "pause", .pause },                  .{ "keyDown", .key_down },     .{ "keyUp", .key_up },
        .{ "pointerDown", .pointer_down },     .{ "pointerUp", .pointer_up }, .{ "pointerMove", .pointer_move },
        .{ "pointerCancel", .pointer_cancel },
    };
    const subtype: Subtype = for (names) |n| {
        if (std.mem.eql(u8, subtype_name, n[0])) break n[1];
    } else {
        if (std.mem.eql(u8, subtype_name, "scroll")) return error.Unsupported;
        return error.Invalid;
    };
    // Each subtype belongs to its source type.
    const allowed = switch (subtype) {
        .pause => true,
        .key_down, .key_up => source_type == .key,
        .pointer_down, .pointer_up, .pointer_move, .pointer_cancel => source_type == .pointer and !is_wheel,
    };
    if (!allowed) return error.Invalid;
    var action: Action = .{
        .source_type = source_type,
        .source_id = try allocator.dupe(u8, id),
        .subtype = subtype,
    };
    errdefer action.deinit(allocator);
    switch (subtype) {
        .pause => action.duration = numberProperty(realm, object, "duration"),
        .key_down, .key_up => {
            const value = stringProperty(realm, object, "value", allocator) orelse return error.Invalid;
            if (firstCodePoint(value) == null) {
                allocator.free(value);
                return error.Invalid;
            }
            action.value = value;
        },
        .pointer_cancel => {},
        .pointer_down, .pointer_up => {
            const button = numberProperty(realm, object, "button") orelse 0;
            if (button < 0 or button > 4 or @floor(button) != button) return error.Invalid;
            action.button = @intFromFloat(button);
            action.properties = try pointerProperties(realm, object);
        },
        .pointer_move => {
            action.properties = try pointerProperties(realm, object);
            action.x = numberProperty(realm, object, "x") orelse 0;
            action.y = numberProperty(realm, object, "y") orelse 0;
            action.duration = numberProperty(realm, object, "duration");
            const origin = engine.getProperty(realm, object, "origin") catch return error.Invalid;
            defer origin.release();
            // An absent origin is "viewport" (WebDriver "process a pointer
            // move action" step 6); an Owned value is a handle, so the
            // engine says whether it is undefined.
            if (engine.typeOf(realm, origin.value) == .undefined) {
                action.origin = .viewport;
            } else if (engine.typeOf(realm, origin.value) == .string) {
                const name = engine.convertToDOMString(realm, origin.borrow(), allocator) catch return error.Invalid;
                defer allocator.free(name);
                if (std.mem.eql(u8, name, "viewport")) {
                    action.origin = .viewport;
                } else if (std.mem.eql(u8, name, "pointer")) {
                    action.origin = .pointer;
                } else return error.Invalid;
            } else {
                const element = engine.convertToPlatformObject(realm, origin.borrow()) orelse return error.Invalid;
                if (!isElement(element)) return error.Invalid;
                action.origin = .{ .element = Weak.of(element) };
            }
        },
    }
    return action;
}

/// WebDriver 15.5 "process a pointer up or pointer down action" steps 4-30
/// (and "process a pointer move action"'s): each property absent, or a
/// number in its range - an integer for the tilts and twist.
fn pointerProperties(realm: runtime.Context, object: JSValue) error{Invalid}!PointerProperties {
    const Range = struct { min: f64, max: f64, integer: bool = false };
    const Get = struct {
        fn number(r: runtime.Context, o: JSValue, name: []const u8, range: Range) error{Invalid}!?f64 {
            const value = engine.getProperty(r, o, name) catch return error.Invalid;
            defer value.release();
            // An Owned value is a handle: only the engine says it is undefined.
            switch (engine.typeOf(r, value.value)) {
                .undefined => return null,
                .number => {},
                else => return error.Invalid,
            }
            const n = engine.convertToUnrestrictedDouble(r, value.borrow()) catch return error.Invalid;
            if (!(n >= range.min and n <= range.max)) return error.Invalid;
            if (range.integer and @floor(n) != n) return error.Invalid;
            return n;
        }
    };
    const pi = std.math.pi;
    const inf = std.math.inf(f64);
    const tilt_x = try Get.number(realm, object, "tiltX", .{ .min = -90, .max = 90, .integer = true });
    const tilt_y = try Get.number(realm, object, "tiltY", .{ .min = -90, .max = 90, .integer = true });
    const twist = try Get.number(realm, object, "twist", .{ .min = 0, .max = 359, .integer = true });
    return .{
        .width = try Get.number(realm, object, "width", .{ .min = 0, .max = inf }),
        .height = try Get.number(realm, object, "height", .{ .min = 0, .max = inf }),
        .pressure = try Get.number(realm, object, "pressure", .{ .min = 0, .max = 1 }),
        .tangential_pressure = try Get.number(realm, object, "tangentialPressure", .{ .min = -1, .max = 1 }),
        .tilt_x = if (tilt_x) |t| @intFromFloat(t) else null,
        .tilt_y = if (tilt_y) |t| @intFromFloat(t) else null,
        .twist = if (twist) |t| @intFromFloat(t) else null,
        .altitude_angle = try Get.number(realm, object, "altitudeAngle", .{ .min = 0, .max = pi / 2.0 }),
        .azimuth_angle = try Get.number(realm, object, "azimuthAngle", .{ .min = 0, .max = 2 * pi }),
    };
}

// ============================================================================
// The vendor file, for every document the tests drive
// ============================================================================

/// The driver whose natives the frame loader defines.
threadlocal var frame_driver: ?*TestDriver = null;

/// Register `driver` as the answer for every document - the page's, its
/// frames' and its popups' - of the
/// Browser whose scope is `scope` (src/html/embedder_scripts.zig): called
/// once, at startup.
pub fn registerForFrames(driver: *TestDriver, scope: *runtime.BrowserScope) !void {
    frame_driver = driver;
    try html.embedder_scripts.register(scope, &frameLoader);
}

pub fn unregisterForFrames(scope: *runtime.BrowserScope) void {
    html.embedder_scripts.unregister(scope);
    frame_driver = null;
}

/// The vendor file, for a document in `realm`, with the natives defined
/// there first; owned by the realm's allocator.
pub fn vendorFor(driver: *TestDriver, realm: runtime.Context) ?[]const u8 {
    driver.defineNatives(realm);
    return realm.allocator.dupe(u8, vendor_js) catch null;
}

fn frameLoader(realm: runtime.Context, src: []const u8) ?[]const u8 {
    if (!std.mem.eql(u8, src, vendor_path)) return null;
    const driver = frame_driver orelse return null;
    return vendorFor(driver, realm);
}
