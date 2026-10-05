//! Text-track selection flags. Parser entry points are dormant until the
//! parser owner's generic finished-children seam reaches media (lane Q19).
pub const State = struct {
    blocked_on_parser: bool = false,
    automatic_selected: bool = false,
    change_pending: bool = false,
    /// Text track mode-change notification steps 1–2.
    pub fn requestChange(self: *@This()) bool {
        if (self.change_pending) return false;
        self.change_pending = true;
        return true;
    }
    /// Queued mode-change notification step 3.1, before firing change.
    pub fn takeChange(self: *@This()) void {
        self.change_pending = false;
    }
};

/// HTML: a media element created by the HTML/XML parser is blocked on it.
/// Not called by production until the generic parser-owner hook is wired.
pub fn parserCreated(state: *State) void {
    state.blocked_on_parser = true;
}
pub const FinishActions = struct {
    honor_preferences: bool,
    populate_pending_tracks: bool,
};
/// The owner must execute both returned actions in the same synchronous step
/// before returning to script. This entry point is likewise dormant (Q19).
pub fn parserFinished(state: *State) FinishActions {
    state.blocked_on_parser = false;
    return .{ .honor_preferences = true, .populate_pending_tracks = true };
}
