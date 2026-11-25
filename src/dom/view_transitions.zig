//! CSS View Transitions 1 (with Level 2's active types and transition
//! root): a Document's same-document view transition, from
//! document.startViewTransition() through its update callback, its
//! activation and its frames to its end - the ViewTransition object's model
//! (`Transition`, owned by the ViewTransition impl) and the document's part
//! (`DocumentState`, kept in its style engine beside the dynamic view
//! transition style sheet the transition writes).
//!
//! Crane draws nothing: a capture keeps no pixels (an old image is "taken"
//! with no bitmap, so ::view-transition-old() still exists), and every box a
//! capture measures is the renderer's, which the default platform does not
//! have - a captured element's border box is 0x0 at the snapshot containing
//! block's origin, the document element's the snapshot containing block (the
//! viewport). Everything else is the spec's: the phases, the update callback
//! queue, the promises, the named elements and the user-agent rules the
//! transition generates (setup transition pseudo-elements, update
//! pseudo-element styles), which getComputedStyle() reads for the
//! ::view-transition-* pseudo-elements (dom.style.engine matches the
//! dynamic sheet for them).
//!
//! Lifetime: the document's active view transition and each transition in
//! its update callback queue are traced from the Document (a child edge per
//! slot), so script needs no reference to keep one going; a transition
//! keeps its update callback (a traced value) and its captured new elements
//! (traced children) itself. Links back from the model are generation-
//! checked and weak.
//!
//! Spec: https://drafts.csswg.org/css-view-transitions-1/#api
//! Spec: https://drafts.csswg.org/css-view-transitions-2/

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const callbacks = @import("callbacks");
const css = @import("css");
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");
const update_the_rendering = @import("update_the_rendering.zig");
const style_engine = @import("style/engine.zig");
const style_hooks = @import("style/hooks.zig");
const animations = @import("animations/root.zig");

/// A weak, generation-checked link to a platform object.
pub const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    pub fn to(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    pub fn get(self: Link) ?*runtime.Instance {
        if (!self.instance.ctx.hasEngine()) return null;
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

// ============================================================================
// The document's part (§7.1.1)
// ============================================================================

/// A Document's view transition state (View Transitions 1 §7.1.1).
pub const DocumentState = struct {
    /// "active view transition": traced from the document (`active_slot`).
    active: ?Link = null,
    /// "rendering suppression for view transitions". Crane hit-tests through
    /// the renderer; nothing reads it yet.
    rendering_suppression: bool = false,
    /// "show view transition tree".
    show_tree: bool = false,
    /// "update callback queue": each traced from the document in a slot of
    /// its own (`queueSlot`).
    queue: std.ArrayList(QueueEntry) = .empty,
    next_queue_id: u64 = 0,

    pub const QueueEntry = struct { transition: Link, id: u64 };

    pub fn deinit(self: *DocumentState, allocator: Allocator) void {
        // The edges die with the document's wrapper; nothing else is held.
        self.queue.deinit(allocator);
        self.* = .{};
    }
};

const active_slot: engine.TracedSlot = .{ .name = "Document:activeViewTransition" };

fn queueSlot(id: u64, buffer: *[64]u8) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "Document:viewTransitionQueue:{d}", .{id}) catch unreachable };
}

/// `document`'s state, or null before its first startViewTransition() (or
/// with no style engine): a read never makes it.
fn stateOf(document: *runtime.Instance) ?*DocumentState {
    return style_engine.viewTransitionState(document);
}

/// `document`'s active view transition (the activeViewTransition getter).
pub fn activeOf(document: *runtime.Instance) ?*runtime.Instance {
    const state = stateOf(document) orelse return null;
    const link = state.active orelse return null;
    return link.get();
}

// ============================================================================
// The ViewTransition's model (§6.2)
// ============================================================================

pub const Phase = enum { pending_capture, update_callback_called, animating, done };

/// A promise made with its owner and kept by it: OWNED resolving state while
/// pending, then a traced edge from the owner (animations.promise.Slot's
/// model, made eagerly: §6.2's promises exist from the start, so their
/// rejections reach unhandledrejection whether or not script read them).
pub const OwnedPromise = struct {
    slot: engine.TracedSlot,
    capability: ?engine.PromiseCapability = null,
    made: bool = false,
    status: enum { pending, fulfilled, rejected } = .pending,

    fn make(self: *OwnedPromise, owner: *runtime.Instance) !void {
        self.capability = try engine.createPromise(owner.ctx);
        self.made = true;
    }

    pub fn get(self: *OwnedPromise, owner: *runtime.Instance) !engine.Owned {
        if (!self.made) try self.make(owner);
        if (self.capability) |capability| return engine.retainValue(owner.ctx, capability.promise);
        return engine.tracedValue(owner, self.slot) orelse error.InvalidStateError;
    }

    fn promiseValue(self: *OwnedPromise) ?runtime.JSValue {
        const capability = self.capability orelse return null;
        return capability.promise;
    }

    pub fn resolve(self: *OwnedPromise, owner: *runtime.Instance, value: runtime.JSValue) void {
        if (self.status != .pending) return;
        self.status = .fulfilled;
        const capability = if (self.capability) |*pending| pending else return;
        engine.resolvePromise(capability, value) catch {};
        self.keepSettled(owner);
    }

    pub fn reject(self: *OwnedPromise, owner: *runtime.Instance, reason: runtime.JSValue) void {
        if (self.status != .pending) return;
        self.status = .rejected;
        const capability = if (self.capability) |*pending| pending else return;
        engine.rejectPromise(capability, reason) catch {};
        self.keepSettled(owner);
    }

    pub fn markHandled(self: *OwnedPromise, owner: *runtime.Instance) void {
        if (self.capability) |capability| {
            engine.markPromiseAsHandled(owner.ctx, capability.promise);
        } else if (engine.tracedValue(owner, self.slot)) |kept| {
            defer kept.release();
            engine.markPromiseAsHandled(owner.ctx, kept.borrow());
        }
    }

    fn keepSettled(self: *OwnedPromise, owner: *runtime.Instance) void {
        const capability = if (self.capability) |*pending| pending else return;
        engine.traceValue(owner, capability.promise, self.slot);
        engine.releasePromiseCapability(capability);
        self.capability = null;
    }

    pub fn deinit(self: *OwnedPromise, owner: *runtime.Instance, owner_live: bool) void {
        if (self.capability) |*capability| {
            engine.releasePromiseCapability(capability);
        } else if (self.made and owner_live) engine.forgetTracedChild(owner, self.slot);
        self.capability = null;
        self.made = false;
    }
};

