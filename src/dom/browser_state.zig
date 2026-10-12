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

const runtime = @import("runtime");
const storage = @import("storage");
const file = @import("file");
const html_core = @import("html_core");

pub const UserAgentStorage = storage.UserAgentStorage;
pub const BlobURLStore = file.BlobURLStore;
pub const Navigables = html_core.Navigables;
pub const BrowsingContext = html_core.BrowsingContext;

/// The browsing contexts of the Browser `realm` belongs to (a side table of
/// its scope), made on first use; null for a realm of no Browser - no scope,
/// not even the standalone one - or out of memory. A frame's realm and a
/// popup's carry their page's scope, so their contexts are on one list.
/// Read on the Browser's window agent thread only (Navigables).
pub fn navigablesOf(realm: runtime.Context) ?*Navigables {
    const scope = realm.browserScope() orelse return null;
    return scope.table(.navigables, Navigables) catch null;
}

/// `scope`'s browsing contexts if it made any list; never makes one.
pub fn existingNavigablesIn(scope: *runtime.BrowserScope) ?*Navigables {
    return scope.existingTable(.navigables, Navigables);
}

/// The browsing context whose active window is `window` (HTML: the
/// Window's browsing context, while it is the active window of one), on
/// its Browser's list. `window` is live: its realm is read.
pub fn browsingContextOf(window: *runtime.Instance) ?*BrowsingContext {
    const navigables = navigablesOf(window.ctx) orelse return null;
    return navigables.ofWindow(@ptrCast(window));
}

/// The user agent's storage shed and bucket file systems (Storage 4.3) of
/// the Browser `realm` belongs to, made on first use; null for a realm no
/// Browser made, or when it cannot be made (out of memory).
pub fn userAgentStorageOf(realm: runtime.Context) ?*storage.UserAgentStorage {
    const scope = realm.browser_scope orelse return null;
    return scope.of(storage.UserAgentStorage) catch null;
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
