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

/// The user agent's storage shed and bucket file systems (Storage 4.3) of
/// the Browser `realm` belongs to, made on first use; null for a realm no
/// Browser made, or when it cannot be made (out of memory).
pub fn userAgentStorageOf(realm: runtime.Context) ?*storage.UserAgentStorage {
    const scope = realm.browser_scope orelse return null;
    return scope.of(storage.UserAgentStorage) catch null;
}
