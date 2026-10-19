//! A Browser's back/forward cache (HTML 7.4.1, the "bfcache" note; lane
//! bfcache-b, tmp/plans/bfcache-design.md phase B): the pages a top-level
//! traversable's navigations left that its unload kept, for a traversal back
//! to their session history entries to show again without a fetch.
//!
//! Per Browser - a supplement of its scope - never per process: two Browsers
//! on two threads each keep their own pages. A page is kept as it was left:
//! its Document, its Window and its realm, never detached (its global stays
//! attached to its own WindowProxy), its timers suspended and its tasks
//! waiting in their group on the Browser's event loop. How many, and for how
//! long, is the Browser's configuration: `back_forward_cache_size` (2, the
//! size WebKit's CacheModel gives a page cache on a small device) and
//! `back_forward_cache_ttl_seconds` (600, Blink's
//! BackForwardCacheImpl::GetTimeToLiveInBackForwardCache). The oldest page
//! leaves first.
//!
//! Phase B keeps only pages of a top-level traversable Crane made (a
//! window.open() popup); the host's own page is never unloaded by a
//! navigation (Browser.navigate replaces its Context), so it is never kept -
//! whether it should be, as an embedder would want, is a later phase's
//! question (the design doc).
//!
//! Leaving the cache - by size, by age, because something was delivered to
//! the page that it cannot answer, because its traversable closed, or because
//! the page that opened it ends - is "eviction": the navigation code's steps
//! (dom.bfcache.PageSteps.evict) destroy the document and end its realm. It
//! runs from a task of the Browser's loop, never inside the collector, and
//! never after the loop: Browser.deinit and Browser.navigate evict every page
//! before the page that opened them ends - the realms are children of the
//! opener's realm, which would end them otherwise - and before the loop goes
//! (the lesson "A step deferred to a loop dies with the loop").
//!
//! This module installs dom.bfcache's Cache (`installHooks`, at process
//! start); the navigation code reaches it only through dom.bfcache.
const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const runtime = @import("runtime");
const dom = @import("dom");
const EventLoop = @import("event_loop.zig").EventLoop;

const KeptPage = dom.bfcache.KeptPage;
const Reason = dom.bfcache.Reason;

/// The default number of pages a Browser keeps (BrowserConfig).
pub const default_size: usize = 2;
/// The default time a page stays in the cache, in seconds (BrowserConfig).
pub const default_ttl_seconds: u64 = 600;

