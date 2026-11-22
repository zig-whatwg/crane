//! Screen Orientation (specs/w3c/screen-orientation.md): each Window's
//! associated ScreenOrientation - its [[type]] and [[angle]] - and the
//! algorithms the interface and HTML run: the common safety checks, lock()
//! and unlock()'s steps, the screen orientation change steps and "update
//! the screen orientation".
//!
//! The ScreenOrientation object is made when script first reads
//! `screen.orientation` (its impl calls `register`), and its internal slots
//! are kept here, per Browser, so that the change steps - which HTML's
//! "update the visibility state" (step 4) and a change of the tab's screen
//! (html.screen_info) run, outside the interface - can reach it from a
//! document. "Initializing the ScreenOrientation object" happens when the
//! browsing context is created; made later, the object takes the screen's
//! current orientation then, which is what the change steps would have
//! brought it to.
//!
//! Locking: no desktop browser locks the screen of a window - Chrome
//! desktop's ScreenOrientationProvider has no delegate and answers
//! SCREEN_ORIENTATION_LOCK_RESULT_ERROR_NOT_AVAILABLE, which Blink's
//! ScreenOrientation lock callback rejects as a NotSupportedError
//! "screen.orientation.lock() is not available on this device."
//! (content/browser/screen_orientation/screen_orientation_provider.cc,
//! third_party/blink/renderer/modules/screen_orientation/
//! screen_orientation.cc; reproduced, not copied). So lock() step 3 ("the
//! user agent does not support locking the screen orientation to
//! orientation") always holds, the screen's active orientation lock is
//! always null, and no lock promise is ever pending: unlock() returns at
//! its step 3. The integrator's ruling, 8:41 PM ET 2026-11-21: lock()
//! rejecting as Chrome desktop does. Lane cdph.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const platform = @import("platform");
const dom = @import("dom");
const interfaces = @import("interfaces");
const screen_info = @import("screen_info.zig");

pub const OrientationType = platform.OrientationType;

/// A Window's associated ScreenOrientation's internal slots.
pub const Slots = struct {
    /// The ScreenOrientation, by identity and slab generation.
    orientation: *runtime.Instance,
    generation: u64,
    /// Its relevant global, by identity and slab generation.
    window: *runtime.Instance,
    window_generation: u64,
    /// [[initialType]], [[type]], [[angle]].
    initial_type: OrientationType,
    type: OrientationType,
    angle: u16,

    fn isLive(self: *const Slots) bool {
        return runtime.SlabAllocator.generationOf(self.orientation) == self.generation;
    }
};

/// The Browser's ScreenOrientation objects (a BrowserScope supplement; the
/// window thread). An entry whose object was collected is skipped by every
/// reader and pruned when another object is registered.
pub const Registry = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayListUnmanaged(Slots) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.entries.deinit(self.allocator);
    }

    fn prune(self: *Registry) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (self.entries.items[i].isLive()) {
                i += 1;
            } else {
                _ = self.entries.swapRemove(i);
            }
        }
    }

    fn ofOrientation(self: *Registry, orientation: *runtime.Instance) ?*Slots {
        for (self.entries.items) |*slots| {
            if (slots.orientation == orientation and slots.isLive()) return slots;
        }
        return null;
    }

    fn ofWindow(self: *Registry, window: *runtime.Instance) ?*Slots {
        const generation = runtime.SlabAllocator.generationOf(window);
        for (self.entries.items) |*slots| {
            if (slots.window == window and slots.window_generation == generation and slots.isLive()) return slots;
        }
        return null;
    }
};

/// "Initializing the ScreenOrientation object" for `orientation`, `window`'s
/// associated ScreenOrientation, just made: [[initialType]] and [[type]]
/// the screen's current orientation type, [[angle]] its current angle.
pub fn register(orientation: *runtime.Instance, window: *runtime.Instance) !void {
    const scope = runtime.BrowserScope.ofInstance(orientation);
    const registry = try scope.of(Registry);
    registry.prune();
    const screen = screen_info.ofWindow(window);
    try registry.entries.append(registry.allocator, .{
        .orientation = orientation,
        .generation = runtime.SlabAllocator.generationOf(orientation),
        .window = window,
        .window_generation = runtime.SlabAllocator.generationOf(window),
        .initial_type = screen.orientation,
        .type = screen.orientation,
        .angle = screen.orientation_angle,
    });
}

