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
//!
//! Each returns a promise and runs as tasks: the command's steps run from a
//! timer on the page's event loop, a tick of actions per timer, each tick
//! waiting its duration before the next, and the promise settles after the
//! last tick's events were dispatched. The events themselves - and every
//! default action they have - are the engine's (src/html/user_input.zig,
//! focus.zig, user_activation.zig): the remote end decides which input a
//! command is, the user agent what that input does.
//!
//! Crane has no layout, so an input source is over an element, not at
//! coordinates: a pointerMove needs an element origin (or the pointer origin
//! with no offset), and a coordinate-only move is reported as "unsupported
//! operation". Offsets from an element origin are not modelled: the pointer
//! is over the element, as if at its centre.
//!
//! Lifetimes. A command holds the elements it will act on weakly (their
//! generation): a listener can remove or collect them, and a closed popup's
//! realm must not be kept alive by a command waiting on it. Every armed timer
//! belongs to a command in `commands`; `endTest` - run by the runner when a
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

const Instance = runtime.Instance;
const JSValue = runtime.JSValue;
const user_input = html.user_input;
const focus = html.focus;
const Weak = user_input.Weak;
const BrowsingContext = html_core.window.BrowsingContext;
const log = std.log.scoped(.test_driver);

/// The vendor file, served for /resources/testdriver-vendor.js.
pub const vendor_js = @embedFile("resources/testdriver-vendor.js");

/// The URL the vendor file is served at.
pub const vendor_path = "/resources/testdriver-vendor.js";

// ============================================================================
// The driver: its natives, its commands, the session's input state
// ============================================================================

const Native = enum { click, send_keys, action_sequence, minimize_window, set_window_rect, get_window_rect, get_all_cookies, get_named_cookie, delete_all_cookies };

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

