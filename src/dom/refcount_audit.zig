//! Refcount step 6: the zombie audit (tmp/plans/refcount-design.md section 7
//! step 6; decision D10: zero reports is the gate for step 7, the switch).
//!
//! Until step 7 the counts decide nothing: the old model (a tree's root
//! wrapper collected, or its realm's end) still frees every node. The audit
//! runs step 7's schedule beside it and marks instead of freeing, so any read
//! of a node step 7 would have freed is seen and reported:
//!
//!  1. The garbage moment. Where the counts lower a tree's total to zero -
//!     a wrapper's or a holder's release, the creator's, a removal, a host's
//!     end, a document's last foreign hold - the tree's root is flagged
//!     `audit_pending` and queued on its agent's deferred teardown queue
//!     (`runtime.gc.DeferredTeardown`, the AgentHost's): the queue, the
//!     between-tasks slices and the realm and agent drains step 7 frees
//!     through (design 1.4: "deref to zero frees later", decision D8).
//!  2. The slice. The item re-checks the root as step 7's would (design 1.4
//!     step 2): still the same instance, no teardown begun, parentless,
//!     unhosted, its total zero. Then every node of the host-including tree
//!     is marked `zombie` - step 7 would have freed them here. A root held
//!     again before its slice is a resurrection (reported apart: step 7's
//!     re-check drops it, and design 1.4 calls it a bug unless allowlisted).
//!  3. Reports. A read of a zombie node through `instance_bridge.getNodeBase`,
//!     Node's internal state, `node_document.set`, a re-insertion or a new
//!     reference is a read step 7 makes a use-after-free: a holder step 5
//!     missed, a step-5i registry, or a weak read the audit must learn
//!     (triage, lane refcount7). The old model's own teardown is not a
//!     report: a node whose teardown began, a realm's coordinated teardown,
//!     the agent's teardown slice.
//!
//! The switch is `CRANE_REFCOUNT_AUDIT=1` in the WPT runner's environment
//! (`enable`, before any page runs); off, each hook costs one load of
//! `audit_requested`. The books are the agent's (`Audit`, on its AgentHost):
//! each report site - its path and the return address of the read - counts
//! its hits, the first `printed_per_site` of them print with their stack, and
//! the agent's end prints every site's total.

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");
const engine = @import("engine");
const NodeBase = @import("node_base.zig").NodeBase;
const refcount = @import("refcount.zig");
const instance_bridge = @import("instance_bridge.zig");
const node_creation = @import("node_creation.zig");
const AgentHost = @import("html_core").agent_host.AgentHost;
const DeferredTeardown = runtime.gc.DeferredTeardown;

const log = std.log.scoped(.refcount_audit);

// process-wide: a diagnostic switch, set once by the WPT runner from CRANE_REFCOUNT_AUDIT before any page runs (and by a unit test around its body); off, the hooks read it and do nothing, so it changes no behaviour of any Browser
var audit_requested: bool = false;

/// Turn the audit on (the WPT runner's `CRANE_REFCOUNT_AUDIT=1`).
pub fn enable() void {
    audit_requested = true;
    log.warn("on: trees the counts call garbage are marked zombie at their teardown slice, and reads of them reported (CRANE_REFCOUNT_AUDIT)", .{});
}

/// Whether the audit is on.
pub inline fn on() bool {
    return audit_requested;
}

/// Tests: set the switch, returning what it was.
pub fn swapForTest(value: bool) bool {
    if (!builtin.is_test) @compileError("swapForTest is for tests");
    const previous = audit_requested;
    audit_requested = value;
    return previous;
}

/// How a zombie node was reached.
pub const Path = enum {
    /// `instance_bridge.getNodeBase`.
    get_node_base,
    /// The Node impl's internal state (getInternal / getInternalState).
    node_state,
    /// `node_document.set`: a node document set on it (adopt, creation).
    node_document,
    /// Linked into a tree, or a node linked under it.
    reinsertion,
    /// A counted reference taken on it.
    reference,
    /// A tree the counts called garbage was held again before its slice.
    resurrection,
};

