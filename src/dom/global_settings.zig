//! What the WindowOrWorkerGlobalScope mixin reads through "this's relevant
//! settings object": a global's origin, whether it is a secure context and
//! cross-origin isolated, and the objects it hands out once per global
//! (IndexedDB's factory, CacheStorage, Performance).
//!
//! HTML gives every global an environment settings object, and each kind of
//! global - a Window, a WorkerGlobalScope - defines how its settings answer.
//! That state is the global's, the mixin's members are implemented once in
//! the mixin impl, and neither may reach into the other's impl - so each
//! global installs its answers here, as `range_boundaries.zig` does for the
//! range subclasses AbstractRange reads.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope-mixin
//!
//! lint-impls: hook for Window, WorkerGlobalScope

const std = @import("std");
const runtime = @import("runtime");

/// One kind of global's answers. Each getter is handed a global `owns`
/// accepted.
pub const Settings = struct {
    /// Whether `global` is a global of this kind.
    owns: *const fn (global: *runtime.Instance) bool,
    /// The settings object's origin, serialized. Owned by the caller,
    /// allocated with `global.ctx.allocator`.
    origin: *const fn (global: *runtime.Instance) anyerror!runtime.USVString,
    /// The settings object's execution environment is a secure context.
    is_secure_context: *const fn (global: *runtime.Instance) bool,
    /// The settings object's cross-origin isolated capability.
    cross_origin_isolated: *const fn (global: *runtime.Instance) bool,
    /// The global's IDBFactory; null where this kind of global has none yet.
    indexed_db: ?*const fn (global: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// The global's CacheStorage; null where this kind of global has none yet.
    caches: ?*const fn (global: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// The global's Performance; null where this kind of global has none yet.
    performance: ?*const fn (global: *runtime.Instance) anyerror!*runtime.Instance = null,
};

/// A Window and a WorkerGlobalScope - with room to spare for the next kind.
const capacity = 4;

threadlocal var installed: [capacity]?Settings = @splat(null);

/// Called by each kind of global. Idempotent: a kind is recognised by its
/// `owns` function and installed once.
pub fn install(settings: Settings) void {
    for (&installed) |*slot| {
        if (slot.*) |existing| {
            if (existing.owns == settings.owns) return;
            continue;
        }
        slot.* = settings;
        return;
    }
    std.debug.panic("global_settings: more than {d} kinds of global", .{capacity});
}

/// The answers for `global`'s kind, or null when no installed kind owns it.
pub fn of(global: *runtime.Instance) ?Settings {
    for (installed) |slot| {
        const settings = slot orelse return null;
        if (settings.owns(global)) return settings;
    }
    return null;
}

var test_owned: runtime.Instance = undefined;

fn testOwns(global: *runtime.Instance) bool {
    return @intFromPtr(global) == @intFromPtr(&test_owned);
}

fn testOrigin(global: *runtime.Instance) anyerror!runtime.USVString {
    _ = global;
    return error.Unexpected;
}

fn testFalse(global: *runtime.Instance) bool {
    _ = global;
    return false;
}

test "a global no kind owns has no settings, and a kind installs once" {
    const saved = installed;
    defer installed = saved;
    installed = @splat(null);

    // Never dereferenced: `owns` compares the address only.
    const global = &test_owned;
    try std.testing.expect(of(global) == null);

    const settings: Settings = .{ .owns = &testOwns, .origin = &testOrigin, .is_secure_context = &testFalse, .cross_origin_isolated = &testFalse };
    install(settings);
    install(settings);
    try std.testing.expect(of(global) != null);
    try std.testing.expect(installed[1] == null);
}
