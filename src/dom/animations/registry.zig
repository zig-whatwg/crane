//! A window event loop's animations: the global animation list, each
//! document's default document timeline, animation time and pending
//! animation event queue, and "update animations and send events" (Web
//! Animations 1 4.4), HTML "update the rendering" step 11.
//!
//! OWNED by the Browser's event loop (src/browser/rendering.zig,
//! `Frames.animations`), reached through update_the_rendering's Loop. It
//! holds every animation, timeline and document as a BORROWED,
//! generation-checked Link: an object script dropped is collected and leaves
//! at the next retire pass. What it owns are the queued events (each an
//! engine.Owned, released when dispatched, dropped, or at the page's end).
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#update-animations-and-send-events
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");
const model = @import("model.zig");
const hooks = @import("hooks.zig");
const update_the_rendering = @import("../update_the_rendering.zig");
const fire_event = @import("../fire_event.zig");
const document_activity = @import("../document_activity.zig");
const performance_timeline = @import("../performance_timeline.zig");

const Allocator = std.mem.Allocator;
const Link = model.Link;

/// An event queued for dispatch at an animation's document for timing
/// (4.5.18), or in a task (`EventTask`).
pub const QueuedEvent = struct {
    /// The event, made when it was queued (lesson: create an event before
    /// queuing its dispatch). OWNED.
    event: engine.Owned,
    event_instance: *runtime.Instance,
    /// The target: the animation, or a CSS animation's owning element.
    target: Link,
    /// The animation it reports on, whose `queued_events` counts it.
    animation: Link,
    /// 4.5.18 the scheduled event time (origin-relative), or unresolved.
    scheduled: ?f64,
    /// 5.4.2 the animation's composite order at queuing.
    class: model.Class,
    sequence: u64,
    /// Queue order, for a stable sort.
    order: u64,

    fn release(self: *QueuedEvent) void {
        self.event.release();
        if (self.animation.get()) |instance| if (hooks.animationOf(instance)) |animation| {
            animation.queued_events -|= 1;
        };
    }
};

const DocumentEntry = struct {
    document: Link,
    /// The default document timeline (4.3.1.1), kept by a traced edge from
    /// the document.
    timeline: ?Link = null,
    /// The document's animation time: its timelines' current time at origin
    /// time zero, ms relative to its time origin. Set at each "update
    /// animations and send events" and constant between them (6.13); null
    /// until first read.
    time: ?f64 = null,
    /// 4.5.18 the pending animation event queue.
    events: std.ArrayListUnmanaged(QueuedEvent) = .empty,
};