/// §7.1.3 a captured element: what the old state kept, and the new element.
/// Computed values are kept as their serializations, for the dynamic
/// sheet's rules.
pub const Captured = struct {
    /// The view transition name (the named elements map's key). Owned.
    name: []u8,
    /// "old image": non-null in the spec once the old state was captured.
    /// Crane keeps no bitmap; this says one was taken.
    has_old_image: bool = false,
    old_width: f64 = 0,
    old_height: f64 = 0,
    /// old writing-mode, direction, text-orientation, mix-blend-mode,
    /// backdrop-filter and color-scheme, as serialized computed values.
    old_values: [captured_properties.len]?[]u8 = @splat(null),
    /// Level 2 §10: the captured element's class list (its
    /// view-transition-class), the new element's when there is one. Owned.
    classes: [][]u8 = &.{},
    /// "new element": traced from the transition (`newSlot`).
    new_element: ?Link = null,
    new_id: u64 = 0,

    fn deinit(self: *Captured, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.old_values) |value| if (value) |v| allocator.free(v);
        freeClasses(allocator, self.classes);
        self.* = undefined;
    }
};

/// The computed values §7.3.1 captures and §7.9 copies onto the group, in
/// the group styles rule's order.
const captured_properties = [_]css.properties.Longhand{ .writing_mode, .direction, .text_orientation, .mix_blend_mode, .backdrop_filter, .color_scheme };

fn freeClasses(allocator: Allocator, classes: [][]u8) void {
    for (classes) |class| allocator.free(class);
    if (classes.len != 0) allocator.free(classes);
}

pub const Transition = struct {
    allocator: Allocator,
    /// The ViewTransition object.
    owner: *runtime.Instance,
    phase: Phase = .pending_capture,
    /// Its "update callback" is traced from the owner (`update_slot`).
    has_update_callback: bool = false,
    /// The document whose transition this is: its relevant global's
    /// associated document, set by startViewTransition.
    document: ?Link = null,
    update_callback_done: OwnedPromise = .{ .slot = .{ .name = "ViewTransition:updateCallbackDone" } },
    ready: OwnedPromise = .{ .slot = .{ .name = "ViewTransition:ready" } },
    finished: OwnedPromise = .{ .slot = .{ .name = "ViewTransition:finished" } },
    /// "named elements", in insertion order.
    named: std.ArrayList(Captured) = .empty,
    next_new_id: u64 = 0,
    /// "initial snapshot containing block size".
    initial_size: ?[2]f64 = null,
    /// §7.5 step 8 waits on the update callback done promise; it had not
    /// settled when the transition was skipped.
    finish_after_update: bool = false,
    /// Level 2 §9: the "active types" startViewTransition was given, which
    /// the ViewTransitionTypeSet the `types` attribute answers starts with.
    /// Owned.
    active_types: [][]u8 = &.{},

    pub const update_slot: engine.TracedSlot = .{ .name = "ViewTransition:update" };
    const reason_slot: engine.TracedSlot = .{ .name = "ViewTransition:updateReason" };

    pub fn init(allocator: Allocator, owner: *runtime.Instance) Transition {
        return .{ .allocator = allocator, .owner = owner };
    }

    /// The ViewTransition's construction: §6.2's promises, made now; the
    /// finished promise "marked as handled".
    pub fn makePromises(self: *Transition) !void {
        try self.update_callback_done.make(self.owner);
        try self.ready.make(self.owner);
        try self.finished.make(self.owner);
        self.finished.markHandled(self.owner);
    }

    pub fn deinit(self: *Transition, owner_live: bool) void {
        self.update_callback_done.deinit(self.owner, owner_live);
        self.ready.deinit(self.owner, owner_live);
        self.finished.deinit(self.owner, owner_live);
        self.clearNamed(owner_live);
        self.named.deinit(self.allocator);
        freeClasses(self.allocator, self.active_types);
        self.active_types = &.{};
        if (owner_live and self.has_update_callback) engine.forgetTracedChild(self.owner, update_slot);
        self.has_update_callback = false;
    }

    fn clearNamed(self: *Transition, owner_live: bool) void {
        for (self.named.items) |*captured| {
            if (owner_live and captured.new_element != null) {
                var buffer: [64]u8 = undefined;
                engine.forgetTracedChild(self.owner, newSlot(captured.new_id, &buffer));
            }
            captured.deinit(self.allocator);
        }
        self.named.clearRetainingCapacity();
    }

    fn documentInstance(self: *const Transition) ?*runtime.Instance {
        const link = self.document orelse return null;
        return link.get();
    }

    fn find(self: *Transition, name: []const u8) ?*Captured {
        for (self.named.items) |*captured| if (std.mem.eql(u8, captured.name, name)) return captured;
        return null;
    }

    /// Level 2 §10.4: whether the class list captured for `name` contains
    /// every one of `classes`.
    pub fn hasClasses(self: *const Transition, name: []const u8, classes: []const []const u8) bool {
        for (self.named.items) |*captured| {
            if (!std.mem.eql(u8, captured.name, name)) continue;
            outer: for (classes) |wanted| {
                for (captured.classes) |class| if (std.mem.eql(u8, class, wanted)) continue :outer;
                return false;
            }
            return true;
        }
        return false;
    }
};

fn newSlot(id: u64, buffer: *[64]u8) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "ViewTransition:new:{d}", .{id}) catch unreachable };
}

/// The model of a ViewTransition object, through its impl.
pub fn transitionOf(instance: *runtime.Instance) ?*Transition {
    return style_hooks.viewTransitionOf(instance);
}

// ============================================================================
// §6.1.1 startViewTransition()
// ============================================================================

/// What startViewTransition's argument gave (Level 2's
/// `(ViewTransitionUpdateCallback or StartViewTransitionOptions)`).
pub const Start = struct {
    /// The update callback, BORROWED, or null.
    update: ?runtime.JSValue = null,
    /// StartViewTransitionOptions' types, OWNED by the transition once
    /// `start` took them.
    types: [][]u8 = &.{},
};

