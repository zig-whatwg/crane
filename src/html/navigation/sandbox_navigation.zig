//! HTML 7.4.2.2 "allowed by sandboxing to navigate": whether a navigable may
//! navigate another, given the sandboxing flags the source document had when
//! the navigation began (its source snapshot params).
//!
//! Crane's navigables are its browsing contexts: a child context's parent is
//! its parent navigable's, and a top-level traversable's context has no
//! parent. The caller snapshots the source document - its active sandboxing
//! flag set and whether its window has transient activation (navigate step
//! 2, "snapshotting source snapshot params").
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#allowed-to-navigate

const std = @import("std");
const BrowsingContext = @import("../window/browsing_context.zig").BrowsingContext;
const SandboxingFlagSet = @import("dom").sandboxing.SandboxingFlagSet;

/// The parts of the source snapshot params the check reads.
pub const SourceSnapshot = struct {
    /// "sandboxing flags": the source document's active sandboxing flag set.
    sandboxing_flags: SandboxingFlagSet,
    /// "has transient activation": the source document's relevant global
    /// object has transient activation.
    has_transient_activation: bool,
};

/// How deep an ancestor walk goes before giving up (a cycle is a bug, never
/// a navigation's answer).
const max_depth = 256;

/// Whether `ancestor` is an ancestor of `context` (not `context` itself).
fn isAncestorOf(ancestor: *const BrowsingContext, context: *const BrowsingContext) bool {
    var current = context.parent;
    var depth: usize = 0;
    while (current) |c| : (current = c.parent) {
        if (c == ancestor) return true;
        depth += 1;
        if (depth > max_depth) return false;
    }
    return false;
}

/// "A navigable source is allowed by sandboxing to navigate a second
/// navigable target, given a source snapshot params sourceSnapshotParams, if
/// the following steps return true".
pub fn allowedBySandboxingToNavigate(source: *const BrowsingContext, target: *const BrowsingContext, snapshot: SourceSnapshot) bool {
    const flags = snapshot.sandboxing_flags;
    // 1. "If source is target, then return true."
    if (source == target) return true;
    // 2. "If source is an ancestor of target, then return true."
    if (isAncestorOf(source, target)) return true;
    // 3. "If target is an ancestor of source":
    if (isAncestorOf(target, source)) {
        // 3.1. "If target is not a top-level traversable, then return true."
        // Deviation, stated (golden rule 2): every engine refuses a source
        // with the sandboxed navigation browsing context flag its ancestors
        // other than the top-level one, as step 5 refuses any other
        // navigable - Blink's LocalFrame::CanNavigate ("The frame attempting
        // navigation is sandboxed, and is therefore disallowed from
        // navigating its ancestors."), Gecko's BrowsingContext::
        // IsSandboxedFrom (a target with a parent it is not an ancestor of)
        // and WebKit's Frame::isSandboxedFrom alike. Chrome 154, Firefox 157
        // and Safari 27 each pass the-iframe-element/
        // iframe_sandbox_navigate_ancestor-1.html (1/1, aligned wpt.fyi
        // revision cc74d2669f), whose frame nested in a sandboxed document
        // must not navigate its parent.
        if (target.parent != null) return !flags.navigation;
        // 3.2. "If sourceSnapshotParams's has transient activation is true,
        // and sourceSnapshotParams's sandboxing flags's sandboxed top-level
        // navigation with user activation browsing context flag is set, then
        // return false."
        if (snapshot.has_transient_activation and flags.top_level_navigation_with_user_activation) return false;
        // 3.3. "If sourceSnapshotParams's has transient activation is false,
        // and sourceSnapshotParams's sandboxing flags's sandboxed top-level
        // navigation without user activation browsing context flag is set,
        // then return false."
        if (!snapshot.has_transient_activation and flags.top_level_navigation_without_user_activation) return false;
        // 3.4. "Return true."
        return true;
    }
    // 4. "If target is a top-level traversable":
    if (target.parent == null) {
        // 4.1. "If source is the one permitted sandboxed navigator of
        // target, then return true."
        if (target.one_permitted_sandboxed_navigator == source) return true;
        // 4.2. "If sourceSnapshotParams's sandboxing flags's sandboxed
        // navigation browsing context flag is set, then return false."
        if (flags.navigation) return false;
        // 4.3. "Return true."
        return true;
    }
    // 5. "If sourceSnapshotParams's sandboxing flags's sandboxed navigation
    // browsing context flag is set, then return false."
    if (flags.navigation) return false;
    // 6. "Return true."
    return true;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const Navigables = @import("../window/browsing_context.zig").Navigables;
const parse = @import("dom").sandboxing.parseSandboxingDirective;

fn sourceSnapshot(sandbox: ?[]const u8, activation: bool) SourceSnapshot {
    return .{
        .sandboxing_flags = if (sandbox) |value| parse(value) else .empty,
        .has_transient_activation = activation,
    };
}

test "an unsandboxed source may navigate anything" {
    var navigables = Navigables.init(testing.allocator);
    defer navigables.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &navigables);
    defer top.deinit();
    const a = try BrowsingContext.initChild(testing.allocator, top);
    defer a.deinit();
    const b = try BrowsingContext.initChild(testing.allocator, top);
    defer b.deinit();
    const other_top = try BrowsingContext.initTopLevel(testing.allocator, &navigables);
    defer other_top.deinit();
    try testing.expect(allowedBySandboxingToNavigate(a, top, sourceSnapshot(null, false)));
    try testing.expect(allowedBySandboxingToNavigate(a, b, sourceSnapshot(null, false)));
    try testing.expect(allowedBySandboxingToNavigate(a, other_top, sourceSnapshot(null, false)));
}

