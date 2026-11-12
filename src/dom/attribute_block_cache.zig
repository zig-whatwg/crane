//! A Document's shared attribute blocks: the cache its parsers share
//! through, and its lifetime (lane nd2 batch 5; plan-v2 A3's follow-up).
//!
//! Elements with equal attribute sets share one immutable block
//! (dom.element_data.AttributeList), which a parser gets from a content-keyed
//! table (dom.element_data.SharingCache). This file says whose table that
//! is and how long it lives. There is no spec for it - which elements share
//! is not web-observable - so the lifetime is the browsers':
//!
//! - Blink (third_party/blink/renderer/core/dom/document.cc, read at
//!   b9ac0a813a76): the Document owns the cache (`element_data_cache_`).
//!   Document::SetParsingState makes it when the document starts parsing
//!   (`if (Parsing() && !element_data_cache_)`), every Element::
//!   ParserSetAttributes of any parser - the document's own, innerHTML's -
//!   reads `GetDocument().GetElementDataCache()`, and Document::
//!   FinishedParsing starts `element_data_cache_clear_timer_` for 10 s, one
//!   shot: "We keep it alive for a while after parsing finishes so that
//!   dynamically inserted content can also benefit from sharing
//!   optimizations. Note that we don't refresh the timer on cache access
//!   since that could lead to huge caches being kept alive indefinitely by
//!   something innocuous like JS setting .innerHTML repeatedly on a timer."
//! - WebKit (Source/WebCore/dom/Document.cpp, read at c8c9cd5cec3f): the
//!   same, word for word - `m_sharedObjectPool`, made by Document::
//!   setParsing, read by Element::parserSetAttributes, dropped by
//!   `m_sharedObjectPoolClearTimer` 10 s after Document::finishedParsing
//!   (`timeToKeepSharedObjectPoolAliveAfterParsingFinished`).
//!
//! Here, as there: the cache is the DOCUMENT's (a pointer in its
//! InteractionState), every parser run of the document shares through it -
//! its own parse, document.write, the fragment parsers (innerHTML,
//! insertAdjacentHTML, createContextualFragment, setHTMLUnsafe), an XML
//! parse - and it goes 10 s after the document's parse ended, by a one-shot
//! timer that no access restarts. A run that is still going when the 10 s
//! are over keeps the cache until it ends (`Run`).
//!
//! CRANE'S MEMORY POLICY, where it differs (the integrator's ruling of
//! 2026-11-12; neither is observable):
//! 1. A parse after the cache has gone makes a new one, with 10 s of its
//!    own from the end of the run that made it. Blink and WebKit have no
//!    cache then, and a late innerHTML of a thousand equal rows shares
//!    nothing; batch 4's cache per parser run did share them, and this
//!    keeps that.
//! 2. So that a page setting innerHTML on a timer cannot make that the
//!    "huge cache" the engines' comment warns of, the table lets go of
//!    every block no element holds any more each time it would grow
//!    (SharingCache.grow), and a cache lives 10 s at most past its last
//!    run.
//!
//! The timer is a BACKGROUND timer (runtime.TimerVTable.
//! setBackgroundTimeout): armed, it is not pending work - a loop with
//! nothing else to do is idle, and a virtual clock does not move to it.
//! Blink's timer is a task on the document's task runner, which is weak to
//! its Document; a browser never ends because its loop went idle, where
//! Crane's hosts run a page until it has. A realm with no timers (an
//! engine-less test) cannot drop a cache later, so there the cache ends
//! with the run that would have armed it - batch 4's lifetime.
//!
//! OWNERSHIP. The cache block is held by up to three things, and freed when
//! the last lets go: its Document (`owner`, until the document's end or the
//! cache's), the parser runs sharing through it (`users`), and an armed
//! timer whose user data it is (`timer`). The Document's end
//! (document_state.InternalState.deinit) lets go of every block and clears
//! the timer; a clear the timer manager does not confirm leaves the block to
//! the timer (lesson architecture-only-confirmed-cancellation-returns-
//! payload-ownership), and a run still pinned leaves it to that run. The
//! timer is read from the document's realm at the moment it is armed, never
//! kept beyond the timer's own life: a retired realm has none
//! (runtime.Context stays valid and inert until its agent ends), and the
//! timer manager's end drops what is armed.
const std = @import("std");
const runtime = @import("runtime");
const element_data = @import("element_data.zig");
const document_state = @import("document_state.zig");

