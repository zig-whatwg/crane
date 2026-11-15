//! An event's dispatch state: what DOM's dispatch algorithm reads and writes
//! on an Event, most of which no IDL member sets.
//!
//! `EventState` is Event's internal state - its flags, target, related
//! target, current target, phase, isTrusted and touch target list (DOM 2.2)
//! - defined here so that the dispatcher (EventTarget) works on it directly:
//! Event's impl keeps it (`InternalState = EventState`), creates it with the
//! event and frees it with the event, and installs `of()` once, at process
//! start (its installHooks). The dispatcher takes `of(event)` once per
//! dispatch and works on the fields; Event's IDL getters read the same
//! fields. WebKit's split: dom/EventDispatcher.cpp's `dispatchEventInDOM`
//! calls Event's non-IDL members (`setEventPhase`, `setTarget`,
//! `setEventPath`) from outside Event.
//!
//! THE PATH IS THE DISPATCH'S (`DispatchPath`), never the Event's (lane ev1,
//! the user 2026-11-15: "adopt the behavior for the dispatch path that other
//! browsers use"). DOM 2.2 gives an event a "path", the empty list outside
//! dispatch (dispatch step 9 empties it), so an Event that is not being
//! dispatched needs no storage for one. How the three engines keep it (their
//! design, read in their source on 2026-11-15; none of their code is here):
//!
//!   - WebKit, Source/WebCore/dom/EventDispatcher.cpp,
//!     EventDispatcher::dispatchEventWithoutDebuggerDeferral: the EventPath
//!     is a local variable of the dispatch. Its contexts are a vector with
//!     room for 32 inside the object (the member m_path, dom/EventPath.h),
//!     so a path that short lives wholly in that stack frame - and a nested
//!     dispatch, entered from a listener, has a frame and a path of its
//!     own. The Event only points at the path, weakly (the member
//!     m_eventPath, dom/Event.h): Event::setEventPath is called just before
//!     the listeners run, and Event::resetAfterDispatch (dom/Event.cpp)
//!     clears the pointer. Event::composedPath answers an empty list
//!     without one.
//!   - Gecko, dom/events/EventDispatcher.cpp, EventDispatcher::Dispatch:
//!     the target chain is a local array of EventTargetChainItem. On the
//!     main thread its storage is borrowed from a small process-wide pool
//!     (sCachedMainThreadChains: four arrays of 128 items, so that the
//!     usual few levels of nested dispatch do not allocate) and given back
//!     when the dispatch returns. The event's mPath (WidgetEvent,
//!     widget/BasicEvents.h) points at the local chain only around
//!     EventTargetChainItem::HandleEventTargetChain, and
//!     EventDispatcher::GetComposedPathFor returns nothing when it is
//!     null. A chain item's retargeted touch targets are optional
//!     (mRetargetedTouchTargets): only a touch event's items have any.
//!   - Blink, third_party/blink/renderer/core/dom/events/
//!     event_dispatcher.cc: the EventDispatcher's constructor asks the
//!     event for its path (Event::InitEventPath, event.cc), which makes a
//!     garbage-collected EventPath on the first dispatch and reuses it for
//!     a later one; the Event keeps one traced pointer to it (event_path_,
//!     event.h) and Event::composedPath answers from the current target.
//!
//! Crane takes WebKit's shape (it is refcounted, with no collected heap to
//! park a finished path in): the path is a local of EventTarget's dispatch,
//! `inline_capacity` items in that frame and the rest from the allocator;
//! `EventState.path` points at it from the time it is built until dispatch
//! step 9, and is null at every other time. One event has at most one
//! dispatch at a time (dispatch step 1 refuses a second), and a nested
//! dispatch - another event's, from a listener - has its own frame and its
//! own path.
//!
//! Also here: "invoke" step 9, which renames a trusted animation or
//! transition event to its legacy WebKit type while the legacy listeners run,
//! and back again.
//!
//! Spec: https://dom.spec.whatwg.org/#interface-event,
//! https://dom.spec.whatwg.org/#concept-event-dispatch
//!
//! lint-impls: hook for Event

const std = @import("std");
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;
const runtime = @import("runtime");
const engine = @import("engine");
const KeptInstance = @import("custom_elements.zig").KeptInstance;
const node_holds = @import("node_holds.zig");
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");

