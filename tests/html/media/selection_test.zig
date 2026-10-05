//! The dormant Q19 entry points are ready for the parser-owner's generic seam.
const std = @import("std");
const selection = @import("html_core").media.track_selection;
test "parser-created media suppresses automatic track selection" {
    var state: selection.State = .{};
    try std.testing.expect(!state.blocked_on_parser);
    selection.parserCreated(&state);
    try std.testing.expect(state.blocked_on_parser);
    try std.testing.expect(!state.automatic_selected);
}
test "parser-finished requests preference selection and pending-track population" {
    var state: selection.State = .{ .blocked_on_parser = true };
    const actions = selection.parserFinished(&state);
    try std.testing.expect(actions.honor_preferences);
    try std.testing.expect(actions.populate_pending_tracks);
    try std.testing.expect(!state.blocked_on_parser);
}
test "track change notification is coalesced until consumed" {
    var state: selection.State = .{};
    try std.testing.expect(state.requestChange());
    try std.testing.expect(!state.requestChange());
    state.takeChange();
    try std.testing.expect(state.requestChange());
}