/// A Browser's cache: a supplement of its scope (runtime.BrowserScope.of).
pub const BackForwardCache = struct {
    allocator: Allocator,
    /// How many pages it keeps; 0 keeps none.
    size: usize = default_size,
    /// How long a page stays, in milliseconds.
    ttl_ms: u64 = default_ttl_seconds * std.time.ms_per_s,
    /// The pages, oldest first.
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    /// The Browser's event loop, which the pages' tasks wait on and whose
    /// timers age them. Set by `configure`; null keeps nothing.
    loop: ?*EventLoop = null,
    /// The timer that ages the oldest page out, while one is armed.
    ttl_timer: runtime.TimerId = 0,
    /// Evictions queued as tasks and not yet run: Browser.deinit and the
    /// opener page's end run them first.
    queued: std.ArrayListUnmanaged(*EvictionTask) = .empty,

    const Entry = struct {
        page: KeptPage,
        /// platform.monotonicMillis when it was stored.
        stored_at_ms: i64,
        /// Its eviction is queued: it stays in `entries` - its documents
        /// still read as cached, inactive, until then - but cannot be
        /// restored, and does not count toward `size`.
        evicting: bool = false,
    };

    /// A new, empty cache (BrowserScope.of): it keeps nothing until
    /// `configure`.
    pub fn init(allocator: Allocator) BackForwardCache {
        return .{ .allocator = allocator };
    }

    /// The scope's end. Every page was evicted before the Browser's loop
    /// ended (`evictAll`); what is left - a page whose realm already ended -
    /// is only bookkeeping.
    pub fn deinit(self: *BackForwardCache) void {
        std.debug.assert(self.queued.items.len == 0);
        self.entries.deinit(self.allocator);
        self.queued.deinit(self.allocator);
    }

    /// The Browser's configuration (Browser.init).
    pub fn configure(self: *BackForwardCache, loop: *EventLoop, size: usize, ttl_seconds: u64) void {
        self.loop = loop;
        self.size = size;
        self.ttl_ms = ttl_seconds * std.time.ms_per_s;
    }

    /// How many pages it holds, those queued for eviction included.
    pub fn count(self: *const BackForwardCache) usize {
        return self.entries.items.len;
    }

    fn keptCount(self: *const BackForwardCache) usize {
        var n: usize = 0;
        for (self.entries.items) |entry| {
            if (!entry.evicting) n += 1;
        }
        return n;
    }

    fn indexOfObject(self: *const BackForwardCache, object: *const anyopaque) ?usize {
        for (self.entries.items, 0..) |*entry, index| {
            if (entry.page.has(object)) return index;
        }
        return null;
    }

    /// Keep `page`, its tasks and timers suspended. The oldest pages beyond
    /// `size` are queued for eviction. False when nothing was kept.
    pub fn store(self: *BackForwardCache, page: KeptPage) bool {
        const loop = self.loop orelse return false;
        if (self.size == 0) return false;
        self.entries.ensureUnusedCapacity(self.allocator, 1) catch return false;
        // Its tasks wait in a group of their own; its timers stop.
        loop.suspendDocument(page.document, page.document_generation, page.window, page.window_generation) catch return false;
        dom.window_documents.suspendTimers(page.realm);
        self.entries.appendAssumeCapacity(.{ .page = page, .stored_at_ms = platform.monotonicMillis() });
        // Oldest first: the ones beyond the size go.
        var over = self.keptCount() -| self.size;
        for (self.entries.items) |*entry| {
            if (over == 0) break;
            if (entry.evicting) continue;
            self.queueEviction(entry);
            over -= 1;
        }
        self.armTtl();
        return true;
    }

    /// Take the page of `traversable` showing `document` out of the cache
    /// for a restore: its tasks and timers stay suspended until the restore
    /// resumes them (`resumePage`). Null for a page it does not hold, or one
    /// leaving it.
    pub fn take(self: *BackForwardCache, traversable: *anyopaque, document: *const anyopaque) ?KeptPage {
        for (self.entries.items, 0..) |entry, index| {
            if (entry.page.traversable != traversable) continue;
            if (@as(*const anyopaque, @ptrCast(entry.page.document)) != document) continue;
            if (entry.evicting) return null;
            // A page whose realm ended with its opener's is no page.
            if (!entry.page.realm.hasEngine()) return null;
            if (runtime.SlabAllocator.generationOf(entry.page.document) != entry.page.document_generation) return null;
            _ = self.entries.orderedRemove(index);
            self.armTtl();
            return entry.page;
        }
        return null;
    }

    /// A restored page's tasks run again - first, at the loop's next drain -
    /// and its timers wait what they had left (HTML "reactivate" step 2).
    pub fn resumePage(self: *BackForwardCache, page: *const KeptPage) void {
        if (self.loop) |loop| loop.resumeDocument(page.document, page.document_generation);
        dom.window_documents.resumeTimers(page.realm);
    }

    /// Whether `object` (a Window or a Document) is a page this cache holds.
    pub fn holds(self: *const BackForwardCache, object: *const anyopaque) bool {
        return self.indexOfObject(object) != null;
    }

    /// The page holding `object` leaves at a queued task, `reason` recorded
    /// for its document first.
    pub fn evictHolding(self: *BackForwardCache, object: *const anyopaque, reason: ?Reason) void {
        const index = self.indexOfObject(object) orelse return;
        const entry = &self.entries.items[index];
        if (entry.evicting) return;
        if (reason) |r| dom.bfcache.makeUnsalvageable(entry.page.document, r);
        self.queueEviction(entry);
    }

    /// Every page of `traversable` leaves now (its traversable is closing),
    /// queued evictions of them included.
    pub fn evictTraversable(self: *BackForwardCache, traversable: *anyopaque) void {
        var index: usize = 0;
        while (index < self.entries.items.len) {
            if (self.entries.items[index].page.traversable != traversable) {
                index += 1;
                continue;
            }
            self.evictAt(index);
            // `evictAt` removed it; the next one moved into its place. An
            // eviction's steps run no script, so nothing else moved.
        }
        self.armTtl();
    }

    /// Every page of `traversable` whose session history entry is gone -
    /// a push cleared the forward history - leaves now: HTML "clear the
    /// forward session history" destroys each removed entry's document.
    pub fn prune(self: *BackForwardCache, traversable: *anyopaque, context: *anyopaque, has_state: *const fn (context: *anyopaque, document_state: u64) bool) void {
        var index: usize = 0;
        while (index < self.entries.items.len) {
            const page = self.entries.items[index].page;
            if (page.traversable != traversable or has_state(context, page.document_state)) {
                index += 1;
                continue;
            }
            self.evictAt(index);
        }
        self.armTtl();
    }

    /// Every page leaves now: the page that opened them, or the Browser, is
    /// ending. Queued evictions run here too, and their tasks then find
    /// nothing.
    pub fn evictAll(self: *BackForwardCache) void {
        while (self.entries.items.len > 0) self.evictAt(0);
        self.cancelTtl();
    }

    /// Evict the page at `index` now: out of the list, its tasks dropped,
    /// then the navigation code's steps.
    fn evictAt(self: *BackForwardCache, index: usize) void {
        const entry = self.entries.orderedRemove(index);
        self.forgetQueued(entry.page.document);
        self.runEviction(entry.page);
    }

    fn runEviction(self: *BackForwardCache, page: KeptPage) void {
        // "Destroy a document" step 5: its tasks are removed without running.
        if (self.loop) |loop| loop.discardDocument(page.document, page.document_generation);
        page.steps.evict(&page);
    }

    /// Queue the eviction of `entry` as a task of the loop: never inside the
    /// step that asked (a store, a delivery), never inside the collector.
    fn queueEviction(self: *BackForwardCache, entry: *Entry) void {
        entry.evicting = true;
        const loop = self.loop orelse return;
        self.queued.ensureUnusedCapacity(self.allocator, 1) catch {
            // The task cannot be tracked: it stays queued by its flag, for
            // the next eviction that runs (evictAll at the latest).
            return;
        };
        const task = self.allocator.create(EvictionTask) catch return;
        task.* = .{ .cache = self, .document = entry.page.document, .generation = entry.page.document_generation };
        self.queued.appendAssumeCapacity(task);
        loop.eventLoop().queueTask(.{ .callback = &EvictionTask.run, .context = task, .drop = &EvictionTask.drop });
    }

    /// The queued eviction of `document`'s page has been run by other means.
    fn forgetQueued(self: *BackForwardCache, document: *const anyopaque) void {
        for (self.queued.items) |task| {
            if (task.document == document) task.done = true;
        }
    }

    fn removeQueued(self: *BackForwardCache, task: *EvictionTask) void {
        for (self.queued.items, 0..) |queued, index| {
            if (queued == task) {
                _ = self.queued.swapRemove(index);
                return;
            }
        }
    }

    // ------------------------------------------------------------------------
    // Ageing
    // ------------------------------------------------------------------------

    /// Arm the timer for the oldest page still kept, or disarm it when there
    /// is none.
    fn armTtl(self: *BackForwardCache) void {
        self.cancelTtl();
        const loop = self.loop orelse return;
        const timer = loop.timerInterface() orelse return;
        var oldest: ?i64 = null;
        for (self.entries.items) |entry| {
            if (entry.evicting) continue;
            oldest = if (oldest) |o| @min(o, entry.stored_at_ms) else entry.stored_at_ms;
        }
        const stored = oldest orelse return;
        const due = stored + @as(i64, @intCast(self.ttl_ms));
        const wait: u64 = @intCast(@max(0, due - platform.monotonicMillis()));
        self.ttl_timer = timer.setTimeout(wait, &ttlFired, self);
    }

    fn cancelTtl(self: *BackForwardCache) void {
        if (self.ttl_timer == 0) return;
        if (self.loop) |loop| if (loop.timerInterface()) |timer| {
            _ = timer.clearTimeout(self.ttl_timer);
        };
        self.ttl_timer = 0;
    }

    /// The ageing timer: a task of the loop. Every page older than the time
    /// to live leaves.
    fn ttlFired(data: ?*anyopaque) void {
        const self: *BackForwardCache = @ptrCast(@alignCast(data orelse return));
        self.ttl_timer = 0;
        const now = platform.monotonicMillis();
        var index: usize = 0;
        while (index < self.entries.items.len) {
            const entry = self.entries.items[index];
            if (now - entry.stored_at_ms >= @as(i64, @intCast(self.ttl_ms))) {
                self.evictAt(index);
            } else index += 1;
        }
        self.armTtl();
    }
};

