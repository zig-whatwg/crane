//! A shadow root's host is gone: the hook its host's teardown reaches.
//!
//! An element keeps its shadow root alive for as long as the element's
//! wrapper lives, and the shadow root keeps its host the same way: an edge
//! each way between their wrappers (engine.traceChild, drawn in
//! Element.attachShadow; Element.zig's `shadow_root_kept`). Script that holds
//! either keeps both, and the collector takes the pair once it holds neither.
//!
//! A host can still be freed while its shadow root lives on: its tree's
//! teardown frees it when a detached ancestor is collected (a node does not
//! keep its tree's root alive), and its realm's end frees it. The host's
//! teardown (Element.deinit) then tells the shadow root, through this hook,
//! and the shadow root forgets its host rather than keep a pointer to freed
//! memory. The shadow root itself stays a working DocumentFragment, freed
//! with its subtree when its own wrapper is collected.
//!
//! Stated deviation, for those cases only: the spec's host always exists - a
//! shadow root's host is its host for its whole life. Such a shadow root
//! answers InvalidStateError for `host`.
//!
//! The ShadowRoot impl installs the implementation in its installHooks, which runs
//! before any element can have a shadow root.
//!
//! lint-impls: hook for ShadowRoot, Element
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What the ShadowRoot impl supplies.
pub const Implementation = struct {
    host_destroyed: ?*const fn (shadow: *runtime.Instance) void = null,
    root_for_host: ?*const fn (host: *runtime.Instance) ?*runtime.Instance = null,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by ShadowRoot's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    var combined = implementation orelse Implementation{};
    if (impl.host_destroyed) |step| combined.host_destroyed = step;
    if (impl.root_for_host) |step| combined.root_for_host = step;
    implementation = combined;
}

/// `shadow`'s host is being torn down: `shadow` forgets it. Nothing to do
/// when no shadow root was ever made.
pub fn hostDestroyed(shadow: *runtime.Instance) void {
    const impl = implementation orelse return;
    const step = impl.host_destroyed orelse return;
    step(shadow);
}

/// An element's shadow root, including a closed root. The IDL shadowRoot
/// getter intentionally hides closed roots; internal tree algorithms do not.
pub fn rootForHost(host: *runtime.Instance) ?*runtime.Instance {
    const impl = implementation orelse return null;
    const step = impl.root_for_host orelse return null;
    return step(host);
}

test "hostDestroyed without an installed implementation does nothing" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var shadow: runtime.Instance = undefined;
    hostDestroyed(&shadow);
}

test "hostDestroyed forwards to the installed implementation" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;

    const Fake = struct {
        var seen: ?*runtime.Instance = null;
        fn hostDestroyed(shadow: *runtime.Instance) void {
            seen = shadow;
        }
    };
    install(.{ .host_destroyed = &Fake.hostDestroyed });
    var shadow: runtime.Instance = undefined;
    hostDestroyed(&shadow);
    try std.testing.expectEqual(@as(?*runtime.Instance, &shadow), Fake.seen);
}
