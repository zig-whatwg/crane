//! Host-side state owned by one agent, freed after the agent is destroyed.
const std = @import("std");
const dom = @import("dom");

pub const AgentHost = struct {
    indexeddb_cleanup: dom.indexeddb.CleanupList,
    event_sources: @import("eventsource").Registry(*anyopaque, *anyopaque),
    media_elements: @import("media/root.zig").Registry(*anyopaque, *anyopaque),
    custom_elements: dom.custom_elements.AgentState,
    embedded_contents: @import("eventsource").Registry(*anyopaque, *anyopaque),
    hyperlink_pings: @import("eventsource").Registry(*anyopaque, *anyopaque),
    /// The agent's queue of native objects whose last owner went away - the
    /// nodes whose wrappers the collector took (engine.AgentOptions.
    /// deferred_teardown) - freed a slice at a time by the agent's event
    /// loop, and fully at the ends of their realms and of the agent.
    deferred_teardown: dom.tree_teardown.DeferredTeardown,
    /// The zombie audit's books (refcount step 6, dom.refcount_audit): what
    /// the agent's trees the counts called garbage were read after their
    /// teardown slice. Empty unless CRANE_REFCOUNT_AUDIT is on; its end
    /// prints the totals.
    refcount_audit: dom.refcount_audit.Audit,
    /// The rejected-promise bookkeeping of every global of the agent's
    /// realms (html.rejected_promises; each entry its `*Tracked`, OWNED by
    /// it): the agent's handles, read and released only on the agent's
    /// thread, and released before the agent ends
    /// (`rejected_promises.releaseAgent`) - so empty here at `deinit`.
    rejections: std.ArrayListUnmanaged(*anyopaque) = .empty,
    /// The agent cluster a dedicated worker's agent is in - its owner's
    /// (HTML "obtain a worker/worklet agent" step 3) - as the worker host
    /// records it when it obtains the agent (html.agent_clusters.ofRealm on
    /// the owner's thread); 0 when none is known. Read by
    /// html.agent_clusters.agentClusterOf.
    agent_cluster: u64 = 0,
    /// The agent's fetches on its event loop - its network scheduler and
    /// every fetch in flight (fetch.algorithms.AgentFetches): pumped by the
    /// agent's loop, on its thread only; reached from a realm through its
    /// agent (dom.agent_fetches). Its realms' ends swept what they left.
    fetches: @import("fetch").algorithms.AgentFetches,
    /// The script-queue drains nested on the agent's stack
    /// (html.script_execution: the "as soon as possible" queues and the
    /// scripts that run when parsing finishes). Read and written only on the
    /// agent's thread, inside a drain.
    script_drain: ScriptDrain = .{},
    /// The [[HostDefined]] records of the classic scripts the agent's
    /// documents ran (html.script_execution): the set an import()'s
    /// referrer is looked up in before it is read. Linked and unlinked only
    /// on the agent's thread.
    classic_scripts: ClassicScripts = .{},
    /// The agent's forms whose past names map has entries
    /// (dom.form_past_names): told of every change that can give one of
    /// their elements another form owner. Read and written only on the
    /// agent's thread.
    form_past_names: dom.form_past_names.Registry,

    pub fn init(allocator: std.mem.Allocator) AgentHost {
        return .{
            .fetches = @import("fetch").algorithms.AgentFetches.init(allocator),
            .indexeddb_cleanup = dom.indexeddb.CleanupList.init(allocator),
            .event_sources = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
            .media_elements = @import("media/root.zig").Registry(*anyopaque, *anyopaque).init(allocator),
            .custom_elements = dom.custom_elements.AgentState.init(allocator),
            .embedded_contents = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
            .hyperlink_pings = @import("eventsource").Registry(*anyopaque, *anyopaque).init(allocator),
            .deferred_teardown = dom.tree_teardown.DeferredTeardown.init(allocator),
            .refcount_audit = dom.refcount_audit.Audit.init(allocator),
            .form_past_names = dom.form_past_names.Registry.init(allocator),
        };
    }
    /// After the agent's end, which emptied and closed the queue.
    pub fn deinit(self: *AgentHost) void {
        // Released while the agent lived: its promises were its handles.
        std.debug.assert(self.rejections.items.len == 0);
        self.classic_scripts.deinit();
        self.form_past_names.deinit();
        self.deferred_teardown.deinit();
        self.refcount_audit.deinit();
        self.indexeddb_cleanup.deinit();
        self.event_sources.deinit();
        self.media_elements.deinit();
        self.custom_elements.deinit();
        self.embedded_contents.deinit();
        self.hyperlink_pings.deinit();
        // After the agent's end: the scheduler's multi handle closes, which
        // touches no engine.
        self.fetches.deinit();
    }
};