/// A queued eviction (`queueEviction`): a task of the Browser's loop.
const EvictionTask = struct {
    cache: *BackForwardCache,
    document: *const anyopaque,
    generation: u64,
    /// Its page left by other means first (evictAll, a closing traversable).
    done: bool = false,

    fn run(data: ?*anyopaque) void {
        const self: *EvictionTask = @ptrCast(@alignCast(data orelse return));
        const cache = self.cache;
        defer cache.allocator.destroy(self);
        cache.removeQueued(self);
        if (self.done) return;
        const index = cache.indexOfObject(self.document) orelse return;
        cache.evictAt(index);
        cache.armTtl();
    }

    /// Never run: the loop ended. Browser.deinit evicted every page before
    /// (`evictAll`), so nothing is left to do but free the record.
    fn drop(data: ?*anyopaque) void {
        const self: *EvictionTask = @ptrCast(@alignCast(data orelse return));
        self.cache.removeQueued(self);
        self.cache.allocator.destroy(self);
    }
};

// ============================================================================
// dom.bfcache's Cache
// ============================================================================

/// The cache of the Browser `realm` belongs to, if it was made.
fn cacheOfRealm(realm: runtime.Context) ?*BackForwardCache {
    const scope = realm.browserScope() orelse return null;
    return scope.existing(BackForwardCache);
}

