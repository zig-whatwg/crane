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
    /// Both Permissions Policies, independently owned by the Document.
    permissions: ?*const fn (document: *runtime.Instance) ?*Policies = null,
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

pub const permissions_policy = @import("html_core").permissions_policy;
pub const Policies = permissions_policy.Policies;
const interfaces = @import("interfaces");
const origins = @import("origin_record.zig");
const document_origin = @import("document_origin.zig");

/// A Document's owned policies, BORROWED while that Document lives.
pub fn permissionsOf(document: *runtime.Instance) ?*Policies {
    const impl = implementation orelse return null;
    const get = impl.permissions orelse return null;
    return get(document);
}

/// HTML "allowed to use" steps 1-4 and Permissions Policy §9.10.
/// This is an actual attempted use, so disabled policies queue a report.
pub fn allowedToUse(document: *runtime.Instance, feature: permissions_policy.Feature) !bool {
    const window = (try interfaces.Document.get_defaultView(document)) orelse return false;
    if (@import("browser_state.zig").browsingContextOf(window) == null) return false;
    if (!@import("document_activity.zig").fullyActive(document, runtime.SlabAllocator.generationOf(document))) return false;
    const policies = permissionsOf(document) orelse return false;
    const origin = (try document_origin.shareable(document)) orelse return false;
    const result = try policies.check(feature, .{ .serialized = origin.serialized orelse "null", .record = origin });
    if (result.violation) |violation| {
        // A reporting allocation failure cannot widen a denied policy.
        reportViolation(document, window, feature, violation) catch {};
    }
    return result.enabled;
}

/// Permissions Policy §§9.4-9.6, before the new Document is constructed.
/// BORROWS every input and returns an independently owned policy pair.
pub fn permissionsForNavigable(allocator: std.mem.Allocator, container: ?*runtime.Instance, origin: *origins.OriginRecord, headers: permissions_policy.Headers) !Policies {
    const element = container orelse return Policies.fromHeaders(allocator, origin, null, null, headers);
    const parent_document = (try interfaces.Node.get_ownerDocument(element)) orelse return error.InvalidStateError;
    const parent = permissionsOf(parent_document) orelse return error.InvalidStateError;
    const parent_origin = (try document_origin.shareable(parent_document)) orelse return error.InvalidStateError;
    try parent.resolveOrigin(.{ .serialized = parent_origin.serialized orelse "null", .record = parent_origin });
    var declared = try containerPermissions(element, parent_document, parent_origin);
    defer declared.deinit();
    return Policies.fromHeaders(allocator, origin, parent, &declared, headers);
}

/// Permissions Policy §9.7, for Fetch's reservation BEFORE the child exists.
/// An iframe or frame container and the BORROWED origin of the future URL.
/// This signature is shared with the phase-C owner (liaison Q19).
pub fn inheritedDeferredFetchPolicy(container: *runtime.Instance, origin: *const origins.Origin) error{OutOfMemory}!@import("deferred_fetches.zig").Policy {
    const denied: @import("deferred_fetches.zig").Policy = .{ .deferred_fetch = false, .deferred_fetch_minimal = false };
    const parent_document = (interfaces.Node.get_ownerDocument(container) catch return denied) orelse return denied;
    const parent = permissionsOf(parent_document) orelse return denied;
    const parent_origin = (try document_origin.shareable(parent_document)) orelse return denied;
    try parent.resolveOrigin(.{ .serialized = parent_origin.serialized orelse "null", .record = parent_origin });
    var declared = try containerPermissions(container, parent_document, parent_origin);
    defer declared.deinit();
    return .{
        .deferred_fetch = permissions_policy.PermissionsPolicy.inheritedValue(.deferred_fetch, &parent.enforce, &declared, origin.*),
        .deferred_fetch_minimal = permissions_policy.PermissionsPolicy.inheritedValue(.deferred_fetch_minimal, &parent.enforce, &declared, origin.*),
    };
}

