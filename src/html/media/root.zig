//! HTML media loading state and agent-owned records, independent of an engine.
pub const LoadState = @import("load_state.zig").LoadState;
pub const Registry = @import("registry.zig").Registry;
pub const Deadline = @import("progress.zig").Deadline;
pub const Progress = @import("progress.zig").Progress;
pub const track_selection = @import("track_selection.zig");