/// The cache of the Browser `object` (a Window or a Document) belongs to.
fn cacheOfObject(object: *const anyopaque) ?*BackForwardCache {
    const instance: *const runtime.Instance = @ptrCast(@alignCast(object));
    return cacheOfRealm(instance.ctx);
}

fn hookEnabled(realm: runtime.Context) bool {
    const cache = cacheOfRealm(realm) orelse return false;
    return cache.loop != null and cache.size > 0;
}

fn hookStore(page: KeptPage) bool {
    const cache = cacheOfRealm(page.realm) orelse return false;
    return cache.store(page);
}

fn hookTake(traversable: *anyopaque, document: *const anyopaque) ?KeptPage {
    const cache = cacheOfObject(document) orelse return null;
    return cache.take(traversable, document);
}

fn hookResume(page: *const KeptPage) void {
    const cache = cacheOfRealm(page.realm) orelse return;
    cache.resumePage(page);
}

fn hookEvictTaken(page: *const KeptPage) void {
    const cache = cacheOfRealm(page.realm) orelse return page.steps.evict(page);
    cache.runEviction(page.*);
}

fn hookHolds(object: *const anyopaque) bool {
    const cache = cacheOfObject(object) orelse return false;
    return cache.holds(object);
}

fn hookEvict(object: *const anyopaque, reason: ?Reason) void {
    const cache = cacheOfObject(object) orelse return;
    cache.evictHolding(object, reason);
}

fn hookEvictTraversable(realm: runtime.Context, traversable: *anyopaque) void {
    const cache = cacheOfRealm(realm) orelse return;
    cache.evictTraversable(traversable);
}

fn hookPrune(realm: runtime.Context, traversable: *anyopaque, context: *anyopaque, has_state: *const fn (context: *anyopaque, document_state: u64) bool) void {
    const cache = cacheOfRealm(realm) orelse return;
    cache.prune(traversable, context, has_state);
}

/// dom.bfcache's Cache, installed once at process start (Context.installHooks).
pub fn installHooks() void {
    dom.bfcache.installCache(.{
        .enabled = &hookEnabled,
        .store = &hookStore,
        .take = &hookTake,
        .resume_page = &hookResume,
        .evict_taken = &hookEvictTaken,
        .holds = &hookHolds,
        .evict = &hookEvict,
        .evict_traversable = &hookEvictTraversable,
        .prune = &hookPrune,
    });
}

/// Every page the Browser whose scope is `scope` keeps leaves now: the page
/// that opened them is about to end (Browser.navigate), or the Browser is
/// (Browser.deinit), while the loop and their opener's realm still live.
pub fn evictAllIn(scope: *runtime.BrowserScope) void {
    const cache = scope.existing(BackForwardCache) orelse return;
    cache.evictAll();
}
