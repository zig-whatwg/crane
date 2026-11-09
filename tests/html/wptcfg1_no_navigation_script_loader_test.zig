//! An embedder's load hands the page no script loader: every script a page
//! includes is fetched, as in a browser (HTML "fetch a classic script").
//!
//! The WPT runner used to answer testharness.js, testharnessreport.js and the
//! testdriver vendor file for the page's parser through an embedder hook
//! (Context.LoadPageOptions.script_loader, carried by
//! dom.top_level_traversables.NavigateOptions and html_core's
//! iframe_integration.EmbedderScriptLoader) - a path no browser has, which
//! the WPT run therefore never tested the way a page loads (lesson
//! architecture-a-host-only-load-path-hides-its-bugs-from-the-suite-that-uses-it).
//! The user, 2026-11-09: "I want our WPT to only ever run Crane with the
//! exact same configuration ... We should never special case something."
//! The runner's report is now served by `wpt serve`, as wptrunner serves its
//! own (tools/wptrunner/wptrunner/environment.py, get_routes). These
//! predicates pin that the hook is gone, so it cannot quietly come back.
//! (html.embedder_scripts stays, answering only the testdriver vendor file,
//! until test_driver's commands move into src/webdriver: lane wptcfg batch 2.)
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const html_core = @import("html_core");

test "an embedder's load of a page carries no script loader" {
    try std.testing.expect(!@hasField(browser_mod.Context.LoadPageOptions, "script_loader"));
    try std.testing.expect(!@hasField(browser_mod.Context.LoadHTMLOptions, "script_loader"));
    try std.testing.expect(!@hasField(browser_mod.Browser.NavigateOptions, "script_loader"));
    try std.testing.expect(!@hasDecl(browser_mod.Context, "ScriptLoader"));
}

test "a browser UI navigation carries no script loader, and no frame navigation keeps one" {
    try std.testing.expect(!@hasField(dom.top_level_traversables.NavigateOptions, "script_loader"));
    try std.testing.expect(!@hasDecl(dom.top_level_traversables, "ScriptLoader"));
    try std.testing.expect(!@hasDecl(html_core.window.iframe_integration, "EmbedderScriptLoader"));
    try std.testing.expect(!@hasField(html_core.window.iframe_integration.IFrameIntegration, "next_script_loader"));
}