const SharingCache = element_data.SharingCache;

/// How long a Document's cache outlives its parse: Blink's
/// `element_data_cache_clear_timer_.StartOneShot(base::Seconds(10))`,
/// WebKit's `timeToKeepSharedObjectPoolAliveAfterParsingFinished { 10_s }`.
pub const keep_ms: u64 = 10 * std.time.ms_per_s;

/// What a parser run is, for the cache's timer.
pub const RunKind = enum {
    /// A document's own parse: the page's, a script-created parser's
    /// (document.open), DOMParser's, an XML document's. Its end starts the
    /// 10 s, again if they were running (Blink's Document::FinishedParsing
    /// starts the one-shot timer each time).
    document,
    /// A fragment parse into the document (innerHTML and the like): an
    /// access, which restarts nothing. Its end starts the 10 s only of a
    /// cache that has none running - one it made itself.
    fragment,
};

/// One Document's cache (the file's comment).
pub const DocumentCache = struct {
    /// The blocks, by content.
    blocks: SharingCache = .{},
    /// The Document's Browser's: its allocator made this block.
    scope: *runtime.BrowserScope,
    /// The Document's slot for this cache, while the Document has it; null
    /// once it let go - at its end, or the cache's.
    owner: ?*document_state.InteractionState,
    /// The Document, valid while `owner` is: its realm's timers arm the
    /// drop.
    document: *runtime.Instance,
    /// The armed drop's timers, while it is armed: the block is that
    /// timer's user data until it fires, is dropped with its manager, or a
    /// clearTimeout is confirmed.
    timer: ?runtime.TimerInterface = null,
    timer_id: runtime.TimerId = 0,
    /// The parser runs sharing through the cache now.
    users: u32 = 0,
    /// The 10 s ended while a run was using it: it goes with its last run.
    expired: bool = false,

    fn create(document: *runtime.Instance, owner: *document_state.InteractionState) error{OutOfMemory}!*DocumentCache {
        const scope = runtime.BrowserScope.ofInstance(document);
        const self = try scope.allocator.create(DocumentCache);
        self.* = .{ .scope = scope, .owner = owner, .document = document };
        owner.attribute_blocks = self;
        return self;
    }

    /// The Document lets go of the cache - its end, or the cache's: the
    /// table's holds on its blocks end (a block no element holds is freed),
    /// the armed timer is cleared, and the block is freed unless a run or an
    /// unconfirmed timer still points at it.
    pub fn end(self: *DocumentCache) void {
        if (self.owner) |owner| {
            std.debug.assert(owner.attribute_blocks == self);
            owner.attribute_blocks = null;
            self.owner = null;
        }
        self.blocks.deinit();
        if (self.timer) |timer| {
            // Only a confirmed clear hands the block back; otherwise the
            // timer frees it when it fires or is dropped.
            if (timer.clearTimeout(self.timer_id)) {
                self.timer = null;
                self.timer_id = 0;
            }
        }
        self.freeIfUnheld();
    }

    fn freeIfUnheld(self: *DocumentCache) void {
        if (self.owner != null or self.users != 0 or self.timer != null) return;
        self.scope.allocator.destroy(self);
    }

    /// Start the 10 s. False when the document's realm has no timers (or
    /// none that are background timers), or arming failed.
    fn arm(self: *DocumentCache) bool {
        std.debug.assert(self.timer == null and self.owner != null);
        const timer = self.document.ctx.getOptionalTimer() orelse return false;
        const id = timer.setBackgroundTimeout(keep_ms, fire, self, dropped);
        if (id == 0) return false;
        self.timer = timer;
        self.timer_id = id;
        return true;
    }

    /// The 10 s are over.
    fn fire(data: ?*anyopaque) void {
        const self: *DocumentCache = @ptrCast(@alignCast(data orelse return));
        self.timer = null;
        self.timer_id = 0;
        if (self.owner == null) return self.freeIfUnheld();
        // A run still shares through it: it goes when that run ends.
        if (self.users != 0) {
            self.expired = true;
            return;
        }
        self.end();
    }

    /// The timer manager ended with the drop armed: it will never fire. The
    /// Document's end - or its next run's - ends the cache.
    fn dropped(data: ?*anyopaque) void {
        const self: *DocumentCache = @ptrCast(@alignCast(data orelse return));
        self.timer = null;
        self.timer_id = 0;
        self.freeIfUnheld();
    }

    /// A run of `kind` stops sharing through the cache.
    fn leave(self: *DocumentCache, kind: RunKind) void {
        self.users -= 1;
        if (self.users != 0) return;
        if (self.owner == null) return self.freeIfUnheld();
        if (self.expired) return self.end();
        if (self.timer) |timer| {
            // The 10 s are running, and a fragment parse is an access: it
            // restarts nothing. A document's parse ended: they start again.
            if (kind == .fragment) return;
            if (!timer.clearTimeout(self.timer_id)) return;
            self.timer = null;
            self.timer_id = 0;
        }
        // No timer to drop it later: the cache ends with this run.
        if (!self.arm()) self.end();
    }
};