/// One struct of an event's path (DOM 2.9 "append to an event path"), built
/// by dom.event_path into a `DispatchPath`.
///
/// 72 bytes, and a dispatch keeps `DispatchPath.inline_capacity` of them in
/// its stack frame: a field added here is paid by every nested dispatch
/// (tests/dom/ev1_event_memory_test.zig pins the size). WebKit's
/// EventContext is 40 bytes, 64 with touch events (four or seven RefPtr and
/// eight bytes of depth and flags, Source/WebCore/dom/EventContext.h).
pub const PathItem = struct {
    invocation_target: *runtime.Instance,
    related_target: ?*runtime.Instance,
    /// Not a field of the standard's struct: what "invoke" steps 1-3 set the
    /// event's target to for this item - the shadow-adjusted target of the
    /// last item at or before it whose shadow-adjusted target is non-null.
    /// That item is the last one dispatch appended through step 6.3 or
    /// 6.9.8, so this is dispatch's `target` when the item was appended;
    /// recorded then, invoke finds it without walking back along the path
    /// (Blink keeps it per tree scope: TreeScopeEventContext::Target).
    ///
    /// It is also the standard's "shadow-adjusted target" of an item that
    /// has one (`has_shadow_adjusted_target`): steps 6.3 and 6.9.8.3 append
    /// with the shadow-adjusted target dispatch's `target` is at that time
    /// (targetOverride for the first item: dom.event_path writes it here).
    target: *runtime.Instance,
    /// Not the standard's either: the invocation target's tree node (null
    /// for a Window or any other target that is not a node), recorded by
    /// "append to an event path" so the path's hold (`DispatchPath.hold`)
    /// needs no lookup.
    invocation_node: ?*NodeBase = null,
    /// The path's counted references while dispatch runs (refcount step
    /// 5g), WebKit's EventContext `RefPtr<Node> m_node` and `RefPtr<Node>
    /// m_relatedTarget` (Source/WebCore/dom/EventContext.h): on the
    /// invocation target, and on the item's relatedTarget when it differs
    /// from the previous item's. The shadow-adjusted targets and the items'
    /// `target`s are always some item's invocation target, held there.
    /// Chainless (`node_holds.CountedRef`), so an item may move; taken by
    /// `DispatchPath.hold` once the path is built and let go by
    /// `DispatchPath.releaseHolds` when dispatch ends. SHADOW MODE: counted
    /// only.
    invocation_ref: node_holds.CountedRef = .{},
    related_ref: node_holds.CountedRef = .{},
    /// The standard's "touch target list" of the item: the run of the
    /// path's `touch_targets` that starts here, `DispatchPath.touch_count`
    /// long (`DispatchPath.touchTargetsOf`) - one retargeted target per
    /// touch target of the event, so every item's run has that length. The
    /// items of one tree share one run (retargeting against a parent
    /// depends only on the parent's root: dom.event_path's THE WALK), and
    /// every event but a TouchEvent has none - a Gecko chain item's
    /// retargeted touch targets are optional in the same way
    /// (EventTargetChainItem's mRetargetedTouchTargets).
    touch_start: u32 = 0,
    /// Whether the standard's "shadow-adjusted target" is non-null; it is
    /// then `target` (`shadowAdjustedTarget`).
    has_shadow_adjusted_target: bool,
    invocation_target_in_shadow_tree: bool,
    root_of_closed_tree: bool,
    slot_in_closed_tree: bool,

    /// The standard's "shadow-adjusted target".
    pub fn shadowAdjustedTarget(self: *const PathItem) ?*runtime.Instance {
        return if (self.has_shadow_adjusted_target) self.target else null;
    }
};

/// An event's touch target list (DOM 2.2: "a list of zero or more potential
/// event targets. Unless stated otherwise it is the empty list"). Only a
/// TouchEvent's is ever anything else (Touch Events: each Touch's target),
/// so an event keeps one pointer for it and the list itself is made when a
/// target is first appended. Blink and WebKit keep the touch lists on
/// TouchEvent alone (TouchEvent::touches_, target_touches_,
/// changed_touches_), Gecko on WidgetTouchEvent (`mTouches`).
pub const TouchTargetList = struct {
    /// The targets, or null for a list nothing was ever appended to.
    heap: ?*std.ArrayList(*runtime.Instance) = null,

    /// The list's targets, in order. Good until the list next changes.
    pub fn toSlice(self: *const TouchTargetList) []const *runtime.Instance {
        const list = self.heap orelse return &.{};
        return list.items;
    }

    /// Append `target`. `allocator` is the event's Browser's
    /// (`runtime.allocatorOf(event)`), every time: `deinit` frees with it.
    pub fn append(self: *TouchTargetList, allocator: std.mem.Allocator, target: *runtime.Instance) error{OutOfMemory}!void {
        const list = try self.ensure(allocator);
        try list.append(allocator, target);
    }

    /// Make the list `targets` ("invoke" step 5: "Set event's touch target
    /// list to pathItem's touch target list"). On failure the list is
    /// empty.
    pub fn assign(self: *TouchTargetList, allocator: std.mem.Allocator, targets: []const *runtime.Instance) error{OutOfMemory}!void {
        self.clear();
        if (targets.len == 0) return;
        const list = try self.ensure(allocator);
        try list.appendSlice(allocator, targets);
    }

    /// Make the list empty (dispatch step 11), keeping its storage.
    pub fn clear(self: *TouchTargetList) void {
        if (self.heap) |list| list.clearRetainingCapacity();
    }

    /// Free the list's storage.
    pub fn deinit(self: *TouchTargetList, allocator: std.mem.Allocator) void {
        const list = self.heap orelse return;
        list.deinit(allocator);
        allocator.destroy(list);
        self.heap = null;
    }

    fn ensure(self: *TouchTargetList, allocator: std.mem.Allocator) error{OutOfMemory}!*std.ArrayList(*runtime.Instance) {
        if (self.heap) |list| return list;
        const list = try allocator.create(std.ArrayList(*runtime.Instance));
        list.* = .empty;
        self.heap = list;
        return list;
    }
};