pub const TestDriver = struct {
    allocator: std.mem.Allocator,
    builtins: [std.enums.values(Native).len]runtime.BuiltinFunction,
    commands: std.ArrayListUnmanaged(*Command) = .empty,
    /// WebDriver's input state for the test's session: every mouse source
    /// moves the one mouse (a page has one), each key source keeps its keys.
    mouse: user_input.Pointer = .{},
    keyboard: user_input.Keyboard = .{},
    key_sources: std.ArrayListUnmanaged(KeySource) = .empty,

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
        for (self.commands.items) |command| command.cancel();
        for (self.commands.items) |command| command.free();
        self.commands.clearRetainingCapacity();
        for (self.key_sources.items) |*source| source.deinit(self.allocator);
        self.key_sources.clearRetainingCapacity();
        self.mouse = .{};
        self.keyboard = .{};
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
// Actions (WebDriver 15.5 "Processing actions")
// ============================================================================

const SourceType = enum { none, key, pointer };
const Subtype = enum { pause, key_down, key_up, pointer_down, pointer_up, pointer_move };

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

const Kind = enum { click, send_keys, actions, minimize, restore, get_rect, get_cookies, get_named_cookie, delete_cookies };

const Command = struct {
    driver: *TestDriver,
    kind: Kind,
    /// The realm the promise is in: the caller's.
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    /// The caller's window, weakly: a command whose window closed is dropped.
    window: ?Weak,
    /// The element a click or send_keys acts on.
    element: ?Weak = null,
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

    /// Arm the command's next step after `delay_ms`.
    fn arm(self: *Command, delay_ms: f64) bool {
        const timer = self.timer orelse return false;
        const ms: u64 = if (delay_ms <= 0) 0 else @intFromFloat(@ceil(delay_ms));
        self.timer_id = timer.setTimeout(ms, &fire, self);
        return true;
    }

    /// Cancel the armed step, if any.
    fn cancel(self: *Command) void {
        const id = self.timer_id orelse return;
        self.timer_id = null;
        if (self.timer) |timer| _ = timer.clearTimeout(id);
    }

    /// Give the promise back unsettled and free the command. Its timer is
    /// not armed (it fired, or `cancel` ran).
    fn free(self: *Command) void {
        const allocator = self.driver.allocator;
        engine.releasePromiseCapability(&self.capability);
        if (self.own_key_source) |id| {
            self.driver.removeKeySource(id);
            allocator.free(id);
        }
        for (self.ticks.items) |*tick| tick.deinit(allocator);
        self.ticks.deinit(allocator);
        allocator.free(self.text);
        allocator.destroy(self);
    }

    /// Whether the window that asked is still some browsing context's active
    /// window: HTML's "no longer open" check, done each step.
    fn windowOpen(self: *Command) bool {
        const weak = self.window orelse return true;
        const window = weak.get() orelse return false;
        const context = BrowsingContext.ofWindow(@ptrCast(window)) orelse return false;
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

    /// The timer's callback: the command's next step, as a task.
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
                else => {},
            }
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
            .get_rect, .get_cookies, .get_named_cookie, .delete_cookies => null,
        };
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
        // Steps 5-7: scrolled into view, in view and not obscured - without
        // layout, a connected element is all three.
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
        // Step 6: a File Upload input takes file paths - none exist here.
        if (html.form_associated.isInput(element)) {
            var buffer: [16]u8 = undefined;
            if (std.mem.eql(u8, html.form_associated.inputType(element, &buffer), "file")) {
                return .{ .code = "invalid argument", .message = "no files can be selected" };
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
        for (tick.actions.items) |*action| {
            if (self.dispatchAction(action)) |failure| return failure;
        }
        return null;
    }

    fn dispatchAction(self: *Command, action: *Action) ?Failure {
        const driver = self.driver;
        switch (action.subtype) {
            .pause => return null,
            .pointer_move => {
                switch (action.origin) {
                    .element => |weak| {
                        // "Get a WebElement origin": a stale one is an error.
                        const element = knownElement(weak) orelse return staleElement();
                        // The element at the origin's in-view centre plus
                        // the offset: the origin itself, or an image map's
                        // area.
                        const target = user_input.hitTest(element, action.x, action.y);
                        user_input.pointerMove(&driver.mouse, target, driver.globalModifiers());
                    },
                    .pointer => {
                        if (action.x != 0 or action.y != 0) return unsupportedMove();
                    },
                    .viewport => return unsupportedMove(),
                }
                return null;
            },
            .pointer_down => {
                if (driver.mouse.currentTarget() == null) return unsupportedMove();
                user_input.pointerDown(&driver.mouse, action.button, driver.globalModifiers());
                return null;
            },
            .pointer_up => {
                user_input.pointerUp(&driver.mouse, action.button, driver.globalModifiers());
                return null;
            },
            .key_down, .key_up => return self.dispatchKeyAction(action),
        }
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
        const context = BrowsingContext.ofWindow(@ptrCast(window)) orelse return noSuchWindow();
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
        const context = BrowsingContext.ofWindow(@ptrCast(window)) orelse return self.reject(noSuchWindow());
        if (context.is_closed) return self.reject(noSuchWindow());
        const document = (interfaces.Window.get_document(window) catch null) orelse return self.reject(noSuchWindow());
        const url = interfaces.Document.get_URL(document) catch return self.reject(outOfMemory());
        defer document.ctx.allocator.free(url);
        const jar = context.cookie_jar orelse {
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

const dom_visibility = @import("dom").visibility_state;
const VisibilityState = dom_visibility.State;

fn staleElement() Failure {
    return .{ .code = "stale element reference", .message = "the element is not connected to its document" };
}

fn unsupportedMove() Failure {
    return .{ .code = "unsupported operation", .message = "Crane has no layout: a pointer moves onto an element origin only" };
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
    if (BrowsingContext.ofWindow(@ptrCast(window)) == null) return null;
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
            return startCommand(driver, realm, native, args);
        }
    }.steps;
}

/// The window of `realm`: the active window of the browsing context whose
/// window is in it.
fn windowOfRealm(realm: runtime.Context) ?*Instance {
    for (BrowsingContext.liveContexts()) |context| {
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
    };
    driver.commands.append(allocator, command) catch {
        command.free();
        promise.release();
        return error.OperationFailed;
    };
    if (failure) |f| {
        command.reject(f);
    } else if (!command.arm(0)) {
        command.reject(.{ .code = "unknown error", .message = "the realm has no timers" });
    }
    return promise.take();
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
    if (value.value.isUndefined()) return null;
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
        if (source_type == .pointer) {
            // "parameters": only a mouse, which is all a page's pointer is here.
            const parameters = engine.getProperty(realm, source.value, "parameters") catch return invalid("bad parameters");
            defer parameters.release();
            if (engine.typeOf(realm, parameters.value) == .object) {
                if (stringProperty(realm, parameters.borrow(), "pointerType", allocator)) |pointer_type| {
                    defer allocator.free(pointer_type);
                    if (!std.mem.eql(u8, pointer_type, "mouse")) return .{ .code = "unsupported operation", .message = "only a mouse pointer is supported" };
                }
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
                error.Unsupported => return .{ .code = "unsupported operation", .message = "wheel and pointerCancel actions are not supported" },
                error.OutOfMemory => return outOfMemory(),
            };
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
        .{ "pause", .pause },              .{ "keyDown", .key_down },     .{ "keyUp", .key_up },
        .{ "pointerDown", .pointer_down }, .{ "pointerUp", .pointer_up }, .{ "pointerMove", .pointer_move },
    };
    const subtype: Subtype = for (names) |n| {
        if (std.mem.eql(u8, subtype_name, n[0])) break n[1];
    } else {
        if (std.mem.eql(u8, subtype_name, "scroll") or std.mem.eql(u8, subtype_name, "pointerCancel")) return error.Unsupported;
        return error.Invalid;
    };
    // Each subtype belongs to its source type.
    const allowed = switch (subtype) {
        .pause => true,
        .key_down, .key_up => source_type == .key,
        .pointer_down, .pointer_up, .pointer_move => source_type == .pointer and !is_wheel,
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
        .pointer_down, .pointer_up => {
            const button = numberProperty(realm, object, "button") orelse 0;
            if (button < 0 or button > 4 or @floor(button) != button) return error.Invalid;
            action.button = @intFromFloat(button);
        },
        .pointer_move => {
            action.x = numberProperty(realm, object, "x") orelse 0;
            action.y = numberProperty(realm, object, "y") orelse 0;
            action.duration = numberProperty(realm, object, "duration");
            const origin = engine.getProperty(realm, object, "origin") catch return error.Invalid;
            defer origin.release();
            if (origin.value.isUndefined()) {
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

// ============================================================================
// The vendor file for frame and popup documents
// ============================================================================

/// The driver whose natives the frame loader defines.
threadlocal var frame_driver: ?*TestDriver = null;

/// Register `driver` as the answer for frame and popup documents
/// (src/html/embedder_scripts.zig): called once, at startup.
pub fn registerForFrames(driver: *TestDriver) void {
    frame_driver = driver;
    html.embedder_scripts.register(&frameLoader);
}

pub fn unregisterForFrames() void {
    html.embedder_scripts.unregister();
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