pub const Registry = struct {
    allocator: Allocator,
    next_sequence: u64 = 1,
    next_order: u64 = 0,
    /// The global animation list (4.5): every animation made in this loop's
    /// realms, in creation order.
    animations: std.ArrayListUnmanaged(Link) = .empty,
    /// Retire dead links once the list doubles since the last pass.
    retire_at: usize = 64,
    documents: std.ArrayListUnmanaged(DocumentEntry) = .empty,
    /// Moves on every change that can move an effect value (any animation's
    /// timing, state, effect, target or keyframes, and each update of a
    /// document that has animations): the style key component of every
    /// element an effect targets (effect_stack.component). Never 0.
    values_revision: u64 = 1,
    /// The last serial a resolved style took (effect_stack.nextStyleSerial).
    style_serial: u64 = 0,
    /// The effects per target for `values_revision` (effect_stack.zig).
    targets: @import("effect_stack.zig").TargetIndex = .{},
    /// commitStyles' partial effect stack, armed for one style read
    /// (effect_stack.Commit; root.commitStyles). Borrowed.
    commit: ?*@import("effect_stack.zig").Commit = null,

    pub fn init(allocator: Allocator) Registry {
        return .{ .allocator = allocator };
    }

    /// The loop ends. The page's end released the events already
    /// (`endPage`); what is left is storage.
    pub fn deinit(self: *Registry) void {
        // The engine values went at the page's end (`endPage`), before the
        // realms; the loop's end never releases one (its agent may be gone).
        for (self.documents.items) |*entry| entry.events.deinit(self.allocator);
        self.documents.deinit(self.allocator);
        self.animations.deinit(self.allocator);
        self.targets.deinit(self.allocator);
        self.* = .{ .allocator = self.allocator };
    }

    /// The page ends (before its realms do): every queued event is released,
    /// never dispatched.
    pub fn endPage(self: *Registry) void {
        for (self.documents.items) |*entry| {
            for (entry.events.items) |*queued| queued.event.release();
            entry.events.deinit(self.allocator);
        }
        self.documents.clearAndFree(self.allocator);
        for (self.animations.items) |link| {
            const instance = link.get() orelse continue;
            if (hooks.animationOf(instance)) |animation| {
                animation.queued_events = 0;
                animation.letGo();
            }
        }
        self.animations.clearAndFree(self.allocator);
        self.targets.deinit(self.allocator);
        self.values_revision +%= 1;
    }

    /// `realm`'s window goes (its document destroyed): its documents' queued
    /// events are released, and its animations stop keeping themselves.
    pub fn windowDestroyed(self: *Registry, realm: runtime.Context) void {
        var index: usize = 0;
        while (index < self.documents.items.len) {
            const entry = &self.documents.items[index];
            const document = entry.document.get();
            if (document == null or document.?.ctx == realm) {
                for (entry.events.items) |*queued| queued.release();
                entry.events.deinit(self.allocator);
                _ = self.documents.swapRemove(index);
            } else index += 1;
        }
        for (self.animations.items) |link| {
            const instance = link.get() orelse continue;
            if (instance.ctx != realm) continue;
            if (hooks.animationOf(instance)) |animation| animation.letGo();
        }
    }

    fn entryFor(self: *Registry, document: *runtime.Instance) ?*DocumentEntry {
        const generation = runtime.SlabAllocator.generationOf(document);
        for (self.documents.items) |*entry| {
            if (entry.document.instance == document and entry.document.generation == generation) return entry;
        }
        return null;
    }

    fn ensureEntry(self: *Registry, document: *runtime.Instance) !*DocumentEntry {
        if (self.entryFor(document)) |entry| return entry;
        self.retireDocuments();
        try self.documents.append(self.allocator, .{ .document = Link.to(document) });
        return &self.documents.items[self.documents.items.len - 1];
    }

    /// Documents freed since: their entries go, events released.
    fn retireDocuments(self: *Registry) void {
        var index: usize = 0;
        while (index < self.documents.items.len) {
            const entry = &self.documents.items[index];
            if (entry.document.get() == null) {
                for (entry.events.items) |*queued| queued.release();
                entry.events.deinit(self.allocator);
                _ = self.documents.swapRemove(index);
            } else index += 1;
        }
    }

    fn retireAnimations(self: *Registry) void {
        var write: usize = 0;
        for (self.animations.items) |link| {
            if (link.get() == null) continue;
            self.animations.items[write] = link;
            write += 1;
        }
        self.animations.shrinkRetainingCapacity(write);
        self.retire_at = @max(64, write * 2);
    }
};

/// The registry of `realm`'s event loop; null for a realm no Browser loop
/// runs (a unit test's).
pub fn of(realm: runtime.Context) ?*Registry {
    return update_the_rendering.animationRegistry(realm);
}

/// Something that can move an effect value changed: every targeted
/// element's style key moves (and only theirs).
pub fn valuesChanged(realm: runtime.Context) void {
    const registry = of(realm) orelse return;
    registry.values_revision +%= 1;
    if (registry.values_revision == 0) registry.values_revision = 1;
}

/// A new animation joins the global animation list (4.5).
pub fn register(animation: *model.Animation) void {
    const registry = of(animation.instance.ctx) orelse return;
    animation.sequence = registry.next_sequence;
    registry.next_sequence += 1;
    if (registry.animations.items.len >= registry.retire_at) registry.retireAnimations();
    registry.animations.append(registry.allocator, Link.to(animation.instance)) catch {};
}

