//! Lane ev1 (the Event's memory): what an Event keeps is pinned here, so
//! that a byte added to every Event is a decision, not an accident.
//!
//! Step 1: the event's path is the dispatch's, not the Event's. Blink's
//! Event holds one pointer (`Member<EventPath> event_path_`, core/dom/events/
//! event.h), WebKit's one weak pointer set for the dispatch
//! (`SingleThreadWeakPtr<const EventPath> m_eventPath`, dom/Event.h), Gecko's
//! WidgetEvent one raw pointer (`nsTArray<EventTargetChainItem>* mPath`,
//! widget/BasicEvents.h). Crane's kept four path items inline, each with its
//! own inline touch target list: 880 of the state's 1,079 bytes, in every
//! Event, dispatched or not.
const std = @import("std");
const dom = @import("dom");

const EventState = dom.event_dispatch.EventState;

test "an Event's state holds a pointer to its path, never the path's items" {
    // 64-bit hosts (the pool's, and every target Crane ships for).
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    try std.testing.expect(@sizeOf(EventState) <= 176);
}
