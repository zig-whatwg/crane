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
//! window loop). (Crane's Documents are fully active until destroyed, so
//! "in extended lifetime" steps 4-5 add nothing.)
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
        /// each once. Compared, never dereferenced.
        owners: std.ArrayListUnmanaged(*const anyopaque) = .empty,

        fn matches(self: *const Entry, key: Key) bool {
            return std.mem.eql(u8, self.storage_key, key.storage_key) and
                std.mem.eql(u8, self.url, key.url) and
                std.mem.eql(u8, self.name, key.name);
        }

        fn hasOwner(self: *const Entry, owner: *const anyopaque) bool {
            return std.mem.indexOfScalar(*const anyopaque, self.owners.items, owner) != null;
        }
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
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const entry = self.findRunning(key) orelse return null;
        const matched = entry.worker_type == options.worker_type and
            entry.credentials == options.credentials and
            entry.extended_lifetime == options.extended_lifetime;
        if (matched and !entry.hasOwner(owner)) try entry.owners.append(self.allocator, owner);
        return .{ .link = entry.link.retain(), .host = entry.host, .matched = matched };
    }

    pub const Found = struct {
        link: *WorkerLink,
        host: *anyopaque,
        matched: bool,
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
        try entry.owners.append(self.allocator, owner);

        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        try self.entries.append(self.allocator, entry);
        _ = link.retain();
    }

    /// The worker whose link is `link` has ended (its thread is joined):
    /// forget it.
    pub fn remove(self: *SharedWorkerManager, link: *WorkerLink) void {
        const entry = blk: {
            std.Io.Threaded.mutexLock(&self.mutex);
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
    pub fn removeOwner(self: *SharedWorkerManager, owner: *const anyopaque, extended: ?*std.ArrayListUnmanaged(Orphan)) usize {
        var orphans: std.ArrayListUnmanaged(*WorkerLink) = .empty;
        defer orphans.deinit(self.allocator);
        {
            std.Io.Threaded.mutexLock(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            for (self.entries.items) |entry| {
                const index = std.mem.indexOfScalar(*const anyopaque, entry.owners.items, owner) orelse continue;
                _ = entry.owners.swapRemove(index);
                if (entry.owners.items.len != 0) continue;
                // Freed when the owner set empties, as every container here.
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

    /// The extended lifetime shared worker timeout has passed since the owner
    /// set of the worker whose link is `link` emptied (its `epoch`): closed
    /// now if its owner set is still empty - no Document connected since.
    /// Whether it was.
    pub fn closeIfStillOrphaned(self: *SharedWorkerManager, link: *WorkerLink, epoch: u64) bool {
        const orphaned = blk: {
            std.Io.Threaded.mutexLock(&self.mutex);
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

    /// How many workers the manager knows (closing ones included).
    pub fn count(self: *SharedWorkerManager) usize {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.entries.items.len;
    }

    /// How many owners the worker whose link is `link` has.
    pub fn ownerCount(self: *SharedWorkerManager, link: *WorkerLink) usize {
        std.Io.Threaded.mutexLock(&self.mutex);
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
