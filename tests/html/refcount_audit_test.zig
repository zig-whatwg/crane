//! Lane refcount7: refcount step 6, the zombie audit (dom.refcount_audit;
//! tmp/plans/refcount-design.md section 7 step 6, decision D10).
//!
//! With the audit on, a tree the counts call garbage is queued on its agent's
//! deferred teardown queue, re-checked at the next slice as step 7 will, and
//! marked zombie there instead of freed; a later read of one of its nodes is
//! reported. The tests keep a bare pointer to a node - the shape of a holder
//! step 5 missed - and read it after the slice.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const dom = h.dom;
const runtime = h.runtime;
const interfaces = @import("interfaces");

const audit = dom.refcount_audit;

fn instanceOf(node: *dom.NodeBase) !*runtime.Instance {
    return @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return error.NotANode));
}

/// One event loop turn: the deferred teardown's slice runs between tasks.
fn turn(page: h.Page) !void {
    _ = try page.browser.runEventLoopBlocking(20);
}

fn aGarbageTreeIsMarkedAtItsSliceAndABareReadReported() !void {
    const saved = audit.swapForTest(true);
    defer _ = audit.swapForTest(saved);
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<p><b>x</b></p>';");
    const host = try page.node("host");
    const p = host.first_child orelse return error.NoChild;
    const b = p.first_child orelse return error.NoChild;
    // The missed holder: a bare pointer to b, with no count.
    const b_instance = try instanceOf(b);
    try page.run("host.innerHTML = '';");
    try testing.expect(p.rc_flags.audit_pending);
    try testing.expect(!p.rc_flags.zombie);
    try turn(page);
    try testing.expect(!p.rc_flags.audit_pending);
    try testing.expect(p.rc_flags.zombie);
    try testing.expect(b.rc_flags.zombie);
    const books = audit.auditOf(host) orelse return error.NoAgent;
    try testing.expect(books.zombie_trees >= 1);
    const before = books.accesses;
    _ = dom.instance_bridge.getNodeBase(@ptrCast(b_instance));
    try testing.expectEqual(before + 1, books.accesses);
    // A read through Node's own state is a report too.
    _ = try interfaces.Node.get_nodeType(b_instance);
    try testing.expect(books.accesses >= before + 2);
}

test "the audit marks a garbage tree zombie at its slice, and a bare read of it is reported" {
    try h.onFreshThread(aGarbageTreeIsMarkedAtItsSliceAndABareReadReported);
}

fn aCountedHolderKeepsItsTreeFromTheAudit() !void {
    const saved = audit.swapForTest(true);
    defer _ = audit.swapForTest(saved);
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<p><b>x</b></p>';");
    const host = try page.node("host");
    const p = host.first_child orelse return error.NoChild;
    const b = p.first_child orelse return error.NoChild;
    // The holder counts: b's tree is not garbage.
    dom.refcount.holderRef(b);
    try page.run("host.innerHTML = '';");
    try turn(page);
    try testing.expect(!p.rc_flags.audit_pending);
    try testing.expect(!b.rc_flags.zombie);
    const books = audit.auditOf(host) orelse return error.NoAgent;
    const before = books.accesses;
    _ = dom.instance_bridge.getNodeBase(@ptrCast(try instanceOf(b)));
    try testing.expectEqual(before, books.accesses);
    // Its release makes the tree garbage; the next slice marks it.
    dom.refcount.holderDeref(b);
    try testing.expect(p.rc_flags.audit_pending);
    try turn(page);
    try testing.expect(b.rc_flags.zombie);
}

test "a counted holder keeps its tree from the audit until it lets go" {
    try h.onFreshThread(aCountedHolderKeepsItsTreeFromTheAudit);
}

fn aTreeHeldAgainBeforeItsSliceIsAResurrection() !void {
    const saved = audit.swapForTest(true);
    defer _ = audit.swapForTest(saved);
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<p><b>x</b></p>';");
    const host = try page.node("host");
    const p = host.first_child orelse return error.NoChild;
    const p_instance = try instanceOf(p);
    try page.run("host.innerHTML = '';");
    try testing.expect(p.rc_flags.audit_pending);
    const books = audit.auditOf(host) orelse return error.NoAgent;
    const resurrections = books.resurrections;
    // A native move of the unheld node, in the same task: it is linked again.
    _ = try interfaces.Node.call_appendChild(try instanceOf(host), p_instance);
    try testing.expectEqual(resurrections + 1, books.resurrections);
    try turn(page);
    try testing.expect(!p.rc_flags.zombie);
    try testing.expect(!p.rc_flags.audit_pending);
}

test "a garbage tree linked again before its slice is a resurrection, not a zombie" {
    try h.onFreshThread(aTreeHeldAgainBeforeItsSliceIsAResurrection);
}

fn theAuditOffMarksNothing() !void {
    const saved = audit.swapForTest(false);
    defer _ = audit.swapForTest(saved);
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<p><b>x</b></p>';");
    const p = (try page.node("host")).first_child orelse return error.NoChild;
    try page.run("host.innerHTML = '';");
    try turn(page);
    try testing.expect(!p.rc_flags.audit_pending);
    try testing.expect(!p.rc_flags.zombie);
}

test "with the audit off nothing is queued or marked" {
    try h.onFreshThread(theAuditOffMarksNothing);
}