/// `orientation`'s internal slots, or null for one never registered.
pub fn slotsOf(orientation: *runtime.Instance) ?*const Slots {
    const registry = runtime.BrowserScope.ofInstance(orientation).existing(Registry) orelse return null;
    return registry.ofOrientation(orientation);
}

/// The `type` getter: [[type]]; an object never registered answers the
/// screen's current type.
pub fn typeOf(orientation: *runtime.Instance) OrientationType {
    if (slotsOf(orientation)) |slots| return slots.type;
    const window = windowOf(orientation) orelse return .landscape_primary;
    return screen_info.ofWindow(window).orientation;
}

/// The `angle` getter: [[angle]].
pub fn angleOf(orientation: *runtime.Instance) u16 {
    if (slotsOf(orientation)) |slots| return slots.angle;
    const window = windowOf(orientation) orelse return 0;
    return screen_info.ofWindow(window).orientation_angle;
}

fn windowOf(orientation: *runtime.Instance) ?*runtime.Instance {
    return @import("user_activation.zig").windowOfRealm(orientation.ctx);
}

/// The exception a step throws or rejects with.
pub const SafetyError = error{ InvalidStateError, SecurityError };

/// The "common safety checks" for `document`.
pub fn commonSafetyChecks(document: *runtime.Instance) SafetyError!void {
    // 1. "If document is not a fully active descendant of a top-level
    //    traversable with user attention, throw an "InvalidStateError"
    //    DOMException."
    if (!hasUserAttention(document)) return error.InvalidStateError;
    // 2. "If document has the sandboxed orientation lock browsing context
    //    flag set, throw "SecurityError" DOMException."
    if (dom.document_scripts.activeSandboxingFlags(document).orientation_lock) return error.SecurityError;
    // 3. "If document's visibility state is "hidden", throw "SecurityError"
    //    DOMException."
    if (interfaces.Document.get_hidden(document) catch false) return error.SecurityError;
}

/// HTML 6.6.2 "a fully active descendant of a top-level traversable with
/// user attention": `document` is fully active, and its top-level
/// traversable's system visibility state is "visible" and it has system
/// focus - which every one has in Crane (html.focus, the tab-focus ruling
/// 2026-11-19).
fn hasUserAttention(document: *runtime.Instance) bool {
    if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return false;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
    const bc = dom.browser_state.browsingContextOf(window) orelse return false;
    return bc.traversableSystemVisibility() == .visible;
}

/// lock(orientation): the promise it returns, OWNED.
pub fn lock(orientation: *runtime.Instance) !runtime.JSValue {
    const realm = orientation.ctx;
    // 1. "Let document be this's relevant global object's associated
    //    Document."
    const window = windowOf(orientation) orelse return rejected(realm, "InvalidStateError", "The object is no longer associated to a document.");
    const document = interfaces.Window.get_document(window) catch return rejected(realm, "InvalidStateError", "The object is no longer associated to a document.");
    // 2. "Run the common safety checks with document. If an exception is
    //    thrown, return a promise rejected with that exception and abort
    //    these steps."
    commonSafetyChecks(document) catch |err| return switch (err) {
        error.InvalidStateError => rejected(realm, "InvalidStateError", "The document is not a fully active descendant of a top-level traversable with user attention."),
        error.SecurityError => rejected(realm, "SecurityError", "The document is sandboxed or hidden."),
    };
    // 3. "If the user agent does not support locking the screen orientation
    //    to orientation, return a promise rejected with a
    //    "NotSupportedError" DOMException and abort these steps" - no
    //    orientation, as Chrome desktop (the header).
    return rejected(realm, "NotSupportedError", "screen.orientation.lock() is not available on this device.");
}

