//! HTML "abort a document" step 2, for the fetches script started: "Cancel
//! any instances of the fetch algorithm in the context of document,
//! discarding any tasks queued for them, and discarding any further data
//! received from the network for them." "Destroy a document" (§7.5.10) runs
//! it first, and then (step 7) removes the document's queued tasks without
//! running them - so a fetch of a destroyed document ends with no further
//! event at all.
//!
//! The fetches are the owners' state - XMLHttpRequest's in-flight request,
//! fetch()'s call - and no IDL member reaches them, so each kind of fetch
//! owner installs a canceler here and "destroy a child navigable"
//! (HTMLIFrameElement's removing steps) calls `abortAll` for each destroyed
//! document's realm. A live document's abort is observable; destruction
//! discards the requests silently. Canceling also lets a destroyed frame's realm
//! go: a fetch in flight holds its owner, and the owner its realm, until it
//! ends (Blink's HasPendingActivity), so it has to end.
//!
//! Only "abort a document" step 2 belongs here. Steps the spec puts in the
//! unloading document cleanup steps (a WebSocket's "make disappear") are
//! not fetches.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#abort-a-document
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#destroy-a-document
//!
//! lint-impls: hook for XMLHttpRequest, WindowOrWorkerGlobalScope, EventSource, HTMLScriptElement, HTMLImageElement, HTMLTrackElement, HTMLMediaElement, HTMLLinkElement, HTMLObjectElement, HTMLAnchorElement, HTMLInputElement, SVGImageElement, SVGUseElement, FontFace, FontFaceSet
const std = @import("std");
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// Fetch 2.4: the parts of an environment settings object's fetch group that
/// Crane keeps there - the in-flight keepalive request body bytes
/// HTTP-network-or-cache fetch step 8.10 bounds at 64 KiB, and the deferred
/// fetch records fetchLater() queues (dom.deferred_fetches; its fetch
/// records are their owners', reached through the cancelers below). Owned
/// by each global with its settings (a Window's, a WorkerGlobalScope's
/// InternalState), `deinit` with it, and reached through
/// `dom.global_settings.fetchGroupOf`. A request that outlives its global
/// holds a slab-generation link to it and releases its bytes only while that
/// is live (dom.keepalive_fetch.Reservation); a deferred record is the
/// group's until it is sent, aborted or freed with it.
///
/// The spec sums the in-flight records at each HTTP-network-or-cache fetch,
/// which counts the request being checked twice (its own record is in the
/// group already). The browsers count a running total instead, reserved
/// when a request starts and released once when it finishes or fails, and
/// so a request of exactly 64 KiB is accepted
/// (fetch/api/request/request-keepalive-quota.html, Chrome and Firefox
/// 6/6): Blink ResourceFetcher::StartLoad and HandleLoaderFinish /
/// HandleLoaderError (inflight_keepalive_bytes_), WebKit
/// KeepaliveRequestTracker::tryRegisterRequest / unregisterRequest, Gecko
/// FetchUtil::Increment/DecrementPendingKeepaliveRequestSize.
pub const FetchGroup = struct {
    inflight_keepalive_bytes: u64 = 0,
    /// "Deferred fetch records": the pending ones, in queueing order.
    deferred: @import("deferred_fetches.zig").Records = .{},

    /// The group's global goes: its pending deferred records go unsent -
    /// its document's unloading cleanup steps sent them, if they ran.
    pub fn deinit(self: *FetchGroup) void {
        self.deferred.deinit();
    }

    /// "64 kibibytes".
    pub const keepalive_quota: u64 = 64 * 1024;

    /// Step 8.10.5: false - a network error - when `length` and the bytes
    /// in flight exceed the quota; otherwise `length` is in flight until
    /// `releaseKeepalive`.
    pub fn reserveKeepalive(self: *FetchGroup, length: u64) bool {
        if (length > keepalive_quota - self.inflight_keepalive_bytes) return false;
        self.inflight_keepalive_bytes += length;
        return true;
    }

    /// A reserved request is done (its done flag is set) or terminated.
    pub fn releaseKeepalive(self: *FetchGroup, length: u64) void {
        std.debug.assert(length <= self.inflight_keepalive_bytes);
        self.inflight_keepalive_bytes -|= length;
    }
};

/// One kind of fetch owner's document-abort and destruction steps.
pub const Owner = struct {
    /// Destroying the realm discards work without running script.
    discard: *const fn (realm: runtime.Context) void,
    /// Mark the requests belonging to this document before any owner runs
    /// script. Return whether any request was marked. Must not run script.
    prepare_abort: ?*const fn (document: *runtime.Instance) bool = null,
    /// Abort only the marked requests; their callbacks may start new ones.
    abort: ?*const fn (document: *runtime.Instance) void = null,
    /// Prepare a provisional navigation's document abort.
    /// Other owners keep their ordinary document-abort preparation.
    prepare_navigation_document_abort: ?*const fn (document: *runtime.Instance) bool = null,
};