/// The agent's books.
pub const Audit = struct {
    gpa: std.mem.Allocator,
    sites: std.AutoHashMapUnmanaged(u64, Site) = .empty,
    /// Trees marked zombie, and their nodes.
    zombie_trees: u64 = 0,
    zombie_nodes: u64 = 0,
    /// Reads of zombie nodes (every path but `resurrection`).
    accesses: u64 = 0,
    resurrections: u64 = 0,
    /// Stack captures taken (`capture_limit`).
    captured: usize = 0,
    /// Re-checks this agent's teardown queue holds (`noteLowered` queues
    /// them; their slice, or a realm's end, takes them out).
    queued: usize = 0,

    pub const Site = struct {
        path: Path,
        address: usize,
        hits: u64 = 0,
        /// The first hit's node name, for the summary.
        name: [32]u8 = undefined,
        name_len: u8 = 0,
    };

    /// Hits of one site printed with their stack, per agent.
    pub const printed_per_site = 3;

    pub fn init(gpa: std.mem.Allocator) Audit {
        return .{ .gpa = gpa };
    }

    /// The agent's end: every site's total, then the books go.
    pub fn deinit(self: *Audit) void {
        if (self.sites.count() > 0 or self.zombie_trees > 0) {
            log.warn("agent end: {d} zombie trees ({d} nodes), {d} zombie reads, {d} resurrections, {d} sites", .{ self.zombie_trees, self.zombie_nodes, self.accesses, self.resurrections, self.sites.count() });
            var it = self.sites.iterator();
            while (it.next()) |entry| {
                const site = entry.value_ptr;
                log.warn("  site {x:0>16}: {s} at 0x{x} (anchor 0x{x}) hits={d} first={s}", .{ entry.key_ptr.*, @tagName(site.path), site.address, auditAnchor(), site.hits, site.name[0..site.name_len] });
            }
        }
        self.sites.deinit(self.gpa);
    }

    /// One hit at (`path`, `address`) on `node`.
    /// Stack captures per agent: a site is the whole stack for the first
    /// hits (two reads through one helper are two sites), and the path and
    /// the reader's return address after them - a capture costs an unwind
    /// (and on aarch64-macos Zig 0.16 leaks ~830 B of unwinder state each:
    /// tools/gc_bench_options.zig).
    pub const capture_limit = 256;

    /// One hit at (`path`, `address`) on `node`.
    pub fn record(self: *Audit, path: Path, node: *NodeBase, address: usize) void {
        if (path == .resurrection) self.resurrections += 1 else self.accesses += 1;
        var buffer: [24]usize = undefined;
        var frames: []const usize = &.{};
        if (self.captured < capture_limit) {
            self.captured += 1;
            frames = std.debug.captureCurrentStackTrace(.{}, &buffer).return_addresses;
        }
        const key = siteKey(path, if (frames.len > 0) frames else &.{address});
        const slot = self.sites.getOrPut(self.gpa, key) catch return;
        if (!slot.found_existing) {
            slot.value_ptr.* = .{ .path = path, .address = address };
            const name = nameOf(node);
            const n = @min(name.len, slot.value_ptr.name.len);
            @memcpy(slot.value_ptr.name[0..n], name[0..n]);
            slot.value_ptr.name_len = @intCast(n);
        }
        slot.value_ptr.hits += 1;
        if (slot.value_ptr.hits > printed_per_site) return;
        printReport(key, path, node, frames);
    }
};

fn siteKey(path: Path, frames: []const usize) u64 {
    var hasher = std.hash.Wyhash.init(0x7263_375f_6175_6474);
    hasher.update(std.mem.asBytes(&path));
    hasher.update(std.mem.sliceAsBytes(frames));
    return hasher.final();
}

/// What a report calls `node`: an element's local name, else its node type's
/// name. Read through the creation hook, which borrows the element's own
/// names (no Node state read, so no report of its own).
fn nameOf(node: *NodeBase) []const u8 {
    if (node.node_type == NodeBase.ELEMENT_NODE) {
        if (instanceOf(node)) |instance| if (node_creation.elementNames(instance)) |names| return names.local_name;
        return "element";
    }
    return switch (node.node_type) {
        NodeBase.TEXT_NODE => "#text",
        NodeBase.COMMENT_NODE => "#comment",
        NodeBase.DOCUMENT_NODE => "#document",
        NodeBase.DOCUMENT_FRAGMENT_NODE => "#document-fragment",
        NodeBase.DOCUMENT_TYPE_NODE => "#doctype",
        NodeBase.ATTRIBUTE_NODE => "#attr",
        NodeBase.PROCESSING_INSTRUCTION_NODE => "#pi",
        NodeBase.CDATA_SECTION_NODE => "#cdata",
        else => "#node",
    };
}

