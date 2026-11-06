//! Implementation for the Animatable mixin (Web Animations 1 6.8):
//! animate() and getAnimations(). Element includes Animatable and inherits
//! both members by alias (codegen/inherited_mixins.zig); the steps are
//! dom.animations' (src/dom/animations/root.zig).
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-animatable-interface-mixin

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const animations = @import("dom").animations;
const Animatable = interfaces.Animatable;

pub const State = Animatable.State;

pub const ImplError = error{};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Operation: animate (6.8): a new KeyframeEffect and Animation for this
/// element, played.
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-animatable-animate
pub fn call_animate(instance: *runtime.Instance, keyframes: ?runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    return animations.animate(instance, keyframes, if (options.was_passed) options.value else null);
}

/// Operation: getAnimations (6.8): the relevant animations for this
/// element, or with `subtree` for its subtree, in composite order.
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-animatable-getanimations
pub fn call_getAnimations(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetAnimationsOptions)) anyerror!runtime.JSValue {
    const given = options.getOrDefault(.{});
    return animations.elementAnimations(instance, given.subtree orelse false, if (given.pseudoElement) |p| p.asSlice() else null);
}
