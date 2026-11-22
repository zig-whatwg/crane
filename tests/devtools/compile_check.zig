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
    _ = @import("cdpt2_fetch_network_test.zig");
    _ = @import("cdpr_playwright_replay_test.zig");
    _ = @import("cdpr_puppeteer_replay_test.zig");
    _ = @import("cdpr_vitest_cdp_replay_test.zig");
    _ = @import("cdpr_window_proxy_test.zig");
    _ = @import("cdph_page_session_test.zig");
}
