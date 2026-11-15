//! Lane ev1 (the Event's memory): what an Event keeps is pinned here, so
//! that a byte added to every Event is a decision, not an accident.
//!
//! Step 1: the event's path is the dispatch's, not the Event's. Blink's
//! Event holds one traced pointer to its path (event_path_, core/dom/events/
//! event.h), WebKit's one weak pointer set for the dispatch (m_eventPath,
//! dom/Event.h), Gecko's WidgetEvent one raw pointer to the dispatch's chain
//! (mPath, widget/BasicEvents.h). Crane's kept four path items inline, each
//! with its own inline touch target list: 880 of the state's 1,079 bytes,
//! in every Event, dispatched or not.
const std = @import("std");
const dom = @import("dom");

const EventState = dom.event_dispatch.EventState;

test "an Event's state holds a pointer to its path, never the path's items" {
    // 64-bit hosts (the pool's, and every target Crane ships for).
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    try std.testing.expect(@sizeOf(EventState) <= 176);
}

test "a dispatch keeps 32 path items of 72 bytes in its frame" {
    // The path's inline items are stack a nested dispatch pays again at
    // every level (WebKit: room for 32 EventContexts, of four to seven
    // pointers and eight more bytes each, in every dispatch's frame).
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    const DispatchPath = dom.event_dispatch.DispatchPath;
    try std.testing.expectEqual(@as(usize, 72), @sizeOf(dom.event_dispatch.PathItem));
    try std.testing.expectEqual(@as(usize, 32), DispatchPath.inline_capacity);
    try std.testing.expect(@sizeOf(DispatchPath) <= 32 * 72 + 72);
}