/// The document's animation time (4.3.1, 6.13): what its document timelines'
/// current time is measured from. Null while the document is not fully
/// active (an inactive timeline). Before the document's first update it is
/// taken once from the loop's latest refresh moment (Blink AnimationClock,
/// Gecko's most recent refresh), and then holds until the next update.
pub fn documentTime(document: *runtime.Instance) ?f64 {
    if (!document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return null;
    const registry = of(document.ctx) orelse return null;
    const entry = registry.ensureEntry(document) catch return null;
    if (entry.time) |time| return time;
    const refresh = update_the_rendering.latestRefresh(document.ctx) orelse return null;
    const time = @max(relativeTime(document.ctx, refresh) orelse return null, 0);
    entry.time = time;
    return time;
}

/// The relative high resolution time of the monotonic moment `moment_ns`
/// for `realm`'s global, as rAF timestamps are (HTML update the rendering
/// step 14).
fn relativeTime(realm: runtime.Context, moment_ns: i64) ?f64 {
    const unsafe_ms = @as(f64, @floatFromInt(moment_ns)) / std.time.ns_per_ms;
    return performance_timeline.relativeCoarseTime(realm, unsafe_ms);
}

/// `document`'s default document timeline (4.3.1.1), made the first time
/// it is asked for. The document keeps it through a traced edge for the
/// document's life; the registry finds it by Link.
pub fn defaultTimeline(document: *runtime.Instance) !*runtime.Instance {
    const registry = of(document.ctx);
    if (registry) |r| if (r.entryFor(document)) |entry| {
        if (entry.timeline) |link| if (link.get()) |timeline| return timeline;
    };
    const timeline = try interfaces.DocumentTimeline.init(document.ctx.allocator, document.ctx);
    if (hooks.timelineOf(timeline)) |t| {
        t.document = Link.to(document);
        t.origin_time = 0;
    }
    engine.traceChild(document, timeline, .{ .name = "Document:timeline" });
    if (registry) |r| {
        const entry = try r.ensureEntry(document);
        entry.timeline = Link.to(timeline);
    }
    return timeline;
}

/// The document a realm's global is associated with: "the Document
/// associated with the Window that is the current global object".
pub fn documentOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const global = performance_timeline.globalOf(realm) orelse return null;
    if (!std.mem.eql(u8, global.vtable.name, "Window")) return null;
    return interfaces.Window.get_document(global) catch null;
}

pub fn requestFrameFor(document: *runtime.Instance) void {
    update_the_rendering.requestFrame(document);
}

/// Whether `document`'s animations have work for its next frame: a queued
/// event, or an animation it times that is running or has a pending task.
/// Its reactivation asks for a frame then (lesson: restoring a document must
/// restore native rendering work).
pub fn needsFrames(document: *runtime.Instance) bool {
    const registry = of(document.ctx) orelse return false;
    if (registry.entryFor(document)) |entry| if (entry.events.items.len != 0) return true;
    for (registry.animations.items) |link| {
        const instance = link.get() orelse continue;
        const animation = hooks.animationOf(instance) orelse continue;
        if (animation.documentForTiming() != document) continue;
        if (animation.hasPendingTask() or animation.playState() == .running) return true;
    }
    return false;
}

// ============================================================================
// Animation events (4.5.18)
// ============================================================================

/// Make an AnimationPlaybackEvent `event_type` for `animation` and queue it
/// at its document for timing, or - with none - in a task (4.5.12 step 5.1.7,
/// 4.5.14 step 1.10, 5.5.2 step 6).
pub fn queuePlaybackEvent(animation: *model.Animation, event_type: []const u8, current_time: ?f64, timeline_time: ?f64, scheduled: ?f64) void {
    const realm = animation.instance.ctx;
    if (!realm.hasEngine()) return;
    const event = interfaces.AnimationPlaybackEvent.call_constructor(
        realm,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.AnimationPlaybackEventInit).passed(.{
            .base = .{},
            .currentTime = if (current_time) |t| .{ .double = t } else null,
            .timelineTime = if (timeline_time) |t| .{ .double = t } else null,
        }),
    ) catch return;
    queueEvent(animation, event, animation.instance, scheduled);
}

/// Queue `event` (just made, unwrapped) for `target`, reporting on
/// `animation`.
pub fn queueEvent(animation: *model.Animation, event: *runtime.Instance, target: *runtime.Instance, scheduled: ?f64) void {
    const realm = animation.instance.ctx;
    const generation = runtime.SlabAllocator.generationOf(event);
    const owned = engine.retainValue(realm, .{ .instance = event }) catch {
        event.releaseIfUnwrapped(generation);
        return;
    };
    var queued: QueuedEvent = .{
        .event = owned,
        .event_instance = event,
        .target = Link.to(target),
        .animation = Link.to(animation.instance),
        .scheduled = scheduled,
        .class = animation.class,
        .sequence = animation.sequence,
        .order = 0,
    };
    if (animation.documentForTiming()) |document| {
        if (of(realm)) |registry| if (registry.ensureEntry(document)) |entry| {
            queued.order = registry.next_order;
            registry.next_order += 1;
            if (entry.events.append(registry.allocator, queued)) {
                animation.queued_events += 1;
                requestFrameFor(document);
                return;
            } else |_| {}
        } else |_| {};
        owned.release();
        return;
    }
    // "Otherwise, queue a task to dispatch the event at animation", on the
    // DOM manipulation task source.
    EventTask.queue(animation, queued) catch owned.release();
}

