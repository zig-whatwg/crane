//! TRANSITIONAL: the old platform code step 0 keeps, compiled so it cannot rot
//! before the recipes step that replaces it retires it (decision 15 as the
//! user changed it, 2026-10-09; docs/platform-protocol-recipes.md, each step's
//! "Retires"). Nothing else compiles these files any more: src/platform/root.zig
//! is no module's root since `platform` became the protocol's facade, and the
//! adapters and backends below are listed only by it. Each Retires step deletes
//! its lines here along with its files; when the last goes, so does this file.
//!
//! Its own executable, not part of tests/platform's directory executable, and
//! not named *_test.zig for that reason: the facade re-exports some of the same
//! files (media_backend.zig, timer_backend.zig, ...), and one file cannot belong
//! to two modules in one compile
//! (docs/lessons/architecture-a-module-bound-twice-cannot-share-a-compile.md).
//!
//! Not covered: layout_backend.zig and layout_adapter.zig (retired by step 12).
//! They import `runtime` (and layout_backend `impls`), and every module graph
//! that has those also has the facade, so they cannot compile beside the old
//! root.

const std = @import("std");
const old = @import("platform_legacy");

test "the old platform root and the code only it lists still compile" {
    std.testing.refAllDecls(old);
    // Step 2a.
    std.testing.refAllDecls(old.network_adapter);
    // Step 2c.
    std.testing.refAllDecls(old.timer_adapter);
    // Step 3.
    std.testing.refAllDecls(old.filesystem_adapter);
    // Step 9.
    std.testing.refAllDecls(old.ui_adapter);
    // Step 11.
    std.testing.refAllDecls(old.clipboard_adapter);
    // Step 13.
    std.testing.refAllDecls(old.notification_adapter);
    std.testing.refAllDecls(old.notification_backend);
    std.testing.refAllDecls(old.push_adapter);
    std.testing.refAllDecls(old.push_backend);
}
