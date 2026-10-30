//! HTML 7.4.6.1 "apply the history step", run as items of a traversable's
//! session history traversal queue (traversal_queue.zig): the traversals of
//! "traverse the history by a delta" and the navigation API, "apply the
//! reload history step", "update for navigable creation/destruction", and
//! "finalize a cross-document navigation" with the "apply the push/replace
//! history step" it ends with (lane nav2 F1: `.push_replace`, whose one
//! changing navigable's step-12 job is the rest of its commit - the entry
//! listed, then the displayed document unloaded and the new one made active,
//! dom.navigables.commitNavigation).
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#apply-the-history-step
//!
//! One item is one apply, run from the queue's service task on the
//! traversable's loop, in phases:
//!
//! 1. `run` (steps 2-12): the target step; the initiator check; checking if
//!    unloading is canceled (the traversable's beforeunload and traverse
//!    navigate event, then the other documents' beforeunload); the changing
//!    and the non-changing navigables; step 8 for each changing one - its
//!    current session history entry is its target (JointHistory.beginApply,
//!    setCurrentEntry), and one whose target is not its active document has
//!    its ongoing navigation set to "traversal"; every view held
//!    (JointHistory.holdAllViews); then step 12: a task per changing
//!    navigable on its active window's loop, each waited for.
//! 2. Each step-12 task: the traverse navigate event (12.7), then a
//!    same-document change queues its afterPotentialUnloads task (14.10.2),
//!    which runs "update document for history step application"; a
//!    cross-document change populates its target entry's document
//!    (dom.navigables.traverseNavigable), whose navigation reports its end -
//!    the new document made active (the change job's end, 14.12.6), failed,
//!    aborted, superseded or its navigable gone.
//! 3. `proceed` once every change job has ended (steps 15-19): a task per
//!    non-changing navigable whose History length or index changes, each
//!    writing its view, each waited for.
//! 4. `proceed` again (step 20): the current session history step.
//!
//! Every task carries the traversable's ID, the item's token and its
//! navigable's ID, never a pointer: a task whose item ended, or whose
//! navigable went, finds nothing and ends its wait; a dropped task ends it
//! too, so the queue always reaches its next item (integrator's condition
//! 2).
//!
//! Engine-free: what needs a window, a realm or a document comes from
//! History through dom.history_traversal (H-NAV2-HT-APPLY); the navigation
//! API and the navigation machinery through their own hooks.
//!
//! Stated deviations:
//! - Step 5 fires beforeunload at each crossing navigable's active document
//!   and its descendants', parents first, as browsers do for a navigation
//!   away (lane nav2 C1); the spec names the crossing navigables' documents
//!   only.
//! - Step 8.3.2-3 (the ongoing navigate event and API method tracker set to
//!   null, so a successful cross-document traversal fires no navigateerror)
//!   is not modelled: with 8.4 no navigation of the navigable can abort them
//!   before it unloads, and their promises never settle in the spec either
//!   (integrator, 2026-10-28).
//! - Step 14.1: while a traversal waits for its change jobs, the
//!   synchronous navigation steps ("finalize a same-document navigation",
//!   `FinalizeItem`) whose target navigable is not in its must-wait set
//!   (`mustWait`) run nested, from the queue's service task
//!   (TraversalQueue.jumpAhead). Only a traversal lets them: the step 20 of
//!   a reload, an update for navigable creation/destruction or a finalize's
//!   own push/replace step would set the current step back under a jumped
//!   push (whatwg/html#10232, #12961). A cross-document navigation's
//!   finalize is an apply of its own (.push_replace, lane nav2 F1), which
//!   waits; only the commits still made inline (an embedder's load, a
//!   javascript: URL's result) settle a running apply
//!   (JointHistory.settleApply).
//! - "Apply the push/replace history step" runs inline in the finalize
//!   (JointHistory.finalizeSameDocument says why).
//! - A traversal whose target step is forward of the current one, appended
//!   before a synchronous push that is still pending, does nothing
//!   (`start`, golden rule 2, whatwg/html#12961).
//! - Step 18 queues a task only for a navigable whose History length or
//!   index changes; one that would be written the values it has is not
//!   (unobservable).
//! - Consecutive queued "update for navigable creation/destruction" items
//!   are one: each applies the current step, so a second one right behind
//!   the first changes nothing (unobservable; a document's n frames go in
//!   one item, not n).

const std = @import("std");
const Allocator = std.mem.Allocator;
const joint_history = @import("joint_history.zig");
const JointHistory = joint_history.JointHistory;
const traversal_queue = @import("traversal_queue.zig");
const TraversalQueue = traversal_queue.TraversalQueue;
const Item = traversal_queue.Item;
const Outcome = traversal_queue.Outcome;
const sandbox_navigation = @import("sandbox_navigation.zig");
const browsing_context = @import("../window/browsing_context.zig");
const BrowsingContext = browsing_context.BrowsingContext;
const Navigables = browsing_context.Navigables;
const dom = @import("dom");
const history_traversal = dom.history_traversal;

/// Where a traversal goes: `delta` used steps away from the current one
/// ("traverse the history by a delta"), or to a given step (the navigation
/// API's traversals).
pub const Target = union(enum) {
    delta: i32,
    step: u32,
};

/// The navigable whose document asked for a traversal - by id: it can go
/// before the traversal runs - and that document's source snapshot params
/// (step 3's initiatorToCheck and sourceSnapshotParams).
pub const Initiator = struct {
    navigable: u64,
    snapshot: sandbox_navigation.SourceSnapshot,
};

/// Which entry point appended the apply.
pub const Kind = enum {
    /// "Apply the traverse history step" (or its resumption).
    traverse,
    /// "Apply the reload history step".
    reload,
    /// "Update for navigable creation/destruction".
    update,
    /// "Finalize a cross-document navigation" and the "apply the push/replace
    /// history step" it ends with (lane nav2 F1): one changing navigable,
    /// whose step-12 job is the rest of its navigation's commit
    /// (dom.navigables.commitNavigation).
    push_replace,
};

/// One navigable whose current session history entry changes (step 6), by
/// id: script runs between its steps and can take it away.
const Change = struct {
    navigable: u64,
    /// The URL of the entry it displays (12.1's displayedEntry), owned: a
    /// same-document change's hashchange compares it.
    old_url: []u8,
    /// Its current entry before the apply (12.1's previousEntry).
    from_entry: u64,
    target_entry: u64,
    /// The target entry's document is the active one (and no reload is
    /// pending): updated in place, without unloading.
    same_document: bool,
    /// The target entry's origin is the displayed one's (12.6-12.7).
    same_origin: bool,
    /// Its continuation was dequeued (14.8): it is in
    /// navigablesThatMustWaitBeforeHandlingSyncNavigation.
    continued: bool = false,
};

