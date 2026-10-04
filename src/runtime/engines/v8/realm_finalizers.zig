//! What a realm's end must finalize that no wrapper owns: the host data of
//! the promise reactions that have not run (engine.PromiseReactionSteps
//! .dropped, protocol_promises.zig) and of the asynchronous iterators still
//! alive (engine.AsyncIteratorSteps.finalize, protocol_async_iterator.zig).
//!
//! Each such record is a node on its realm's list - the realm's WrapperCache
//! keeps it (`WrapperCache.finalizers`), as Blink keeps per-context state on
//! V8PerContextData - and leaves it when it ends another way: its promise
//! settled, or the collector took it. The realm's end drains the list before
//! the realm's objects are torn down (context_manager.removeContextByKey),
//! and the wrapper cache's end drains it again as a safety net: each node
//! still there is unlinked and its `drop` runs, once.
//!
//! Single-threaded, like the realm: a list is reached only on the thread
//! that runs its realm.

const std = @import("std");
const runtime = @import("runtime");

const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

/// A record on a realm's list. Embedded in the record; `drop` finds the
/// record with @fieldParentPtr.
pub const Node = struct {
    prev: ?*Node = null,
    next: ?*Node = null,
    /// The list the node is on; null once it left.
    list: ?*List = null,
    /// The realm ended first: disarm what script could still reach, free the
    /// host's data and the record. Called with the node already unlinked.
    /// Never runs script; never runs while the engine collects.
    drop: *const fn (node: *Node) void,

    /// Leave the list, if on one. A node that is not on a list is left
    /// alone.
    pub fn unlink(self: *Node) void {
        const list = self.list orelse return;
        if (self.prev) |prev| prev.next = self.next else list.head = self.next;
        if (self.next) |next| next.prev = self.prev;
        self.prev = null;
        self.next = null;
        self.list = null;
        list.count -= 1;
    }
};

/// A realm's records.
pub const List = struct {
    head: ?*Node = null,
    count: usize = 0,
    /// The realm has ended (`drain` ran): nothing joins any more.
    ended: bool = false,

    /// Put `node` on the list. error.RealmEnded once the realm has ended:
    /// the caller still owns the record.
    pub fn add(self: *List, node: *Node) error{RealmEnded}!void {
        std.debug.assert(node.list == null);
        if (self.ended) return error.RealmEnded;
        node.prev = null;
        node.next = self.head;
        if (self.head) |head| head.prev = node;
        self.head = node;
        node.list = self;
        self.count += 1;
    }

    /// The realm ends: every node still here is unlinked and dropped, and
    /// nothing joins after. A drop that adds or unlinks nodes is fine: the
    /// list is re-read after each.
    pub fn drain(self: *List) void {
        self.ended = true;
        while (self.head) |node| {
            node.unlink();
            node.drop(node);
        }
    }
};

/// `realm`'s list: its wrapper cache's. Null for a realm with no wrapper
/// cache - a context a host made by hand (tests), or one already retired:
/// its records then end only when they settle or are collected.
pub fn listOf(realm: runtime.Context) ?*List {
    const storage = realm.getV8WrapperCacheStorage() orelse return null;
    const cache: *WrapperCache = @ptrCast(@alignCast(storage));
    return &cache.finalizers;
}
