//! The Browser's web state, as a realm reaches it: supplements of its scope
//! (runtime.BrowserScope; docs/instances.md rule 2, "reach state through the
//! realm you run in"). A platform object's relevant realm is `instance.ctx`;
//! code running script asks its current realm.
//!
//! Each store here is defined by a module that cannot import runtime (runtime
//! imports storage, and the file module is a leaf), so the step from a realm
//! to its Browser's store lives here, once, for every caller: the bindings,
//! fetch's scheme fetch, the unloading cleanup steps.
//!
//! A realm no Browser made (a unit test's) has no scope, and no store: each
//! accessor answers null, and its caller does what the spec says when the
//! user agent has no such storage.

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");
const storage = @import("storage");
const file = @import("file");
const html_core = @import("html_core");
const fetch = @import("fetch");

pub const UserAgentStorage = storage.UserAgentStorage;
pub const BlobURLStore = file.BlobURLStore;
pub const Navigables = html_core.Navigables;
pub const BrowsingContext = html_core.BrowsingContext;
pub const NetworkContext = fetch.network.NetworkContext;
/// A tab's scope (docs/instances.md rule 2), for the layers that import no
/// runtime (html_core's browsing contexts).
pub const TabScope = runtime.TabScope;

const log = std.log.scoped(.browser_state);

/// The browsing contexts of the Browser `realm` belongs to (a side table of
/// its scope), made on first use; null for a realm of no Browser - no scope,
/// not even the standalone one - or out of memory. A frame's realm and a
/// popup's carry their page's scope, so their contexts are on one list.
/// Read on the Browser's window agent thread only (Navigables), which a
/// Debug build checks (`checkWindowAgentThread`).
pub fn navigablesOf(realm: runtime.Context) ?*Navigables {
    const scope = realm.browserScope() orelse return null;
    checkWindowAgentThread(scope);
    return scope.table(.navigables, Navigables) catch null;
}

/// `scope`'s browsing contexts if it made any list; never makes one. The
/// window agent's thread only, as `navigablesOf`.
pub fn existingNavigablesIn(scope: *runtime.BrowserScope) ?*Navigables {
    checkWindowAgentThread(scope);
    return scope.existingTable(.navigables, Navigables);
}

/// Debug: a Browser's browsing contexts are read on its window agent's
/// thread alone - the thread whose agent claimed the Browser's DOM memory
/// (runtime.gc.ExternalMemory.claim), which makes, discards and frees every
/// browsing context. A read from any other thread - a worker's realm, whose
/// end runs on the worker's thread - races those changes: lane crash1's
/// crash, a worker's end walking the list while the window agent removed
/// frames, panicked "incorrect alignment" once in a 13,683-file sweep. Here
/// it fails on every such read, in the unit tests and the bug-finding
/// runner (Crane's modules in Debug), whatever the timing. A scope no agent
/// has claimed (an engine-less test's, a Browser's end after its agent let
/// go) is not checked, as its DOM memory is not (element_name's
/// checkOwnerThread, the same check for element names).
fn checkWindowAgentThread(scope: *runtime.BrowserScope) void {
    if (comptime !debug_checks or @TypeOf(scope.dom_memory.thread) == void) return;
    const owner = scope.dom_memory.thread orelse return;
    const current = std.Thread.getCurrentId();
    if (owner == current) return;
    log.err("a Browser's browsing contexts were read on thread {d}; its window agent's thread is {d}", .{ current, owner });
    @panic("a Browser's browsing contexts were read on a thread other than its window agent's");
}

const debug_checks = builtin.mode == .debug;

/// The browsing context whose active window is `window` (HTML: the
/// Window's browsing context, while it is the active window of one), on
/// its Browser's list. `window` is live: its realm is read.
pub fn browsingContextOf(window: *runtime.Instance) ?*BrowsingContext {
    const navigables = navigablesOf(window.ctx) orelse return null;
    return navigables.ofWindow(@ptrCast(window));
}