/// §6.1.1 steps 2-7 for the new `transition` (step 1 is the caller's: it
/// made the ViewTransition in this's relevant realm), on `document`.
pub fn start(document: *runtime.Instance, transition_instance: *runtime.Instance, options: Start) !void {
    const transition = transitionOf(transition_instance) orelse {
        freeClasses(document.ctx.allocator, options.types);
        return error.InvalidStateError;
    };
    transition.document = Link.to(document);
    freeClasses(transition.allocator, transition.active_types);
    transition.active_types = options.types;
    // 2. "If updateCallback is provided, set transition's update callback
    // to updateCallback."
    if (options.update) |callback| {
        engine.traceValue(transition_instance, callback, Transition.update_slot);
        transition.has_update_callback = true;
    }
    // The document's state is made here, by the first transition: every
    // other path reads it (stateOf).
    const state = (try style_engine.ensureViewTransitionState(document)) orelse {
        // A document with no style engine renders nothing: as hidden.
        try skipWithException(transition, "InvalidStateError", "The document is not rendered.");
        return;
    };
    // 4. "If document's visibility state is "hidden", then skip transition
    // with an "InvalidStateError" DOMException, and return transition."
    const visibility = interfaces.Document.get_visibilityState(document) catch ._hidden_;
    if (visibility != ._visible_) {
        try skipWithException(transition, "InvalidStateError", "The document is hidden.");
        return;
    }
    // 5. "If document's active view transition is not null, then skip that
    // view transition with an "AbortError" DOMException in this's relevant
    // Realm."
    if (state.active) |link| if (link.get()) |previous| if (transitionOf(previous)) |previous_transition| {
        if (previous_transition.phase != .done) try skipWithException(previous_transition, "AbortError", "A new view transition started.");
    };
    // 6. "Set document's active view transition to transition."
    setActive(document, state, transition_instance);
    // "The view transition process continues in setup view transition, via
    // perform pending transition operations": at the next rendering
    // opportunity.
    update_the_rendering.requestFrame(document);
}

fn setActive(document: *runtime.Instance, state: *DocumentState, transition: ?*runtime.Instance) void {
    if (transition) |instance| {
        engine.traceChild(document, instance, active_slot);
        state.active = Link.to(instance);
    } else {
        if (state.active != null) engine.forgetTracedChild(document, active_slot);
        state.active = null;
    }
}

// ============================================================================
// §7.2 perform pending transition operations (update the rendering step 18)
// ============================================================================

/// HTML "update the rendering" step 18 for `document`.
pub fn performPendingTransitionOperations(document: *runtime.Instance, frame: update_the_rendering.Frame) void {
    _ = frame;
    const state = stateOf(document) orelse return;
    const link = state.active orelse return;
    const instance = link.get() orelse {
        state.active = null;
        return;
    };
    const transition = transitionOf(instance) orelse return;
    switch (transition.phase) {
        // 1.1
        .pending_capture => setup(transition) catch {},
        // 1.2
        .animating => handleTransitionFrame(transition) catch {},
        else => {},
    }
}

// ============================================================================
// §7.3 setup and activation
// ============================================================================

/// §7.3 "setup view transition".
fn setup(transition: *Transition) !void {
    // 1.
    const document = transition.documentInstance() orelse return;
    // 2. "Flush the update callback queue."
    flushUpdateCallbackQueue(document);
    if (transition.phase != .pending_capture) return;
    // 3. "Capture the old state for transition. If failure is returned, then
    // skip the view transition for transition with an "InvalidStateError"
    // DOMException in transition's relevant Realm, and return."
    if (!try captureOldState(transition, document)) {
        try skipWithException(transition, "InvalidStateError", "Duplicate view-transition-name.");
        return;
    }
    // 4. "Set document's rendering suppression for view transitions to
    // true."
    if (stateOf(document)) |state| state.rendering_suppression = true;
    // 5. Queue a global task on the DOM manipulation task source.
    try queueTask(transition, .after_capture);
}

const TaskKind = enum { after_capture, flush_queue };

const Task = struct {
    allocator: Allocator,
    transition: Link,
    kind: TaskKind,
    kept: bool,

    fn run(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context orelse return));
        defer drop(self);
        const instance = self.transition.get() orelse return;
        engine.runTaskInRealm(instance.ctx, steps, self) catch {};
    }

    fn steps(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context orelse return));
        const instance = self.transition.get() orelse return;
        const transition = transitionOf(instance) orelse return;
        const document = transition.documentInstance() orelse return;
        switch (self.kind) {
            .after_capture => {
                // 5.1 "If transition's phase is "done", then abort these
                // steps."
                if (transition.phase == .done) return;
                // 5.2 "schedule the update callback for transition."
                scheduleUpdateCallback(transition) catch {};
                // 5.3 "Flush the update callback queue."
                flushUpdateCallbackQueue(document);
            },
            .flush_queue => flushUpdateCallbackQueue(document),
        }
    }

    fn drop(context: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(context orelse return));
        if (self.kept) if (self.transition.get()) |instance| engine.releasePlatformObject(instance);
        self.allocator.destroy(self);
    }
};

/// Queue a global task on the DOM manipulation task source, given the
/// transition's relevant global object.
fn queueTask(transition: *Transition, kind: TaskKind) !void {
    const loop = transition.owner.ctx.getOptionalEventLoop() orelse return;
    const task = try transition.allocator.create(Task);
    task.* = .{ .allocator = transition.allocator, .transition = Link.to(transition.owner), .kind = kind, .kept = true };
    engine.keepPlatformObjectAlive(transition.owner);
    const document = transition.documentInstance();
    loop.queueTask(.{ .callback = Task.run, .drop = Task.drop, .context = task, .document = document, .document_generation = if (document) |doc| runtime.SlabAllocator.generationOf(doc) else 0 });
}

/// The snapshot containing block's size: the viewport's (Crane's media
/// values), the document element's captured rectangle.
fn snapshotContainingBlockSize(document: *runtime.Instance) [2]f64 {
    const media = style_hooks.mediaValues(document);
    return .{ media.width, media.height };
}

