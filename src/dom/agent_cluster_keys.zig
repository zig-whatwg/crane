//! Whether a similar-origin window agent's cluster is origin-keyed: HTML's
//! `Origin-Agent-Cluster` header (7.1.2 "Origin-keyed agent clusters") and
//! each browsing context group's historical agent cluster key map (8.1.2.2
//! "obtain a similar-origin window agent" steps 3-5).
//!
//! The navigation that creates a document decides its origin's keying in its
//! browsing context group ("create and initialize a Document object" step 7:
//! requestsOAC, then `obtain`), and the first decision for an origin holds for
//! the group's life. Window.originAgentCluster, document.domain's setter (step
//! 6) and the engine's agent cluster key (html.agent_clusters) read it back
//! with `isOriginKeyed`. The map is append-only for a group, so reading it
//! later answers what the document's creation decided.
//!
//! Crane's browsing context groups are ids on browsing contexts
//! (`BrowsingContext.virtual_group_id`) with no object of their own, so every
//! group's map is kept in one table per Browser (a BrowserScope supplement),
//! by group id. A group ends when none of its browsing contexts is live, and
//! its map goes with the next decision recorded (`forgetEndedGroups`).
//!
//! As Gecko keeps it: BrowsingContextGroup::mUseOriginAgentCluster, a map of
//! principal to bool, filled once per principal by
//! SetUseOriginAgentClusterFromNetwork and read by UsesOriginAgentCluster,
//! which answers true without the map for a principal that is always
//! origin-keyed or a cross-origin isolated group.
//!
//! Design ported from lane serial's unfinished 5e9e708c84 (never gated): the
//! map as a BrowserScope supplement keyed by group and origin, and
//! requestsOAC's two conditions. Its whole-Browser lifetime, its hand-rolled
//! `?1` match and its origin-only secure context are not kept.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#origin-keyed-agent-clusters
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#obtain-similar-origin-window-agent
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#initialise-the-document-object

const std = @import("std");
const runtime = @import("runtime");
const fetch = @import("fetch");
const Navigables = @import("html_core").Navigables;
const browser_state = @import("browser_state.zig");

/// Every live browsing context group's historical agent cluster key map: by
/// group id, whether each origin's agent cluster key is the origin (true) or
/// its site (false). A BrowserScope supplement, made on first use; guarded by
/// its own mutex (a worker thread may read a window realm's keying through
/// html.agent_clusters).
pub const HistoricalKeys = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    groups: std.AutoHashMapUnmanaged(u64, Origins) = .empty,

    /// One group's map, by serialized origin; the keys are owned.
    const Origins = std.StringHashMapUnmanaged(bool);

    pub fn init(allocator: std.mem.Allocator) HistoricalKeys {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *HistoricalKeys) void {
        var groups = self.groups.valueIterator();
        while (groups.next()) |origins| freeOrigins(self.allocator, origins);
        self.groups.deinit(self.allocator);
    }

    /// "Obtain a similar-origin window agent" steps 4-5 for `origin` in group
    /// `group`: whether its key is the origin - map[origin] when it exists,
    /// else requestsOAC, recorded. Out of memory, the request alone answers
    /// and nothing is recorded.
    pub fn obtain(self: *HistoricalKeys, group: u64, origin: []const u8, requests_oac: bool) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const entry = self.groups.getOrPut(self.allocator, group) catch return requests_oac;
        if (!entry.found_existing) entry.value_ptr.* = .empty;
        // 4. "Otherwise, if group's historical agent cluster key map[origin]
        // exists, then set key to group's historical agent cluster key
        // map[origin]."
        if (entry.value_ptr.get(origin)) |origin_keyed| return origin_keyed;
        // 5.1. "If requestsOAC is true, then set key to origin." 5.2. "Set
        // group's historical agent cluster key map[origin] to key."
        const key = self.allocator.dupe(u8, origin) catch return requests_oac;
        entry.value_ptr.put(self.allocator, key, requests_oac) catch self.allocator.free(key);
        return requests_oac;
    }

    /// Group `group`'s map[origin], if a document of `origin` was created
    /// there.
    pub fn get(self: *HistoricalKeys, group: u64, origin: []const u8) ?bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const origins = self.groups.getPtr(group) orelse return null;
        return origins.get(origin);
    }

    /// Forget the map of every group but `keep` that has ended: one none of
    /// whose browsing contexts is on `navigables`, the Browser's list. "The
    /// historical agent cluster key map only ever gains entries over the
    /// lifetime of the browsing context group" - and goes with it.
    pub fn forgetEndedGroups(self: *HistoricalKeys, keep: u64, navigables: *const Navigables) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        // Collected, then removed: the map is not changed under its iterator.
        while (true) {
            var ended: [16]u64 = undefined;
            var count: usize = 0;
            var groups = self.groups.keyIterator();
            while (groups.next()) |group| {
                if (group.* == keep or isGroupLive(navigables, group.*)) continue;
                ended[count] = group.*;
                count += 1;
                if (count == ended.len) break;
            }
            for (ended[0..count]) |group| {
                var removed = self.groups.fetchRemove(group) orelse continue;
                freeOrigins(self.allocator, &removed.value);
            }
            if (count < ended.len) return;
        }
    }

    fn freeOrigins(allocator: std.mem.Allocator, origins: *Origins) void {
        var keys = origins.keyIterator();
        while (keys.next()) |key| allocator.free(key.*);
        origins.deinit(allocator);
    }
};

