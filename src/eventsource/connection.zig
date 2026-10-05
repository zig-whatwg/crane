//! HTML 9.2.3 connection transitions, applied only when the corresponding
//! remote-event task runs. A boolean result says whether to fire its event.
/// The EventSource readyState values and processing-model transitions.
pub const Connection = struct {
    /// HTML 9.2.2 readyState constants.
    pub const State = enum(u16) { connecting = 0, open = 1, closed = 2 };
    state: State = .connecting,
    pending_tasks: usize = 0,

    /// HTML 9.2.9: a queued task's share lasts through its script's return.
    pub fn beginTask(self: *Connection) void {
        self.pending_tasks += 1;
    }
    /// Return a task's share only after its run/drop has finished.
    pub fn endTask(self: *Connection) void {
        @import("std").debug.assert(self.pending_tasks != 0);
        self.pending_tasks -= 1;
    }
    /// Active sources and queued/running tasks require pending activity.
    pub fn needsHold(self: *const Connection) bool {
        return self.state != .closed or self.pending_tasks != 0;
    }

    /// "Announce the connection": CLOSED suppresses an already queued open.
    pub fn announce(self: *Connection) bool {
        if (self.state == .closed) return false;
        self.state = .open;
        return true;
    }
    /// "Reestablish the connection" steps 1.1–1.3, before firing error.
    pub fn reestablish(self: *Connection) bool {
        if (self.state == .closed) return false;
        self.state = .connecting;
        return true;
    }
    /// "Fail the connection": enter CLOSED before firing error, at most once.
    pub fn fail(self: *Connection) bool {
        if (self.state == .closed) return false;
        self.state = .closed;
        return true;
    }
    /// close() and HTML 9.2.9 forcible close; no event is requested.
    pub fn close(self: *Connection) void {
        self.state = .closed;
    }
    /// "Reestablish the connection" step 5.1, after the delayed wait.
    pub fn canReconnect(self: *const Connection) bool {
        return self.state == .connecting;
    }
};