/// An element's "document-scoped view transition name" (Level 2 §11.4):
/// its computed view-transition-name, null for `none`. `auto` and
/// `match-element` name the element itself ("-ua-element-" and its
/// identity), so its old and new captures pair; an `auto` element with an
/// id is named by it (§11.4 step 3).
fn transitionNameOf(allocator: Allocator, element: *runtime.Instance, style: *const css.computed_style.ComputedStyle) !?[]u8 {
    const value = style.get(.view_transition_name);
    switch (value) {
        .keyword => |keyword| switch (keyword) {
            .none => return null,
            .auto => {
                if (@import("element_data.zig").of(element)) |data| {
                    const id = data.idValue();
                    if (id.len != 0) return try allocator.dupe(u8, id);
                }
                return try std.fmt.allocPrint(allocator, "-ua-element-{x}", .{@intFromPtr(element)});
            },
            .match_element => return try std.fmt.allocPrint(allocator, "-ua-element-{x}", .{@intFromPtr(element)}),
            else => return null,
        },
        .text => |text| {
            // The serialization is the escaped <custom-ident>: the name is
            // the identifier it spells.
            return try css.tokenizer.decode(allocator, text.bytes);
        },
        else => return null,
    }
}

/// The element's view-transition-class (Level 2 §10.2), owned.
fn classesOf(allocator: Allocator, style: *const css.computed_style.ComputedStyle) ![][]u8 {
    const value = style.get(.view_transition_class);
    if (value != .text) return &.{};
    var list: std.ArrayList([]u8) = .empty;
    errdefer {
        for (list.items) |class| allocator.free(class);
        list.deinit(allocator);
    }
    var it = std.mem.tokenizeScalar(u8, value.text.bytes, ' ');
    while (it.next()) |escaped| try list.append(allocator, try css.tokenizer.decode(allocator, escaped));
    return list.toOwnedSlice(allocator);
}

/// Every element of `document`'s tree in tree order (the paint order this
/// engine can know without a renderer).
const ElementWalk = struct {
    root: *NodeBase,
    current: ?*NodeBase,

    fn init(document: *runtime.Instance) ?ElementWalk {
        const node = instance_bridge.getNodeBase(document) orelse return null;
        return .{ .root = node, .current = node.firstChild() };
    }

    fn next(self: *ElementWalk) ?*runtime.Instance {
        while (self.current) |node| {
            self.current = following(node, self.root);
            if (node.node_type != NodeBase.ELEMENT_NODE) continue;
            const instance = node.registeredInstance() orelse continue;
            return instance;
        }
        return null;
    }

    fn following(node: *NodeBase, root: *NodeBase) ?*NodeBase {
        if (node.firstChild()) |child| return child;
        var current: *NodeBase = node;
        while (current != root) {
            if (current.next_sibling) |sibling| return sibling;
            current = current.parent_node orelse return null;
        }
        return null;
    }
};

fn serializeComputed(allocator: Allocator, style: *const css.computed_style.ComputedStyle, longhand: css.properties.Longhand) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try style.serializeResolved(longhand, &out, allocator);
    return out.toOwnedSlice(allocator);
}

/// §7.3.1 "capture the old state"; false for failure.
fn captureOldState(transition: *Transition, document: *runtime.Instance) !bool {
    const allocator = transition.allocator;
    // 5. No implementation-defined maximum is reached by a viewport.
    // 6. "Set transition's initial snapshot containing block size."
    transition.initial_size = snapshotContainingBlockSize(document);
    const root = interfaces.Document.get_documentElement(document) catch null;
    // 3, 4, 7: the elements that capture, and their names.
    var names: std.ArrayList([]u8) = .empty;
    defer {
        for (names.items) |name| allocator.free(name);
        names.deinit(allocator);
    }
    var elements: std.ArrayList(*runtime.Instance) = .empty;
    defer elements.deinit(allocator);
    var walk = ElementWalk.init(document) orelse return true;
    while (walk.next()) |element| {
        // 7.1-7.2: no renderer skips contents or fragments a box.
        // 7.3-7.4: "If transitionName is none, or element is not rendered,
        // then continue."
        const style_hold = (try style_engine.computedStyle(element, null)) orelse continue;
        defer style_hold.release();
        const style = style_hold.style;
        const name = try transitionNameOf(allocator, element, style) orelse continue;
        var owns_name = true;
        defer if (owns_name) allocator.free(name);
        if (!try style_engine.isBeingRendered(element)) continue;
        // 7.5 "If usedTransitionNames contains transitionName, then ...
        // return failure."
        for (names.items) |used| if (std.mem.eql(u8, used, name)) return false;
        // 7.6-7.8
        try names.append(allocator, name);
        owns_name = false;
        try elements.append(allocator, element);
    }
    // 8. "For each element in captureElements": the capture.
    for (elements.items, names.items) |element, name| {
        const style_hold = (try style_engine.computedStyle(element, null)) orelse continue;
        defer style_hold.release();
        const style = style_hold.style;
        var capture: Captured = .{ .name = try allocator.dupe(u8, name), .has_old_image = true };
        errdefer capture.deinit(allocator);
        // 8.3-8.5: the snapshot containing block for the document element,
        // else the element's border box (no renderer: 0x0).
        if (root != null and root.? == element) {
            const size = transition.initial_size.?;
            capture.old_width = size[0];
            capture.old_height = size[1];
        }
        // 8.7-8.12
        for (captured_properties, 0..) |longhand, i| capture.old_values[i] = try serializeComputed(allocator, style, longhand);
        capture.classes = try classesOf(allocator, style);
        // 8.14 "Set namedElements[transitionName] to capture."
        if (transition.find(name)) |existing| {
            existing.deinit(allocator);
            existing.* = capture;
        } else try transition.named.append(allocator, capture);
    }
    return true;
}

/// §7.3.2 "capture the new state"; false for failure.
fn captureNewState(transition: *Transition, document: *runtime.Instance) !bool {
    const allocator = transition.allocator;
    var used: std.ArrayList([]u8) = .empty;
    defer {
        for (used.items) |name| allocator.free(name);
        used.deinit(allocator);
    }
    var walk = ElementWalk.init(document) orelse return true;
    while (walk.next()) |element| {
        const style_hold = (try style_engine.computedStyle(element, null)) orelse continue;
        defer style_hold.release();
        const style = style_hold.style;
        const name = try transitionNameOf(allocator, element, style) orelse continue;
        var owns_name = true;
        defer if (owns_name) allocator.free(name);
        // 4.3
        if (!try style_engine.isBeingRendered(element)) continue;
        // 4.5 "If usedTransitionNames contains transitionName, then return
        // failure."
        for (used.items) |seen| if (std.mem.eql(u8, seen, name)) return false;
        // 4.6
        try used.append(allocator, name);
        owns_name = false;
        // 4.7 "If namedElements[transitionName] does not exist, then set
        // namedElements[transitionName] to a new captured element struct."
        const captured = transition.find(name) orelse blk: {
            try transition.named.append(allocator, .{ .name = try allocator.dupe(u8, name) });
            break :blk &transition.named.items[transition.named.items.len - 1];
        };
        // 4.8 "Set namedElements[transitionName]'s new element to element."
        const id = transition.next_new_id;
        transition.next_new_id += 1;
        var buffer: [64]u8 = undefined;
        engine.traceChild(transition.owner, element, newSlot(id, &buffer));
        captured.new_element = Link.to(element);
        captured.new_id = id;
        freeClasses(allocator, captured.classes);
        captured.classes = &.{};
        captured.classes = try classesOf(allocator, style);
    }
    return true;
}

