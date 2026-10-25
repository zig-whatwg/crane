//! CSS Shadow1 §4.2: value-only tree identity. No global state or node holds.
//! The existing shadow_hosts hook carries owner-installed callbacks.
const runtime = @import("runtime");
const hosts = @import("shadow_hosts.zig");

/// A ShadowRoot serial; zero for the document scope. Borrowed for this call.
pub fn serialOf(root: *runtime.Instance) u64 {
    return hosts.scopeSerial(root);
}

/// ShadowRoot creation/adoption uses its node document's monotonic counter.
pub fn nextForDocument(document: *runtime.Instance) u64 {
    return hosts.nextScopeSerial(document);
}