/// One agent's nested script-queue drains (html.script_execution
/// `DrainScope`). A drain runs scripts on its agent's thread, and a script it
/// runs can insert another script and ask for a drain of its own - which
/// nests on the same agent's stack, whatever document it is for. So the
/// state is the agent's: V8 keeps "is running microtasks" and the microtasks
/// scope depth on each MicrotaskQueue (src/execution/microtask-queue.h,
/// `is_running_microtasks_`, `microtasks_depth_`), the queue Blink's
/// per-agent EventLoop owns (platform/scheduler/public/event_loop.h). It was
/// one pair of process-wide variables, and two Browsers' drains on two
/// threads interleaved on them (docs/instances.md).
pub const ScriptDrain = struct {
    /// The document the innermost drain walks - an identity, compared and
    /// never read through: a script the drain runs can end it.
    document: ?*const anyopaque = null,
    /// How many drains are nested on the agent's stack.
    depth: usize = 0,
};

/// The [[HostDefined]] records of one agent's classic scripts
/// (html.script_execution `ClassicScriptRecord`, which embeds a `Link`).
/// A document's module map owns each record and frees it with the document;
/// this only links them, so that a [[HostDefined]] the engine hands back - an
/// import()'s referrer - is read only while its record exists.
///
/// The agent's, because only the agent's own realms run its scripts'
/// functions, so only they can hand one of its records back: a script's
/// functions run on its agent's thread, which is the only thread that links,
/// unlinks or walks the list. Blink keeps the same information - a copy of
/// the referencing script's base URL and fetch options, ReferrerScriptInfo
/// (bindings/core/v8/referrer_script_info.h) - in the script's V8
/// host-defined options, on the agent's own heap. It was one process-wide
/// list, linked and unlinked from every Browser's thread with no lock, and
/// two Browsers running classic scripts at once dropped each other's records
/// from it (tests/html/instances_classic_scripts_test.zig).
pub const ClassicScripts = struct {
    records: std.DoublyLinkedList = .{},

    /// What a record embeds to be in a list.
    pub const Link = struct {
        node: std.DoublyLinkedList.Node = .{},
        /// The list the record is in; null when it is in none - not linked
        /// yet, unlinked, or outlived by its agent's host.
        list: ?*ClassicScripts = null,

        /// The next record in its list, for a walk from `first`.
        pub fn next(self: *const Link) ?*Link {
            const node = self.node.next orelse return null;
            return @fieldParentPtr("node", node);
        }
    };

    pub fn add(self: *ClassicScripts, link: *Link) void {
        std.debug.assert(link.list == null);
        self.records.prepend(&link.node);
        link.list = self;
    }

    /// Take `link` out of its list, if it is in one.
    pub fn remove(link: *Link) void {
        const list = link.list orelse return;
        list.records.remove(&link.node);
        link.list = null;
    }

    /// The most recently added record, or null.
    pub fn first(self: *const ClassicScripts) ?*Link {
        const node = self.records.first orelse return null;
        return @fieldParentPtr("node", node);
    }

    /// At the end of the agent's host: every record still linked - its
    /// document not yet freed - forgets the list, so freeing it later
    /// unlinks it from nothing.
    fn deinit(self: *ClassicScripts) void {
        while (self.records.popFirst()) |node| {
            const link: *Link = @fieldParentPtr("node", node);
            link.list = null;
        }
    }
};

test "a classic script record is in its agent's list from add until remove, and the host's end orphans the rest" {
    var list: ClassicScripts = .{};
    var a: ClassicScripts.Link = .{};
    var b: ClassicScripts.Link = .{};
    list.add(&a);
    list.add(&b);
    try std.testing.expectEqual(&b, list.first().?);
    try std.testing.expectEqual(&a, b.next().?);
    try std.testing.expect(a.next() == null);

    ClassicScripts.remove(&b);
    try std.testing.expect(b.list == null);
    try std.testing.expectEqual(&a, list.first().?);
    // Removing a link that is in no list does nothing.
    ClassicScripts.remove(&b);

    list.deinit();
    try std.testing.expect(a.list == null);
    try std.testing.expect(list.first() == null);
    // A record freed after its host's end unlinks from nothing.
    ClassicScripts.remove(&a);
}