/// An event dispatched from a task: the animation has no document for
/// timing.
const EventTask = struct {
    allocator: Allocator,
    queued: QueuedEvent,

    fn queue(animation: *model.Animation, queued: QueuedEvent) !void {
        const realm = animation.instance.ctx;
        const loop = realm.getOptionalEventLoop() orelse return error.NoEventLoop;
        const task = try realm.allocator.create(EventTask);
        task.* = .{ .allocator = realm.allocator, .queued = queued };
        const global = performance_timeline.globalOf(realm);
        animation.queued_events += 1;
        loop.queueTask(.{
            .callback = run,
            .context = task,
            .drop = drop,
            .document = if (global) |g| @ptrCast(g) else null,
            .document_generation = if (global) |g| runtime.SlabAllocator.generationOf(g) else 0,
        });
    }

    fn run(context: ?*anyopaque) void {
        const self: *EventTask = @ptrCast(@alignCast(context.?));
        var queued = self.queued;
        self.allocator.destroy(self);
        dispatch(&queued);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *EventTask = @ptrCast(@alignCast(context.?));
        var queued = self.queued;
        self.allocator.destroy(self);
        queued.release();
    }
};

/// Dispatch one queued event at its target, then release it.
fn dispatch(queued: *QueuedEvent) void {
    defer {
        const animation_instance = queued.animation.get();
        queued.release();
        if (animation_instance) |instance| if (hooks.animationOf(instance)) |animation| animation.settle();
    }
    const target = queued.target.get() orelse return;
    _ = fire_event.dispatchTrusted(target, queued.event_instance) catch {};
}

// ============================================================================
// Update animations and send events (4.4)
// ============================================================================

/// HTML update the rendering step 11 for `document` at `frame`: Web
/// Animations "update animations and send events" given the relative high
/// resolution time of frameTimestamp.
pub fn updateAnimationsAndSendEvents(document: *runtime.Instance, frame: update_the_rendering.Frame) void {
    const realm = document.ctx;
    const registry = of(realm) orelse return;
    const now = relativeTime(realm, frame.timestamp_ns) orelse return;
    // 1. "Update the current time of all timelines associated with doc
    // passing now as the timestamp": a document timeline's current time is
    // the document's time less its origin time. Monotonic: never earlier
    // than a time already read (4.3.1).
    {
        const entry = registry.ensureEntry(document) catch return;
        entry.time = if (entry.time) |previous| @max(previous, now) else now;
    }
    // ... which updates every animation associated with them: the pending
    // tasks of an animation that is now ready, its finished state, and the
    // events it queues. Snapshot first: resolving a promise can reach
    // script (a `then` getter on the animation).
    var snapshot = animationsTimedBy(registry, document) catch return;
    defer snapshot.deinit(registry.allocator);
    for (snapshot.items) |link| {
        const instance = link.get() orelse continue;
        const animation = hooks.animationOf(instance) orelse continue;
        if (animation.documentForTiming() != document) continue;
        animation.runPendingTasks();
        animation.updateFinishedState(false, false);
        if (animation.css != null) @import("css_events.zig").update(animation);
        animation.settle();
    }
    // 2. Remove replaced animations for doc.
    removeReplacedAnimations(registry, document);
    // 3. Perform a microtask checkpoint.
    if (realm.hasEngine()) if (realm.agent) |agent| engine.performMicrotaskCheckpoint(agent) catch {};
    // 4-7.
    sendEvents(document);
}

fn animationsTimedBy(registry: *Registry, document: *runtime.Instance) !std.ArrayListUnmanaged(Link) {
    var list: std.ArrayListUnmanaged(Link) = .empty;
    errdefer list.deinit(registry.allocator);
    for (registry.animations.items) |link| {
        const instance = link.get() orelse continue;
        const animation = hooks.animationOf(instance) orelse continue;
        if (animation.documentForTiming() == document) try list.append(registry.allocator, link);
    }
    return list;
}