/// One dispatch's path (DOM 2.2 "path", while it is not the empty list): a
/// local of the dispatch that builds it - see THE PATH IS THE DISPATCH'S
/// above. The event points at it (`EventState.path`) from `dom.event_path`'s
/// build until dispatch step 9 (`EventState.clearPath`), which must come
/// before this object's frame ends.
///
/// Its first `inline_capacity` items are in the object itself, so a dispatch
/// through a tree that deep allocates nothing; a longer path moves to the
/// allocator. NEVER COPIED OR MOVED once the event points at it. `init`
/// writes every field but the inline items: declare it `undefined` in a
/// scope with runtime safety off, or ReleaseSafe fills the whole frame with
/// 0xaa on every dispatch.
pub const DispatchPath = struct {
    /// WebKit's count (EventPath's m_path has room for 32 contexts inline,
    /// Source/WebCore/dom/EventPath.h).
    pub const inline_capacity = 32;

    /// Serves the items past `inline_capacity` and the touch targets.
    allocator: std.mem.Allocator,
    /// How many items the path has.
    len: usize,
    /// The items' storage once they outgrew the inline ones - its length is
    /// the capacity - and empty while they are the inline ones.
    heap: []PathItem,
    /// Every item's touch targets, run after run (`PathItem.touch_start`),
    /// each `touch_count` long. Empty, and never allocated, for every event
    /// but a TouchEvent.
    touch_targets: std.ArrayList(*runtime.Instance),
    /// How many touch targets the event has: the length of every item's
    /// touch target list.
    touch_count: u32,
    /// The event's currentTarget attribute value ("invoke" step 7), or null
    /// before the first listener's item. It is the dispatch's to keep, not
    /// the Event's: outside dispatch it is null (dispatch step 8), so an
    /// event with no path has none. With its slab generation when set:
    /// script reads it through `EventState.currentTargetForScript`, so a
    /// current target whose slot was given back and reissued - another
    /// realm's Window, after that realm's end - reads null, never the
    /// newcomer (lane winslot1, kinds 5-7).
    current_target: ?*runtime.Instance,
    current_target_generation: u64,
    inline_items: [inline_capacity]PathItem,

    /// An empty path. Field by field: an assignment of the whole struct
    /// would write the inline items too.
    pub fn init(self: *DispatchPath, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.len = 0;
        self.heap = &.{};
        self.touch_targets = .empty;
        self.touch_count = 0;
        self.current_target = null;
        self.current_target_generation = 0;
    }

    /// Set the event's currentTarget attribute value ("invoke" step 7).
    pub fn setCurrentTarget(self: *DispatchPath, target: *runtime.Instance) void {
        self.current_target = target;
        self.current_target_generation = runtime.SlabAllocator.generationOf(target);
    }

    /// Let the path's references go and free what it allocated. The event
    /// must not point at it any more (`EventState.clearPath`).
    pub fn deinit(self: *DispatchPath) void {
        self.releaseHolds();
        if (self.heap.len != 0) self.allocator.free(self.heap);
        self.heap = &.{};
        self.len = 0;
        self.touch_targets.deinit(self.allocator);
    }

    /// The path's items, in order. Good until the next `append`.
    pub fn items(self: *DispatchPath) []PathItem {
        const storage: []PathItem = if (self.heap.len != 0) self.heap else &self.inline_items;
        return storage[0..self.len];
    }

    /// `items`, to read.
    pub fn constItems(self: *const DispatchPath) []const PathItem {
        const storage: []const PathItem = if (self.heap.len != 0) self.heap else &self.inline_items;
        return storage[0..self.len];
    }

    /// DOM 2.9 "append to an event path" step 5: "Append a new struct to
    /// event's path".
    pub fn append(self: *DispatchPath, item: PathItem) error{OutOfMemory}!void {
        const capacity = if (self.heap.len != 0) self.heap.len else inline_capacity;
        if (self.len == capacity) {
            const grown = try self.allocator.alloc(PathItem, capacity * 2);
            @memcpy(grown[0..self.len], self.constItems());
            if (self.heap.len != 0) self.allocator.free(self.heap);
            self.heap = grown;
        }
        const storage: []PathItem = if (self.heap.len != 0) self.heap else &self.inline_items;
        storage[self.len] = item;
        self.len += 1;
    }

    /// `item`'s touch target list.
    pub fn touchTargetsOf(self: *const DispatchPath, item: *const PathItem) []const *runtime.Instance {
        if (self.touch_count == 0) return &.{};
        return self.touch_targets.items[item.touch_start..][0..self.touch_count];
    }

    /// Take the path's counted references (each item's `invocation_ref`
    /// and `related_ref`) once dom.event_path has built it; `releaseHolds`
    /// lets them go when dispatch ends.
    pub fn hold(self: *DispatchPath) void {
        var previous_related: ?*runtime.Instance = null;
        for (self.items()) |*item| {
            item.invocation_ref.take(item.invocation_target, item.invocation_node);
            if (item.related_target) |related| {
                if (related != previous_related) item.related_ref.take(related, instance_bridge.getNodeBase(@ptrCast(related)));
            }
            previous_related = item.related_target;
            // TODO(refcount 5g): each item's touch target list - always empty
            // until a TouchEvent fills the event's (Touch is a stub) - takes
            // its references here when one can.
        }
    }

    /// Let the path's counted references go: dispatch step 9, and every
    /// other way the path ends. Safe to repeat (a released ref holds
    /// nothing).
    pub fn releaseHolds(self: *DispatchPath) void {
        for (self.items()) |*item| {
            item.invocation_ref.release(item.invocation_target);
            if (item.related_target) |related| item.related_ref.release(related);
        }
    }
};

