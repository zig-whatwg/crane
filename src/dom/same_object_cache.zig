//! The generated [SameObject] caches' edges (binding3 item 9h).
//!
//! A generated [SameObject] getter caches the child its impl made in the
//! owner's generated state (`cached_<name>`), as a bare pointer. Whoever
//! wraps the child owns it: the wrapper cache frees it once its wrapper is
//! collected. A script read wraps it, and the binding ties its wrapper to the
//! owner's (interface.zig `recordSameObjectEdge`). A native read -
//! `interfaces.SVGAElement.get_href` from an extract-an-origin step - made a
//! child that nothing wrapped and nothing freed: an SVGAnimatedString, its
//! attribute name and its namespace per element (Codex row 45 Q14).
//!
//! So the getter traces the child it caches from its owner, whoever reads it
//! first (`made`): engine.traceChild makes the child's wrapper in its relevant
//! realm, which then owns the child, and keeps it for exactly as long as the
//! owner's wrapper lives - or holds it until the owner gets one. That is what
//! a script read leaves, so a native read and a script read leave one state.
//! Blink keeps the same object the same way: the owner's `Trace` visits the
//! child's `Member<>` (Element::Trace visits its ElementRareData, whose
//! class_list_, dataset_ and attribute_map_ are traced members).
//!
//! The owner's destruction chain ends an edge still waiting for the owner's
//! wrapper (`end`): engine.forgetTracedChild, which an owner that can be
//! freed unwrapped calls from its teardown. The edge of an owner that has a
//! wrapper dies with the wrapper.
//!
//! The slot is the attribute's, in a namespace of its own ("SameObject:"),
//! apart from the slots impls trace their own children in.
const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");

/// The traced slot of the [SameObject] attribute whose cache is
/// `cached_<attribute>`.
fn slotOf(comptime attribute: []const u8) engine.TracedSlot {
    return .{ .name = "SameObject:" ++ attribute };
}

/// `child` was just made for `owner`'s [SameObject] `attribute` and cached:
/// `owner` keeps it, as a script read would have it kept.
pub fn made(owner: *runtime.Instance, child: *runtime.Instance, comptime attribute: []const u8) void {
    engine.traceChild(owner, child, slotOf(attribute));
}

/// `owner`'s destruction chain is at `State`'s level: end the edge each of
/// that level's cached children may still wait on (an owner freed before it
/// was ever wrapped). Never makes a wrapper; safe in any teardown, the
/// collector's included (engine.forgetTracedChild).
pub fn end(comptime State: type, owner: *runtime.Instance) void {
    const own = &owner.getState(State).own;
    inline for (comptime std.meta.fieldNames(@TypeOf(own.*)), comptime std.meta.fieldTypes(@TypeOf(own.*))) |field_name, field_type| {
        if (comptime std.mem.startsWith(u8, field_name, "cached_") and field_type == ?*runtime.Instance) {
            if (@field(own, field_name) != null) engine.forgetTracedChild(owner, slotOf(field_name["cached_".len..]));
        }
    }
}
