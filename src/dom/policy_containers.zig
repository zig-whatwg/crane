//! A Document's policy container (HTML 7.1.6): the policies that apply to it
//! - its referrer policy, and its CSP list - which every request it makes
//! carries a clone of (Fetch "populate request from client" step 3).
//!
//! Document keeps its container in its own state. What sets one - a
//! navigation's response or inheritance ("determine navigation params policy
//! container"), a meta element named referrer - and what reads one - a
//! Window's settings object, as a request's client - may not name Document's
//! impl, so Document installs the accessor here. A WorkerGlobalScope's
//! container is its settings object's, reached through `global_settings`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#policy-containers
//!
//! lint-impls: hook for Document

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const fetch = @import("fetch");

pub const PolicyContainer = fetch.internal.PolicyContainer;

/// What Document supplies.
pub const Implementation = struct {
    /// `document`'s policy container - owned by the document, borrowed for
    /// as long as it lives - or null when `document` is not a Document.
    of: *const fn (document: *runtime.Instance) ?*PolicyContainer,
};

// process-wide: hook table written once at process start by Document.installHooks (B0); comptime in B9
var implementation: ?Implementation = null;

/// Called by Document's installHooks.
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `document`'s policy container, or null - not a Document, or no
/// implementation installed.
pub fn of(document: *runtime.Instance) ?*PolicyContainer {
    const impl = implementation orelse return null;
    return impl.of(document);
}

/// Give `document` the policy container `container`, which it takes:
/// "set document's policy container" in "create and initialize a Document
/// object" (step 9's new document) and wherever HTML replaces it. A
/// non-Document releases it.
pub fn set(document: *runtime.Instance, container: PolicyContainer) void {
    var taken = container;
    const target = of(document) orelse return taken.deinit();
    target.deinit();
    target.* = taken;
}

/// The test implementation: a "document" here is a PolicyContainer's address,
/// so the tests keep no container-level state (lint-global-state counts it).
fn testOf(document: *runtime.Instance) ?*PolicyContainer {
    return @ptrCast(@alignCast(document));
}

test "a document's container is reached, and replaced, through the hook" {
    const saved = implementation;
    defer implementation = saved;
    implementation = .{ .of = &testOf };
    var container = PolicyContainer.init(std.testing.allocator);
    defer container.deinit();
    const document: *runtime.Instance = @ptrCast(@alignCast(&container));

    try std.testing.expect(of(document) == &container);
    set(document, try PolicyContainer.fromResponse(std.testing.allocator, "no-referrer"));
    try std.testing.expectEqual(fetch.internal.ReferrerPolicy.no_referrer, of(document).?.referrer_policy);
}

test "without an installed implementation there is no container, and one handed over is released" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    var container = PolicyContainer.init(std.testing.allocator);
    defer container.deinit();
    const document: *runtime.Instance = @ptrCast(@alignCast(&container));
    try std.testing.expect(of(document) == null);
    set(document, try PolicyContainer.fromResponse(std.testing.allocator, "origin"));
}
