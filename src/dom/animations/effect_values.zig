//! The effect value of a keyframe effect for one target property (Web
//! Animations 1 5.3.4, with Web Animations 2 3.2.1's iteration composite
//! step) and the effect composition that folds it onto the underlying value
//! (5.4.3-5.4.4). Generic over the value type: the style engine combines
//! css.style_values.Value through css.interpolation, the tests combine
//! numbers. `ops` provides:
//!
//!   interpolate(ops, a: V, b: V, p: f64) !V   // owned result
//!   add(ops, underlying: V, value: V) !V      // owned result
//!   accumulate(ops, underlying: V, value: V) !V
//!   retain(ops, v: V) V                       // a second owner of v
//!   release(ops, v: V) void
//!
//! Inputs are borrowed; every returned V is OWNED by the caller.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-effect-value-of-a-keyframe-animation-effect
//! Spec: https://drafts.csswg.org/web-animations-2/#the-effect-value-of-a-keyframe-animation-effect
const std = @import("std");
const easing_mod = @import("easing.zig");

pub const Composite = enum { replace, add, accumulate };

/// One computed keyframe's value for the target property.
pub fn PropertyKeyframe(comptime V: type) type {
    return struct {
        /// The computed keyframe offset.
        offset: f64,
        /// The keyframe-specific easing; null is linear.
        easing: ?*const easing_mod.Easing = null,
        /// The keyframe-specific composite operation; null is unset.
        composite: ?Composite = null,
        value: V,
    };
}

pub const Sample = struct {
    /// The iteration progress (4.7.8); null is unresolved.
    progress: ?f64,
    /// The current iteration (4.7.5).
    current_iteration: f64 = 0,
    /// The before flag the effect's easing used (CSS Easing 2).
    before_flag: bool = false,
};

pub const Options = struct {
    /// The keyframe effect's composite operation.
    composite: Composite = .replace,
    /// Web Animations 2: iteration composite `accumulate`.
    iteration_accumulate: bool = false,
};

