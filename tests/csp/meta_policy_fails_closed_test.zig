//! A `<meta http-equiv=Content-Security-Policy>` whose policy cannot be
//! recorded fails CLOSED: never a document without it.
//!
//! HTMLMetaElement's Content Security Policy state parsed the policy with
//! `catch return` and enforced it with `csp_list.append(policy) catch
//! policy.deinit()`: out of memory dropped the policy, and the document ran
//! as if it had none (lane leaks2's fail-open table). Steps 3-5 are
//! csp.integration.enforceMetaPolicy now, and any allocation failure in them
//! leaves the list `unenforceable`, which every CSP decision entry point
//! reads as "Blocked".

const std = @import("std");
const testing = std.testing;
const csp = @import("csp");

const request_check = csp.request_check;
const navigation_check = csp.navigation_check;

/// One enforcement of `content` with `allocator`: afterwards the list either
/// holds the policy or is unenforceable - never neither. Unenforceable is the
/// failure, reported as OutOfMemory for checkAllAllocationFailures, which
/// then also checks that nothing leaked.
fn enforceWith(allocator: std.mem.Allocator, content: []const u8) !void {
    var list = csp.CSPList.init(allocator);
    defer list.deinit();
    csp.integration.enforceMetaPolicy(&list, content, null, "https://example.test/page.html");
    if (list.unenforceable) {
        try testing.expectEqual(@as(usize, 0), list.policies.items.len);
        try expectBlocksEverything(&list);
        return error.OutOfMemory;
    }
    try testing.expectEqual(@as(usize, 1), list.policies.items.len);
    const policy = &list.policies.items[0];
    try testing.expect(policy.source == .meta and policy.disposition == .enforce);
    try testing.expect(policy.getDirective("script-src") != null);
    // Step 4's removals.
    try testing.expect(policy.getDirective("sandbox") == null);
    try testing.expect(policy.getDirective("frame-ancestors") == null);
    try testing.expect(policy.getDirective("report-uri") == null);
    try testing.expectEqualStrings("https://example.test/page.html", policy.delivery_url.?);
}

const meta_content = "script-src 'none'; img-src 'self'; sandbox; frame-ancestors 'none'; report-uri /r";

test "a meta policy is enforced, or its list fails closed: every allocation failure in turn" {
    try enforceWith(testing.allocator, meta_content);
    try testing.checkAllAllocationFailures(testing.allocator, enforceWith, .{meta_content});
}

fn scriptRequest() request_check.Request {
    return .{ .url = request_check.Url.ofSerialized("https://example.test/a.js"), .destination = "script" };
}

/// Every CSP decision entry point says Blocked (or its fail-closed answer)
/// for `list`.
fn expectBlocksEverything(list: *const csp.CSPList) !void {
    try testing.expect(list.blocksEverything());
    try testing.expect(!list.isEmpty());
    // Fetch (CSP 4.1.2), for any destination.
    try testing.expectEqual(request_check.Result.blocked, request_check.shouldRequestBeBlocked(list, scriptRequest(), null));
    try testing.expectEqual(request_check.Result.blocked, request_check.shouldRequestBeBlocked(list, .{ .url = request_check.Url.ofSerialized("https://example.test/i.png"), .destination = "image" }, null));
    try testing.expectEqual(request_check.Result.blocked, request_check.shouldRequestBeBlocked(list, .{ .url = request_check.Url.ofSerialized("https://example.test/data"), .destination = "" }, null));
    // Navigation (4.2.4): any URL, a javascript: one's inline check too.
    const page = navigation_check.NavigationRequest.ofSerialized("https://example.test/next.html");
    const javascript = navigation_check.NavigationRequest.ofSerialized("javascript:void(0)");
    try testing.expectEqual(navigation_check.Result.blocked, navigation_check.shouldNavigationRequestBeBlocked(list, page, .other, null));
    try testing.expectEqual(navigation_check.Result.blocked, navigation_check.preNavigationChecks(list, page, .form_submission, null));
    try testing.expectEqual(navigation_check.Result.blocked, navigation_check.javascriptUrlInlineChecks(list, javascript, null));
    // Script compilation (4.4.1, 4.5.1).
    try testing.expectEqual(csp.code_generation.Result.blocked, csp.code_generation.ensureDoesNotBlockStringCompilation(list, "1 + 1", null));
    try testing.expectEqual(csp.code_generation.Result.blocked, csp.code_generation.ensureDoesNotBlockWasmByteCompilation(list, null));
    // Plugin content without a URL.
    try testing.expectEqual(csp.plugin_check.Result.blocked, csp.plugin_check.shouldPluginContentWithoutUrlBeBlocked(list, null, null));
    // The integration checks.
    try testing.expect(csp.integration.shouldBlockFetch(list, "https", "example.test", null, "/a.js", .script, 0).blocked);
    try testing.expect(csp.integration.shouldBlockInlineScript(list, .{ .content = "1" }).blocked);
    try testing.expect(csp.integration.shouldBlockInlineStyle(list, .{ .content = "p{}" }).blocked);
    // Trusted Types: required, policy creation and sink mismatches blocked.
    try testing.expect(csp.directives.require_trusted_types.doesSinkTypeRequireTrustedTypes(list, "script", false));
    try testing.expectEqual(csp.directives.trusted_types.Result.blocked, csp.directives.trusted_types.shouldPolicyCreationBeBlocked(list, "p", &.{}, null));
    try testing.expectEqual(csp.directives.require_trusted_types.Result.blocked, try csp.directives.require_trusted_types.shouldSinkTypeMismatchViolationBeBlocked(testing.allocator, list, "Element innerHTML", "script", "x", null));
    // The directives with list-wide answers: the strict ones.
    try testing.expect(csp.directives.upgrade_insecure.shouldUpgradeInsecureRequests(list));
    try testing.expect(!csp.directives.sandbox.areScriptsAllowed(list));
    try testing.expect(!csp.directives.sandbox.areFormsAllowed(list));
    try testing.expect(!csp.directives.form_action.isFormActionAllowedByList(list, "https", "example.test", null, "/"));
    try testing.expect(!csp.directives.base_uri.isBaseUriAllowedByList(list, "https", "example.test", null, "/"));
    const ancestors = [_]csp.directives.frame_ancestors.AncestorOrigin{.{ .scheme = "https", .host = "example.test", .port = 443 }};
    try testing.expect(csp.directives.frame_ancestors.checkNavigationResponse(list, false, &ancestors, "https://example.test/", null));
}

test "an unenforceable list blocks every CSP decision, and so does its copy" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    // A list with no policies allows everything ...
    try testing.expect(list.isEmpty());
    try testing.expectEqual(request_check.Result.allowed, request_check.shouldRequestBeBlocked(&list, scriptRequest(), null));
    // ... until a policy could not be recorded.
    list.markUnenforceable();
    try expectBlocksEverything(&list);
    // A clone - an inherited policy container's - fails closed too.
    var copy = try csp.parsing.copyList(testing.allocator, &list);
    defer copy.deinit();
    try expectBlocksEverything(&copy);
}

test "an enforced meta policy still decides by its directives" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    csp.integration.enforceMetaPolicy(&list, "img-src 'none'", null, null);
    try testing.expect(!list.unenforceable);
    try testing.expectEqual(request_check.Result.allowed, request_check.shouldRequestBeBlocked(&list, scriptRequest(), null));
    try testing.expectEqual(request_check.Result.blocked, request_check.shouldRequestBeBlocked(&list, .{ .url = request_check.Url.ofSerialized("https://example.test/i.png"), .destination = "image" }, null));
}