/// Event's eventPhase values (DOM 2.2).
pub const Phase = struct {
    pub const none: u8 = 0;
    pub const capturing: u8 = 1;
    pub const at_target: u8 = 2;
    pub const bubbling: u8 = 3;
};

/// The member an event keeps its target in (engine.traceChild): the target
/// dispatch left it with, which script reads after dispatch (`event.target`,
/// `srcElement`). Blink: Event::Trace visits target_ (core/dom/events/
/// event.cc); it was a bare pointer here, and a held event read a freed node
/// once the target's tree was collected (lane ownerdoc,
/// crane/od-event-keeps-its-targets.html).
pub const target_slot: engine.TracedSlot = .{ .name = "target" };

/// The member an event keeps its relatedTarget in (engine.traceChild). The
/// relatedTarget is DOM's (2.2), one per event, which the relatedTarget
/// attributes of MouseEvent, FocusEvent and their subclasses return
/// (UI Events): dispatch retargets it item by item and can leave it on a
/// different object than the one it was initialized to - a shadow host
/// instead of a node in its shadow tree - so the event keeps the one it
/// holds. Blink: Event::Trace visits the related target (MouseEvent::Trace
/// related_target_, FocusEvent's); WebKit: RefPtr<EventTarget>.
pub const related_target_slot: engine.TracedSlot = .{ .name = "relatedTarget" };

/// What keeps the relatedTarget an event holds safe to read: its place in
/// the event's state until lane ev1, 56 bytes that were zero in every event
/// without a relatedTarget - a block of its own since, made for the mouse,
/// focus and drag events that are given one. Blink and WebKit keep the
/// related target on MouseEvent and FocusEvent, never on Event
/// (MouseEvent::related_target_; WebKit's MouseEvent's and FocusEvent's
/// m_relatedTarget); Gecko keeps one on every WidgetEvent (mRelatedTarget).
pub const RelatedKeep = struct {
    /// The related target `related_target_slot`'s edge holds, with its slab
    /// generation and realm: the teardown net - a realm's teardown frees
    /// its Instances whatever points at them, and the getter then reads
    /// null, never a freed object.
    kept: KeptInstance,
    /// One counted reference on it (refcount step 5g): WebKit's MouseEvent
    /// and FocusEvent hold `RefPtr<EventTarget> m_relatedTarget`. Taken
    /// whether or not script has wrapped the event; a related target that
    /// is not a node is not counted (decision D3). SHADOW MODE: the edge
    /// keeps it until refcount step 9b; this decides nothing yet.
    hold: node_holds.RefHold = .{},
};