/// The effect value (5.3.4) of the property whose `keyframes` (property-
/// specific: sorted by computed offset, every one setting the property) are
/// given, at `sample`, over `underlying`. Null when the iteration progress is
/// unresolved (step 1: the effect is not applied).
pub fn effectValue(comptime V: type, ops: anytype, keyframes: []const PropertyKeyframe(V), sample: Sample, options: Options, underlying: V) !?V {
    // 1.
    const progress = sample.progress orelse return null;
    // 7.
    if (keyframes.len == 0) return ops.retain(underlying);
    // 8-9. The implicit keyframes at 0 and 1 hold the underlying value
    // (composite replace, linear easing).
    const K = PropertyKeyframe(V);
    var has_zero = false;
    var has_one = false;
    for (keyframes) |k| {
        if (k.offset == 0) has_zero = true;
        if (k.offset == 1) has_one = true;
    }
    const first_implicit: ?K = if (has_zero) null else .{ .offset = 0, .composite = .replace, .value = underlying };
    const last_implicit: ?K = if (has_one) null else .{ .offset = 1, .composite = .replace, .value = underlying };
    const view: View(V) = .{ .first = first_implicit, .middle = keyframes, .last = last_implicit };
    const n = view.len();

    // 10-11. The interval endpoints, as indices into the view.
    var endpoints: [2]usize = undefined;
    var count: usize = 0;
    if (progress < 0 and view.countAt(0) > 1) {
        endpoints[0] = 0;
        count = 1;
    } else if (progress >= 1 and view.countAt(1) > 1) {
        endpoints[0] = n - 1;
        count = 1;
    } else {
        // 11.1: the last keyframe whose offset <= progress and < 1; else the
        // last keyframe whose offset is 0.
        var start: ?usize = null;
        for (0..n) |i| {
            const offset = view.at(i).offset;
            if (offset <= progress and offset < 1) start = i;
        }
        if (start == null) {
            for (0..n) |i| if (view.at(i).offset == 0) {
                start = i;
            };
        }
        const s = start orelse 0;
        endpoints[0] = s;
        // 11.2: the next keyframe after it.
        endpoints[1] = @min(s + 1, n - 1);
        count = 2;
    }

    // 12. Each endpoint's value, composited with the underlying value and
    // then accumulated across iterations. OWNED.
    var endpoint_values: [2]V = undefined;
    var made: usize = 0;
    errdefer for (endpoint_values[0..made]) |v| ops.release(v);
    for (endpoints[0..count]) |index| {
        const keyframe = view.at(index);
        endpoint_values[made] = try endpointValue(V, ops, keyframe, options, underlying);
        made += 1;
        if (options.iteration_accumulate and sample.current_iteration > 0) {
            // WA2 3.2.1 step 12.2: accumulate the FINAL keyframe's value
            // (Va) and this keyframe's (Vb) `current iteration` times.
            const final = view.at(n - 1);
            const final_value = try endpointValue(V, ops, final, options, underlying);
            defer ops.release(final_value);
            const times: u64 = if (std.math.isInf(sample.current_iteration)) 0 else @intFromFloat(@min(sample.current_iteration, 1e6));
            var i: u64 = 0;
            while (i < times) : (i += 1) {
                const next = try ops.accumulate(final_value, endpoint_values[made - 1]);
                ops.release(endpoint_values[made - 1]);
                endpoint_values[made - 1] = next;
            }
        }
    }
    // 13.
    if (count == 1) return endpoint_values[0];
    defer ops.release(endpoint_values[0]);
    defer ops.release(endpoint_values[1]);
    // 14-17.
    const start_offset = view.at(endpoints[0]).offset;
    const end_offset = view.at(endpoints[1]).offset;
    const interval_distance = if (end_offset == start_offset) 0 else (progress - start_offset) / (end_offset - start_offset);
    const transformed = if (view.at(endpoints[0]).easing) |e| e.evaluate(interval_distance, sample.before_flag) else interval_distance;
    // 18.
    return try ops.interpolate(endpoint_values[0], endpoint_values[1], transformed);
}

/// Step 12.1: an endpoint's value combined with the underlying value when
/// its composite operation (or, unset, the effect's) is not replace.
fn endpointValue(comptime V: type, ops: anytype, keyframe: PropertyKeyframe(V), options: Options, underlying: V) !V {
    const operation = keyframe.composite orelse options.composite;
    return switch (operation) {
        .replace => ops.retain(keyframe.value),
        .add => try ops.add(underlying, keyframe.value),
        .accumulate => try ops.accumulate(underlying, keyframe.value),
    };
}

/// 5.4.4: an effect value composed onto the underlying value. Since the
/// keyframes' own composite operations already combined each endpoint with
/// the underlying value (5.3.4 step 12.1), the effect value IS the
/// composited result; this is the identity, kept as a named step so the
/// stack reads as the spec does. Takes ownership of `effect_value`.
pub fn compose(comptime V: type, effect_value: V) V {
    return effect_value;
}

/// The property-specific keyframes with the implicit 0 and 1 keyframes.
fn View(comptime V: type) type {
    return struct {
        const K = PropertyKeyframe(V);
        first: ?K,
        middle: []const K,
        last: ?K,

        fn len(self: @This()) usize {
            return self.middle.len + @intFromBool(self.first != null) + @intFromBool(self.last != null);
        }

        fn at(self: @This(), index: usize) K {
            if (self.first) |f| {
                if (index == 0) return f;
                return self.rest(index - 1);
            }
            return self.rest(index);
        }

        fn rest(self: @This(), index: usize) K {
            if (index < self.middle.len) return self.middle[index];
            return self.last.?;
        }

        fn countAt(self: @This(), offset: f64) usize {
            var c: usize = 0;
            for (0..self.len()) |i| {
                if (self.at(i).offset == offset) c += 1;
            }
            return c;
        }
    };
}
