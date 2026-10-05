//! The media lane's focused red/green suite, also imported by tests/html.
test {
    _ = @import("load_state_test.zig");
    _ = @import("registry_test.zig");
    _ = @import("objects_test.zig");
    _ = @import("backend_test.zig");
    _ = @import("delay_test.zig");
    _ = @import("track_list_test.zig");
    _ = @import("progress_test.zig");
    _ = @import("selection_test.zig");
    _ = @import("subtree_teardown_test.zig");
}
