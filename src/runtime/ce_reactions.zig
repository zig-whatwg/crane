//! [CEReactions] reaches the HTML owner without importing its implementation.
const Instance = @import("instance.zig").Instance;

pub const Hooks = struct {
    begin: *const fn (?*Instance) void,
    end: *const fn (?*Instance) void,
};
// process-wide: immutable function pointers installed once before Browsers start; each call resolves its own relevant agent, so threads and Browsers share no reaction state
var hooks: ?Hooks = null;

/// CustomElementRegistry installs this while process_start is .starting.
/// The owner checks that phase before crossing the runtime tier's boundary.
pub fn install(implementation: Hooks) void {
    hooks = implementation;
}

pub fn begin(instance: ?*Instance) void {
    (hooks orelse return).begin(instance);
}

pub fn end(instance: ?*Instance) void {
    (hooks orelse return).end(instance);
}