/// An apply on the traversable's queue (see the file comment).
pub const ApplyItem = struct {
    item: Item,
    /// The traversable's Browser's list, which outlives every task of its
    /// loop: the traversable is looked up by id on it.
    navigables: *Navigables,
    top_id: u64,
    allocator: Allocator,
    kind: Kind,
    /// `.traverse`: where to.
    target: Target = .{ .step = 0 },
    /// "Resume applying the traverse history step": the traversable's
    /// navigate event was fired and intercepted; checkForCancelation is
    /// false.
    resumed: bool = false,
    initiator: ?Initiator = null,
    /// A delta traversal ("traverse the history by a delta") whose target
    /// step, when it was appended, took some navigable to another document:
    /// a pending traversal for the delta rules (`pendingCrossDocumentDelta`).
    cross_document_delta: bool = false,
    /// A delta traversal: the navigable whose History asked for it.
    delta_navigable: u64 = 0,
    /// `.reload`: the navigable whose entry's reload is pending, the entry
    /// it reloads, and the navigation API state it is given (owned; null
    /// keeps the entry's).
    reload_navigable: u64 = 0,
    reload_entry: u64 = 0,
    reload_api_state: ?joint_history.SerializedState = null,
    /// `.reload` made by history.go(0) (the reload rules in History).
    go_zero: bool = false,
    /// A navigation API traversal ("perform a navigation API traversal" step
    /// 12): its key's checks, which run first (12.1-12.3), and the navigable
    /// whose navigation API asked. Owned until rejected or dropped.
    api: ?history_traversal.ApiTraversal = null,
    api_navigable: u64 = 0,
    /// `.push_replace`: the navigable and its cross-document navigation's id,
    /// and whether its step-12 job handed it the commit.
    commit_navigable: u64 = 0,
    commit_id: u64 = 0,
    commit_ran: bool = false,

    // What the run decided, for the later phases.
    phase: enum { start, changes, nonchanging } = .start,
    target_step: u32 = 0,
    changes: std.ArrayListUnmanaged(Change) = .empty,
    nonchanging: std.ArrayListUnmanaged(u64) = .empty,

    fn make(top: *BrowsingContext, allocator: Allocator, kind: Kind) ?*ApplyItem {
        const navigables = top.navigables orelse return null;
        const self = allocator.create(ApplyItem) catch return null;
        self.* = .{
            .item = .{
                .run = &run,
                .destroy = &destroy,
                .proceed = &proceed,
                // Step 14.1: only a traversal lets synchronous navigation
                // steps jump it (see the file comment).
                .accepts_sync = if (kind == .traverse) &acceptsSync else null,
            },
            .navigables = navigables,
            .top_id = top.id,
            .allocator = allocator,
            .kind = kind,
        };
        return self;
    }

    /// Step 14.1's condition for synchronous navigation steps targeting
    /// `target`: the apply waits for its change jobs, and `target` is not in
    /// navigablesThatMustWaitBeforeHandlingSyncNavigation.
    fn acceptsSync(item: *Item, target: u64) bool {
        const self: *ApplyItem = @fieldParentPtr("item", item);
        return self.phase == .changes and !self.mustWait(target);
    }

    /// Whether `navigable` is in navigablesThatMustWaitBeforeHandlingSyncNavigation:
    /// a changing navigable whose continuation was dequeued (14.8) - in
    /// Crane, a same-document change whose step-12 task ran, or a change
    /// whose job ended (a cross-document one's document was made active
    /// with its continuation).
    fn mustWait(self: *const ApplyItem, navigable: u64) bool {
        for (self.changes.items) |c| {
            if (c.navigable != navigable) continue;
            if (c.continued) return true;
            return std.mem.indexOfScalar(u64, self.item.waiting_on.items, navigable) == null;
        }
        return false;
    }

    fn run(item: *Item) Outcome {
        const self: *ApplyItem = @fieldParentPtr("item", item);
        return self.start() catch .done;
    }

    fn proceed(item: *Item) Outcome {
        const self: *ApplyItem = @fieldParentPtr("item", item);
        return switch (self.phase) {
            .start => .done,
            .changes => self.nonchangingJobs() catch self.finish(),
            .nonchanging => self.finish(),
        };
    }

    fn destroy(item: *Item) void {
        const self: *ApplyItem = @fieldParentPtr("item", item);
        // However it ended - finished, completed early by the delta rules,
        // out of memory, or its traversable ending - an apply that began
        // has its step 20 (the step what its documents were shown).
        if (self.navigables.byId(self.top_id)) |top| {
            if (top.joint_history) |history| history.endApply(item.token);
        }
        if (self.api) |api| api.drop(api.context);
        // A .push_replace apply that ends before its job ran - unrun when
        // its traversable ended, its job not queued or dropped - ends its
        // navigation, which otherwise waits for it (liveness, condition 2).
        // Not for a navigable being destroyed: its navigations end with it.
        if (self.kind == .push_replace and !self.commit_ran) {
            if (self.navigables.byId(self.commit_navigable)) |bc| {
                if (!bc.orphaned and !bc.is_closed and bc.active_document != null) _ = dom.navigables.commitNavigation(@ptrCast(bc), self.commit_id, null);
            }
        }
        for (self.changes.items) |c| self.allocator.free(c.old_url);
        self.changes.deinit(self.allocator);
        self.nonchanging.deinit(self.allocator);
        if (self.reload_api_state) |*state| state.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn token(self: *const ApplyItem) u64 {
        return self.item.token;
    }

    /// Steps 2-12.
    fn start(self: *ApplyItem) !Outcome {
        if (self.kind == .push_replace) return self.startPushReplace();
        const navigables = self.navigables;
        const allocator = self.allocator;
        const top = navigables.byId(self.top_id) orelse return .done;
        var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer tree.deinit(allocator);
        try top.collectDescendants(allocator, &tree);
        const history = try top.jointHistory();
        for (tree.items) |bc| _ = ensureEntries(bc) catch {};

        // "Perform a navigation API traversal" 12.1-12.3, in the queued steps
        // before they apply: "Let targetSHE be the session history entry in
        // navigableSHEs whose navigation API key is key. If no such entry
        // exists ... reject the finished promise ... with an
        // "InvalidStateError" DOMException. Abort these steps." "If targetSHE
        // is navigable's active session history entry" - a traversal queued
        // before took it there - the same. Step 4 applies targetSHE's step:
        // the nearest one that shows it (JointHistory.nearestStepOf, as
        // browsers do), asked now that the traversals queued before have run.
        if (self.api) |api| {
            const target_she = history.entryByKey(self.api_navigable, &api.key);
            const active = history.activeEntry(self.api_navigable);
            if (target_she == null or target_she == active) {
                self.api = null;
                api.reject(api.context);
                return .done;
            }
            self.target = .{ .step = history.nearestStepOf(target_she.?) };
            self.api = null;
            api.drop(api.context);
        }

        // Step 2: "Let targetStep be the result of getting the used step
        // given traversable and step" - for a traversal its target ("traverse
        // the history by a delta" 4.2-4.4 asks the delta's used step as its
        // queued steps run), for a reload or an update the current step.
        const step: u32 = switch (self.kind) {
            .traverse => switch (self.target) {
                .delta => |delta| history.stepByDelta(delta) orelse return .done,
                .step => |s| s,
            },
            .reload, .update => history.current_step,
            // `startPushReplace` took it above.
            .push_replace => return .done,
        };
        const target = history.usedStepAtOrBefore(step) orelse return .done;
        self.target_step = target;
        // Deviation, stated (golden rule 2): a traversal forward of the
        // current step that was appended before a synchronous push still
        // pending does nothing. That push's finalize jumps it (14.1) and
        // clears the forward history - its target - and the spec activates
        // the pruned target anyway (whatwg/html#12961, open: no engine keeps
        // a pre-resolved target; Blink discards a pruned pending entry).
        // wpt.fyi (WPT 07ce6e987a, Chrome 156 / Firefox 159 / Safari 27):
        // html/browsers/browsing-the-web/overlapping-navigations-and-
        // traversals/forward-to-pruned-entry PASS/PASS/PASS - no popstate;
        // navigation-api/navigation-methods/forward-to-pruned-entry
        // PASS/FAIL/PASS - the traversal aborts before its navigate event
        // fires (Firefox rejects with InvalidStateError, not AbortError).
        if (self.kind == .traverse and target > history.current_step and history.hasPendingPush()) return .done;

        // The navigable a reload reloads: its entry's reload is pending.
        const reloading: ?*BrowsingContext = if (self.kind == .reload) blk: {
            const bc = navigables.byId(self.reload_navigable) orelse return .done;
            if (bc.orphaned or bc.is_closed or bc.getTop() != top) return .done;
            break :blk bc;
        } else null;

        // Step 3: "If initiatorToCheck is not null ... for each navigable of
        // get all navigables whose current session history entry will change
        // or reload: if initiatorToCheck is not allowed by sandboxing to
        // navigate navigable given sourceSnapshotParams, then return
        // "initiator-disallowed"." An initiator gone since it asked is
        // allowed nothing.
        if (self.initiator) |initiator| {
            const source = navigables.byId(initiator.navigable) orelse return .done;
            for (tree.items) |bc| {
                const current = history.listedCurrentEntry(bc.id) orelse continue;
                const target_entry = history.entryAt(bc.id, target) orelse continue;
                if (current == target_entry) continue;
                if (!sandbox_navigation.allowedBySandboxingToNavigate(source, bc, initiator.snapshot)) return .done;
            }
        }

        // Steps 4, 6 and 7, in one walk from the traversable, parents first:
        // the navigables that change (6), those under a navigable whose
        // document changes - which go with it, and are not looked at (4's
        // note) - and the navigables that only need their History length
        // and index (7): those whose entry stays, under ones whose entry
        // stays.
        var skipped: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer skipped.deinit(allocator);
        var crossing: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer crossing.deinit(allocator);
        var changed: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer changed.deinit(allocator);
        for (tree.items) |bc| {
            if (bc.parent) |parent| {
                if (std.mem.indexOfScalar(*BrowsingContext, skipped.items, parent) != null) {
                    try skipped.append(allocator, bc);
                    continue;
                }
            }
            const current = history.listedCurrentEntry(bc.id) orelse continue;
            const target_entry = history.entryAt(bc.id, target) orelse continue;
            const reload_pending = reloading == bc;
            if (current == target_entry and !reload_pending) {
                // Step 7, "getting all navigables that only need history
                // object length/index update": its parent's entry stays too.
                const parent_stays = if (bc.parent) |parent| std.mem.indexOfScalar(*BrowsingContext, changed.items, parent) == null else true;
                if (parent_stays) try self.nonchanging.append(allocator, bc.id);
                continue;
            }
            const same_document = !reload_pending and current.document_state == target_entry.document_state and
                target_entry.document != null and target_entry.document == bc.getActiveDocument();
            const displayed = history.activeEntry(bc.id) orelse current;
            const old_url = try allocator.dupe(u8, displayed.url);
            self.changes.append(allocator, .{
                .navigable = bc.id,
                .old_url = old_url,
                .from_entry = current.id,
                .target_entry = target_entry.id,
                .same_document = same_document,
                .same_origin = std.mem.eql(u8, displayed.origin, target_entry.origin),
            }) catch |err| {
                allocator.free(old_url);
                return err;
            };
            try changed.append(allocator, bc);
            if (!same_document) {
                // Step 4: it might experience a cross-document traversal; its
                // descendants are unloaded with its document, not traversed.
                try crossing.append(allocator, bc);
                try skipped.append(allocator, bc);
            }
        }

        // Step 5: "If checkForCancelation is true, and the result of checking
        // if unloading is canceled given navigablesCrossingDocuments,
        // traversable, targetStep, and userInvolvement is not "continue",
        // then return that result." An update does not check; neither does
        // a resumed traversal (its navigate event was fired and intercepted).
        if (self.kind != .update and !self.resumed) {
            if (try self.unloadingCanceled(top, history, target, crossing.items, skipped.items)) return .done;
            // The handlers ran script: the traversable - and its history -
            // may be gone.
            if (navigables.byId(self.top_id) != top) return .done;
        }

        // Step 8 for each changing navigable: "Set navigable's current
        // session history entry to targetEntry" - and the documents read
        // given targetStep from here on (JointHistory.Apply). Each changing
        // navigable's document keeps reading the history it saw until its
        // "update document for history step application", every other one
        // until its step 18: all views are held.
        history.beginApply(self.token(), target);
        for (self.changes.items) |c| history.setCurrentEntry(c.navigable, c.target_entry);
        history.holdAllViews();
        // Step 8.3: "If targetEntry's document is not navigable's active
        // document, then queue a global task ... Set navigable's ongoing
        // navigation to "traversal"" - for every such navigable before any
        // step-12 task runs (integrator, 2026-10-28: a navigate handler of
        // an earlier navigable that navigates a later one is ignored, navigate
        // step 18). Set here, in the apply, which the spec runs on the
        // traversal queue; a reload's target document is its active one. Not
        // modelled, stated in the file comment: 8.3.2-3.
        for (self.changes.items) |c| {
            if (c.same_document or self.kind == .reload) continue;
            const bc = navigables.byId(c.navigable) orelse continue;
            const integration = dom.navigables.integrationOf(@ptrCast(bc)) orelse continue;
            integration.beginTraversal();
        }

        // Steps 9-12: a task per changing navigable, on its active window's
        // loop, each one's end waited for (14) - the wait recorded before
        // its task is queued. (Out of memory, a wait not recorded is not
        // waited for; its task still runs.)
        self.phase = .changes;
        var waiting = false;
        for (self.changes.items) |c| {
            const recorded = TraversalQueue.waitFor(navigables, self.top_id, self.token(), c.navigable);
            if (recorded) waiting = true;
            const queued = if (navigables.byId(c.navigable)) |bc| JobTask.queue(self, bc, .change) else false;
            if (!queued) {
                clearTraversal(navigables, c.navigable);
                if (recorded) TraversalQueue.populationEnded(navigables, self.top_id, self.token(), c.navigable);
            }
        }
        if (waiting) return .pending;
        return self.nonchangingJobs() catch self.finish();
    }

    /// "Finalize a cross-document navigation" and its push/replace step's
    /// steps 2-12, as far as they run before the navigable's step-12 job
    /// (lane nav2 F1). The entry is listed - steps 5-9 - and the apply begun
    /// (step 8: `beginPushReplace`) by that job, from the commit, right
    /// before the navigable's active document unloads: so a navigation that
    /// cannot go on lists nothing. Not here:
    /// - step 5: "apply the push/replace history step" passes
    ///   checkForCancelation false (beforeunload ran in "navigate");
    /// - step 8.3-8.4: its target is no traversal;
    /// - 14.1: only a traversal lets synchronous navigation steps jump it
    ///   (`make`), so a same-document navigation's finalize appended after
    ///   this one waits for it.
    /// Step 7: the non-changing navigables, those not under the navigable,
    /// whose views step 18 writes.
    fn startPushReplace(self: *ApplyItem) !Outcome {
        const navigables = self.navigables;
        const allocator = self.allocator;
        const top = navigables.byId(self.top_id) orelse return .done;
        const bc = navigables.byId(self.commit_navigable) orelse return .done;
        if (bc.orphaned or bc.is_closed or bc.getTop() != top) return .done;
        var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer tree.deinit(allocator);
        try top.collectDescendants(allocator, &tree);
        for (tree.items) |other| {
            if (isSelfOrUnder(other, bc)) continue;
            try self.nonchanging.append(allocator, other.id);
        }
        const old_url = try allocator.dupe(u8, "");
        self.changes.append(allocator, .{
            .navigable = bc.id,
            .old_url = old_url,
            .from_entry = 0,
            .target_entry = 0,
            .same_document = false,
            .same_origin = false,
        }) catch |err| {
            allocator.free(old_url);
            return err;
        };
        self.phase = .changes;
        const recorded = TraversalQueue.waitFor(navigables, self.top_id, self.token(), bc.id);
        if (!JobTask.queue(self, bc, .change)) {
            if (recorded) TraversalQueue.populationEnded(navigables, self.top_id, self.token(), bc.id);
            return .done;
        }
        return if (recorded) .pending else .done;
    }

    /// Step 5, "checking if unloading is canceled", for a traversal or a
    /// reload: whether it was.
    fn unloadingCanceled(self: *ApplyItem, top: *BrowsingContext, history: *JointHistory, target: u32, crossing: []const *BrowsingContext, skipped: []const *BrowsingContext) !bool {
        const allocator = self.allocator;
        var before: []const *BrowsingContext = skipped;
        // Step 4: the traversable's own navigate event, when its entry
        // changes within its origin - with its beforeunload first, when it
        // crosses documents ("because we want beforeunload events to fire
        // before navigate events").
        if (self.kind == .traverse) {
            const current = history.listedCurrentEntry(top.id);
            const target_entry = history.entryAt(top.id, target);
            if (current != null and target_entry != null and current.? != target_entry.? and
                std.mem.eql(u8, current.?.origin, target_entry.?.origin))
            {
                if (crossing.len > 0 and crossing[0] == top) {
                    if (history_traversal.beforeUnloadCanceled(&.{top}, allocator)) return true;
                    // The traversable's document had its beforeunload: the
                    // rest have theirs below.
                    before = skipped[1..];
                    if (self.navigables.byId(self.top_id) != top) return true;
                }
                if (top.getActiveWindow()) |w| {
                    const window = @as(*anyopaque, w);
                    if (!dom.navigation_api.fireTraverse(@ptrCast(@alignCast(window)), target_entry.?.id, .none)) return true;
                }
                if (self.navigables.byId(self.top_id) != top) return true;
            }
        }
        // Steps 5-8: beforeunload at the other crossing documents, and
        // their descendants', parents first.
        if (history_traversal.beforeUnloadCanceled(before, allocator)) return true;
        // A reload's navigation API state is the entry's once navigate and
        // beforeunload permit it.
        if (self.kind == .reload) {
            if (self.reload_api_state) |state| {
                if (self.navigables.byId(self.top_id) != top) return true;
                history.setEntryApiState(self.reload_entry, state);
                self.reload_api_state = null;
            }
        }
        return false;
    }

    /// Steps 15-19: when every change job has ended, a task per navigable
    /// that only needs its History length and index, each waited for.
    /// Returns `.done` through `finish` when there is none to wait for.
    fn nonchangingJobs(self: *ApplyItem) !Outcome {
        const navigables = self.navigables;
        self.phase = .nonchanging;
        const top = navigables.byId(self.top_id) orelse return .done;
        const history = top.joint_history orelse return .done;
        // A commit settled the apply (JointHistory.settleApply): the views
        // were released then.
        if (!history.isApplying(self.token())) return self.finish();
        // Step 17: "Let (scriptHistoryLength, scriptHistoryIndex) be the
        // result of getting the history object length and index given
        // traversable and targetStep."
        const script = history.lengthAndIndex();
        var waiting = false;
        for (self.nonchanging.items) |id| {
            const bc = navigables.byId(id) orelse continue;
            if (!history.isViewHeld(id)) continue;
            // Stated (file comment): one that would be written the length
            // and index it has needs no task.
            const has = history.historyView(id);
            if (has.length == script.length and has.index == script.index) {
                history.releaseView(id);
                continue;
            }
            if (!TraversalQueue.waitFor(navigables, self.top_id, self.token(), id)) {
                history.releaseView(id);
                continue;
            }
            waiting = true;
            if (!JobTask.queue(self, bc, .nonchanging)) TraversalQueue.populationEnded(navigables, self.top_id, self.token(), id);
        }
        if (waiting) return .pending;
        return self.finish();
    }

    /// Step 20: "Set traversable's current session history step to
    /// targetStep." (Done by `destroy`, which every way out reaches.)
    fn finish(self: *ApplyItem) Outcome {
        _ = self;
        return .done;
    }

    /// Whether a change job of a cross-document change is still waited for
    /// (step 14): its target document is not active yet.
    fn awaitsCrossDocumentChange(self: *const ApplyItem) bool {
        if (self.phase != .changes) return false;
        for (self.changes.items) |c| {
            if (c.same_document) continue;
            if (std.mem.indexOfScalar(u64, self.item.waiting_on.items, c.navigable) != null) return true;
        }
        return false;
    }

    /// The change of `navigable`, if this apply changes it.
    fn changeOf(self: *ApplyItem, navigable: u64) ?*Change {
        for (self.changes.items) |*c| {
            if (c.navigable == navigable) return c;
        }
        return null;
    }
};

/// A task of an apply for one navigable: its step-12 task, its
/// afterPotentialUnloads task (14.10.2), or its step-18 task. By ids only.
const JobTask = struct {
    navigables: *Navigables,
    top_id: u64,
    token: u64,
    navigable: u64,
    kind: enum { change, update, nonchanging },
    allocator: Allocator,

    /// Queue `kind`'s task for `bc` (its active window's loop). False when
    /// it could not be queued: the caller ends the wait.
    fn queue(owner: *ApplyItem, bc: *BrowsingContext, kind: @FieldType(JobTask, "kind")) bool {
        const allocator = owner.navigables.allocator;
        const self = allocator.create(JobTask) catch return false;
        self.* = .{
            .navigables = owner.navigables,
            .top_id = owner.top_id,
            .token = owner.token(),
            .navigable = bc.id,
            .kind = kind,
            .allocator = allocator,
        };
        if (history_traversal.queueTask(owner.navigables, bc, .{ .callback = &JobTask.run, .context = self, .drop = &JobTask.drop })) return true;
        allocator.destroy(self);
        return false;
    }

    /// The task's job is over: the apply stops waiting for it.
    fn ended(self: *const JobTask) void {
        TraversalQueue.populationEnded(self.navigables, self.top_id, self.token, self.navigable);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *JobTask = @ptrCast(@alignCast(context orelse return));
        defer self.allocator.destroy(self);
        if (self.kind == .change) clearTraversal(self.navigables, self.navigable);
        self.ended();
    }

    fn run(context: ?*anyopaque) void {
        const self: *JobTask = @ptrCast(@alignCast(context orelse return));
        defer self.allocator.destroy(self);
        // Ended here unless the job went on: a queued update task, or a
        // population that will report its end.
        if (self.steps()) return;
        if (self.kind == .change) clearTraversal(self.navigables, self.navigable);
        self.ended();
    }

    /// The apply this task is for, if it is still the running one.
    fn apply(self: *const JobTask) ?*ApplyItem {
        const top = self.navigables.byId(self.top_id) orelse return null;
        const traversals = top.traversal_queue orelse return null;
        const running = traversals.running orelse return null;
        if (running.token != self.token or running.run != &ApplyItem.run) return null;
        return @fieldParentPtr("item", running);
    }

    /// The task's steps: true when its job goes on past this task.
    fn steps(self: *JobTask) bool {
        const item = self.apply() orelse return false;
        const navigable = self.navigables.byId(self.navigable) orelse return false;
        if (navigable.orphaned or navigable.is_closed) return false;
        const top = self.navigables.byId(self.top_id) orelse return false;
        const history = top.joint_history orelse return false;
        switch (self.kind) {
            .nonchanging => {
                // Step 18: "Set document's history object's index to
                // scriptHistoryIndex ... length to scriptHistoryLength."
                history.releaseView(self.navigable);
                return false;
            },
            .update => {
                // 14.10.2, afterPotentialUnloads for a same-document change:
                // "activate history entry", then "update document for
                // history step application". Its handlers can end the apply:
                // what it reads is copied.
                const c = item.changeOf(self.navigable) orelse return false;
                const entry_id = c.target_entry;
                if (history.entryById(entry_id) == null) return false;
                const old_url = self.allocator.dupe(u8, c.old_url) catch return false;
                defer self.allocator.free(old_url);
                // 14.12.2 "activate history entry": the navigable's pending
                // same-document entries - made since this traversal's
                // continuation for it was dequeued - are no longer active,
                // and their finalize steps do nothing (JointHistory
                // .finalizeSameDocument, step 2's case).
                history.dropPending(self.navigable);
                const entry = history.entryById(entry_id) orelse return false;
                history_traversal.updateSameDocument(navigable, old_url, entry);
                return false;
            },
            .change => return self.changeSteps(item, navigable, history),
        }
    }

    /// Step 12 for one changing navigable.
    fn changeSteps(self: *JobTask, item: *ApplyItem, navigable: *BrowsingContext, history: *JointHistory) bool {
        const c = item.changeOf(self.navigable) orelse return false;
        // "Apply the push/replace history step" (lane nav2 F1): the rest of
        // the navigation's commit, whose new document's activation ends the
        // job (14.12.6).
        if (item.kind == .push_replace) {
            item.commit_ran = true;
            return dom.navigables.commitNavigation(@ptrCast(navigable), item.commit_id, .{ .traversable_id = self.top_id, .token = self.token });
        }
        const top_id = self.top_id;
        const navigables = self.navigables;
        // 12.7: "If navigationType is "traverse", navigable is not
        // traversable, targetEntry is not displayedEntry, and oldOrigin is the
        // same as displayedEntry's document state's origin: fire a traverse
        // navigate event" (not cancelable).
        if (item.kind == .traverse and navigable.parent != null and c.same_origin and c.target_entry != c.from_entry) {
            if (navigable.getActiveWindow()) |w| {
                const window = @as(*anyopaque, w);
                _ = dom.navigation_api.fireTraverse(@ptrCast(@alignCast(window)), c.target_entry, .none);
            }
            // The listeners ran script: the apply, the traversable, the
            // navigable may be gone (a destroyed one's wait ended with it).
            if (self.apply() != item) return false;
            if (navigables.byId(self.navigable) != navigable or navigable.orphaned or navigable.is_closed) return false;
        }
        const entry = history.entryById(c.target_entry) orelse return false;
        if (c.same_document) {
            // 14.2-14.8: its continuation is dequeued - the navigable joins
            // navigablesThatMustWaitBeforeHandlingSyncNavigation - and 12.1's
            // displayedEntry is the one its document shows now: a
            // synchronous navigation that jumped this apply (14.1) moved it
            // (its URL is the hashchange's oldURL).
            c.continued = true;
            if (history.displayedEntry(navigable.id)) |displayed| {
                if (displayed.id != c.target_entry) {
                    // The apply's allocator: it frees the changes' URLs.
                    if (item.allocator.dupe(u8, displayed.url)) |url| {
                        item.allocator.free(c.old_url);
                        c.old_url = url;
                    } else |_| {}
                }
            }
            // 14.10.1: "Set navigable's ongoing navigation to null" - for a
            // traversal; it ends a navigation of the navigable in flight
            // (overlapping-navigations-and-traversals/cross-document-nav-
            // same-document-traversal: Chrome 156 and Safari 27 PASS, Firefox
            // 159 FAIL, at wpt.fyi 07ce6e987a). A reload is never
            // same-document here. Not for the push/replace step a finalize
            // applies (inline, JointHistory.finalizeSameDocument):
            // whatwg/html#12861 - there it would end a cross-document
            // navigation started after the synchronous one, which no browser
            // does (same-document-nav-cross-document-nav, both subtests
            // PASS/PASS/PASS at 07ce6e987a); its open PR #12942 limits these
            // writes to traversals and reloads.
            if (item.kind == .traverse) {
                if (dom.navigables.integrationOf(@ptrCast(navigable))) |integration| integration.clearOngoingNavigation();
                if (self.apply() != item) return false;
                if (navigables.byId(self.navigable) != navigable or navigable.orphaned or navigable.is_closed) return false;
            }
            // 14.10.2: it goes on in an afterPotentialUnloads task of its own.
            return JobTask.queue(item, navigable, .update);
        }
        // 12.8: populate the target entry's document - a navigation, whose
        // end the apply waits for (recorded at step 12, before this task was
        // queued). "Not started" is an end.
        // Its navigation takes over the "traversal" step 8.4 set (its id is
        // the ongoing traversal's); one that commits at once has ended it.
        return dom.navigables.traverseNavigable(@ptrCast(navigable), entry.id, entry.url, entry.resource, c.from_entry, .{ .traversable_id = top_id, .token = self.token });
    }
};

/// A changing navigable that step 8.4 marked "traversal" and whose
/// population never started - its step-12 task found its apply gone, was
/// dropped or could not be queued - is no longer traversing. One whose
/// population started is its navigation's to end
/// (IFrameIntegration.traversal_navigation).
fn clearTraversal(navigables: *Navigables, navigable: u64) void {
    const bc = navigables.byId(navigable) orelse return;
    const integration = dom.navigables.integrationOf(@ptrCast(bc)) orelse return;
    if (integration.ongoing_navigation == .traversal and integration.traversal_navigation == 0) integration.ongoing_navigation = .none;
}

// =============================================================================
// Appending
// =============================================================================

/// The traversable's queue, made on first use with this module's service
/// schedule. Null when the traversable is on no Browser's list.
fn queueOf(top: *BrowsingContext) ?*TraversalQueue {
    return top.traversalQueue(&scheduleService) catch null;
}

/// The traversable's history, with entries for `bc` and its ancestors
/// (BrowsingContext.ensureHistoryEntries).
fn ensureEntries(bc: *BrowsingContext) !*JointHistory {
    return bc.ensureHistoryEntries(&history_traversal.documentInfo);
}

fn append(top: *BrowsingContext, self: *ApplyItem) void {
    const queue = queueOf(top) orelse {
        self.item.destroy(&self.item);
        return;
    };
    _ = queue.append(&self.item);
}

/// "Append session history traversal steps" to `top`'s queue: a traversal
/// to `target` ("traverse the history by a delta", "perform a navigation API
/// traversal", "resume applying the traverse history step").
pub fn traverse(top: *BrowsingContext, allocator: Allocator, target: Target, options: struct {
    resumed: bool = false,
    initiator: ?Initiator = null,
    cross_document_delta: bool = false,
    delta_navigable: u64 = 0,
    /// Taken: rejected or dropped exactly once.
    api: ?history_traversal.ApiTraversal = null,
    api_navigable: u64 = 0,
}) void {
    const self = ApplyItem.make(top, allocator, .traverse) orelse {
        if (options.api) |api| api.drop(api.context);
        return;
    };
    self.api = options.api;
    self.api_navigable = options.api_navigable;
    self.target = target;
    self.resumed = options.resumed;
    self.initiator = options.initiator;
    self.cross_document_delta = options.cross_document_delta;
    self.delta_navigable = options.delta_navigable;
    append(top, self);
}

/// HTML "reload" step 4: "Append the following session history traversal
/// steps to traversable: apply the reload history step to traversable" -
/// for `navigable`, whose active entry `entry_id` is the one reloaded, with
/// navigation API state `api_state` (BORROWED; null keeps the entry's).
/// `go_zero`: history.go(0) asked for it.
pub fn reload(navigable: *BrowsingContext, allocator: Allocator, entry_id: u64, api_state: ?joint_history.SerializedState, go_zero: bool) void {
    const top = navigable.getTop();
    const self = ApplyItem.make(top, allocator, .reload) orelse return;
    self.reload_navigable = navigable.id;
    self.reload_entry = entry_id;
    self.go_zero = go_zero;
    if (api_state) |state| {
        self.reload_api_state = state.clone(allocator) catch {
            self.item.destroy(&self.item);
            return;
        };
    }
    append(top, self);
}

/// HTML "update for navigable creation/destruction" for `top`'s
/// traversable, appended by "create a new child navigable" step 12 and
/// "destroy a child navigable" step 9. Stated (file comment): one already
/// queued last, not yet running, is this one.
pub fn updateForNavigableCreationDestruction(top: *BrowsingContext) void {
    const queue = top.traversal_queue orelse (queueOf(top) orelse return);
    if (queue.items.items.len > 0) {
        const last = queue.items.items[queue.items.items.len - 1];
        if (last.run == &ApplyItem.run) {
            const queued: *ApplyItem = @fieldParentPtr("item", last);
            if (queued.kind == .update) return;
        }
    }
    const self = ApplyItem.make(top, top.allocator, .update) orelse return;
    append(top, self);
}

// =============================================================================
// Synchronous navigations: "finalize a same-document navigation"
// =============================================================================

/// HTML "URL and history update steps" step 14 and "navigate to a fragment"
/// step 18: "Append the following session history synchronous navigation
/// steps involving navigable to traversable: finalize a same-document
/// navigation" - for `nav`, the pending entry `navigable`'s synchronous
/// steps made (JointHistory.navigateSameDocument). With no queue to append
/// to (a traversable on no Browser's list), or no memory to, it is
/// finalized now.
pub fn finalizeSameDocument(navigable: *BrowsingContext, allocator: Allocator, nav: joint_history.SameDocumentNavigation) void {
    const top = navigable.getTop();
    const queue = queueOf(top) orelse return finalizeNow(top, navigable.id, nav);
    const self = allocator.create(FinalizeItem) catch return finalizeNow(top, navigable.id, nav);
    self.* = .{
        .item = .{ .target = navigable.id, .run = &FinalizeItem.run, .destroy = &FinalizeItem.destroy },
        .navigables = queue.navigables,
        .top_id = top.id,
        .navigable = navigable.id,
        .nav = nav,
        .allocator = allocator,
    };
    // Out of memory, the queue destroyed it unrun.
    if (!queue.append(&self.item)) finalizeNow(top, navigable.id, nav);
}

/// "Append session history traversal steps to navigable's traversable
/// navigable to finalize a cross-document navigation" (navigate step 23.9's
/// completionSteps; lane nav2 F1): the commit of `navigable`'s
/// cross-document navigation `navigation_id` goes on as a .push_replace
/// apply of its traversable's queue. False when no item was appended (no
/// queue, no memory): the caller commits now, as before F1.
pub fn finalizeCrossDocument(navigable: *BrowsingContext, allocator: Allocator, navigation_id: u64) bool {
    const top = navigable.getTop();
    const queue = queueOf(top) orelse return false;
    const self = ApplyItem.make(top, allocator, .push_replace) orelse return false;
    self.commit_navigable = navigable.id;
    self.commit_id = navigation_id;
    // Out of memory, the queue destroys it unrun - and the caller, told so,
    // commits itself: that destroy must not end the navigation.
    self.commit_ran = true;
    if (!queue.append(&self.item)) return false;
    // Appended: never run inside `append`, so its job is still to come.
    self.commit_ran = false;
    return true;
}

/// The .push_replace apply `waiter` names lists `navigable`'s entry
/// (`listed`, from JointHistory.listCrossDocument) - "finalize a
/// cross-document navigation" steps 5-9 - and begins its "apply the
/// push/replace history step" to `listed.step`: step 8 (the navigable's
/// current entry is the new one), every document's view held until the
/// spec writes it (the navigable's when its new document is active, the
/// others' at step 18). The commit calls it right before the navigable's
/// active document unloads. Nothing when that apply is not the running one.
pub fn beginPushReplace(navigable: *BrowsingContext, waiter: dom.navigables.TraversalWaiter, listed: joint_history.ListedCrossDocument) void {
    const top = navigable.getTop();
    if (top.id != waiter.traversable_id) return;
    const traversals = top.traversal_queue orelse return;
    const running = traversals.running orelse return;
    if (running.token != waiter.token or running.run != &ApplyItem.run) return;
    const item: *ApplyItem = @fieldParentPtr("item", running);
    if (item.kind != .push_replace) return;
    const history = top.joint_history orelse return;
    item.target_step = listed.step;
    if (item.changeOf(navigable.id)) |c| c.target_entry = listed.entry;
    history.beginApply(waiter.token, listed.step);
    history.setCurrentEntry(navigable.id, listed.entry);
    history.holdAllViews();
}

/// Whether `bc` is `ancestor` or one of its descendants.
fn isSelfOrUnder(bc: *BrowsingContext, ancestor: *BrowsingContext) bool {
    var at: ?*BrowsingContext = bc;
    while (at) |current| : (at = current.parent) {
        if (current == ancestor) return true;
    }
    return false;
}

/// `finalizeSameDocument` at once, from the synchronous steps themselves.
fn finalizeNow(top: *BrowsingContext, navigable: u64, nav: joint_history.SameDocumentNavigation) void {
    const history = top.joint_history orelse return;
    const done = history.finalizeSameDocument(navigable, nav.entry, nav.replaces) orelse return;
    if (done.removed) dom.navigation_api.entriesRemoved(@ptrCast(top));
}

/// "Finalize a same-document navigation" as synchronous navigation steps
/// targeting the navigable (TraversalQueue Item.target): run in turn, or
/// nested while a traversal waits (step 14.1). Steps 2-6 are
/// JointHistory.finalizeSameDocument's, its push/replace step applied
/// inline; it runs no script.
const FinalizeItem = struct {
    item: Item,
    navigables: *Navigables,
    top_id: u64,
    navigable: u64,
    nav: joint_history.SameDocumentNavigation,
    allocator: Allocator,

    fn run(item: *Item) Outcome {
        const self: *FinalizeItem = @fieldParentPtr("item", item);
        const top = self.navigables.byId(self.top_id) orelse return .done;
        const history = top.joint_history orelse return .done;
        const done = history.finalizeSameDocument(self.navigable, self.nav.entry, self.nav.replaces) orelse return .done;
        // A push cleared forward entries of the whole traversable: the
        // navigation APIs that handed them out dispose of them - in a task of
        // their own (dispose handlers run script), after the views the push
        // wrote (dispose-for-navigation-in-child-entries-updated).
        if (done.removed) EntriesRemovedTask.queue(self.navigables, top);
        return .done;
    }

    fn destroy(item: *Item) void {
        const self: *FinalizeItem = @fieldParentPtr("item", item);
        self.allocator.destroy(self);
    }
};

/// dom.navigation_api.entriesRemoved for a traversable, by id, in a task on
/// its loop. Not queued (no loop, no memory): no dispose event fires.
const EntriesRemovedTask = struct {
    navigables: *Navigables,
    top_id: u64,
    allocator: Allocator,

    fn queue(navigables: *Navigables, top: *BrowsingContext) void {
        const allocator = navigables.allocator;
        const self = allocator.create(EntriesRemovedTask) catch return;
        self.* = .{ .navigables = navigables, .top_id = top.id, .allocator = allocator };
        if (!history_traversal.queueTask(navigables, top, .{ .callback = &run, .context = self, .drop = &drop })) allocator.destroy(self);
    }

    fn run(context: ?*anyopaque) void {
        const self: *EntriesRemovedTask = @ptrCast(@alignCast(context orelse return));
        const navigables = self.navigables;
        const id = self.top_id;
        self.allocator.destroy(self);
        const top = navigables.byId(id) orelse return;
        dom.navigation_api.entriesRemoved(@ptrCast(top));
    }

    fn drop(context: ?*anyopaque) void {
        const self: *EntriesRemovedTask = @ptrCast(@alignCast(context orelse return));
        self.allocator.destroy(self);
    }
};

// =============================================================================
// The delta rules (History's call_go states them)
// =============================================================================

/// The latest delta traversal of `top` that takes some navigable to another
/// document and is queued or running - one asked for by the navigable
/// `navigable`'s History when given, by any otherwise.
pub fn pendingCrossDocumentDelta(top: *BrowsingContext, navigable: ?u64) ?*ApplyItem {
    const queue = top.traversal_queue orelse return null;
    var i = queue.items.items.len;
    while (i > 0) {
        i -= 1;
        if (crossDocumentDelta(queue.items.items[i], navigable)) |pending| return pending;
    }
    if (queue.running) |item| return crossDocumentDelta(item, navigable);
    return null;
}

fn crossDocumentDelta(item: *Item, navigable: ?u64) ?*ApplyItem {
    if (item.run != &ApplyItem.run) return null;
    const apply: *ApplyItem = @fieldParentPtr("item", item);
    if (apply.kind != .traverse or apply.target != .delta or !apply.cross_document_delta) return null;
    if (navigable) |id| if (apply.delta_navigable != id) return null;
    // Running, it is pending until its cross-document populations have made
    // their documents active (the rules' "target document is not yet
    // active"); its steps 15-20 after that are not.
    if (apply.item.started and !apply.awaitsCrossDocumentChange()) return null;
    return apply;
}

/// The child navigable rule: `pending`, a delta traversal of the same
/// navigable that takes a document elsewhere, is replaced by one to its
/// target plus `delta`. Queued, its delta grows; running - its documents
/// read its target step (JointHistory.viewStep), its population in flight -
/// it is finished now, and a traversal by `delta` from there is put first:
/// it runs next, and its population supersedes the pending one's
/// (HTMLIFrameElement's navigation for a traversal ends the ongoing one), so
/// one document loads.
pub fn coalesceDelta(top: *BrowsingContext, pending: *ApplyItem, delta: i32) void {
    const history = top.jointHistory() catch return;
    const queue = top.traversal_queue orelse return;
    const running = if (queue.running) |item| item == &pending.item else false;
    if (!running) {
        const sum = pending.target.delta + delta;
        if (history.stepByDelta(sum) == null) return;
        pending.target = .{ .delta = sum };
        return;
    }
    if (history.stepByDelta(delta) == null) return;
    const self = ApplyItem.make(top, pending.allocator, .traverse) orelse return;
    self.target = .{ .delta = delta };
    // Whether it takes a document elsewhere, from the pending one's target
    // (the step its documents read meanwhile).
    self.cross_document_delta = if (history.stepByDelta(delta)) |step| changesDocument(top, history, step) else false;
    self.delta_navigable = pending.delta_navigable;
    // Ahead of anything queued after the pending one: it replaces it.
    queue.items.insert(queue.allocator, 0, &self.item) catch {
        self.item.destroy(&self.item);
        return;
    };
    self.item.token = queue.next_token;
    queue.next_token += 1;
    // The pending one's step 20 (its destroy) comes first: the new delta
    // counts from its target.
    TraversalQueue.completeById(pending.navigables, top.id, pending.item.token);
}

/// The reload rule (b) in History: a history.go(0) reload of `top`'s own
/// navigable that is queued or running is cancelled - removed, or finished
/// with its population left to be superseded by the traversal appended
/// next. Whether one was.
pub fn cancelGoZeroReload(top: *BrowsingContext) bool {
    const queue = top.traversal_queue orelse return false;
    var cancelled = false;
    var i: usize = 0;
    while (i < queue.items.items.len) {
        const item = queue.items.items[i];
        if (isGoZeroReloadOf(item, top.id)) {
            _ = queue.items.orderedRemove(i);
            item.destroy(item);
            cancelled = true;
        } else i += 1;
    }
    if (queue.running) |item| {
        if (isGoZeroReloadOf(item, top.id)) {
            TraversalQueue.completeById(queue.navigables, top.id, item.token);
            cancelled = true;
        }
    }
    return cancelled;
}

fn isGoZeroReloadOf(item: *Item, navigable: u64) bool {
    if (item.run != &ApplyItem.run) return false;
    const apply: *ApplyItem = @fieldParentPtr("item", item);
    return apply.kind == .reload and apply.go_zero and apply.reload_navigable == navigable;
}

/// Whether applying `step` would take some navigable of `top`'s tree to
/// another document: its entry there differs from its current one and is
/// not on the document it shows.
pub fn changesDocument(top: *BrowsingContext, history: *JointHistory, step: u32) bool {
    var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer tree.deinit(top.allocator);
    top.collectDescendants(top.allocator, &tree) catch return false;
    for (tree.items) |bc| {
        const current = history.listedCurrentEntry(bc.id) orelse continue;
        const target_entry = history.entryAt(bc.id, step) orelse continue;
        if (current == target_entry) continue;
        const same_document = current.document_state == target_entry.document_state and
            target_entry.document != null and target_entry.document == bc.getActiveDocument();
        if (!same_document) return true;
    }
    return false;
}

// =============================================================================
// The service task
// =============================================================================

/// The queue's schedule (traversal_queue.Schedule): one service task on the
/// traversable's active window's loop - or, with none, the next in
/// TraversalQueue.serviceContext's order (History's queue_task). Never
/// inline.
fn scheduleService(navigables: *Navigables, traversable_id: u64) bool {
    const top = navigables.byId(traversable_id) orelse return false;
    const allocator = navigables.allocator;
    const task = allocator.create(ServiceTask) catch return false;
    task.* = .{ .navigables = navigables, .traversable_id = traversable_id, .allocator = allocator };
    if (history_traversal.queueTask(navigables, top, .{ .callback = &ServiceTask.run, .context = task, .drop = &ServiceTask.drop })) return true;
    allocator.destroy(task);
    return false;
}

/// The queue's service task: by the traversable's id, never a pointer to
/// its queue.
const ServiceTask = struct {
    navigables: *Navigables,
    traversable_id: u64,
    /// Its own copy: a task dropped at teardown reads nothing else.
    allocator: Allocator,

    fn run(context: ?*anyopaque) void {
        const self: *ServiceTask = @ptrCast(@alignCast(context orelse return));
        const navigables = self.navigables;
        const id = self.traversable_id;
        self.allocator.destroy(self);
        TraversalQueue.service(navigables, id);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *ServiceTask = @ptrCast(@alignCast(context orelse return));
        self.allocator.destroy(self);
    }
};