/// §7.3 "activate view transition".
fn activate(transition: *Transition) !void {
    // 1. "If transition's phase is "done", then return."
    if (transition.phase == .done) return;
    const document = transition.documentInstance() orelse return;
    // 2.
    if (stateOf(document)) |state| state.rendering_suppression = false;
    // 3. "If transition's initial snapshot containing block size is not
    // equal to the snapshot containing block size, then skip".
    if (transition.initial_size) |initial| {
        const now = snapshotContainingBlockSize(document);
        if (initial[0] != now[0] or initial[1] != now[1]) {
            try skipWithException(transition, "InvalidStateError", "The snapshot containing block changed size.");
            return;
        }
    }
    // 4. "Capture the new state for transition."
    if (!try captureNewState(transition, document)) {
        try skipWithException(transition, "InvalidStateError", "Duplicate view-transition-name.");
        return;
    }
    // 5. Each new element's "captured in a view transition": painting only.
    // 6. "Setup transition pseudo-elements for transition."
    if (stateOf(document)) |state| state.show_tree = true;
    // 7. "Update pseudo-element styles for transition." (with step 6's
    // rules: the dynamic sheet is written whole)
    if (!try updatePseudoElementStyles(transition, document)) {
        try skipWithException(transition, "InvalidStateError", "A captured element is not rendered.");
        return;
    }
    // 8.
    transition.phase = .animating;
    // 9. "Resolve transition's ready promise."
    transition.ready.resolve(transition.owner, .undefined);
    update_the_rendering.requestFrame(document);
}

// ============================================================================
// §7.3.3 and §7.9: the dynamic view transition style sheet
// ============================================================================

/// §7.9 "update pseudo-element styles", with §7.3.3's rules: the document's
/// dynamic view transition style sheet rewritten from the named elements.
/// False for failure (a new element no longer rendered).
fn updatePseudoElementStyles(transition: *Transition, document: *runtime.Instance) !bool {
    const allocator = transition.allocator;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    const root = interfaces.Document.get_documentElement(document) catch null;
    const size = snapshotContainingBlockSize(document);
    for (transition.named.items) |*captured| {
        var name_buffer: std.ArrayList(u8) = .empty;
        defer name_buffer.deinit(allocator);
        try css.serialize.appendIdentifier(&name_buffer, allocator, captured.name);
        const name = name_buffer.items;
        const new_element = if (captured.new_element) |link| link.get() else null;
        // §7.3.3 step 3.7-3.9: the animation rules.
        if (!captured.has_old_image) {
            try appendRule(&text, allocator, ":root::view-transition-new({s}) {{ animation-name: -ua-view-transition-fade-in; }}\n", .{name});
        } else if (new_element == null) {
            try appendRule(&text, allocator, ":root::view-transition-old({s}) {{ animation-name: -ua-view-transition-fade-out; }}\n", .{name});
        } else {
            try appendRule(&text, allocator, "@keyframes -ua-view-transition-group-anim-{s} {{ from {{ transform: matrix(1, 0, 0, 1, 0, 0); width: {d}px; height: {d}px; backdrop-filter: {s}; }} }}\n", .{ name, captured.old_width, captured.old_height, captured.old_values[4] orelse "none" });
            try appendRule(&text, allocator, ":root::view-transition-group({s}) {{ animation-name: -ua-view-transition-group-anim-{s}; }}\n", .{ name, name });
            try appendRule(&text, allocator, ":root::view-transition-image-pair({s}) {{ isolation: isolate; }}\n", .{name});
            try appendRule(&text, allocator, ":root::view-transition-old({s}) {{ animation-name: -ua-view-transition-fade-out, -ua-mix-blend-mode-plus-lighter; }}\n", .{name});
            try appendRule(&text, allocator, ":root::view-transition-new({s}) {{ animation-name: -ua-view-transition-fade-in, -ua-mix-blend-mode-plus-lighter; }}\n", .{name});
        }
        // §7.9 step 1: the group styles rule.
        var width = captured.old_width;
        var height = captured.old_height;
        var owned_values: [captured_properties.len]?[]u8 = @splat(null);
        defer for (owned_values) |value| if (value) |v| allocator.free(v);
        var values: [captured_properties.len][]const u8 = undefined;
        if (new_element) |element| {
            // 3.1 "Return failure if ... capturedElement's new element is
            // not rendered."
            if (!try style_engine.isBeingRendered(element)) return false;
            const style_hold = (try style_engine.computedStyle(element, null)) orelse return false;
            defer style_hold.release();
            const style = style_hold.style;
            // 3.2-3.5: the snapshot containing block, else its border box.
            if (root != null and root.? == element) {
                width = size[0];
                height = size[1];
            } else {
                width = 0;
                height = 0;
            }
            // 3.6-3.11
            for (captured_properties, 0..) |longhand, i| {
                owned_values[i] = try serializeComputed(allocator, style, longhand);
                values[i] = owned_values[i].?;
            }
        } else for (captured_properties, 0..) |_, i| {
            values[i] = captured.old_values[i] orelse "initial";
        }
        try appendRule(&text, allocator, ":root::view-transition-group({s}) {{ width: {d}px; height: {d}px; transform: matrix(1, 0, 0, 1, 0, 0); writing-mode: {s}; direction: {s}; text-orientation: {s}; mix-blend-mode: {s}; backdrop-filter: {s}; color-scheme: {s}; }}\n", .{ name, width, height, values[0], values[1], values[2], values[3], values[4], values[5] });
    }
    try style_engine.setViewTransitionSheet(document, text.items);
    return true;
}