/// The run-time address of this function: a report prints it beside its
/// stack, so an offline symbolizer recovers the image's load slide from the
/// function's link-time address (`nm wpt_runner | grep auditAnchor`; then
/// `atos -o wpt_runner -l <load>`), with no OS call here (lint-platform).
pub noinline fn auditAnchor() usize {
    return @intFromPtr(&auditAnchor);
}

/// One report line, its stack as raw return addresses: a capture, never a
/// DWARF load in the runner (symbolized offline against `auditAnchor`).
fn printReport(key: u64, path: Path, node: *NodeBase, frames: []const usize) void {
    var line: [24 * 19 + 1]u8 = undefined;
    var used: usize = 0;
    for (frames) |address| {
        const written = std.fmt.bufPrint(line[used..], " 0x{x}", .{address}) catch break;
        used += written.len;
    }
    log.warn("{s} {s} site={x:0>16} node={*} ({s}) anchor=0x{x} stack:{s}", .{
        if (path == .resurrection) "RESURRECTED" else "ZOMBIE",
        @tagName(path),
        key,
        node,
        nameOf(node),
        auditAnchor(),
        line[0..used],
    });
}

// ============================================================================
// The agent a node belongs to
// ============================================================================

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    const raw = node.owner_instance orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// The AgentHost of `instance`'s realm's agent (a ShadowRealm's: its
/// principal realm's), as dom.agent_fetches finds it; null for a realm with
/// no agent (an engine-less test's).
fn agentHostOf(instance: *runtime.Instance) ?*AgentHost {
    var current: ?runtime.Context = instance.ctx;
    while (current) |realm| : (current = realm.principal_realm) {
        const agent = realm.agent orelse continue;
        return @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    }
    return null;
}

// ============================================================================
// 1. The garbage moment
// ============================================================================

/// The counts lowered the total of the tree whose root is `root`: when that
/// leaves it garbage, flag it and queue its re-check on its agent's teardown
/// queue. `foreign_holds` is the root's document's foreign holds when `root`
/// is a Document (null: unknown, not garbage).
pub fn noteLowered(root: *NodeBase, foreign_holds: ?u32) void {
    if (!on()) return;
    if (root.rc_flags.audit_pending or root.rc_flags.zombie) return;
    if (!isGarbageRoot(root, foreign_holds)) return;
    const instance = instanceOf(root) orelse return;
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return;
    const host = agentHostOf(instance) orelse return;
    // A realm's end is not a slice: what it frees is the old model's, and
    // nothing of a re-check may outlive it (`realmTearingDown`).
    if (runtime.cleanup_coordinator.isContextTearingDown()) {
        dropQueued(host);
        return;
    }
    root.rc_flags.audit_pending = true;
    if (!host.deferred_teardown.push(.{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .owner = queueOwner(&host.refcount_audit),
        .steps = &audit_steps,
        .weight = 0,
    })) {
        root.rc_flags.audit_pending = false;
        return;
    }
    host.refcount_audit.queued += 1;
}

/// The owner the audit's re-checks are queued under: the agent's books.
fn queueOwner(audit: *Audit) *const anyopaque {
    return @ptrCast(audit);
}

/// A realm of `node`'s agent is tearing down (its nodes are being freed):
/// the audit's queued re-checks go, their roots unflagged. The realm's end
/// drains only the items its own wrapper cache queued (the old model's), and
/// the Browser's end requires an empty queue after it; a re-check of a tree
/// of another realm of the agent is lost with them - a diagnostic's gap,
/// never a report.
pub fn realmTearingDown(node: *NodeBase) void {
    if (!on()) return;
    const instance = instanceOf(node) orelse return;
    const host = agentHostOf(instance) orelse return;
    dropQueued(host);
}

fn dropQueued(host: *AgentHost) void {
    const audit = &host.refcount_audit;
    if (audit.queued == 0) return;
    const owner = queueOwner(audit);
    var at = host.deferred_teardown.head;
    while (at) |item| : (at = item.next) {
        if (item.owner != owner) continue;
        if (runtime.SlabAllocator.generationOf(item.instance) != item.generation) continue;
        if (instance_bridge.getNodeBaseUnaudited(item.instance)) |root| root.rc_flags.audit_pending = false;
    }
    host.deferred_teardown.dropOwner(owner);
    audit.queued = 0;
}

