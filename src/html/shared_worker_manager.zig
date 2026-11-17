//! HTML's shared worker manager (§ 10.2.6.4): every shared worker a Browser
//! runs, as a supplement of its scope (runtime.BrowserScope, docs/instances.md
//! rule 2) - "a user agent has an associated shared worker manager", and a
//! Browser is one user agent (one profile). Two Browsers share no shared
//! worker.
//!
//! An entry is one SharedWorkerGlobalScope as the SharedWorker constructor's
//! steps look for it: its constructor storage key, constructor URL and name
//! (the key, step 11.2), its type and credentials (step 11.4), and its owner
//! set (§ 10.2.3, "the worker's lifetime") - the Documents that made or
//! connected to it ("run a worker" step 9, the manager's step 11.5.8). The
//! worker itself runs on a thread of its own (html.WorkerThread); the entry
//! holds its link, through which the manager reads its closing flag and
//! closes it.
//!
//! "Closing orphan workers" ("run a worker" onComplete step 7): a worker's
//! closing flag is set "no sooner than it stops being protected, and no
//! later than it stops being permissible". A shared worker without extended
//! lifetime is protected while it is actively needed - while a Document in
//! its owner set is fully active - and permissible while its owner set is not
//! empty, or has been empty for no more than the between-loads shared worker
//! timeout while some navigable's document is still loading. Crane closes it
//! at the earliest point the spec allows: when its owner set empties (a
//! Document leaves the owner set when it is destroyed - "destroy a document"
//! step 8). The between-loads timeout only widens what is permissible, and
//! the spec says implementations "are not required to keep shared workers
//! alive for that duration"; Chromium does the same (SharedWorkerHost
//! destructs when its last client goes). A worker that is not actively needed
//! and keeps executing may be terminated ("terminate a worker", § 10.2.4) -
//! so the close aborts a script that is running, as Chromium's does.
//!
//! A worker made with extendedLifetime true is "in extended lifetime" while
//! its owner set has been empty for less than the extended lifetime shared
//! worker timeout - and so actively needed and protected: it closes only
//! once that timeout has passed with its owner set still empty
//! (`closeIfStillOrphaned`; the caller arms the timer, on its Browser's
//! window loop).
//!
//! "Suspending workers" ("run a worker" step 8): a worker that is
//! "suspendable" - not actively needed, but permissible - has its script
//! suspended until it stops being suspendable. A shared worker is actively
//! needed while some Document of its owner set is fully active; a Document
//! the back/forward cache keeps is not (it stays in the owner set until it is
//! destroyed). So each owner here carries whether its Document is fully
//! active (`ownerInactive` at the cache's store, `ownerActive` at its
//! restore, a new owner active), and a worker whose owner set holds none
//! that is is suspended - with the workers it owns (WorkerRegistry.
//! markSubtree) - and resumed as soon as one is again. One made with
//! extendedLifetime is still "in extended lifetime" for the extended
//! lifetime shared worker timeout after its last owner stopped being fully
//! active ("in extended lifetime" step 5), so actively needed: it is
//! suspended once that timeout has passed with no owner fully active
//! (`suspendIfStillInactive`; the caller arms the timer). Chrome does the
//! same (SharedWorkerHost::OnClientStateChanged, under kFreezeSharedWorker:
//! Freeze() when no client is active - after kSharedWorkerDestructionDelay
//! for an extended lifetime - and Resume() when one is), and so does Firefox
//! (SharedWorkerManager::UpdateFrozen freezes the worker when every actor is
//! frozen); back-forward-cache/eligibility/shared-worker.html and
//! shared-worker-active-client.window.js pass in Chrome, Firefox and Safari
//! on wpt.fyi.
//!
//! The manager's steps run on its Browser's window thread (SharedWorker is
//! [Exposed=Window]); a realm's end on ANY thread asks it to drop that realm
//! from every owner set (a worker realm owns no shared worker, and finds
//! nothing), so a mutex guards the entries. It is never held across a post to
//! a sink or a link's terminate.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const html_core = @import("html_core");
const workers = html_core.workers;
const WorkerLink = @import("worker_link.zig").WorkerLink;
const WorkerRegistry = @import("worker_registry.zig").WorkerRegistry;