fn appendRule(text: *std.ArrayList(u8), allocator: Allocator, comptime format: []const u8, args: anytype) !void {
    try text.print(allocator, format, args);
}

// ============================================================================
// §7.4 the update callback
// ============================================================================

/// §7.4 "schedule the update callback".
fn scheduleUpdateCallback(transition: *Transition) !void {
    const document = transition.documentInstance() orelse return;
    const state = stateOf(document) orelse return;
    // 1. "Append transition to transition's relevant settings object's
    // update callback queue."
    const id = state.next_queue_id;
    state.next_queue_id += 1;
    try state.queue.append(transition.allocator, .{ .transition = Link.to(transition.owner), .id = id });
    var buffer: [64]u8 = undefined;
    engine.traceChild(document, transition.owner, queueSlot(id, &buffer));
    // 2. "Queue a global task ... to flush the update callback queue."
    try queueTask(transition, .flush_queue);
}

/// §7.4 "flush the update callback queue".
fn flushUpdateCallbackQueue(document: *runtime.Instance) void {
    const state = stateOf(document) orelse return;
    if (state.queue.items.len == 0) return;
    // Taken first: a callback can schedule another.
    const allocator = document.ctx.allocator;
    const entries = state.queue.toOwnedSlice(allocator) catch return;
    defer allocator.free(entries);
    // 1. "For each transition in document's update callback queue, call the
    // update callback given transition."
    for (entries) |entry| {
        const instance = entry.transition.get() orelse continue;
        if (transitionOf(instance)) |transition| callUpdateCallback(transition) catch {};
        var buffer: [64]u8 = undefined;
        if (stateOf(document) != null) engine.forgetTracedChild(document, queueSlot(entry.id, &buffer));
    }
    // 2. "Set document's update callback queue to an empty list."
}

/// §7.4 "call the update callback".
fn callUpdateCallback(transition: *Transition) !void {
    const owner = transition.owner;
    const realm = owner.ctx;
    // 1-2.
    if (transition.phase != .done) transition.phase = .update_callback_called;
    // 3-5. callbackPromise: "a promise resolved with undefined", or the
    // result of invoking the update callback (a Promise<any>-returning
    // callback: what it throws is a rejection).
    var callback_promise: engine.Owned = undefined;
    const callback_value = if (transition.has_update_callback) engine.tracedValue(owner, Transition.update_slot) else null;
    if (callback_value) |function| {
        defer function.release();
        const callback: engine.CallbackFunction = .{ .function = .{ .value = function.borrow() }, .context = realm };
        callback_promise = callbacks.call.ViewTransitionUpdateCallback.invoke(realm, &callback, .undefined, .{}) catch |err| switch (err) {
            // A Window whose document is not fully active runs no callback.
            error.OutOfMemory => return err,
            else => return,
        };
    } else callback_promise = try engine.createResolvedPromise(realm, .undefined);
    defer callback_promise.release();
    // 6-8. "React to callbackPromise with fulfillSteps and rejectSteps."
    const reaction = try transition.allocator.create(Reaction);
    reaction.* = .{ .allocator = transition.allocator, .transition = Link.to(owner) };
    engine.keepPlatformObjectAlive(owner);
    engine.reactToPromise(realm, callback_promise.borrow(), &Reaction.steps, reaction) catch |err| {
        Reaction.dropped(reaction);
        return err;
    };
    // 9. No timeout: the update callback has as long as it takes.
}

const Reaction = struct {
    allocator: Allocator,
    transition: Link,

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .rejected = rejected, .dropped = dropped };

    fn fulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Reaction = @ptrCast(@alignCast(data orelse return));
        defer dropped(self);
        const instance = self.transition.get() orelse return;
        const transition = transitionOf(instance) orelse return;
        // fulfillSteps 1. "Resolve transition's update callback done
        // promise with undefined."
        transition.update_callback_done.resolve(instance, .undefined);
        if (transition.finish_after_update) {
            transition.finish_after_update = false;
            transition.finished.resolve(instance, .undefined);
        }
        // 2. "Activate transition."
        activate(transition) catch {};
    }

    fn rejected(data: ?*anyopaque, reason: runtime.JSValue) void {
        const self: *Reaction = @ptrCast(@alignCast(data orelse return));
        defer dropped(self);
        const instance = self.transition.get() orelse return;
        const transition = transitionOf(instance) orelse return;
        // rejectSteps 1. "Reject transition's update callback done promise
        // with reason."
        transition.update_callback_done.reject(instance, reason);
        engine.traceValue(instance, reason, Transition.reason_slot);
        // 2. "If transition's phase is "done", then return." - its finished
        // promise rejects along (§7.5 step 8).
        if (transition.phase == .done) {
            if (transition.finish_after_update) {
                transition.finish_after_update = false;
                transition.finished.reject(instance, reason);
            }
            return;
        }
        // 3. "Mark as handled transition's ready promise."
        transition.ready.markHandled(instance);
        // 4. "Skip the view transition transition with reason."
        skip(transition, reason) catch {};
    }

    fn dropped(data: ?*anyopaque) void {
        const self: *Reaction = @ptrCast(@alignCast(data orelse return));
        if (self.transition.get()) |instance| engine.releasePlatformObject(instance);
        self.allocator.destroy(self);
    }
};

// ============================================================================
// §7.5 skip, §7.8 transition frames, §7.10 clear
// ============================================================================

/// Skip `transition` with a new DOMException named `name` in its relevant
/// realm.
pub fn skipWithException(transition: *Transition, name: []const u8, message: []const u8) !void {
    const exception = try engine.createDOMException(transition.owner.ctx, name, message);
    defer exception.release();
    try skip(transition, exception.borrow());
}

