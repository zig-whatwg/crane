//! WPT (Web Platform Tests) Runner
//!
//! This module provides a test runner for the official Web Platform Tests (WPT)
//! suite. It executes WPT tests using V8 as the JavaScript engine and reports
//! results in the standard wptreport.json format compatible with wpt.fyi.
//!
//! ## Architecture
//!
//! ```
//! WPT Test Files (tests/wpt/)
//!    ↓ Discovery
//! Test Parser (extracts metadata, scripts)
//!    ↓ Parse
//! Browser Context (Window/Worker globals)
//!    ↓ Execute
//! Test Harness Bridge (collects results)
//!    ↓ Report
//! wptreport.json (wpt.fyi compatible)
//! ```
//!
//! ## Supported Test Formats
//!
//! - `.html` - Full HTML test documents
//! - `.any.js` - Multi-context tests (window + worker)
//! - `.window.js` - Window-only tests
//! - `.worker.js` - Worker-only tests
//!
//! ## Usage
//!
//! ```bash
//! zig build wpt                    # Run all in-scope tests
//! zig build wpt -- url/            # Run URL tests only
//! zig build wpt -- url/ encoding/  # Run multiple categories
//! ```
//!
//! ## Output
//!
//! Results are written to `wpt-results/wptreport.json` in the standard format:
//! ```json
//! {
//!   "run_info": {...},
//!   "results": [{
//!     "test": "/url/url-constructor.any.js",
//!     "status": "OK",
//!     "subtests": [{
//!       "name": "URL constructor, empty string",
//!       "status": "PASS"
//!     }]
//!   }]
//! }
//! ```

pub const config = @import("config.zig");
pub const test_parser = @import("test_parser.zig");
pub const test_harness = @import("test_harness.zig");
pub const browser_context = @import("browser_context.zig");
pub const result_reporter = @import("result_reporter.zig");
pub const http_server = @import("http_server.zig");
pub const browser_adapter = @import("browser_adapter.zig");

// Re-export main entry point
pub const main = @import("main.zig").main;

// Re-export commonly used types
pub const HttpServer = http_server.HttpServer;
pub const ServerConfig = http_server.ServerConfig;

test "wpt_runner module compiles" {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