/// A parser run's share in its document's cache: `begin` when the run
/// starts, `blocks()` for each element it makes ("create an element for a
/// token": dom.element_attributes.setParsed), `end` on every path the run
/// ends by - finished, aborted, replaced, failed. Between the first
/// `blocks()` and `end` the cache stays, whatever its timer does.
pub const Run = struct {
    /// The document whose cache the run shares through, until the run has
    /// looked it up (once: `join`); null for a run with none.
    document: ?*runtime.Instance = null,
    /// `document`'s slab generation at `begin`: a scripted parser can
    /// outlive its document.
    generation: u64 = 0,
    kind: RunKind = .fragment,
    cache: ?*DocumentCache = null,

    /// A run of `kind` for `document` - the parsed document, or a fragment
    /// parse's context element's node document (whose cache a template's
    /// contents and a declarative shadow root, made by the same run, share
    /// through too). Null: the run's elements share nothing.
    pub fn begin(document: ?*runtime.Instance, kind: RunKind) Run {
        const doc = document orelse return .{};
        return .{ .document = doc, .generation = runtime.SlabAllocator.generationOf(doc), .kind = kind };
    }

    /// The table the run's next element takes its block from, or null: the
    /// element's list is then its own. The same table for the whole run,
    /// unless its document ends first.
    pub inline fn blocks(self: *Run) ?*SharingCache {
        if (self.cache) |cache| return if (cache.owner != null) &cache.blocks else null;
        if (self.document == null) return null;
        return self.join();
    }

    /// The run's first element with attributes: find the document's cache,
    /// or make it. Once a run - a failure leaves the run with none.
    noinline fn join(self: *Run) ?*SharingCache {
        const document = self.document.?;
        self.document = null;
        if (runtime.SlabAllocator.generationOf(document) != self.generation) return null;
        const state = document_state.Registry.get(document) orelse return null;
        const shared = state.ensureInteractionState() catch return null;
        const cache = shared.attribute_blocks orelse (DocumentCache.create(document, shared) catch return null);
        cache.users += 1;
        self.cache = cache;
        return &cache.blocks;
    }

    /// The run is over. Safe to call again, and for a run that never
    /// shared.
    pub fn end(self: *Run) void {
        self.document = null;
        const cache = self.cache orelse return;
        self.cache = null;
        cache.leave(self.kind);
    }
};

/// The cache `document` has now, if any: for tests and memory reports.
pub fn of(document: *runtime.Instance) ?*const DocumentCache {
    const state = document_state.Registry.get(document) orelse return null;
    const shared = state.interaction_state orelse return null;
    return shared.attribute_blocks;
}
