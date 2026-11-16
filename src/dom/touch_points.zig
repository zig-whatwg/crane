//! A Touch's place in the TouchEvent that lists it, as the hook Touch
//! installs.
//!
//! DOM 2.2 gives every event a "touch target list", "for the exclusive use
//! of defining the TouchEvent interface": dispatch retargets each entry
//! against every path item (DOM 2.9 dispatch steps 5.1-5.2, 6.9.4), and
//! "invoke" step 5 sets the event's list to the item's before its listeners
//! run. A TouchEvent's list is its touches' targets (Touch Events,
//! "Retargeting": each touch's target is its unadjusted target retargeted
//! against the event's target), so a listener reads a touch's target there:
//! Gecko's EventDispatcher retargets each Touch's target per chain item
//! (EventTargetChainItem::RetargetTouchTargets), Blink keeps per-tree-scope
//! touch lists (TouchEventContext).
//!
//! Neither step has an IDL member, and TouchEvent may not reach into Touch's
//! impl, so Touch installs them here:
//!
//! - `unadjustedTarget` is a touch's target as it was made (TouchInit's,
//!   or the element a touch point started on), which TouchEvent puts in its
//!   touch target list;
//! - `adopt` tells a touch it is listed in `event`'s touch target list at
//!   `index`: while `event` is dispatched, the touch's target is that entry.
//!
//! lint-impls: hook for Touch

const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

/// What the Touch impl supplies.
pub const Implementation = struct {
    unadjusted_target: *const fn (touch: *runtime.Instance) ?*runtime.Instance,
    adopt: *const fn (touch: *runtime.Instance, event: *runtime.Instance, index: u32) void,
};

// process-wide: hook table written once at process start by Touch.installHooks; the touches themselves are per-object state
var implementation: Hook(?Implementation) = .init(null);

/// Called by Touch's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// `touch`'s unadjusted target, or null for an object that is no Touch.
pub fn unadjustedTarget(touch: *runtime.Instance) ?*runtime.Instance {
    const impl = implementation.get() orelse return null;
    return impl.unadjusted_target(touch);
}

/// `touch` is entry `index` of `event`'s touch target list.
pub fn adopt(touch: *runtime.Instance, event: *runtime.Instance, index: u32) void {
    const impl = implementation.get() orelse return;
    impl.adopt(touch, event, index);
}

test "with no Touch installed, a touch has no target and adopting it does nothing" {
    const std = @import("std");
    const override = implementation.overrideForTest(null);
    defer override.restore();
    // Never dereferenced: with no implementation the call does not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expect(unadjustedTarget(&object) == null);
    adopt(&object, &object, 0);
}