/// An Event's internal state (DOM 2.2): every flag, the targets, the phase
/// and isTrusted, and - while the event is dispatched - where its path is.
/// Owned by the event (Event's impl creates and frees it); the dispatcher
/// writes it through `of()`.
pub const EventState = struct {
    // DOM 2.2 - the event's flags, initially unset.
    stop_propagation_flag: bool = false,
    stop_immediate_propagation_flag: bool = false,
    canceled_flag: bool = false,
    in_passive_listener_flag: bool = false,
    initialized_flag: bool = false,
    dispatch_flag: bool = false,

    /// DOM 2.2 "path": the dispatch's (`DispatchPath`) while this event is
    /// dispatched and its path is built, and null - the empty list - before
    /// dispatch, after its step 9 (`clearPath`) and for a dispatch whose
    /// path stays empty. BORROWED from the dispatcher's frame, as WebKit's
    /// Event points weakly at its dispatch's EventPath (m_eventPath) and
    /// Gecko's WidgetEvent at its dispatch's chain (mPath).
    path: ?*DispatchPath = null,

    /// The target attribute's value, initially null (srcElement returns it
    /// too). Set with `setTarget`, which keeps it for script.
    target: ?*runtime.Instance = null,
    /// DOM 2.2 "relatedTarget", initially null. Set with `setRelatedTarget`,
    /// which keeps it; dispatch writes it per path item ("invoke" step 4)
    /// and keeps the value it ends with (`endDispatch`).
    related_target: ?*runtime.Instance = null,
    /// The slab generation of `target` when the event last kept it
    /// (`keepTarget`): script reads the target through it
    /// (`targetForScript`), so a target whose slot was given back and
    /// reissued - another realm's Window, after that realm's end - reads
    /// null, never the newcomer (lane winslot1, kinds 5-7). The
    /// currentTarget attribute's value and its generation are the
    /// dispatch's (`DispatchPath.current_target`): null outside dispatch.
    target_generation: u64 = 0,
    /// The eventPhase attribute's value, initially NONE (`Phase`). One byte:
    /// with the six flags and isTrusted it fills one word.
    phase: u8 = Phase.none,
    /// The isTrusted attribute's value, initially false.
    is_trusted: bool = false,

    /// DOM 2.2 "touch target list", initially the empty list.
    touch_target_list: TouchTargetList = .{},

    /// The target `target_slot`'s edge holds, or null for none (`keepTarget`).
    traced_target: ?*runtime.Instance = null,

    /// What keeps the relatedTarget the event holds (`RelatedKeep`), or
    /// null for an event that keeps none - every event but a mouse, focus
    /// or drag event that was given one. Made by `keepRelatedTarget`, freed
    /// when the event stops keeping one and at its teardown.
    related_keep: ?*RelatedKeep = null,

    /// One counted reference on the target the event keeps (refcount step
    /// 5g): WebKit's Event holds `RefPtr<EventTarget> m_target`
    /// (Source/WebCore/dom/Event.h). Taken whether or not script has
    /// wrapped the event (`keepTarget`); a target that is not a node is not
    /// counted (decision D3). SHADOW MODE: the edge keeps it until refcount
    /// step 9b; this decides nothing yet. The relatedTarget's is in its
    /// `RelatedKeep`.
    target_hold: node_holds.RefHold = .{},

    /// A new event's state. The allocator is not kept (lane ev1 step 2:
    /// 16 bytes in every Event): the one thing the state allocates, a
    /// TouchEvent's touch target list, takes the event's Browser's
    /// allocator (`runtime.allocatorOf(event)`) at each use, as a node's
    /// state does (lane perf2 batch 5). The parameter stays until the
    /// fourteen impls that reach here through webidl.utils' initEventBase
    /// stop passing one.
    pub fn init(_: std.mem.Allocator) EventState {
        return .{};
    }

    /// Release what the state owns: the touch target list, allocated with
    /// `allocator` - the event's Browser's (`runtime.allocatorOf(event)`).
    /// `event`'s edge to its target is the event's teardown to end
    /// (`forgetTarget`). The path is never the state's to free; an event
    /// that goes while it is dispatched only stops pointing at it, its
    /// references let go.
    pub fn deinit(self: *EventState, allocator: std.mem.Allocator) void {
        self.clearPath();
        self.touch_target_list.deinit(allocator);
    }

    /// Set `event`'s target (and so its srcElement) to `target`, and keep it
    /// while script can reach the event (`keepTarget`).
    pub fn setTarget(self: *EventState, event: *runtime.Instance, target: ?*runtime.Instance) void {
        self.target = target;
        self.keepTarget(event);
    }

    /// Keep the event's current target (`target_slot`) while script can
    /// reach the event, and let a target it no longer has go.
    ///
    /// Only an event script can reach keeps it: one with a wrapper. An event
    /// script has not seen - the engine fires most of them, and nobody hears
    /// most of those - keeps nothing: tracing would wrap every target the
    /// engine fires at (docs/lessons/architecture-tracing-a-holders-nodes-
    /// makes-a-wrapper-per-node.md) and hold it strongly until the event is
    /// freed. The dispatcher holds the target while it runs; a listener that
    /// sees the event wraps it, and the end of dispatch (`endDispatch`) draws
    /// the edge then.
    pub fn keepTarget(self: *EventState, event: *runtime.Instance) void {
        self.target_hold.set(self.target);
        const target = self.target;
        self.target_generation = if (target) |t| runtime.SlabAllocator.generationOf(t) else 0;
        if (target == self.traced_target) return;
        if (target) |t| {
            if (!engine.hasWrapper(event)) return;
            self.traced_target = t;
            engine.traceChild(event, t, target_slot);
        } else {
            self.traced_target = null;
            engine.forgetTracedChild(event, target_slot);
        }
    }

    /// The target attribute's value as script reads it (`target`,
    /// `srcElement`): during dispatch the one the dispatcher holds; after it,
    /// the one the event kept, while its slot is still that object's. An
    /// event script has not seen draws no edge to its target (above): made
    /// and dispatched natively at another realm's Window, and kept past that
    /// realm's end, it named a torn-down Window, and - its slot given back -
    /// whatever the slab put there next.
    pub fn targetForScript(self: *const EventState) ?*runtime.Instance {
        const target = self.target orelse return null;
        if (self.dispatch_flag) return target;
        if (runtime.SlabAllocator.generationOf(target) != self.target_generation) return null;
        return target;
    }

    /// The currentTarget attribute's value as dispatch last set it - the
    /// dispatch's (`DispatchPath.setCurrentTarget`) - and null for an event
    /// that is not being dispatched (dispatch step 8).
    pub fn currentTarget(self: *const EventState) ?*runtime.Instance {
        const path = self.path orelse return null;
        return path.current_target;
    }

    /// The currentTarget attribute's value as script reads it: the
    /// dispatch's, while its slot is still that object's.
    pub fn currentTargetForScript(self: *const EventState) ?*runtime.Instance {
        const path = self.path orelse return null;
        const target = path.current_target orelse return null;
        if (runtime.SlabAllocator.generationOf(target) != path.current_target_generation) return null;
        return target;
    }

    /// End `event`'s edge to its target, at the event's teardown. An event
    /// its wrapper's collection frees has no edge left to end.
    pub fn forgetTarget(self: *EventState, event: *runtime.Instance) void {
        if (self.traced_target != null) engine.forgetTracedChild(event, target_slot);
        self.traced_target = null;
        self.target_hold.release();
    }

    /// Set `event`'s relatedTarget to `related` and keep it: what the
    /// constructors and the legacy init*Event() methods of MouseEvent,
    /// FocusEvent and their subclasses initialize.
    pub fn setRelatedTarget(self: *EventState, event: *runtime.Instance, related: ?*runtime.Instance) void {
        self.related_target = related;
        self.keepRelatedTarget(event);
    }

    /// The relatedTarget attribute's value: `related_target`, or null once
    /// the realm of the one the event keeps has been torn down (the net).
    /// Mid-dispatch it is the current path item's, which the path holds.
    pub fn relatedTarget(self: *const EventState) ?*runtime.Instance {
        const related = self.related_target orelse return null;
        if (self.related_keep) |keep| {
            if (keep.kept.instance == related) return keep.kept.get();
        }
        return related;
    }

    /// Keep `related_target`, and let go of one the event no longer holds.
    ///
    /// Unlike the target's edge, this one is drawn whether or not script has
    /// wrapped the event (an owner script has not seen holds it until its
    /// wrapper is made): the constructors set it before the binding wraps
    /// the event, and the events that carry one - focus, mouse and drag
    /// events - are few, so nothing wraps a node per fired event.
    ///
    /// The keep's record is allocated the first time the event keeps one
    /// (`RelatedKeep`, from the event's Browser's allocator). An event that
    /// cannot allocate it has NO relatedTarget from then on - the pointer is
    /// set to null - never one it reads without the keep: an unkept
    /// relatedTarget is a pointer to a node the collector, or its realm's
    /// end, may free under the event.
    pub fn keepRelatedTarget(self: *EventState, event: *runtime.Instance) void {
        self.keepRelatedTargetWith(event, runtime.allocatorOf(event));
    }

    /// `keepRelatedTarget` with the allocator a new record comes from,
    /// which is always the event's Browser's (a record is freed with that
    /// one, whatever is passed here): a parameter so that a test can make
    /// the allocation fail.
    pub fn keepRelatedTargetWith(self: *EventState, event: *runtime.Instance, allocator: std.mem.Allocator) void {
        const related = self.related_target orelse {
            // The event keeps none now: its record, hold and edge go.
            return self.forgetRelatedTarget(event);
        };
        if (self.related_keep) |keep| {
            keep.hold.set(related);
            if (keep.kept.instance == related) return;
            keep.kept = KeptInstance.of(related);
            engine.traceChild(event, related, related_target_slot);
            return;
        }
        const keep = allocator.create(RelatedKeep) catch {
            self.related_target = null;
            return;
        };
        keep.* = .{ .kept = KeptInstance.of(related) };
        keep.hold.set(related);
        self.related_keep = keep;
        engine.traceChild(event, related, related_target_slot);
    }

    /// End `event`'s edge to its relatedTarget and free the keep's record,
    /// at the event's teardown.
    pub fn forgetRelatedTarget(self: *EventState, event: *runtime.Instance) void {
        const keep = self.related_keep orelse return;
        self.related_keep = null;
        engine.forgetTracedChild(event, related_target_slot);
        keep.hold.release();
        runtime.allocatorOf(event).destroy(keep);
    }

    /// DOM 2.2 "set the canceled flag" given the event, whose cancelable
    /// attribute value is `cancelable`: set the canceled flag if cancelable
    /// is true and the in passive listener flag is unset, and do nothing
    /// otherwise.
    pub fn setCanceledFlag(self: *EventState, cancelable: bool) void {
        if (cancelable and !self.in_passive_listener_flag) self.canceled_flag = true;
    }

    /// The path's items, in order: empty when the event is not being
    /// dispatched. BORROWED from the dispatch; good while it runs.
    pub fn pathItems(self: *const EventState) []const PathItem {
        const path = self.path orelse return &.{};
        return path.constItems();
    }

    /// Dispatch step 9: "Set event's path to the empty list." The path's
    /// counted references go, and the event stops pointing at the
    /// dispatch's path, whose storage is the dispatcher's to free
    /// (WebKit's Event::resetAfterDispatch clears its path pointer the
    /// same way).
    pub fn clearPath(self: *EventState) void {
        const path = self.path orelse return;
        path.releaseHolds();
        self.path = null;
    }

    /// Dispatch steps 7-11: leave `event` in a state in which it can be
    /// dispatched again. Step 7: eventPhase NONE. Step 8: currentTarget
    /// null. Step 9: the path empty. Step 10: the dispatch, stop propagation
    /// and stop immediate propagation flags unset - leaving them set made the
    /// next dispatch of the same event object a no-op, which is how a
    /// `stopPropagation()` in one dispatch silently swallowed every later
    /// one. Step 11: with `clear_targets`, the target, relatedTarget and
    /// touch target list cleared.
    ///
    /// Dispatch is over: invoke wrote the target and relatedTarget raw, item
    /// by item, while the path held them, and a listener may have wrapped
    /// the event meanwhile - so the values the event ends with are kept
    /// now, after step 11, never an edge to a value step 11 then drops.
    ///
    /// The values are kept BEFORE the path lets go of its own references
    /// (refcount step 7's prerequisite (b2), lane refcount8): a target only
    /// the path held - a node removed during dispatch - is taken on while its
    /// tree still counts it, never after its total passed through zero.
    pub fn finishDispatch(self: *EventState, event: *runtime.Instance, clear_targets: bool) void {
        // Step 8, currentTarget null, is `clearPath`'s below: the current
        // target is the dispatch's.
        self.phase = Phase.none;
        self.dispatch_flag = false;
        self.stop_propagation_flag = false;
        self.stop_immediate_propagation_flag = false;
        if (clear_targets) {
            self.target = null;
            self.related_target = null;
            self.touch_target_list.clear();
        }
        self.keepTarget(event);
        self.keepRelatedTarget(event);
        self.clearPath();
    }

    /// Dispatch steps 7-10, for a dispatch whose clearTargets is false.
    pub fn endDispatch(self: *EventState, event: *runtime.Instance) void {
        self.finishDispatch(event, false);
    }
};

