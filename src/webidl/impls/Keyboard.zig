//! Implementation for Keyboard interface
//!
//! Keyboard Lock §2.2 - The Keyboard interface's lock() and unlock()
//! Spec: https://wicg.github.io/keyboard-lock/#keyboard-interface
//!
//! A Keyboard is its Navigator's `keyboard` ([SameObject]): an EventTarget
//! with the keyboard lock's state - "enable keyboard lock" and the
//! "reserved key codes" - which lock() and unlock() change from steps they
//! enqueue on the "keyboard lock task queue". Crane runs that queue as tasks
//! on the Keyboard's event loop, in the order the calls enqueued them.
//!
//! Headless, there is no system keyboard to reserve keys of: the steps keep
//! the state the spec describes, and "register a system key press handler"
//! (which the spec makes optional) and "unregister" it do nothing.
//!
//! Not implemented here: getLayoutMap() and onlayoutchange (Keyboard Map).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const BrowsingContext = @import("html_core").window.BrowsingContext;
const Keyboard = interfaces.Keyboard;
const log = std.log.scoped(.keyboard);

pub const State = Keyboard.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// "Enable keyboard lock", the "reserved key codes", and how many lock()
/// steps are enqueued on the keyboard lock task queue and not yet run.
pub const InternalState = struct {
    allocator: Allocator,
    enabled: bool = false,
    /// Owned strings.
    reserved: std.ArrayListUnmanaged([]u8) = .empty,
    pending_locks: u32 = 0,

    fn resetReserved(self: *InternalState) void {
        for (self.reserved.items) |code| self.allocator.free(code);
        self.reserved.clearRetainingCapacity();
    }

    fn deinit(self: *InternalState) void {
        self.resetReserved();
        self.reserved.deinit(self.allocator);
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance: an EventTarget - through its interface, which sets
/// up the listener state - with the keyboard lock state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.EventTarget.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: the keyboard lock state, then the EventTarget part
/// through its interface. A step still enqueued finds the instance gone by
/// its slab generation.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.EventTarget.deinit(instance);
}

/// Getter for onlayoutchange (Keyboard Map): not implemented.
pub fn get_onlayoutchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onlayoutchange (Keyboard Map): not implemented.
pub fn set_onlayoutchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// unlock(): "1. Enqueue the following steps to the keyboard lock task
/// queue: 1. If enable keyboard lock is true, then run the following
/// substeps: 1. Unregister the system key press handler. 2. Set enable
/// keyboard lock to be false. 3. Reset reserved key codes to be an empty
/// sequence."
pub fn call_unlock(instance: *runtime.Instance) anyerror!void {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    enqueue(instance, .unlock, null, null);
}

/// lock(keyCodes): Keyboard Lock §2.2.1.
pub fn call_lock(instance: *runtime.Instance, keyCodes: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const realm = engine.currentRealm() orelse instance.ctx;

    // The sequence<DOMString> argument, converted here (the binding hands it
    // over as it came); "optional ... = []": not passed is the empty list.
    const codes: ?[][]u8 = if (keyCodes.was_passed) (try engine.convertToSequenceOfDOMStrings(realm, keyCodes.value, internal.allocator)) orelse
        return error.TypeError else null;
    var codes_taken = false;
    defer if (!codes_taken) if (codes) |list| freeCodes(internal.allocator, list);

    // Step 1: "Let p be a new Promise."
    var capability = try engine.createPromise(realm);
    const p = engine.retainValue(realm, capability.promise) catch |err| {
        engine.releasePromiseCapability(&capability);
        return err;
    };
    errdefer p.release();

    // Step 2: "If not currently executing in the currently active top-level
    // browsing context, then reject p with an "InvalidStateError"
    // DOMException." Its relevant global's document must be the active
    // document of a top-level traversable. Then p is returned: the steps the
    // spec goes on to enqueue could only settle a promise already rejected.
    if (!inActiveTopLevelBrowsingContext(instance)) {
        rejectWith(&capability, realm, "InvalidStateError", "Keyboard lock is only available to the active document of a top-level browsing context.");
        engine.releasePromiseCapability(&capability);
        return p.take();
    }

    // Step 3: "Enqueue the following steps to the keyboard lock task queue".
    // Step 4: "Return p."
    internal.pending_locks += 1;
    codes_taken = true;
    enqueue(instance, .lock, capability, codes);
    return p.take();
}

/// Operation: getLayoutMap (Keyboard Map): not implemented.
pub fn call_getLayoutMap(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

// ============================================================================
// The keyboard lock task queue
// ============================================================================

/// Whether `instance`'s relevant global object is the active window of a
/// top-level browsing context.
fn inActiveTopLevelBrowsingContext(instance: *runtime.Instance) bool {
    const record = instance.ctx.getRealm() orelse return false;
    const window = record.global_object orelse return false;
    const bc = BrowsingContext.ofWindow(@ptrCast(window)) orelse return false;
    return bc.isTopLevel();
}

const Kind = enum { lock, unlock };

/// Steps enqueued on the keyboard lock task queue, run as a task of the
/// Keyboard's event loop. It names the Keyboard by address and slab
/// generation: an enqueued step outlives nothing it does not own.
const Step = struct {
    kind: Kind,
    keyboard: *runtime.Instance,
    generation: u64,
    allocator: Allocator,
    /// lock()'s p and its realm. OWNED.
    capability: ?engine.PromiseCapability,
    realm: runtime.Context,
    /// lock()'s keyCodes. OWNED.
    codes: ?[][]u8,

    /// A task of the event loop.
    fn run(context: ?*anyopaque) void {
        const self: *Step = @ptrCast(@alignCast(context.?));
        defer self.finish();
        if (runtime.SlabAllocator.generationOf(self.keyboard) != self.generation) return;
        // A realm the adapter has retired has nobody to hear it.
        if (!self.realm.hasEngine()) return;
        engine.runTaskInRealm(self.realm, steps, self) catch |err| log.debug("keyboard lock steps not run: {s}", .{@errorName(err)});
    }

    /// The loop ends with the step still enqueued: nothing settles p.
    fn drop(context: ?*anyopaque) void {
        const self: *Step = @ptrCast(@alignCast(context.?));
        self.finish();
    }

    fn steps(data: ?*anyopaque) void {
        const self: *Step = @ptrCast(@alignCast(data.?));
        const internal = getInternal(self.keyboard) orelse return;
        switch (self.kind) {
            .lock => self.lockSteps(internal),
            .unlock => unlockSteps(internal),
        }
    }

    /// lock() step 3's substeps.
    fn lockSteps(self: *Step, internal: *InternalState) void {
        internal.pending_locks -|= 1;
        const capability = if (self.capability) |*c| c else return;
        // 3.1: "Reset reserved key codes to be an empty set."
        internal.resetReserved();
        // 3.2: "If the optional keyCodes argument is present ... For each
        // string key in keyCodes: 1. If key is not a valid key code attribute
        // value, then set enable keyboard lock to be false, and reject p with
        // an "InvalidAccessError" DOMException. 2. Append key to reserved key
        // codes." A rejected p is settled: the steps stop there.
        if (self.codes) |codes| {
            for (codes) |key| {
                if (!isValidCode(key)) {
                    internal.enabled = false;
                    internal.resetReserved();
                    rejectWith(capability, self.realm, "InvalidAccessError", "The key code is not a valid key code attribute value.");
                    return;
                }
                if (containsCode(internal.reserved.items, key)) continue;
                const copy = internal.allocator.dupe(u8, key) catch return;
                internal.reserved.append(internal.allocator, copy) catch {
                    internal.allocator.free(copy);
                    return;
                };
            }
        }
        // 3.3: "If enable keyboard lock is currently false: 1. Optionally,
        // register a system key press handler. 2. Set enable keyboard lock
        // to be true." No handler, headless.
        if (!internal.enabled) internal.enabled = true;
        // 3.4: "If there is a pending lock() task in the keyboard lock task
        // queue, then set enable keyboard lock to be false, and reject p with
        // an "AbortError" DOMException."
        if (internal.pending_locks > 0) {
            internal.enabled = false;
            rejectWith(capability, self.realm, "AbortError", "A newer keyboard lock request was made.");
            return;
        }
        // 3.5: "Resolve p."
        engine.resolvePromise(capability, runtime.JSValue.jsUndefined) catch {};
    }

    fn finish(self: *Step) void {
        if (self.capability) |*c| engine.releasePromiseCapability(c);
        if (self.codes) |codes| freeCodes(self.allocator, codes);
        self.allocator.destroy(self);
    }
};

/// unlock()'s enqueued substeps.
fn unlockSteps(internal: *InternalState) void {
    if (!internal.enabled) return;
    // 1.1.1: "Unregister the system key press handler" - none, headless.
    // 1.1.2-3.
    internal.enabled = false;
    internal.resetReserved();
}

/// Enqueue `kind`'s steps for `keyboard`, taking `capability` and `codes`:
/// a task on the Keyboard's event loop, or - with none, as in tests - now.
fn enqueue(keyboard: *runtime.Instance, kind: Kind, capability: ?engine.PromiseCapability, codes: ?[][]u8) void {
    const internal = getInternal(keyboard).?;
    const step = internal.allocator.create(Step) catch {
        var owned = capability;
        if (owned) |*c| engine.releasePromiseCapability(c);
        if (codes) |list| freeCodes(internal.allocator, list);
        if (kind == .lock) internal.pending_locks -|= 1;
        return;
    };
    step.* = .{
        .kind = kind,
        .keyboard = keyboard,
        .generation = runtime.SlabAllocator.generationOf(keyboard),
        .allocator = internal.allocator,
        .capability = capability,
        .realm = engine.currentRealm() orelse keyboard.ctx,
        .codes = codes,
    };
    const loop = keyboard.ctx.getOptionalEventLoop() orelse return Step.run(step);
    loop.queueTask(.{ .callback = Step.run, .context = step, .drop = Step.drop });
}

fn rejectWith(capability: *engine.PromiseCapability, realm: runtime.Context, name: []const u8, message: []const u8) void {
    const reason = engine.createDOMException(realm, name, message) catch return;
    defer reason.release();
    engine.rejectPromise(capability, reason.value) catch {};
}

fn freeCodes(allocator: Allocator, codes: [][]u8) void {
    for (codes) |code| allocator.free(code);
    allocator.free(codes);
}

fn containsCode(list: []const []u8, key: []const u8) bool {
    for (list) |code| {
        if (std.mem.eql(u8, code, key)) return true;
    }
    return false;
}

/// UI Events KeyboardEvent code Values: whether `key` is a "key code
/// attribute value" - one of the code values the specification defines.
/// Spec: https://w3c.github.io/uievents-code/#key-code-attribute-value
fn isValidCode(key: []const u8) bool {
    for (key_codes) |code| {
        if (std.mem.eql(u8, code, key)) return true;
    }
    return false;
}

/// The code values of UI Events KeyboardEvent code Values §3 (writing
/// system, functional, control pad, arrow pad, numpad, function and media
/// keys) and §4's legacy and special values.
const key_codes = [_][]const u8{
    // 3.1.1 Writing System Keys
    "Backquote",
    "Backslash",
    "BracketLeft",
    "BracketRight",
    "Comma",
    "Digit0",
    "Digit1",
    "Digit2",
    "Digit3",
    "Digit4",
    "Digit5",
    "Digit6",
    "Digit7",
    "Digit8",
    "Digit9",
    "Equal",
    "IntlBackslash",
    "IntlRo",
    "IntlYen",
    "KeyA",
    "KeyB",
    "KeyC",
    "KeyD",
    "KeyE",
    "KeyF",
    "KeyG",
    "KeyH",
    "KeyI",
    "KeyJ",
    "KeyK",
    "KeyL",
    "KeyM",
    "KeyN",
    "KeyO",
    "KeyP",
    "KeyQ",
    "KeyR",
    "KeyS",
    "KeyT",
    "KeyU",
    "KeyV",
    "KeyW",
    "KeyX",
    "KeyY",
    "KeyZ",
    "Minus",
    "Period",
    "Quote",
    "Semicolon",
    "Slash",
    // 3.1.2 Functional Keys
    "AltLeft",
    "AltRight",
    "Backspace",
    "CapsLock",
    "ContextMenu",
    "ControlLeft",
    "ControlRight",
    "Enter",
    "MetaLeft",
    "MetaRight",
    "ShiftLeft",
    "ShiftRight",
    "Space",
    "Tab",
    "Convert",
    "KanaMode",
    "Lang1",
    "Lang2",
    "Lang3",
    "Lang4",
    "Lang5",
    "NonConvert",
    // 3.2 Control Pad Section
    "Delete",
    "End",
    "Help",
    "Home",
    "Insert",
    "PageDown",
    "PageUp",
    // 3.3 Arrow Pad Section
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    "ArrowUp",
    // 3.4 Numpad Section
    "NumLock",
    "Numpad0",
    "Numpad1",
    "Numpad2",
    "Numpad3",
    "Numpad4",
    "Numpad5",
    "Numpad6",
    "Numpad7",
    "Numpad8",
    "Numpad9",
    "NumpadAdd",
    "NumpadBackspace",
    "NumpadClear",
    "NumpadClearEntry",
    "NumpadComma",
    "NumpadDecimal",
    "NumpadDivide",
    "NumpadEnter",
    "NumpadEqual",
    "NumpadHash",
    "NumpadMemoryAdd",
    "NumpadMemoryClear",
    "NumpadMemoryRecall",
    "NumpadMemoryStore",
    "NumpadMemorySubtract",
    "NumpadMultiply",
    "NumpadParenLeft",
    "NumpadParenRight",
    "NumpadStar",
    "NumpadSubtract",
    // 3.5 Function Section
    "Escape",
    "F1",
    "F2",
    "F3",
    "F4",
    "F5",
    "F6",
    "F7",
    "F8",
    "F9",
    "F10",
    "F11",
    "F12",
    "F13",
    "F14",
    "F15",
    "F16",
    "F17",
    "F18",
    "F19",
    "F20",
    "F21",
    "F22",
    "F23",
    "F24",
    "Fn",
    "FnLock",
    "PrintScreen",
    "ScrollLock",
    "Pause",
    // 3.6 Media Keys
    "BrowserBack",
    "BrowserFavorites",
    "BrowserForward",
    "BrowserHome",
    "BrowserRefresh",
    "BrowserSearch",
    "BrowserStop",
    "Eject",
    "LaunchApp1",
    "LaunchApp2",
    "LaunchMail",
    "MediaPlayPause",
    "MediaSelect",
    "MediaStop",
    "MediaTrackNext",
    "MediaTrackPrevious",
    "Power",
    "Sleep",
    "AudioVolumeDown",
    "AudioVolumeMute",
    "AudioVolumeUp",
    "WakeUp",
    // 4.1 Legacy Modifier Keys, 4.2 Legacy Process Keys
    "Hyper",
    "Super",
    "Turbo",
    "Abort",
    "Resume",
    "Suspend",
    "Again",
    "Copy",
    "Cut",
    "Find",
    "Open",
    "Paste",
    "Props",
    "Select",
    "Undo",
    "Hiragana",
    "Katakana",
    // 5 Special Values
    "Unidentified",
};
