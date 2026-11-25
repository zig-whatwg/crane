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
    _ = @import("tpf_remote_objects_test.zig");
    _ = @import("tpc_console_replay_test.zig");
    _ = @import("tpc_idle_server_test.zig");
    _ = @import("tpf_resize_observer_test.zig");
    _ = @import("tpf_streamed_document_test.zig");
    _ = @import("tpf_console_webcompat_test.zig");
    _ = @import("tpf_rejection_report_test.zig");
    _ = @import("mcp1_local_link_test.zig");
    _ = @import("mcp1_pages_test.zig");
    _ = @import("mcp1_console_test.zig");
    _ = @import("mcp1_script_test.zig");
    _ = @import("mcp1_exception_text_test.zig");
    _ = @import("mcp1_network_test.zig");
    _ = @import("mcp1_input_test.zig");
    _ = @import("mcp1_title_test.zig");
    _ = @import("mcp1_title_timing_test.zig");
    _ = @import("mcp1_snapshot_test.zig");
    _ = @import("mcp1_target_title_test.zig");
    _ = @import("mcp1_history_test.zig");
    _ = @import("mcp1_history_tool_test.zig");
    _ = @import("mcp1_resize_test.zig");
    _ = @import("mcp1_stdio_test.zig");
    _ = @import("mcp1_paths_test.zig");
}