/// What the Event impl supplies.
pub const Implementation = struct {
    /// `event`'s state, or null when `event` is not an Event or has none
    /// (one never constructed through Event's steps: its initialized flag is
    /// unset). BORROWED: it lives as long as the event.
    state: *const fn (event: *runtime.Instance) ?*EventState,
    /// Set `event`'s type attribute value to `event_type`, which the event
    /// then holds, and hand back the value it held (its owner is the caller).
    /// No copy, no free: the swap is undone with the value it returned.
    swap_type: *const fn (event: *runtime.Instance, event_type: runtime.DOMString) ?runtime.DOMString,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: Hook(?Implementation) = .init(null);

/// Called by Event's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// `event`'s dispatch state, or null when it has none (see
/// `Implementation.state`). Taken once per dispatch: the pointer is good for
/// as long as the event is.
pub fn of(event: *runtime.Instance) ?*EventState {
    const impl = implementation.get() orelse return null;
    return impl.state(event);
}

/// `event`'s type attribute value becomes `event_type`; the previous value is
/// returned, to be swapped back. Null when `event` is not an Event.
pub fn swapType(event: *runtime.Instance, event_type: runtime.DOMString) ?runtime.DOMString {
    const impl = implementation.get() orelse return null;
    return impl.swap_type(event, event_type);
}

/// "Invoke" step 9.2: the legacy type an event type is renamed to for
/// listeners registered only under that name - the table's second column for
/// the first - or null.
pub fn legacyEventType(event_type: []const u8) ?[]const u8 {
    const table = [_][2][]const u8{
        .{ "animationend", "webkitAnimationEnd" },
        .{ "animationiteration", "webkitAnimationIteration" },
        .{ "animationstart", "webkitAnimationStart" },
        .{ "transitionend", "webkitTransitionEnd" },
    };
    for (table) |row| {
        if (std.mem.eql(u8, event_type, row[0])) return row[1];
    }
    return null;
}

test "invoke step 9.2 maps the four unprefixed types, exactly, and nothing else" {
    try std.testing.expectEqualStrings("webkitAnimationEnd", legacyEventType("animationend").?);
    try std.testing.expectEqualStrings("webkitAnimationIteration", legacyEventType("animationiteration").?);
    try std.testing.expectEqualStrings("webkitAnimationStart", legacyEventType("animationstart").?);
    try std.testing.expectEqualStrings("webkitTransitionEnd", legacyEventType("transitionend").?);
    try std.testing.expect(legacyEventType("AnimationEnd") == null);
    try std.testing.expect(legacyEventType("webkitAnimationEnd") == null);
    try std.testing.expect(legacyEventType("transitionrun") == null);
}

test "an event's state starts with every flag unset, no targets and phase NONE" {
    var state = EventState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);
    try std.testing.expect(!state.initialized_flag and !state.dispatch_flag and !state.canceled_flag);
    try std.testing.expect(state.target == null and state.currentTarget() == null and state.related_target == null);
    try std.testing.expectEqual(Phase.none, state.phase);
    try std.testing.expect(!state.is_trusted);
    try std.testing.expect(state.path == null);
    try std.testing.expectEqual(@as(usize, 0), state.pathItems().len);
}