/// 4.4 steps 4-7: take doc's pending animation event queue, sort it, and
/// dispatch each event at its target.
fn sendEvents(document: *runtime.Instance) void {
    const registry = of(document.ctx) orelse return;
    const entry = registry.entryFor(document) orelse return;
    // 4-5. Take the queue before any dispatch (lesson: take what an event
    // reports before dispatching it): events listeners queue wait for the
    // next update.
    var events = entry.events;
    entry.events = .empty;
    var next: usize = 0;
    defer {
        for (events.items[next..]) |*queued| queued.release();
        events.deinit(registry.allocator);
    }
    // 6. A stable sort: scheduled event time (unresolved first), then
    // composite order.
    std.sort.block(QueuedEvent, events.items, {}, eventLessThan);
    // 7.
    while (next < events.items.len) {
        const queued = &events.items[next];
        next += 1;
        dispatch(queued);
    }
}

fn eventLessThan(_: void, a: QueuedEvent, b: QueuedEvent) bool {
    if (a.scheduled == null and b.scheduled != null) return true;
    if (a.scheduled != null and b.scheduled == null) return false;
    if (a.scheduled != null and b.scheduled != null and a.scheduled.? != b.scheduled.?) return a.scheduled.? < b.scheduled.?;
    if (a.class != b.class) return @backingInt(a.class) < @backingInt(b.class);
    if (a.sequence != b.sequence) return a.sequence < b.sequence;
    return a.order < b.order;
}

// ============================================================================
// 5.5.2 Removing replaced animations
// ============================================================================

fn removeReplacedAnimations(registry: *Registry, document: *runtime.Instance) void {
    // The replaceable animations whose target is in doc, in composite order.
    var candidates: std.ArrayListUnmanaged(*model.Animation) = .empty;
    defer candidates.deinit(registry.allocator);
    for (registry.animations.items) |link| {
        const instance = link.get() orelse continue;
        const animation = hooks.animationOf(instance) orelse continue;
        if (!isReplaceable(animation)) continue;
        const effect = animation.effectModel() orelse continue;
        const target = effect.targetElement() orelse continue;
        // "whose effect target is a descendant of doc".
        const owner = interfaces.Node.get_ownerDocument(target) catch continue;
        if (owner != document or !(interfaces.Node.get_isConnected(target) catch false)) continue;
        candidates.append(registry.allocator, animation) catch return;
    }
    if (candidates.items.len < 2) return;
    std.mem.sort(*model.Animation, candidates.items, {}, compositeOrderLessThan);
    // From the highest composite order down: an active animation is removed
    // when every one of its target properties is already covered by a
    // higher one on the same target.
    var covered = Covered.init(registry.allocator);
    defer covered.deinit();
    var index = candidates.items.len;
    while (index > 0) {
        index -= 1;
        const animation = candidates.items[index];
        const effect = animation.effectModel() orelse continue;
        const target = effect.targetElement() orelse continue;
        var all_covered = true;
        var any = false;
        for (effect.keyframes.frames.items) |frame| for (frame.properties.items) |property| {
            any = true;
            if (!covered.has(target, effect.pseudo, property.name)) all_covered = false;
        };
        if (animation.replace_state == .active and any and all_covered) {
            // 1-6.
            animation.replace_state = .removed;
            const timeline_time = animation.timelineTime();
            const scheduled = if (animation.timelineModel()) |timeline| timeline.toOriginRelative(timeline_time) else null;
            queuePlaybackEvent(animation, "remove", animation.currentTime(), timeline_time, scheduled);
            animation.settle();
        }
        for (effect.keyframes.frames.items) |frame| for (frame.properties.items) |property| {
            covered.add(target, effect.pseudo, property.name) catch {};
        };
    }
}

/// 5.5.2 "replaceable".
fn isReplaceable(animation: *model.Animation) bool {
    if (animation.class != .script and animation.css != null and @import("css_events.zig").hasOwningElement(animation)) return false;
    if (animation.playState() != .finished) return false;
    if (animation.replace_state == .removed) return false;
    if (animation.timelineModel() == null) return false;
    const effect = animation.effectModel() orelse return false;
    if (!effect.isInEffect()) return false;
    return effect.targetElement() != null;
}

