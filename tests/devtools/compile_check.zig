//! Every test file of tests/devtools in one compile, for `zig build
//! check-devtools` (nothing runs). The suite itself is build.zig's
//! addTestFilesFromDir over this directory; this executable has the Crane
//! test runner too (`@import("root").poisoning`).

test {
    _ = @import("cdpt_transport_test.zig");
    _ = @import("cdpt_targets_test.zig");
    _ = @import("cdpt_input_network_fetch_test.zig");
    _ = @import("cdpt_queue_test.zig");
    _ = @import("cdpt2_target_lifecycle_test.zig");
    _ = @import("cdpt2_input_test.zig");
    _ = @import("cdpt2_browser_test.zig");
}