/// One slot per kind of fetch owner, with room to spare.
const slot_count = 20;
pub const OwnerSlots = [slot_count]?Owner;
// process-wide: owners install the same immutable hooks before Browsers or worker threads start
var cancelers: OwnerSlots = .{null} ** slot_count;

/// Read-only startup capacity check for the native integration tests.
pub fn ownerCount() usize {
    var filled: usize = 0;
    for (cancelers) |owner| if (owner != null) {
        filled += 1;
    };
    return filled;
}

/// Called by each owner's installHooks, once, at process start (process_start.zig).
pub fn install(owner: Owner) void {
    process_start.assertInstalling();
    tryInstall(&cancelers, owner) catch @panic("document fetch owner table is full");
}

/// Fill an explicit table so startup overflow cannot silently leave one
/// kind of document fetch uncanceled. Registration is idempotent even when
/// the table is full.
pub fn tryInstall(slots: *OwnerSlots, owner: Owner) error{OwnerSlotsFull}!void {
    var available: ?*?Owner = null;
    for (slots) |*slot| {
        if (slot.*) |existing| {
            // The same owner only if EVERY step it names is: two owners
            // whose `discard` steps have the same body are one function in a
            // release build (LLVM folds identical functions), and keying by
            // it dropped the second owner's abort steps there
            // (docs/lessons/debugging-equal-constants-share-one-address-in-a-release-build.md).
            if (std.meta.eql(existing, owner)) return;
            continue;
        }
        if (available == null) available = slot;
    }
    const slot = available orelse return error.OwnerSlotsFull;
    slot.* = owner;
}

/// "Destroy a document": discard every request and its queued delivery in
/// `realm`, firing nothing. Kept separate from the live document's abort.
pub fn abortAll(realm: runtime.Context) void {
    for (cancelers) |slot| {
        const owner = slot orelse return;
        owner.discard(realm);
    }
}

/// HTML "abort a document" step 2: abort this document's requests with their
/// API's observable outcome. True means at least one request was canceled,
/// so the document must be made unsalvageable. A reused Window's realm is
/// insufficient identity: each owner records the document at request start.
pub fn abort(document: *runtime.Instance) bool {
    return abortDocument(document, false);
}

/// The provisional navigation call is explicit: a stop invoked reentrantly
/// on a descendant must still use ordinary cancellation.
pub fn abortForNavigation(document: *runtime.Instance) bool {
    return abortDocument(document, true);
}

fn abortDocument(document: *runtime.Instance, for_navigation: bool) bool {
    var canceled = false;
    for (cancelers) |slot| {
        const owner = slot orelse break;
        const prepare = if (for_navigation)
            owner.prepare_navigation_document_abort orelse owner.prepare_abort orelse continue
        else
            owner.prepare_abort orelse continue;
        canceled = prepare(document) or canceled;
    }
    // Snapshot all owners before callbacks can start a request of any kind.
    // Blink loader cancellation clears the old loader before dispatch; new
    // work created by an abort listener is independent of that old loader.
    for (cancelers) |slot| {
        const owner = slot orelse break;
        const abort_owner = owner.abort orelse continue;
        abort_owner(document);
    }
    return canceled;
}