/// Whether `root` is the root of a tree the counts call garbage: parentless,
/// unhosted, no hold anywhere in it, not being torn down - and, a Document,
/// no held detached node of it (decision D6).
fn isGarbageRoot(root: *const NodeBase, foreign_holds: ?u32) bool {
    if (root.parent_node != null or root.rc_flags.hosted or root.subtree_holds != 0) return false;
    if (root.rc_flags.destroying) return false;
    if (root.node_type == NodeBase.DOCUMENT_NODE) {
        const foreign = foreign_holds orelse return false;
        if (foreign != 0) return false;
    }
    return true;
}

/// A tree the counts called garbage was held again (a reference reached its
/// root, or the root was linked) before its slice.
pub fn noteResurrected(root: *NodeBase) void {
    if (!root.rc_flags.audit_pending) return;
    root.rc_flags.audit_pending = false;
    const instance = instanceOf(root) orelse return;
    const host = agentHostOf(instance) orelse return;
    host.refcount_audit.record(.resurrection, root, @returnAddress());
}

// ============================================================================
// 2. The slice
// ============================================================================

const audit_steps: DeferredTeardown.Steps = .{ .run = runAudit };

fn runAudit(item: *DeferredTeardown.Item, budget: usize) DeferredTeardown.Progress {
    _ = budget;
    const done: DeferredTeardown.Progress = .{ .freed = 0, .done = true };
    const books: *Audit = @ptrCast(@alignCast(@constCast(item.owner.?)));
    books.queued -|= 1;
    // The old model freed it (or reissued its slot), or is freeing it.
    if (runtime.SlabAllocator.generationOf(item.instance) != item.generation) return done;
    if (runtime.instance_lifecycle.isCleanupStarted(item.instance)) return done;
    const root = instance_bridge.getNodeBaseUnaudited(item.instance) orelse return done;
    if (!root.rc_flags.audit_pending) return done;
    root.rc_flags.audit_pending = false;
    const foreign = if (root.node_type == NodeBase.DOCUMENT_NODE) refcount.documentForeignHolds(root) else null;
    if (!isGarbageRoot(root, foreign)) return done;
    const host = agentHostOf(item.instance) orelse return done;
    host.refcount_audit.zombie_trees += 1;
    host.refcount_audit.zombie_nodes += markTree(root);
    return done;
}

/// Marks every node of `tree_root`'s host-including tree zombie: an
/// iterative walk of the tree, recursive only into hosted roots (they nest as
/// shallowly as shadow trees and templates do). Returns the nodes marked.
fn markTree(tree_root: *NodeBase) u64 {
    var marked: u64 = 0;
    var node: *NodeBase = tree_root;
    while (true) {
        node.rc_flags.zombie = true;
        marked += 1;
        var hosted: [2]?*NodeBase = undefined;
        for (refcount.hostedRoots(node, &hosted)) |maybe| if (maybe) |hosted_root| {
            marked += markTree(hosted_root);
        };
        node = nextInTree(tree_root, node) orelse return marked;
    }
}

const nextInTree = refcount.nextInTree;

// ============================================================================
// 3. Reports
// ============================================================================

/// A read of `node` through `path`: reported when `node` is a zombie and the
/// read is not the old model's own teardown. `address` is the reader's
/// return address (the site key).
pub inline fn checkRead(node: *NodeBase, path: Path, address: usize) void {
    if (!on()) return;
    if (!node.rc_flags.zombie) return;
    reportRead(node, path, address);
}

fn reportRead(node: *NodeBase, path: Path, address: usize) void {
    const instance = instanceOf(node) orelse return;
    // The old model's teardown of this node, of its realm, or the agent's
    // teardown slice (the old model's frees, and this audit's marking).
    if (runtime.instance_lifecycle.isCleanupStarted(instance)) return;
    if (runtime.cleanup_coordinator.isContextTearingDown()) return;
    const host = agentHostOf(instance) orelse return;
    if (host.deferred_teardown.slicing) return;
    host.refcount_audit.record(path, node, address);
}

/// The books of `node`'s agent (tests).
pub fn auditOf(node: *NodeBase) ?*Audit {
    const instance = instanceOf(node) orelse return null;
    const host = agentHostOf(instance) orelse return null;
    return &host.refcount_audit;
}