test "a dispatch path keeps its first items inline, grows past them, and keeps each item's touch targets" {
    var path: DispatchPath = undefined;
    path.init(std.testing.allocator);
    defer path.deinit();
    try std.testing.expectEqual(@as(usize, 0), path.items().len);

    // Never dereferenced: the items only carry the addresses.
    var targets: [3 * DispatchPath.inline_capacity]runtime.Instance = undefined;
    // An event with two touch targets: every fourth item starts a run of
    // its own (a new tree), the three after it share that run.
    path.touch_count = 2;
    var start: u32 = 0;
    for (&targets, 0..) |*target, i| {
        if (i % 4 == 0) {
            start = @intCast(path.touch_targets.items.len);
            try path.touch_targets.appendSlice(std.testing.allocator, &.{ target, &targets[0] });
        }
        try path.append(.{
            .invocation_target = target,
            .related_target = null,
            .target = &targets[0],
            .touch_start = start,
            .has_shadow_adjusted_target = i == 0,
            .invocation_target_in_shadow_tree = false,
            .root_of_closed_tree = false,
            .slot_in_closed_tree = false,
        });
        // The first `inline_capacity` items need no allocation.
        try std.testing.expectEqual(i >= DispatchPath.inline_capacity, path.heap.len != 0);
    }
    try std.testing.expectEqual(targets.len, path.items().len);
    for (path.constItems(), 0..) |*item, i| {
        try std.testing.expectEqual(&targets[i], item.invocation_target);
        try std.testing.expectEqual(if (i == 0) @as(?*runtime.Instance, &targets[0]) else null, item.shadowAdjustedTarget());
        const touch = path.touchTargetsOf(item);
        try std.testing.expectEqual(@as(usize, 2), touch.len);
        try std.testing.expectEqual(&targets[i - i % 4], touch[0]);
        try std.testing.expectEqual(&targets[0], touch[1]);
    }

    // An event points at the path only until dispatch step 9.
    var state = EventState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);
    state.path = &path;
    try std.testing.expectEqual(targets.len, state.pathItems().len);
    state.clearPath();
    try std.testing.expect(state.path == null);
    try std.testing.expectEqual(@as(usize, 0), state.pathItems().len);
}