/// The network context (fetch.network.NetworkContext) of the Browser `realm`
/// belongs to: its connections, TLS options and WebSocket gate, which every
/// request of its realms - windows, frames, workers - carries. Null for a
/// realm no Browser made (no scope, or out of memory): its requests use the
/// defaults and share nothing.
pub fn networkOf(realm: runtime.Context) ?*NetworkContext {
    const scope = realm.browserScope() orelse return null;
    return scope.of(NetworkContext) catch null;
}

/// The user agent's storage shed and bucket file systems (Storage 4.3) of
/// the Browser `realm` belongs to, made on first use; null for a realm no
/// Browser made, or when it cannot be made (out of memory).
pub fn userAgentStorageOf(realm: runtime.Context) ?*storage.UserAgentStorage {
    const scope = realm.browser_scope orelse return null;
    return scope.of(storage.UserAgentStorage) catch null;
}

/// The tab `realm` belongs to (runtime.TabScope.ofRealm): a Window realm's,
/// its frames' and an isolated world's; null for a worker's, or a realm no
/// Browser tab made.
pub fn tabOf(realm: runtime.Context) ?*TabScope {
    return TabScope.ofRealm(realm);
}

/// The storage shed of the top-level traversable `realm`'s Window is in -
/// session storage (Storage 4.3: "a traversable navigable holds a storage
/// shed") - its tab's, made on first use. Null for a realm of no tab, a tab
/// that has closed, or out of memory: "the user agent is configured to not
/// allow" session storage there.
pub fn sessionStorageShedOf(realm: runtime.Context) ?*storage.StorageShed {
    const tab = TabScope.ofRealm(realm) orelse return null;
    return sessionStorageShedIn(tab);
}

/// `tab`'s storage shed, made on first use. Null for a closed tab or out of
/// memory.
pub fn sessionStorageShedIn(tab: *TabScope) ?*storage.StorageShed {
    if (tab.get(.session_storage, storage.StorageShed)) |shed| return shed;
    if (tab.closed) return null;
    const shed = tab.allocator.create(storage.StorageShed) catch return null;
    shed.* = storage.initTraversableStorageShed(tab.allocator);
    if (!tab.put(.session_storage, storage.StorageShed, shed)) return null;
    return shed;
}

/// The user agent's blob URL store (File API 8.1) of the Browser `realm`
/// belongs to, made on first use: URL.createObjectURL adds to it, and a
/// request's client carries it to scheme fetch "blob". Null for a realm no
/// Browser made, or out of memory.
pub fn blobURLStoreOf(realm: runtime.Context) ?*file.BlobURLStore {
    const scope = realm.browser_scope orelse return null;
    return scope.of(file.BlobURLStore) catch null;
}

/// `realm`'s Browser's blob URL store if it made one; never makes one (a
/// revoke, or an environment's end, in a Browser that never made a blob URL
/// has nothing to remove).
pub fn existingBlobURLStoreOf(realm: runtime.Context) ?*file.BlobURLStore {
    const scope = realm.browser_scope orelse return null;
    return scope.existing(file.BlobURLStore);
}

