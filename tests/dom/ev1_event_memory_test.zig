//! Lane ev1 (the Event's memory): what an Event keeps is pinned here, so
//! that a byte added to every Event is a decision, not an accident.
//!
//! Step 1: the event's path is the dispatch's, not the Event's. Blink's
//! Event holds one traced pointer to its path (event_path_, core/dom/events/
//! event.h), WebKit's one weak pointer set for the dispatch (m_eventPath,
//! dom/Event.h), Gecko's WidgetEvent one raw pointer to the dispatch's chain
//! (mPath, widget/BasicEvents.h). Crane's kept four path items inline, each
//! with its own inline touch target list: 848 of the state's 1,024 bytes,
//! in every Event, dispatched or not.
//!
//! Step 2: every byte that was left. The state kept a copy of its allocator
//! (16 bytes; it now takes its Browser's at each use); the currentTarget and
//! its generation (16 bytes) are the dispatch's, since DOM makes
//! currentTarget null outside dispatch; what keeps a relatedTarget safe to
//! read (56 bytes: the kept instance with its generation and realm, and the
//! counted hold) is a block made only for an event that has one, as Blink
//! and WebKit keep the related target on MouseEvent and FocusEvent alone;
//! the phase is one byte beside the seven flags; and a CustomEvent kept a
//! block of its own for a flag nothing read. What remains in every Event's
//! 88 bytes: DOM's flags, phase, target and relatedTarget, the touch target
//! list and path pointers, the related keep's pointer, and what keeps the
//! target safe to read after dispatch - its slab generation, the traced
//! edge's record and the counted hold.
const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");

const EventState = dom.event_dispatch.EventState;

test "an Event's state holds a pointer to its path, never the path's items" {
    // 64-bit hosts (the pool's, and every target Crane ships for).
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    try std.testing.expect(@FieldType(EventState, "path") == ?*dom.event_dispatch.DispatchPath);
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(dom.event_dispatch.TouchTargetList));
}

test "an Event's state is 88 bytes" {
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    // 1,024 bytes before lane ev1; 176 with the path at dispatch; 160
    // without the allocator copy; 112 with the relatedTarget's keep in a
    // block of its own; 96 with the currentTarget in the dispatch; 88 with
    // the phase in one byte.
    try std.testing.expectEqual(@as(usize, 88), @sizeOf(EventState));
    try std.testing.expect(!@hasField(EventState, "allocator"));
    try std.testing.expect(!@hasField(EventState, "current_target"));
    try std.testing.expect(!@hasField(EventState, "current_target_generation"));
    try std.testing.expect(@FieldType(EventState, "related_keep") == ?*dom.event_dispatch.RelatedKeep);
    try std.testing.expect(@FieldType(EventState, "phase") == u8);
    // The safety fields are the same types they were, wherever they are:
    // the kept instance (pointer, slab generation, realm) and the counted
    // hold (pointer, slab generation, NodeBase), and the generations are
    // the slab's full width.
    try std.testing.expect(@FieldType(dom.event_dispatch.RelatedKeep, "kept") == dom.custom_elements.KeptInstance);
    try std.testing.expect(@FieldType(dom.event_dispatch.RelatedKeep, "hold") == dom.node_holds.RefHold);
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(dom.event_dispatch.RelatedKeep));
    try std.testing.expect(@FieldType(EventState, "target_hold") == dom.node_holds.RefHold);
    try std.testing.expect(@FieldType(EventState, "target_generation") == u64);
    try std.testing.expect(@FieldType(dom.event_dispatch.DispatchPath, "current_target_generation") == u64);
}

test "an Event's state block and a CustomEvent's are 48 bytes: a CustomEvent keeps nothing of its own" {
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    // The generated State: the type (24), six booleans, the time stamp and
    // the pointer to the dispatch state.
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(interfaces.Event.State));
    // Its detail is its wrapper's; it had an 8-byte pointer here, to a
    // 16-byte block that held one flag nothing read.
    try std.testing.expectEqual(@sizeOf(interfaces.Event.State), @sizeOf(interfaces.CustomEvent.State));
}

test "a dispatch keeps 32 path items of 72 bytes in its frame" {
    // The path's inline items are stack a nested dispatch pays again at
    // every level (WebKit: room for 32 EventContexts, of four to seven
    // pointers and eight more bytes each, in every dispatch's frame).
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    const DispatchPath = dom.event_dispatch.DispatchPath;
    try std.testing.expectEqual(@as(usize, 72), @sizeOf(dom.event_dispatch.PathItem));
    try std.testing.expectEqual(@as(usize, 32), DispatchPath.inline_capacity);
    // The header: the allocator, the length, the heap items, the touch
    // targets and their count, the current target and its generation.
    try std.testing.expectEqual(@as(usize, 32 * 72 + 96), @sizeOf(DispatchPath));
}
