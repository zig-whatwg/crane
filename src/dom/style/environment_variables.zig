//! CSS Environment Variables 1 §3: document-bound host values for env().
//! The cascade owns substitution and fallback; this provider supplies owned
//! CSS token text and the revision the existing style hook observes.
//!
//! lint-impls: hook for PlatformState

const std = @import("std");
const runtime = @import("runtime");
const values = @import("css").environment_variables;
const hooks = @import("hooks.zig");

pub const Variable = values.Variable;

/// The HTML owner installs these callbacks once at process start. They read
/// only the given document's Browser and retain no object or platform state.
pub const Hooks = struct {
    value: ?*const fn (document: *runtime.Instance, variable: Variable, x: u32, y: u32) ?f64 = null,
    revision: ?*const fn (document: *runtime.Instance) u64 = null,
};

/// The HTML-owned callbacks share the existing process-start hook record.
pub fn install(provider: Hooks) void {
    hooks.install(.{ .environment_provider = provider });
}

/// §3 substitution step 1: look up the decoded name and its indices in the
/// document's Browser. The caller owns any returned text; OOM propagates.
/// Unknown names, wrong arities and unavailable host values return null.
pub fn lookup(context: *const anyopaque, allocator: std.mem.Allocator, name: []const u8, indices: []const u32) std.mem.Allocator.Error!?[]u8 {
    const query = values.query(name, indices) orelse return null;
    const provider = hooks.environmentProvider() orelse return null;
    const valueOf = provider.value orelse return null;
    const document: *runtime.Instance = @ptrCast(@alignCast(@constCast(context)));
    const value = valueOf(document, query.variable, query.x, query.y) orelse return null;
    return values.serialize(allocator, query.variable, value);
}

/// The host revision pulled by StyleEngine.ensureActive. Without a provider
/// or a BrowserPlatform, it is 0. No Browser pointer or value is cached here.
pub fn revision(document: *runtime.Instance) u64 {
    const provider = hooks.environmentProvider() orelse return 0;
    const revisionOf = provider.revision orelse return 0;
    return revisionOf(document);
}