/// unlock(): steps 1-3 (step 3 always returns: the screen's active
/// orientation lock is never set, the header).
pub fn unlock(orientation: *runtime.Instance) SafetyError!void {
    // 1. "Let document be this's relevant global object's associated
    //    Document."
    const window = windowOf(orientation) orelse return error.InvalidStateError;
    const document = interfaces.Window.get_document(window) catch return error.InvalidStateError;
    // 2. "Run the common safety checks with document. If an exception is
    //    thrown, re-throw that exception and abort these steps."
    try commonSafetyChecks(document);
    // 3. "If screen's active orientation lock is null, return undefined."
}

fn rejected(realm: runtime.Context, name: []const u8, message: []const u8) !runtime.JSValue {
    const exception = try engine.createDOMException(realm, name, message);
    defer exception.release();
    return (try engine.createRejectedPromise(realm, exception.value)).take();
}

/// The "screen orientation change steps" for `document`.
pub fn changeSteps(document: *runtime.Instance) void {
    const scope = runtime.BrowserScope.ofInstance(document);
    // Nothing to update in a Browser whose script never read
    // screen.orientation.
    const registry = scope.existing(Registry) orelse return;
    if (registry.entries.items.len == 0) return;
    // 1. "Let documents be an ordered set consisting of document followed
    //    by document's descendant navigables's active documents, if any, in
    //    tree order."
    var documents = dom.navigables.inclusiveDescendantDocuments(document, scope.allocator);
    defer documents.deinit(scope.allocator);
    // 2. "For each doc in documents, update the screen orientation of doc."
    for (documents.items) |entry| {
        if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
        update(registry, entry.document);
    }
}

/// "Update the screen orientation" of `document`.
fn update(registry: *Registry, document: *runtime.Instance) void {
    // 1. "If document is not a fully active descendant of a top-level
    //    traversable with user attention, abort these steps."
    if (!hasUserAttention(document)) return;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return;
    // 2. "Let type and angle be the screen's current orientation type and
    //    current orientation angle."
    const screen = screen_info.ofWindow(window);
    // 3. "Let screenOrientation be document's relevant global object's
    //    associated ScreenOrientation" - none made yet: when it is, it takes
    //    the current type and angle (`register`).
    const slots = registry.ofWindow(window) orelse return;
    // 4. "If type is equal to screenOrientation's [[type]] and angle is
    //    equal to screenOrientation's [[angle]], abort these steps."
    if (slots.type == screen.orientation and slots.angle == screen.orientation_angle) return;
    // 5. "Queue a global task on the user interaction task source with
    //    document's relevant global object to perform the following steps."
    const loop = document.ctx.getOptionalEventLoop() orelse return;
    const task = registry.allocator.create(ChangeTask) catch return;
    task.* = .{
        .allocator = registry.allocator,
        .orientation = slots.orientation,
        .generation = slots.generation,
        .type = screen.orientation,
        .angle = screen.orientation_angle,
    };
    loop.queueTask(.{ .callback = ChangeTask.run, .context = task, .drop = ChangeTask.drop, .document = @ptrCast(document) });
}

/// "Update the screen orientation" step 5's task.
const ChangeTask = struct {
    allocator: std.mem.Allocator,
    orientation: *runtime.Instance,
    generation: u64,
    type: OrientationType,
    angle: u16,

    fn run(context: ?*anyopaque) void {
        const self: *ChangeTask = @ptrCast(@alignCast(context orelse return));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.orientation) != self.generation) return;
        const registry = runtime.BrowserScope.ofInstance(self.orientation).existing(Registry) orelse return;
        const slots = registry.ofOrientation(self.orientation) orelse return;
        // Already there: an earlier task of the same change set it (the
        // change steps run for a document and again for each descendant
        // whose visibility state is updated with it). Chrome fires one
        // change per orientation change (ScreenOrientation::
        // OnOrientationChange compares with what it last told the page).
        if (slots.type == self.type and slots.angle == self.angle) return;
        // 5.1 "Set screenOrientation's [[angle]] to angle."
        slots.angle = self.angle;
        // 5.2 "Set screenOrientation's [[type]] to type."
        slots.type = self.type;
        // 5.3 "Fire an event named "change" at screenOrientation."
        dom.navigables.fireSimpleEvent(self.orientation, "change");
    }

    fn drop(context: ?*anyopaque) void {
        const self: *ChangeTask = @ptrCast(@alignCast(context orelse return));
        self.allocator.destroy(self);
    }
};