/// "Create and initialize a Document object" steps 7.1-7.3: requestsOAC
/// for a response whose `Origin-Agent-Cluster` header list value is `header`
/// (null: none), in a reserved environment that is a secure context or not
/// (`secure`, `isSecureTopLevelCreationUrl`).
///
/// "1. Let oacHeader be the result of getting a structured field value given
/// `Origin-Agent-Cluster` and "item" from navigationParams's response's
/// header list. 2. Let requestsOAC be true if oacHeader is not null and
/// oacHeader[0] is the boolean true; otherwise false. 3. If navigationParams's
/// reserved environment is a non-secure context, then set requestsOAC to
/// false."
pub fn requestsOAC(allocator: std.mem.Allocator, header: ?[]const u8, secure: bool) bool {
    const value = header orelse return false;
    // A value that does not parse as one item is null (Fetch "get a
    // structured field value" step 5). Out of memory, it is not asked for.
    const boolean = fetch.internal.structured_fields.parseItemBoolean(allocator, value) catch return false;
    if (boolean != true) return false;
    return secure;
}

/// HTML 8.1.3.5 "secure context" for a reserved environment - a navigation's,
/// before it is an environment settings object - whose top-level creation
/// URL is `url`: step 2, "Is url potentially trustworthy?" (Secure Contexts
/// 3.2, which Mixed Content's a priori authenticated URL is). A top-level
/// navigation's top-level creation URL is its own URL; a child navigable's is
/// its parent environment's.
pub fn isSecureTopLevelCreationUrl(allocator: std.mem.Allocator, url: []const u8) bool {
    return fetch.mixed_content.isAPrioriAuthenticated(allocator, url) catch false;
}

/// "Obtain a similar-origin window agent" for a document of `origin`
/// (serialized) created in browsing context group `group` of a Browser
/// (`scope`), given requestsOAC: whether its agent cluster is origin-keyed
/// (step 6.3: its key is an origin), recorded for the group.
///
/// Steps 1-2: an opaque origin's site is the origin itself - always
/// origin-keyed, and recorded nowhere: no other document has that origin.
/// Step 3: a cross-origin isolated group keys by origin without the map.
/// With no scope (a realm no Browser made) nothing is recorded.
pub fn obtain(scope: ?*runtime.BrowserScope, group: u64, origin: []const u8, requests_oac: bool, cross_origin_isolated: bool) bool {
    if (isOpaque(origin)) return true;
    if (cross_origin_isolated) return true;
    const browser = scope orelse return requests_oac;
    const keys = browser.of(HistoricalKeys) catch return requests_oac;
    // A Browser that has made no browsing context yet can tell no group has
    // ended.
    if (browser_state.existingNavigablesIn(browser)) |navigables| keys.forgetEndedGroups(group, navigables);
    return keys.obtain(group, origin, requests_oac);
}

/// Whether the agent cluster of a window in browsing context group `group`
/// whose document's origin is `origin` (serialized) is origin-keyed - what
/// `obtain` decided when a document of that origin was created there; true
/// for an opaque origin and in a cross-origin isolated group. An origin no
/// document recorded (a realm no navigation made) is site-keyed.
pub fn isOriginKeyed(scope: ?*runtime.BrowserScope, group: u64, origin: []const u8, cross_origin_isolated: bool) bool {
    if (isOpaque(origin)) return true;
    if (cross_origin_isolated) return true;
    const browser = scope orelse return false;
    const keys = browser.existing(HistoricalKeys) orelse return false;
    return keys.get(group, origin) orelse false;
}

/// A group is live while one of its browsing contexts is - a closed or
/// orphaned one included: a Window can still read its keying. Asked on the
/// window agent's thread, which makes and frees every browsing context of
/// the Browser; a list with none answers that every group is live, so
/// nothing is forgotten by a Browser that cannot tell.
fn isGroupLive(navigables: *const Navigables, group: u64) bool {
    const contexts = navigables.contexts();
    if (contexts.len == 0) return true;
    for (contexts) |context| {
        if (context.virtual_group_id == group) return true;
    }
    return false;
}

fn isOpaque(origin: []const u8) bool {
    return origin.len == 0 or std.mem.eql(u8, origin, "null");
}