/// §9.4: only iframe has an allow-based container policy. A frame has none.
fn containerPermissions(container: *runtime.Instance, document: *runtime.Instance, parent_origin: *origins.OriginRecord) error{OutOfMemory}!permissions_policy.PermissionsPolicy {
    const allocator = container.ctx.allocator;
    const data = @import("element_data.zig").of(container) orelse return permissions_policy.PermissionsPolicy.initWithOrigin(allocator, parent_origin);
    if (!std.mem.eql(u8, data.namespaceSlice() orelse "", "http://www.w3.org/1999/xhtml") or
        !std.mem.eql(u8, data.local_name.asSlice(), "iframe"))
        return permissions_policy.PermissionsPolicy.initWithOrigin(allocator, parent_origin);
    const target = try declaredOrigin(container, document, parent_origin);
    defer target.release();
    const allow = if (data.findAttribute(null, "allow")) |attribute| attribute.value else "";
    var policy = try permissions_policy.PermissionsPolicy.fromAllowAttributeOrigins(allocator, allow, parent_origin, target);
    errdefer policy.deinit();
    if (data.findAttribute(null, "allowfullscreen") != null and !policy.declared_policy.contains(.fullscreen)) {
        try policy.declared_policy.put(.fullscreen, permissions_policy.Allowlist.allowAll(allocator));
    }
    return policy;
}

/// Permissions Policy §7 "declared origin", steps 1-5. The returned record
/// is OWNED, retaining parent identity for srcdoc and the fallback case.
fn declaredOrigin(container: *runtime.Instance, document: *runtime.Instance, parent_origin: *origins.OriginRecord) error{OutOfMemory}!*origins.OriginRecord {
    const allocator = container.ctx.allocator;
    const data = @import("element_data.zig").of(container) orelse return parent_origin.retain();
    if (@import("document_scripts.zig").activeSandboxingFlags(document).origin) return origins.OriginRecord.create(allocator, "null");
    if (data.findAttribute(null, "sandbox")) |sandbox| {
        if (@import("sandboxing.zig").parseSandboxingDirective(sandbox.value).origin) return origins.OriginRecord.create(allocator, "null");
    }
    if (data.findAttribute(null, "srcdoc") != null) return parent_origin.retain();
    if (data.findAttribute(null, "src")) |src| {
        if (try @import("encoding_parse.zig").encodingParseAndSerialize(container, src.value)) |url| {
            defer allocator.free(url);
            // ipv4_serializer.zig:26 inserts each octet at idx <= the
            // current length, and separators at 0; bounds cannot fail (Q53).
            const serialized = fetch.internal.origins.serializedOriginOf(allocator, url) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.IndexOutOfBounds => unreachable,
            };
            defer allocator.free(serialized);
            return origins.OriginRecord.create(allocator, serialized);
        }
    }
    return parent_origin.retain();
}

/// Permissions Policy §9.13. The existing Reporting queue snapshots this
/// body and the endpoint before the synchronous check returns.
fn reportViolation(document: *runtime.Instance, global: *runtime.Instance, feature: permissions_policy.Feature, violation: permissions_policy.Violation) !void {
    const engine = @import("engine");
    const allocator = document.ctx.allocator;
    const Body = struct {
        featureId: []const u8,
        sourceFile: ?[]const u8 = null,
        lineNumber: ?u32 = null,
        columnNumber: ?u32 = null,
        disposition: []const u8,
    };
    var body: Body = .{ .featureId = feature.toString(), .disposition = @tagName(violation.disposition) };
    // Step 2 uses the same existing engine contract as CSP's report capture.
    const running = if (global.ctx.agent) |agent| try engine.runningScriptLocation(agent, allocator) else null;
    defer if (running) |location| location.deinit(allocator);
    if (running) |location| {
        body.sourceFile = location.url;
        body.lineNumber = location.line;
        body.columnNumber = location.column;
    }
    const json = try std.json.Stringify.valueAlloc(allocator, body, .{});
    defer allocator.free(json);
    // Reporting §2.3 steps 2-4 use the settings object's creation URL,
    // not a later same-document URL, with credentials and fragment removed.
    const url = try @import("csp").violation_events.stripUrlForReports(allocator, global.ctx.creationUrl() orelse global.ctx.documentUrl() orelse "about:blank");
    defer allocator.free(url);
    try @import("reporting.zig").generate(global, "permissions-policy-violation", violation.endpoint orelse "", url, json);
}
