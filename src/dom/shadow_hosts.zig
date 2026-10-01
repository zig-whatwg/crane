//! A shadow root's host is gone: the hook its host's teardown reaches.
//!
//! An element keeps its shadow root alive for as long as the element lives
//! (Element.zig's `shadow_root_kept`, a `same_object.KeptChild`). A shadow
//! root does not keep its host: there is no traced edge from the shadow
//! root's wrapper to the host's, so V8 may collect the host while script
//! still holds the shadow root - `document.createElement("div")
//! .attachShadow({mode: "open"})` keeps nothing of the host. The host's
//! teardown (Element.deinit) then tells the shadow root, through this hook,
//! and the shadow root forgets its host rather than keep a pointer to freed
//! memory. The shadow root itself stays a working DocumentFragment, freed
//! with its subtree when its own wrapper is collected.
//!
//! Stated deviation: the spec's host always exists - a shadow root's host is
//! its host for its whole life, and Blink and WebKit keep the host alive
//! through the shadow root. Until wrappers are traced (the host <-> shadow
//! root edge of the tracing redesign), such a shadow root answers
//! InvalidStateError for `host`.
//!
//! The ShadowRoot impl installs the implementation in its `init`, which runs
//! before any element can have a shadow root.
//!
//! lint-impls: hook for ShadowRoot

const runtime = @import("runtime");

/// What the ShadowRoot impl supplies.
pub const Implementation = struct {
    host_destroyed: *const fn (shadow: *runtime.Instance) void,
};

/// Per thread, as a shadow root and its host live on one thread.
threadlocal var implementation: ?Implementation = null;

/// Called by the ShadowRoot impl. Idempotent: every call installs the same
/// function.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// `shadow`'s host is being torn down: `shadow` forgets it. Nothing to do
/// when no shadow root was ever made.
pub fn hostDestroyed(shadow: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.host_destroyed(shadow);
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