test "document abort prepares every owner before callbacks and destruction stays silent" {
    const saved = cancelers;
    defer cancelers = saved;
    cancelers = .{null} ** slot_count;

    const TestState = struct {
        first_marked: bool = false,
        second_marked: bool = false,
        all_prepared: bool = false,
        aborted: usize = 0,
        discarded: usize = 0,
        navigation_prepared: bool = false,

        fn of(document: *runtime.Instance) *@This() {
            return @ptrCast(@alignCast(document.state));
        }
        fn discard(realm: runtime.Context) void {
            const state: *@This() = @ptrCast(@alignCast(realm));
            state.discarded += 1;
        }
        fn discardOther(realm: runtime.Context) void {
            const state: *@This() = @ptrCast(@alignCast(realm));
            state.discarded += 10;
        }
        fn prepare(document: *runtime.Instance) bool {
            of(document).first_marked = true;
            return true;
        }
        fn prepareOther(document: *runtime.Instance) bool {
            of(document).second_marked = true;
            return true;
        }
        fn prepareNavigation(document: *runtime.Instance) bool {
            of(document).navigation_prepared = true;
            return false;
        }
        fn abortFirst(document: *runtime.Instance) void {
            const state = of(document);
            state.all_prepared = state.first_marked and state.second_marked;
            state.aborted += 1;
        }
        fn abortOther(document: *runtime.Instance) void {
            of(document).aborted += 10;
        }
    };
    const state = try std.testing.allocator.create(TestState);
    defer std.testing.allocator.destroy(state);
    state.* = .{};
    var document: runtime.Instance = undefined;
    document.state = state;
    const realm: runtime.Context = @ptrCast(@alignCast(state));
    abortAll(realm);
    try std.testing.expect(!abort(&document));
    const first: Owner = .{ .discard = TestState.discard, .prepare_abort = TestState.prepare, .abort = TestState.abortFirst, .prepare_navigation_document_abort = TestState.prepareNavigation };
    install(first);
    install(first);
    install(.{ .discard = TestState.discardOther, .prepare_abort = TestState.prepareOther, .abort = TestState.abortOther });
    try std.testing.expect(abort(&document));
    try std.testing.expect(state.all_prepared);
    try std.testing.expectEqual(@as(usize, 11), state.aborted);
    try std.testing.expectEqual(@as(usize, 0), state.discarded);
    abortAll(realm);
    try std.testing.expectEqual(@as(usize, 11), state.discarded);
    try std.testing.expectEqual(@as(usize, 11), state.aborted);
    state.* = .{};
    try std.testing.expect(abortForNavigation(&document));
    try std.testing.expect(state.navigation_prepared);
    try std.testing.expect(!state.first_marked);
    try std.testing.expect(state.second_marked);
    try std.testing.expectEqual(@as(usize, 11), state.aborted);
    try std.testing.expectEqual(@as(usize, 0), state.discarded);
}

test "owners that share a discard step are both installed: a release build can make two steps one function" {
    // Two kinds of fetch owner whose `discard` steps have the same body share
    // one function in a release build. Each owner's abort steps still run,
    // as they do in Debug.
    const saved = cancelers;
    defer cancelers = saved;
    cancelers = .{null} ** slot_count;
    const Owners = struct {
        fn aborted(document: *runtime.Instance) *usize {
            return @ptrCast(@alignCast(document.state));
        }
        fn discard(_: runtime.Context) void {}
        fn prepare(_: *runtime.Instance) bool {
            return true;
        }
        fn abortFirst(document: *runtime.Instance) void {
            aborted(document).* += 1;
        }
        fn abortSecond(document: *runtime.Instance) void {
            aborted(document).* += 10;
        }
    };
    var aborted: usize = 0;
    var document: runtime.Instance = undefined;
    document.state = &aborted;
    install(.{ .discard = Owners.discard, .prepare_abort = Owners.prepare, .abort = Owners.abortFirst });
    install(.{ .discard = Owners.discard, .prepare_abort = Owners.prepare, .abort = Owners.abortSecond });
    try std.testing.expect(abort(&document));
    try std.testing.expectEqual(@as(usize, 11), aborted);
}

test "full owner table rejects a new owner and accepts an already installed owner" {
    if (comptime !@hasDecl(@This(), "tryInstall")) {
        try std.testing.expect(false);
        return;
    } else {
        const saved = cancelers;
        defer cancelers = saved;
        const Callbacks = struct {
            fn first(_: runtime.Context) void {}
            fn second(context: runtime.Context) void {
                std.mem.doNotOptimizeAway(context);
            }
        };
        const owner: Owner = .{ .discard = Callbacks.first };
        cancelers = .{owner} ** slot_count;
        try tryInstall(&cancelers, owner);
        try std.testing.expectError(error.OwnerSlotsFull, tryInstall(&cancelers, .{ .discard = Callbacks.second }));
    }
}

test "a fetch group holds at most 64 KiB of keepalive bodies in flight, released as each ends" {
    var group: FetchGroup = .{};
    // Exactly the quota fits; one more byte does not.
    try std.testing.expect(!group.reserveKeepalive(FetchGroup.keepalive_quota + 1));
    try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
    try std.testing.expect(group.reserveKeepalive(FetchGroup.keepalive_quota));
    try std.testing.expect(!group.reserveKeepalive(1));
    // An empty body fits even when the group is full.
    try std.testing.expect(group.reserveKeepalive(0));
    group.releaseKeepalive(FetchGroup.keepalive_quota);
    try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);

    // request-keepalive-quota.html "slow-2": only the bytes a request held
    // come back when it ends.
    try std.testing.expect(group.reserveKeepalive(FetchGroup.keepalive_quota - 1));
    try std.testing.expect(group.reserveKeepalive(1));
    group.releaseKeepalive(1);
    try std.testing.expect(!group.reserveKeepalive(2));
    try std.testing.expect(group.reserveKeepalive(1));
    group.releaseKeepalive(1);
    group.releaseKeepalive(FetchGroup.keepalive_quota - 1);
    try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
    // A length past any u64 sum never wraps the check.
    try std.testing.expect(!group.reserveKeepalive(std.math.maxInt(u64)));
}
