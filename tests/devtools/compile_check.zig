//! Every test file of tests/devtools in one compile, for `zig build
//! check-devtools` (nothing runs). The suite itself is build.zig's
//! addTestFilesFromDir over this directory.

test {
    _ = @import("cdpt_transport_test.zig");
    _ = @import("cdpt_targets_test.zig");
    _ = @import("cdpt_input_network_fetch_test.zig");
    _ = @import("cdpt_queue_test.zig");
    _ = @import("cdpr_playwright_replay_test.zig");
    _ = @import("cdpr_puppeteer_replay_test.zig");
    _ = @import("cdpr_vitest_cdp_replay_test.zig");
}