pub const SharedWorkerManager = struct {
    allocator: Allocator,
    /// Protects `entries` and every entry's `owners`. Never held across a
    /// link's terminate or a post.
    mutex: std.Io.Mutex = .init,
    entries: std.ArrayListUnmanaged(*Entry) = .empty,

    /// What a SharedWorker constructor's steps match a worker against.
    /// Every slice BORROWED.
    pub const Key = struct {
        /// The constructor storage key: "obtain a storage key for
        /// non-storage purposes" given the outside settings - its origin,
        /// serialized (Crane partitions no storage).
        storage_key: []const u8,
        /// The constructor URL, serialized.
        url: []const u8,
        /// options["name"].
        name: []const u8,
    };

    /// HTML's extended lifetime shared worker timeout: "how long the user
    /// agent allows shared workers which the web developer has requested be
    /// given an extended lifetime, to survive and perform work after all of
    /// their owners have disappeared" - implementation-defined, "anywhere
    /// from 10 seconds to 5 minutes"; the lower end, so an orphan of a test
    /// page does not outlive the next ones by long.
    pub const extended_lifetime_timeout_ms: u64 = 10_000;

    /// A worker whose owner set emptied with an extended lifetime: closed
    /// once the timeout passes, unless an owner joined since (`epoch`).
    pub const Orphan = struct {
        /// A reference, the caller's to release.
        link: *WorkerLink,
        epoch: u64,
    };

    /// One SharedWorkerGlobalScope the manager knows.
    pub const Entry = struct {
        /// The key, OWNED.
        storage_key: []u8,
        url: []u8,
        name: []u8,
        worker_type: workers.WorkerType,
        credentials: workers.RequestCredentials,
        /// The global scope's extended lifetime: options["extendedLifetime"].
        extended_lifetime: bool = false,
        /// Bumped whenever the owner set empties: an extended lifetime's
        /// timer armed for an earlier emptying finds another epoch.
        orphan_epoch: u64 = 0,
        /// The worker's link (a reference): its closing flag, its sink, its
        /// termination.
        link: *WorkerLink,
        /// The worker's start, opaque to the manager: what a `connect` posted
        /// to the worker's loop finds there (the worker host's thread host).
        /// Dereferenced only on the worker's thread, by tasks of its loop.
        host: *anyopaque,
        /// The owner set: the realms of the Documents that own the worker,
        /// each once, with whether each Document is fully active.
        owners: std.ArrayListUnmanaged(Owner) = .empty,
        /// Bumped whenever its owner set stops holding a fully active
        /// Document, or holds one again: a suspension timer armed for an
        /// extended lifetime (`suspendIfStillInactive`) finds another epoch.
        inactive_epoch: u64 = 0,

        fn matches(self: *const Entry, key: Key) bool {
            return std.mem.eql(u8, self.storage_key, key.storage_key) and
                std.mem.eql(u8, self.url, key.url) and
                std.mem.eql(u8, self.name, key.name);
        }

        fn indexOfOwner(self: *const Entry, owner: *const anyopaque) ?usize {
            for (self.owners.items, 0..) |item, index| {
                if (item.realm == owner) return index;
            }
            return null;
        }

        fn hasOwner(self: *const Entry, owner: *const anyopaque) bool {
            return self.indexOfOwner(owner) != null;
        }

        /// "Actively needed" from its owners (HTML 10.2.3 step 2): an
        /// owner set with a fully active Document.
        fn hasActiveOwner(self: *const Entry) bool {
            for (self.owners.items) |item| {
                if (item.active) return true;
            }
            return false;
        }
    };

    /// One Document of an owner set: its realm - compared, never
    /// dereferenced - and whether it is fully active (false while the
    /// back/forward cache keeps it).
    pub const Owner = struct {
        realm: *const anyopaque,
        active: bool = true,
    };

    /// A shared worker in extended lifetime whose owners are all cached: it
    /// is suspended once the extended lifetime shared worker timeout passes
    /// unless an owner is fully active again by then (`epoch`). The link is a
    /// reference, the caller's to release.
    pub const Inactive = struct {
        link: *WorkerLink,
        epoch: u64,
    };

    pub fn init(allocator: Allocator) SharedWorkerManager {
        return .{ .allocator = allocator };
    }

    /// The scope's end, after every worker thread was joined: an entry still
    /// here is let go.
    pub fn deinit(self: *SharedWorkerManager) void {
        for (self.entries.items) |entry| self.destroyEntry(entry);
        self.entries.deinit(self.allocator);
    }

    /// The manager of the Browser `realm` belongs to; null for a realm with
    /// none (a test realm).
    pub fn of(realm: runtime.Context) ?*SharedWorkerManager {
        const scope = realm.browser_scope orelse return null;
        return scope.of(SharedWorkerManager) catch null;
    }

    /// The manager of `realm`'s Browser if one was made; never makes one.
    pub fn existingOf(realm: runtime.Context) ?*SharedWorkerManager {
        const scope = realm.browser_scope orelse return null;
        return scope.existing(SharedWorkerManager);
    }

    /// What a constructor asks for beyond the key: options["type"],
    /// ["credentials"] and ["extendedLifetime"] (step 11.4).
    pub const Options = struct {
        worker_type: workers.WorkerType,
        credentials: workers.RequestCredentials,
        extended_lifetime: bool = false,
    };

    /// The SharedWorker constructor's steps 11.1-11.2: the worker whose
    /// constructor storage key, constructor URL and name are `key`'s and
    /// whose closing flag is false - and, when there is one, `owner` joins
    /// its owner set (step 11.5.8). Step 11.4 is checked here too, through
    /// `options`: a mismatch is no owner. The worker's link (retained - the
    /// caller releases it), its thread host and whether its type,
    /// credentials and extended lifetime matched; null when no worker
    /// matches.
    pub fn connect(self: *SharedWorkerManager, key: Key, options: Options, owner: *const anyopaque) Allocator.Error!?Found {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const entry = self.findRunning(key) orelse return null;
        const matched = entry.worker_type == options.worker_type and
            entry.credentials == options.credentials and
            entry.extended_lifetime == options.extended_lifetime;
        var resumes = false;
        if (matched) {
            // The constructor runs in a fully active Document: the worker is
            // actively needed again if its owners were all cached.
            resumes = !entry.hasActiveOwner();
            if (entry.indexOfOwner(owner)) |index| {
                entry.owners.items[index].active = true;
            } else try entry.owners.append(self.allocator, .{ .realm = owner });
            if (resumes) entry.inactive_epoch +%= 1;
        }
        return .{ .link = entry.link.retain(), .host = entry.host, .matched = matched, .resumes = resumes };
    }

    pub const Found = struct {
        link: *WorkerLink,
        host: *anyopaque,
        matched: bool,
        /// The worker's owner set had no fully active Document before this
        /// owner joined: it was suspended (or about to be), and the caller
        /// resumes it - with the workers it owns - before it connects.
        resumes: bool = false,
    };

    /// "Run a worker" for a shared worker, the manager's part: the new
    /// worker's entry, its owner set `owner` alone (step 9). Takes a
    /// reference to `link`. From now on a constructor with the same key
    /// finds it.
    pub fn add(
        self: *SharedWorkerManager,
        key: Key,
        options: Options,
        link: *WorkerLink,
        host: *anyopaque,
        owner: *const anyopaque,
    ) Allocator.Error!void {
        const entry = try self.allocator.create(Entry);
        errdefer self.allocator.destroy(entry);
        const storage_key = try self.allocator.dupe(u8, key.storage_key);
        errdefer self.allocator.free(storage_key);
        const url = try self.allocator.dupe(u8, key.url);
        errdefer self.allocator.free(url);
        const name = try self.allocator.dupe(u8, key.name);
        errdefer self.allocator.free(name);
        entry.* = .{
            .storage_key = storage_key,
            .url = url,
            .name = name,
            .worker_type = options.worker_type,
            .credentials = options.credentials,
            .extended_lifetime = options.extended_lifetime,
            .link = link,
            .host = host,
        };
        errdefer entry.owners.deinit(self.allocator);
        try entry.owners.append(self.allocator, .{ .realm = owner });

        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        try self.entries.append(self.allocator, entry);
        _ = link.retain();
    }

    /// The worker whose link is `link` has ended (its thread is joined):
    /// forget it.
    pub fn remove(self: *SharedWorkerManager, link: *WorkerLink) void {
        const entry = blk: {
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            for (self.entries.items, 0..) |entry, i| {
                if (entry.link == link) break :blk self.entries.swapRemove(i);
            }
            return;
        };
        self.destroyEntry(entry);
    }

    /// "Destroy a document" step 8 for the Document whose realm is `owner`:
    /// it leaves every owner set it is in, and each worker whose owner set
    /// it empties is closed (see the file's header: closing orphan workers) -
    /// now, or, for a worker with an extended lifetime, once the timeout has
    /// passed: those are appended to `extended` (each link retained) for the
    /// caller to arm (`closeIfStillOrphaned` when it fires); with no list,
    /// or no room in it, they are closed now. How many workers were closed
    /// now.
    ///
    /// A worker it leaves with owners none of which is fully active - the
    /// last one shown went, the others are cached - is suspendable now:
    /// suspended (`Transitions`, with `registry`'s nested workers).
    pub fn removeOwner(self: *SharedWorkerManager, owner: *const anyopaque, extended: ?*std.ArrayListUnmanaged(Orphan), transitions: ?*Transitions) usize {
        var orphans: std.ArrayListUnmanaged(*WorkerLink) = .empty;
        defer orphans.deinit(self.allocator);
        {
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            for (self.entries.items) |entry| {
                const index = entry.indexOfOwner(owner) orelse continue;
                const was_active = entry.hasActiveOwner();
                _ = entry.owners.swapRemove(index);
                if (entry.owners.items.len != 0) {
                    if (was_active and !entry.hasActiveOwner()) self.becameInactive(entry, transitions);
                    continue;
                }
                // Freed when the owner set empties, as every container here.
                // A suspended worker stays suspended until it closes: Chrome,
                // the one engine shipping extendedLifetime, keeps a frozen
                // worker frozen when its last client goes
                // (SharedWorkerHost::OnClientConnectionLost re-evaluates the
                // freeze only while clients remain).
                entry.owners.clearAndFree(self.allocator);
                entry.orphan_epoch +%= 1;
                if (entry.extended_lifetime) {
                    if (extended) |list| {
                        if (list.append(self.allocator, .{ .link = entry.link.retain(), .epoch = entry.orphan_epoch })) |_| {
                            continue;
                        } else |_| entry.link.release();
                    }
                }
                // No memory to note it: close it under the lock (a link's
                // terminate takes only its own lock, which no path holds
                // while taking this one).
                orphans.append(self.allocator, entry.link.retain()) catch {
                    _ = entry.link.terminate();
                    entry.link.release();
                };
            }
        }
        for (orphans.items) |link| {
            _ = link.terminate();
            link.release();
        }
        return orphans.items.len;
    }

    // ------------------------------------------------------------------------
    // Suspending workers (see the file's header)
    // ------------------------------------------------------------------------

    /// What a change to owners' activity asks of the caller, done outside
    /// the manager's lock: workers to suspend and to resume - each with the
    /// workers it owns (WorkerRegistry.markSubtree) - and the extended
    /// lifetime workers whose suspension waits for the timeout (the caller
    /// arms `suspendIfStillInactive`). Every link retained; `apply` then
    /// `deinit`.
    pub const Transitions = struct {
        allocator: Allocator,
        suspend_now: std.ArrayListUnmanaged(*WorkerLink) = .empty,
        resume_now: std.ArrayListUnmanaged(*WorkerLink) = .empty,
        /// Null: an extended lifetime worker is suspended now too (a caller
        /// with no timer to arm).
        delayed: ?std.ArrayListUnmanaged(Inactive) = null,

        pub fn init(allocator: Allocator, with_delays: bool) Transitions {
            return .{ .allocator = allocator, .delayed = if (with_delays) .empty else null };
        }

        /// Suspend and resume the links (and their nested workers, when
        /// `registry` knows them). The delayed ones are the caller's.
        pub fn apply(self: *Transitions, registry: ?*WorkerRegistry) void {
            for (self.suspend_now.items) |link| {
                if (registry) |r| _ = r.markSubtree(link, true) else _ = link.suspendExecution();
            }
            for (self.resume_now.items) |link| {
                if (registry) |r| _ = r.markSubtree(link, false) else _ = link.resumeFromSuspension();
            }
        }

        pub fn deinit(self: *Transitions) void {
            for (self.suspend_now.items) |link| link.release();
            for (self.resume_now.items) |link| link.release();
            self.suspend_now.deinit(self.allocator);
            self.resume_now.deinit(self.allocator);
            if (self.delayed) |*list| {
                for (list.items) |item| item.link.release();
                list.deinit(self.allocator);
            }
        }

        /// Under the manager's lock: `link` is to be suspended now. With no
        /// memory to note it, it is suspended here - the link alone (its
        /// flag; no registry lock is taken under the manager's).
        fn suspendLink(self: *Transitions, link: *WorkerLink) void {
            self.suspend_now.append(self.allocator, link.retain()) catch {
                link.release();
                _ = link.suspendExecution();
            };
        }

        fn resumeLink(self: *Transitions, link: *WorkerLink) void {
            self.resume_now.append(self.allocator, link.retain()) catch {
                link.release();
                _ = link.resumeFromSuspension();
            };
        }
    };

    /// The Document whose realm is `owner` is no longer fully active - the
    /// back/forward cache keeps it (its unload's store step): in each owner
    /// set it is in, it stops counting, and a worker left with no fully
    /// active owner is suspendable.
    pub fn ownerInactive(self: *SharedWorkerManager, owner: *const anyopaque, transitions: *Transitions) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.entries.items) |entry| {
            const index = entry.indexOfOwner(owner) orelse continue;
            if (!entry.owners.items[index].active) continue;
            entry.owners.items[index].active = false;
            if (!entry.hasActiveOwner()) self.becameInactive(entry, transitions);
        }
    }

    /// The Document whose realm is `owner` is fully active again (the
    /// back/forward cache restored it): each worker it owns is actively
    /// needed again, and resumes if it was suspended.
    pub fn ownerActive(self: *SharedWorkerManager, owner: *const anyopaque, transitions: *Transitions) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.entries.items) |entry| {
            const index = entry.indexOfOwner(owner) orelse continue;
            if (entry.owners.items[index].active) continue;
            const had_active = entry.hasActiveOwner();
            entry.owners.items[index].active = true;
            if (had_active) continue;
            entry.inactive_epoch +%= 1;
            transitions.resumeLink(entry.link);
        }
    }

    /// Under the lock: `entry`'s owner set, not empty, just lost its last
    /// fully active Document. Suspended now - or, in extended lifetime, once
    /// the timeout passes (`suspendIfStillInactive`).
    fn becameInactive(self: *SharedWorkerManager, entry: *Entry, transitions: ?*Transitions) void {
        _ = self;
        entry.inactive_epoch +%= 1;
        const list = transitions orelse {
            _ = entry.link.suspendExecution();
            return;
        };
        if (entry.extended_lifetime) {
            if (list.delayed) |*delayed| {
                if (delayed.append(list.allocator, .{ .link = entry.link.retain(), .epoch = entry.inactive_epoch })) |_| {
                    return;
                } else |_| entry.link.release();
            }
        }
        list.suspendLink(entry.link);
    }

    /// The extended lifetime shared worker timeout has passed since the
    /// worker whose link is `link` lost its last fully active owner (its
    /// `epoch`): suspended now - with its nested workers, through `registry`
    /// - if none of its owners is fully active again and it still has
    /// owners (an emptied owner set closes it instead). Whether it was.
    pub fn suspendIfStillInactive(self: *SharedWorkerManager, link: *WorkerLink, epoch: u64, registry: ?*WorkerRegistry) bool {
        const still = blk: {
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            for (self.entries.items) |entry| {
                if (entry.link != link) continue;
                break :blk entry.owners.items.len != 0 and !entry.hasActiveOwner() and entry.inactive_epoch == epoch;
            }
            break :blk false;
        };
        if (!still) return false;
        if (registry) |r| _ = r.markSubtree(link, true) else _ = link.suspendExecution();
        return true;
    }

    /// Whether the worker whose link is `link` has a fully active Document
    /// in its owner set.
    pub fn hasActiveOwnerOf(self: *SharedWorkerManager, link: *const WorkerLink) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.entries.items) |entry| {
            if (entry.link == link) return entry.hasActiveOwner();
        }
        return false;
    }

    /// What `doomForLockContention` found.
    pub const Doom = union(enum) {
        /// `link` is no shared worker's here.
        not_shared,
        /// An owner's Document is fully active, or an owner's page is not one
        /// the cache can doom (being restored): nothing changed.
        kept,
        /// Every owner's page is doomed and the worker is closing: the owner
        /// realms (compared only), OWNED by the `allocator` passed.
        doomed: []*const anyopaque,
    };

    /// Lock contention for a lock the shared worker whose link is `link`
    /// holds (Chrome's SharedWorkerHost::OnLockContention: nothing while a
    /// client is active; otherwise every client - each one cached - is
    /// evicted, and with them goes the worker). Under the lock: when no
    /// Document of its owner set is fully active, `doom` dooms every owner's
    /// kept page (dom.bfcache.doomRealms, all or none), and the worker's
    /// closing flag is set, so no SharedWorker constructor matches it any
    /// more - a page connecting meanwhile starts a new worker instead of
    /// resuming one whose lock was broken. The caller wakes it (its
    /// termination) and evicts the pages. Any thread.
    pub fn doomForLockContention(
        self: *SharedWorkerManager,
        link: *WorkerLink,
        allocator: Allocator,
        context: *anyopaque,
        doom: *const fn (context: *anyopaque, realms: []const *const anyopaque) bool,
    ) Doom {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const entry = for (self.entries.items) |entry| {
            if (entry.link == link) break entry;
        } else return .not_shared;
        if (entry.owners.items.len == 0 or entry.hasActiveOwner()) return .kept;
        const realms = allocator.alloc(*const anyopaque, entry.owners.items.len) catch return .kept;
        for (entry.owners.items, realms) |owner, *realm| realm.* = owner.realm;
        if (!doom(context, realms)) {
            allocator.free(realms);
            return .kept;
        }
        _ = entry.link.requestClose();
        return .{ .doomed = realms };
    }

    /// The extended lifetime shared worker timeout has passed since the owner
    /// set of the worker whose link is `link` emptied (its `epoch`): closed
    /// now if its owner set is still empty - no Document connected since.
    /// Whether it was.
    pub fn closeIfStillOrphaned(self: *SharedWorkerManager, link: *WorkerLink, epoch: u64) bool {
        const orphaned = blk: {
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            for (self.entries.items) |entry| {
                if (entry.link != link) continue;
                break :blk entry.owners.items.len == 0 and entry.orphan_epoch == epoch;
            }
            break :blk false;
        };
        if (orphaned) _ = link.terminate();
        return orphaned;
    }

    /// Whether `owner` - a Document's realm - is in the owner set of a
    /// shared worker. A snapshot: the set may change as soon as the lock
    /// drops.
    pub fn hasOwner(self: *SharedWorkerManager, owner: *const anyopaque) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.entries.items) |entry| {
            if (entry.hasOwner(owner)) return true;
        }
        return false;
    }

    /// How many workers the manager knows (closing ones included).
    pub fn count(self: *SharedWorkerManager) usize {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.entries.items.len;
    }

    /// How many owners the worker whose link is `link` has.
    pub fn ownerCount(self: *SharedWorkerManager, link: *WorkerLink) usize {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.entries.items) |entry| {
            if (entry.link == link) return entry.owners.items.len;
        }
        return 0;
    }

    /// Step 11.2's match: same key, closing flag false. Under the lock.
    fn findRunning(self: *SharedWorkerManager, key: Key) ?*Entry {
        for (self.entries.items) |entry| {
            if (!entry.link.runsTasks()) continue;
            if (entry.matches(key)) return entry;
        }
        return null;
    }

    fn destroyEntry(self: *SharedWorkerManager, entry: *Entry) void {
        entry.link.release();
        entry.owners.deinit(self.allocator);
        self.allocator.free(entry.storage_key);
        self.allocator.free(entry.url);
        self.allocator.free(entry.name);
        self.allocator.destroy(entry);
    }
};