/// §7.5 "skip the view transition" with `reason` (BORROWED).
pub fn skip(transition: *Transition, reason: runtime.JSValue) !void {
    const owner = transition.owner;
    // 1. 2. (a skipped transition is not skipped again)
    if (transition.phase == .done) return;
    const document = transition.documentInstance();
    // 3. "If transition's phase is before "update-callback-called", then
    // schedule the update callback for transition."
    if (transition.phase == .pending_capture) try scheduleUpdateCallback(transition);
    // 4. "Set rendering suppression for view transitions to false."
    if (document) |doc| if (stateOf(doc)) |state| {
        state.rendering_suppression = false;
        // 5. "If document's active view transition is transition, Clear view
        // transition transition."
        if (state.active) |link| if (link.get() == owner) clear(transition, doc);
    };
    // 6.
    transition.phase = .done;
    // 7. "Reject transition's ready promise with reason."
    transition.ready.reject(owner, reason);
    // 8. "Resolve transition's finished promise with the result of reacting
    // to transition's update callback done promise": undefined when it
    // fulfilled, its reason when it rejected - now if it settled, else when
    // it does (Reaction).
    switch (transition.update_callback_done.status) {
        .fulfilled => transition.finished.resolve(owner, .undefined),
        .rejected => if (engine.tracedValue(owner, Transition.reason_slot)) |kept| {
            defer kept.release();
            transition.finished.reject(owner, kept.borrow());
        } else transition.finished.reject(owner, reason),
        .pending => transition.finish_after_update = true,
    }
}

/// §7.6: the document became hidden.
pub fn pageVisibilityChanged(document: *runtime.Instance) void {
    const instance = activeOf(document) orelse return;
    const transition = transitionOf(instance) orelse return;
    if (transition.phase == .done) return;
    skipWithException(transition, "InvalidStateError", "The document became hidden.") catch {};
}

/// §7.8 "handle transition frame".
fn handleTransitionFrame(transition: *Transition) !void {
    // 1.
    const document = transition.documentInstance() orelse return;
    // 2-3. Any animation of the transition root pseudo-element or its
    // descendants that is paused or running.
    // 4. "If hasActiveAnimations is false": the end.
    if (!hasActiveAnimations(document)) {
        transition.phase = .done;
        clear(transition, document);
        transition.finished.resolve(transition.owner, .undefined);
        return;
    }
    // 5.
    if (transition.initial_size) |initial| {
        const now = snapshotContainingBlockSize(document);
        if (initial[0] != now[0] or initial[1] != now[1]) {
            try skipWithException(transition, "InvalidStateError", "The snapshot containing block changed size.");
            return;
        }
    }
    // 6. "Update pseudo-element styles for transition."
    if (!try updatePseudoElementStyles(transition, document)) {
        try skipWithException(transition, "InvalidStateError", "A captured element is not rendered.");
        return;
    }
    update_the_rendering.requestFrame(document);
}

/// Whether an animation of `document`'s document timeline targets one of
/// the document element's view transition pseudo-elements and is paused or
/// running (§7.8 step 3; the pending animation event queue is the
/// animations module's, and an animation it holds an event for is running
/// or just finished there).
fn hasActiveAnimations(document: *runtime.Instance) bool {
    const root = (interfaces.Document.get_documentElement(document) catch null) orelse return false;
    const registry = animations.registry.of(document.ctx) orelse return false;
    for (registry.animations.items) |link| {
        const instance = link.get() orelse continue;
        const animation = animations.hooks.animationOf(instance) orelse continue;
        const effect = animation.effectModel() orelse continue;
        const target = effect.targetElement() orelse continue;
        if (target != root) continue;
        const pseudo = effect.pseudo orelse continue;
        // An effect's pseudo-element is written with its "::" (CSS
        // Animations' and KeyframeEffect's alike).
        if (!std.mem.startsWith(u8, std.mem.trimStart(u8, pseudo, ":"), "view-transition")) continue;
        switch (animation.playState()) {
            .paused, .running => return true,
            else => {},
        }
    }
    return false;
}

/// §7.10 "clear view transition".
fn clear(transition: *Transition, document: *runtime.Instance) void {
    const state = stateOf(document) orelse return;
    // 1-2. "Set document's active view transition to null."
    if (state.active) |link| if (link.get() == transition.owner or link.get() == null) setActive(document, state, null);
    // 3. Each named element's new element's "captured in a view
    // transition" (painting only); its edge goes.
    // 4. "Set document's show view transition tree to false."
    state.show_tree = false;
    // 5. Remove the transition's rules from the dynamic sheet: it holds
    // this transition's only.
    style_engine.setViewTransitionSheet(document, null) catch {};
    transition.clearNamed(true);
}

// ============================================================================
// §3.2 the view transition pseudo-element tree
// ============================================================================

/// The transition whose pseudo-element tree `document` shows: its active
/// view transition, once §7.7 "setup transition pseudo-elements" ran (the
/// "show view transition tree" flag; the phase is animating then) and until
/// §7.10 "clear view transition".
fn shownTransition(document: *runtime.Instance) ?*Transition {
    const state = stateOf(document) orelse return null;
    if (!state.show_tree) return null;
    const instance = activeOf(document) orelse return null;
    const transition = transitionOf(instance) orelse return null;
    if (transition.phase != .animating) return null;
    return transition;
}

/// The named view transition pseudo-elements (§3.2), by the start of a
/// pseudo-element's bare name.
const PseudoKind = enum { group, image_pair, old, new };

const pseudo_kinds = [_]struct { prefix: []const u8, kind: PseudoKind }{
    .{ .prefix = "view-transition-group(", .kind = .group },
    .{ .prefix = "view-transition-image-pair(", .kind = .image_pair },
    .{ .prefix = "view-transition-old(", .kind = .old },
    .{ .prefix = "view-transition-new(", .kind = .new },
};

/// A bare pseudo-element name ("view-transition-group(x)") as its kind and
/// its argument; null for any other name.
fn splitNamed(name: []const u8) ?struct { kind: PseudoKind, argument: []const u8 } {
    for (pseudo_kinds) |entry| {
        if (!std.ascii.startsWithIgnoreCase(name, entry.prefix)) continue;
        if (name.len <= entry.prefix.len or name[name.len - 1] != ')') return null;
        return .{ .kind = entry.kind, .argument = name[entry.prefix.len .. name.len - 1] };
    }
    return null;
}

/// §3.2: whether `element` originates, right now, the view transition
/// pseudo-element whose bare name is `name` - "view-transition", or a named
/// one whose argument is a captured name: `element` is its document's
/// document element and the document shows the tree of a transition that
/// generated it (§7.7: a group and an image pair for each named element, an
/// old image where the old state was captured, a new image where there is a
/// new element). False for any other name, and for an argument with a class
/// list or the universal selector, which select pseudo-elements but name
/// none.
pub fn originatesPseudoElement(element: *runtime.Instance, name: []const u8) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    const root = (interfaces.Document.get_documentElement(document) catch null) orelse return false;
    if (root != element) return false;
    const transition = shownTransition(document) orelse return false;
    if (std.ascii.eqlIgnoreCase(name, "view-transition")) return true;
    const named = splitNamed(name) orelse return false;
    const captured = transition.find(named.argument) orelse return false;
    return switch (named.kind) {
        .group, .image_pair => true,
        .old => captured.has_old_image,
        .new => captured.new_element != null,
    };
}

