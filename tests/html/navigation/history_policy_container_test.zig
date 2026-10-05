//! A document state's history policy container (HTML 7.4.1): the policy
//! container a document of a URL that "requires storing the policy container
//! in history" (about: and data: - local, but not blob:) was made with, kept
//! by its document state so a traversal back to it ("determining navigation
//! params policy container" step 1) gives the new document those policies
//! rather than its traversal's initiator's.

const std = @import("std");
const testing = std.testing;
const html_core = @import("html_core");
const joint = html_core.navigation.joint_history;
const PolicyContainer = joint.PolicyContainer;

const top: u64 = 1;

fn containerWith(policy: @FieldType(PolicyContainer, "referrer_policy")) PolicyContainer {
    var container = PolicyContainer.init(testing.allocator);
    container.referrer_policy = policy;
    return container;
}

test "the document state keeps the history policy container for every entry of it" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    try h.commitDocument(top, "about:blank", null, "http://x.test", .push);
    const blank = h.currentEntry(top).?;
    const state = blank.document_state;
    const blank_id = blank.id;
    try testing.expect(h.historyPolicyContainer(blank_id) == null);

    var container = containerWith(.no_referrer);
    defer container.deinit();
    try h.setHistoryPolicyContainer(state, &container);
    try testing.expectEqual(.no_referrer, h.historyPolicyContainer(blank_id).?.referrer_policy);

    // A same-document entry on that document shares its document state, and
    // with it the container.
    try h.commitSameDocument(top, "about:blank#x", .null, .push, null);
    const fragment = h.currentEntry(top).?;
    try testing.expectEqual(state, fragment.document_state);
    try testing.expectEqual(.no_referrer, h.historyPolicyContainer(fragment.id).?.referrer_policy);

    // The entries of the first document have none.
    try testing.expect(h.historyPolicyContainer(h.entryAt(top, 0).?.id) == null);
}

test "a replace by a new document state drops the replaced state's container" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    try h.commitDocument(top, "data:text/html,a", null, "null", .push);
    var container = containerWith(.origin);
    defer container.deinit();
    try h.setHistoryPolicyContainer(h.currentEntry(top).?.document_state, &container);

    try h.commitDocument(top, "http://x.test/b", null, "http://x.test", .replace);
    try testing.expect(h.historyPolicyContainer(h.currentEntry(top).?.id) == null);
}

test "setting it again replaces it; an unknown entry has none" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "about:blank", null, "http://x.test");
    const entry = h.currentEntry(top).?;
    var first = containerWith(.origin);
    defer first.deinit();
    var second = containerWith(.same_origin);
    defer second.deinit();
    try h.setHistoryPolicyContainer(entry.document_state, &first);
    try h.setHistoryPolicyContainer(entry.document_state, &second);
    try testing.expectEqual(.same_origin, h.historyPolicyContainer(entry.id).?.referrer_policy);
    try testing.expect(h.historyPolicyContainer(999_999) == null);
}

test "requiresStoringPolicyContainerInHistory - about: and data:, not blob: nor http(s)" {
    const f = html_core.navigation.navigate_steps.requiresStoringPolicyContainerInHistory;
    try testing.expect(f("about:blank"));
    try testing.expect(f("about:srcdoc"));
    try testing.expect(f("data:text/html,x"));
    try testing.expect(!f("blob:http://x.test/0e5d8f2a-7b1c-4c3d-8e9f-1a2b3c4d5e6f"));
    try testing.expect(!f("http://x.test/"));
    try testing.expect(!f("https://x.test/"));
    try testing.expect(!f("javascript:1"));
}