test "a sandboxed source may navigate itself and its descendants" {
    var navigables = Navigables.init(testing.allocator);
    defer navigables.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &navigables);
    defer top.deinit();
    const frame = try BrowsingContext.initChild(testing.allocator, top);
    defer frame.deinit();
    const child = try BrowsingContext.initChild(testing.allocator, frame);
    defer child.deinit();
    const grandchild = try BrowsingContext.initChild(testing.allocator, child);
    defer grandchild.deinit();
    const sandboxed = sourceSnapshot("", false);
    try testing.expect(allowedBySandboxingToNavigate(frame, frame, sandboxed));
    try testing.expect(allowedBySandboxingToNavigate(frame, child, sandboxed));
    try testing.expect(allowedBySandboxingToNavigate(frame, grandchild, sandboxed));
}

test "a sandboxed source may navigate neither a sibling nor an ancestor short of the top" {
    var navigables = Navigables.init(testing.allocator);
    defer navigables.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &navigables);
    defer top.deinit();
    const parent = try BrowsingContext.initChild(testing.allocator, top);
    defer parent.deinit();
    const frame = try BrowsingContext.initChild(testing.allocator, parent);
    defer frame.deinit();
    const sibling = try BrowsingContext.initChild(testing.allocator, parent);
    defer sibling.deinit();
    const sandboxed = sourceSnapshot("allow-scripts", false);
    try testing.expect(!allowedBySandboxingToNavigate(frame, sibling, sandboxed));
    // Step 3.1, as every engine does it: an ancestor that is not top-level
    // is refused - even with allow-top-navigation, which reaches only the
    // top-level one.
    try testing.expect(!allowedBySandboxingToNavigate(frame, parent, sandboxed));
    try testing.expect(!allowedBySandboxingToNavigate(frame, parent, sourceSnapshot("allow-top-navigation", true)));
    // Unsandboxed, it may.
    try testing.expect(allowedBySandboxingToNavigate(frame, parent, sourceSnapshot(null, false)));
}

test "the top-level ancestor: allow-top-navigation, and allow-top-navigation-by-user-activation with activation" {
    var navigables = Navigables.init(testing.allocator);
    defer navigables.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &navigables);
    defer top.deinit();
    const frame = try BrowsingContext.initChild(testing.allocator, top);
    defer frame.deinit();
    try testing.expect(!allowedBySandboxingToNavigate(frame, top, sourceSnapshot("allow-scripts", false)));
    try testing.expect(!allowedBySandboxingToNavigate(frame, top, sourceSnapshot("allow-scripts", true)));
    try testing.expect(allowedBySandboxingToNavigate(frame, top, sourceSnapshot("allow-top-navigation", false)));
    try testing.expect(allowedBySandboxingToNavigate(frame, top, sourceSnapshot("allow-top-navigation", true)));
    try testing.expect(!allowedBySandboxingToNavigate(frame, top, sourceSnapshot("allow-top-navigation-by-user-activation", false)));
    try testing.expect(allowedBySandboxingToNavigate(frame, top, sourceSnapshot("allow-top-navigation-by-user-activation", true)));
}

test "another top-level traversable: only its one permitted sandboxed navigator" {
    var navigables = Navigables.init(testing.allocator);
    defer navigables.deinit();
    const top = try BrowsingContext.initTopLevel(testing.allocator, &navigables);
    defer top.deinit();
    const frame = try BrowsingContext.initChild(testing.allocator, top);
    defer frame.deinit();
    const popup = try BrowsingContext.initAuxiliary(testing.allocator, frame, false);
    defer popup.deinit();
    const sandboxed = sourceSnapshot("allow-scripts allow-popups", false);
    try testing.expect(!allowedBySandboxingToNavigate(frame, popup, sandboxed));
    popup.one_permitted_sandboxed_navigator = frame;
    try testing.expect(allowedBySandboxingToNavigate(frame, popup, sandboxed));
    // allow-top-navigation does not reach another top-level traversable.
    popup.one_permitted_sandboxed_navigator = null;
    try testing.expect(!allowedBySandboxingToNavigate(frame, popup, sourceSnapshot("allow-top-navigation", true)));
}