/// Whether `name` (bare) is a view transition pseudo-element's.
pub fn isViewTransitionPseudoElement(name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, "view-transition") or splitNamed(name) != null;
}

/// Append to `names` the bare names of the view transition pseudo-elements
/// `document` shows, in tree order: ::view-transition, then for each named
/// element its group, image pair, old and new image. Each is allocated with
/// `allocator` and owned by the list; one already there is not added again.
/// Nothing when no tree is shown.
pub fn appendPseudoElementNames(document: *runtime.Instance, allocator: Allocator, names: *std.ArrayList([]u8)) Allocator.Error!void {
    const transition = shownTransition(document) orelse return;
    try appendOwned(allocator, names, try allocator.dupe(u8, "view-transition"));
    for (transition.named.items) |*captured| {
        try appendOwned(allocator, names, try std.fmt.allocPrint(allocator, "view-transition-group({s})", .{captured.name}));
        try appendOwned(allocator, names, try std.fmt.allocPrint(allocator, "view-transition-image-pair({s})", .{captured.name}));
        if (captured.has_old_image) try appendOwned(allocator, names, try std.fmt.allocPrint(allocator, "view-transition-old({s})", .{captured.name}));
        if (captured.new_element != null) try appendOwned(allocator, names, try std.fmt.allocPrint(allocator, "view-transition-new({s})", .{captured.name}));
    }
}

/// Append `name` (OWNED) to `names`, or free it when it is there already.
fn appendOwned(allocator: Allocator, names: *std.ArrayList([]u8), name: []u8) Allocator.Error!void {
    for (names.items) |n| if (std.mem.eql(u8, n, name)) {
        allocator.free(name);
        return;
    };
    names.append(allocator, name) catch |err| {
        allocator.free(name);
        return err;
    };
}

/// §3.2's tree, by name: whether the view transition pseudo-element
/// `descendant` (a bare name) is a descendant of `ancestor` - every named
/// one is under ::view-transition; a group's image pair and old and new
/// images are under that group; the old and new images under their image
/// pair. Whether either exists is the caller's question.
pub fn isPseudoElementDescendant(ancestor: []const u8, descendant: []const u8) bool {
    const below = splitNamed(descendant) orelse return false;
    if (std.ascii.eqlIgnoreCase(ancestor, "view-transition")) return true;
    const above = splitNamed(ancestor) orelse return false;
    if (!std.mem.eql(u8, above.argument, below.argument)) return false;
    return switch (above.kind) {
        .group => below.kind != .group,
        .image_pair => below.kind == .old or below.kind == .new,
        .old, .new => false,
    };
}

test "view transition pseudo-element tree: descendants by name" {
    try std.testing.expect(isPseudoElementDescendant("view-transition", "view-transition-group(a)"));
    try std.testing.expect(isPseudoElementDescendant("view-transition", "view-transition-new(a)"));
    try std.testing.expect(isPseudoElementDescendant("view-transition-group(a)", "view-transition-image-pair(a)"));
    try std.testing.expect(isPseudoElementDescendant("view-transition-group(a)", "view-transition-old(a)"));
    try std.testing.expect(isPseudoElementDescendant("view-transition-image-pair(a)", "view-transition-new(a)"));
    try std.testing.expect(!isPseudoElementDescendant("view-transition-group(a)", "view-transition-group(a)"));
    try std.testing.expect(!isPseudoElementDescendant("view-transition-group(a)", "view-transition-image-pair(b)"));
    try std.testing.expect(!isPseudoElementDescendant("view-transition-image-pair(a)", "view-transition-group(a)"));
    try std.testing.expect(!isPseudoElementDescendant("view-transition-new(a)", "view-transition-old(a)"));
    try std.testing.expect(!isPseudoElementDescendant("view-transition-group(a)", "before"));
    try std.testing.expect(!isPseudoElementDescendant("before", "view-transition-group(a)"));
    try std.testing.expect(!isPseudoElementDescendant("view-transition-group(a)", "view-transition"));
    try std.testing.expect(isViewTransitionPseudoElement("view-transition-old(x)"));
    try std.testing.expect(!isViewTransitionPseudoElement("before"));
}

/// Level 2 §10.4 (the view_transition_classes style hook): whether
/// `originating` - the document element - has an active view transition
/// that captured `name` with every one of `classes`.
pub fn viewTransitionClasses(originating: *runtime.Instance, name: []const u8, classes: []const []const u8) bool {
    const document = (interfaces.Node.get_ownerDocument(originating) catch null) orelse return false;
    const root = (interfaces.Document.get_documentElement(document) catch null) orelse return false;
    if (root != originating) return false;
    const instance = activeOf(document) orelse return false;
    const transition = transitionOf(instance) orelse return false;
    if (transition.phase != .animating) return false;
    return transition.hasClasses(name, classes);
}

/// §3.1 (the view_transition_only_child style hook): whether the view
/// transition pseudo-element `pseudo` ("view-transition-new(name)") of the
/// tree `originating` - the document element - shows has no sibling, which
/// is when :only-child matches it. The groups are the root's children; an
/// image pair is its group's one child; an old image has a sibling when the
/// pair holds a new one, and the other way round. False when no tree is
/// shown, or it holds no such pseudo-element.
pub fn viewTransitionOnlyChild(originating: *runtime.Instance, pseudo: []const u8) bool {
    const document = (interfaces.Node.get_ownerDocument(originating) catch null) orelse return false;
    const root = (interfaces.Document.get_documentElement(document) catch null) orelse return false;
    if (root != originating) return false;
    const transition = shownTransition(document) orelse return false;
    const named = splitNamed(pseudo) orelse return false;
    const captured = transition.find(named.argument) orelse return false;
    return switch (named.kind) {
        .group => transition.named.items.len == 1,
        .image_pair => true,
        .old => captured.has_old_image and captured.new_element == null,
        .new => captured.new_element != null and !captured.has_old_image,
    };
}