test "an event's touch target list is one pointer, empty until a target is appended" {
    try std.testing.expectEqual(@sizeOf(usize), @sizeOf(TouchTargetList));
    const allocator = std.testing.allocator;
    var list: TouchTargetList = .{};
    defer list.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), list.toSlice().len);
    list.clear();
    try list.assign(allocator, &.{});
    try std.testing.expect(list.heap == null);

    // Never dereferenced: the list only carries the addresses.
    var targets: [3]runtime.Instance = undefined;
    try list.append(allocator, &targets[0]);
    try list.append(allocator, &targets[1]);
    try std.testing.expectEqualSlices(*runtime.Instance, &.{ &targets[0], &targets[1] }, list.toSlice());
    // "Invoke" step 5 replaces the list; dispatch step 11 empties it.
    try list.assign(allocator, &.{ &targets[2], &targets[0] });
    try std.testing.expectEqualSlices(*runtime.Instance, &.{ &targets[2], &targets[0] }, list.toSlice());
    list.clear();
    try std.testing.expectEqual(@as(usize, 0), list.toSlice().len);
    try list.append(allocator, &targets[1]);
    try std.testing.expectEqualSlices(*runtime.Instance, &.{&targets[1]}, list.toSlice());
}

test "set the canceled flag honours cancelable and the in passive listener flag" {
    var state = EventState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);
    state.setCanceledFlag(false);
    try std.testing.expect(!state.canceled_flag);
    state.in_passive_listener_flag = true;
    state.setCanceledFlag(true);
    try std.testing.expect(!state.canceled_flag);
    state.in_passive_listener_flag = false;
    state.setCanceledFlag(true);
    try std.testing.expect(state.canceled_flag);
}

test "without an installed implementation an event has no state" {
    const override = implementation.overrideForTest(null);
    defer override.restore();
    // Never dereferenced: with nothing installed nothing reads it.
    var event: runtime.Instance = undefined;
    try std.testing.expect(of(&event) == null);
}