pub fn compositeOrderLessThan(_: void, a: *model.Animation, b: *model.Animation) bool {
    if (a.class != b.class) return @backingInt(a.class) < @backingInt(b.class);
    return a.sequence < b.sequence;
}

/// The (target, pseudo, property) triples a higher animation sets: target
/// properties as the longhands their names expand to.
const Covered = struct {
    allocator: Allocator,
    entries: std.ArrayListUnmanaged(Entry) = .empty,

    const Entry = struct { target: *runtime.Instance, pseudo: []const u8, longhand: Key };
    const Key = union(enum) { longhand: u16, custom: []const u8 };

    fn init(allocator: Allocator) Covered {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *Covered) void {
        self.entries.deinit(self.allocator);
    }

    fn add(self: *Covered, target: *runtime.Instance, pseudo: ?[]const u8, name: []const u8) !void {
        var keys: [64]Key = undefined;
        for (keysOf(target, name, &keys)) |key| try self.entries.append(self.allocator, .{ .target = target, .pseudo = pseudo orelse "", .longhand = key });
    }

    fn has(self: *const Covered, target: *runtime.Instance, pseudo: ?[]const u8, name: []const u8) bool {
        var keys: [64]Key = undefined;
        const wanted = keysOf(target, name, &keys);
        if (wanted.len == 0) return false;
        outer: for (wanted) |key| {
            for (self.entries.items) |entry| {
                if (entry.target != target or !std.mem.eql(u8, entry.pseudo, pseudo orelse "")) continue;
                if (keyEql(entry.longhand, key)) continue :outer;
            }
            return false;
        }
        return true;
    }

    fn keyEql(a: Key, b: Key) bool {
        return switch (a) {
            .longhand => |l| b == .longhand and b.longhand == l,
            .custom => |c| b == .custom and std.mem.eql(u8, b.custom, c),
        };
    }

    /// The physical longhands `name` sets on `target` (5.5.2 "target
    /// property": shorthands expanded, logical properties resolved with the
    /// target's computed writing mode and direction).
    fn keysOf(target: *runtime.Instance, name: []const u8, out: *[64]Key) []const Key {
        if (std.mem.startsWith(u8, name, "--")) {
            out[0] = .{ .custom = name };
            return out[0..1];
        }
        const css = @import("css");
        const property = css.properties.lookup(name) orelse return out[0..0];
        const style = @import("../style/root.zig").engine.computedStyle(target, null) catch null;
        var count: usize = 0;
        switch (property) {
            .longhand => |l| {
                out[0] = .{ .longhand = @backingInt(if (style) |s| s.physical(l) else l) };
                count = 1;
            },
            .shorthand => |s| for (s.longhands()) |l| {
                if (count == out.len) break;
                out[count] = .{ .longhand = @backingInt(if (style) |cs| cs.physical(l) else l) };
                count += 1;
            },
        }
        return out[0..count];
    }
};

// ============================================================================
// getAnimations() (6.8, 6.10)
// ============================================================================

/// The relevant animations (4.6.7) whose effect target `matches`, in
/// composite order, as a new Array of the current realm. OWNED.
pub fn relevantAnimations(realm: runtime.Context, context: anytype, comptime matches: fn (@TypeOf(context), *const model.Effect) bool) !engine.Owned {
    const allocator = realm.allocator;
    var found: std.ArrayListUnmanaged(*model.Animation) = .empty;
    defer found.deinit(allocator);
    if (of(realm)) |registry| {
        for (registry.animations.items) |link| {
            const instance = link.get() orelse continue;
            const animation = hooks.animationOf(instance) orelse continue;
            const effect = animation.effectModel() orelse continue;
            if (!matches(context, effect)) continue;
            if (!animation.isRelevant()) continue;
            try found.append(allocator, animation);
        }
    }
    std.mem.sort(*model.Animation, found.items, {}, compositeOrderLessThan);
    const instances = try allocator.alloc(*runtime.Instance, found.items.len);
    defer allocator.free(instances);
    for (found.items, instances) |animation, *instance| instance.* = animation.instance;
    const result_realm = engine.currentRealm() orelse realm;
    return engine.createSequenceOfPlatformObjects(result_realm, instances);
}