/// Cross-thread snapshot of each tab's DevTools/BiDi UA, extra-header, and
/// network overrides (`BrowsingContext.host_overrides`), stored as a supplement
/// on `BrowserScope`. Updated on the window thread whenever a tab's overrides
/// change or when a Window spawns a worker; read on worker threads under
/// `mutex` so nested worker main-script requests inherit the ancestor frame's
/// current `user_agent`, `accept_language`, `extra_headers`, and network
/// conditions (matching Blink's `OnWorkerMainScriptRequestWillBeSent`).
pub const TabOverrideStore = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    /// tab_id (top-level BrowsingContext.id) -> owned OverrideSnapshot (or null when cleared).
    /// Entries are overwritten in place rather than removed so the map accumulates no tombstones.
    tabs: std.AutoHashMapUnmanaged(u64, ?*fetch.internal.request.OverrideSnapshot) = .empty,
    /// ancestor Window realm pointer (opaque key, never dereferenced) -> tab_id.
    realm_tabs: std.AutoHashMapUnmanaged(usize, u64) = .empty,

    pub fn init(allocator: std.mem.Allocator) TabOverrideStore {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TabOverrideStore) void {
        var it = self.tabs.valueIterator();
        while (it.next()) |slot| if (slot.*) |snap| snap.destroy(self.allocator);
        self.tabs.deinit(self.allocator);
        self.realm_tabs.deinit(self.allocator);
    }

    /// Publish `tab_id`'s current host overrides from the window thread.
    pub fn publish(scope: *runtime.BrowserScope, tab_id: u64, overrides: *const html_core.window.host_overrides.HostOverrides) void {
        const store = scope.of(TabOverrideStore) catch return;
        const next = fetch.internal.request.OverrideSnapshot.createWithNetwork(
            store.allocator,
            overrides.user_agent,
            overrides.accept_language,
            overrides.extra_headers,
            overrides.network_offline,
            overrides.network_rules,
        ) catch return;
        std.Io.Threaded.mutexLockUncancelable(&store.mutex);
        defer std.Io.Threaded.mutexUnlock(&store.mutex);
        const gop = store.tabs.getOrPut(store.allocator, tab_id) catch {
            if (next) |snap| snap.destroy(store.allocator);
            return;
        };
        if (gop.found_existing) if (gop.value_ptr.*) |old| old.destroy(store.allocator);
        gop.value_ptr.* = next;
    }

    /// Associate an ancestor Window realm pointer (opaque key) with its top-level `tab_id`.
    pub fn bindRealm(scope: *runtime.BrowserScope, realm_key: *const anyopaque, tab_id: u64) void {
        const store = scope.of(TabOverrideStore) catch return;
        std.Io.Threaded.mutexLockUncancelable(&store.mutex);
        defer std.Io.Threaded.mutexUnlock(&store.mutex);
        store.realm_tabs.put(store.allocator, @intFromPtr(realm_key), tab_id) catch {};
    }

    /// Look up the top-level `tab_id` recorded for an ancestor Window realm key (any thread).
    pub fn tabForRealm(scope: *runtime.BrowserScope, realm_key: *const anyopaque) ?u64 {
        const store = scope.existing(TabOverrideStore) orelse return null;
        std.Io.Threaded.mutexLockUncancelable(&store.mutex);
        defer std.Io.Threaded.mutexUnlock(&store.mutex);
        return store.realm_tabs.get(@intFromPtr(realm_key));
    }

    /// Copy `tab_id`'s current override snapshot into `request` under the lock (any thread).
    /// Returns true whenever `TabOverrideStore` owns the tab's state (including when overrides
    /// were cleared, leaving `request.override_snapshot == null`), false if no store exists.
    pub fn copyIntoRequest(scope_ptr: *anyopaque, tab_id: u64, request: *fetch.internal.InternalRequest) std.mem.Allocator.Error!bool {
        const scope: *runtime.BrowserScope = @ptrCast(@alignCast(scope_ptr));
        const store = scope.existing(TabOverrideStore) orelse return false;
        std.Io.Threaded.mutexLockUncancelable(&store.mutex);
        defer std.Io.Threaded.mutexUnlock(&store.mutex);
        const slot = store.tabs.get(tab_id) orelse return false;
        if (slot) |snap| {
            try request.setOverrideSnapshotWithNetwork(
                snap.user_agent,
                snap.accept_language,
                snap.extra_headers,
                snap.network_offline,
                snap.network_rules,
            );
        } else if (request.override_snapshot) |old| {
            old.destroy(request.allocator);
            request.override_snapshot = null;
        }
        return true;
    }
};
