//! A computed style a caller holds (lane cs1): what dom.style.computedStyle
//! answers. The engine caches one style per element and replaces it - the
//! old one released - whenever a read finds it stale: its key moved, or it
//! is volatile (its cascade read per-element state - a form control against
//! :checked or :autofill, a dialog against :modal - or its flat-tree parent's
//! is), and a volatile style is resolved again on EVERY read of the element
//! or of anything below it. A style a caller merely borrowed died at the
//! next such read (lane a11y1's hiddenViaStyle, f6ff67afb). A held one
//! stays, unchanged, until the caller releases it, whatever is read or
//! resolved meanwhile: the hold is a reference on the style
//! (ComputedStyle.refs), as Blink's scoped_refptr<const ComputedStyle> was.
//!
//! The rules (runtime.native_holds): take it, and `defer held.release()` on
//! the next line; never keep it past the native call that took it, in a
//! struct or anywhere else; never call into script, or run an event-loop
//! turn, while holding it - Debug checks both of those at every script
//! entry and turn. Release it exactly once.

const std = @import("std");
const runtime = @import("runtime");
const css = @import("css");

const ComputedStyle = css.computed_style.ComputedStyle;

pub const HeldStyle = struct {
    /// Valid until `release`.
    style: *const ComputedStyle,
    /// Debug: the agent's hold count this hold is on (runtime.native_holds).
    holds: runtime.native_holds.Ref,

    pub fn release(self: HeldStyle) void {
        runtime.native_holds.leave(self.holds);
        @constCast(self.style).release();
    }
};

/// A hold on `style`, which `realm`'s native frame reads: a reference on it,
/// or - its count full - on a clone of it that shares its groups.
pub fn hold(realm: runtime.Context, style: *const ComputedStyle) std.mem.Allocator.Error!HeldStyle {
    const target = @constCast(style);
    const held: *ComputedStyle = if (target.retain()) target else try style.clone(style.allocator);
    return .{ .style = held, .holds = runtime.native_holds.enter(realm) };
}
