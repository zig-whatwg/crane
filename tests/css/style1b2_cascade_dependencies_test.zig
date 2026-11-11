//! Lane style1 batch 2 (S2): the cascade records what it read beyond its
//! matched declarations, so a matched-properties cache knows when a style it
//! keeps can stand for another element's cascade.
//!
//! Blink: MatchedPropertiesCache::IsStyleCacheable / IsCacheable read flags
//! the StyleBuilder sets while it applies a value (HasAttrFunction,
//! HasSiblingFunctions, HasElementDependentRandomFunctions,
//! HasContainerRelativeValue, HasExplicitInheritance). WebKit: isCacheable
//! (hasAttrContent, useTreeCountingFunctions, isContainerDependent,
//! hasRandomCachingKeyMap) and hasExplicitlyInheritedProperties. Crane's
//! cascade reads each of these inputs through a Context provider; with
//! `Context.dependencies` set, every read is recorded where it happens.
//!
//! RED at d963a905627: css.cascade.Dependencies does not exist.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const cascade_mod = css.cascade;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const math = css.math_values;

fn implemented() bool {
    return @hasDecl(cascade_mod, "Dependencies") and @hasField(cascade_mod.Context, "dependencies");
}

const Inputs = struct {
    attribute_calls: usize = 0,
    count_calls: usize = 0,
    random_calls: usize = 0,
    container_calls: usize = 0,
    system_calls: usize = 0,
    metric_calls: usize = 0,
    note: math.UnavailableNote = .{},

    fn attribute(raw: *const anyopaque, _: []const u8) ?[]const u8 {
        const self: *Inputs = @ptrCast(@alignCast(@constCast(raw)));
        self.attribute_calls += 1;
        return "label";
    }
    fn counts(raw: *anyopaque) math.TreeCounts {
        const self: *Inputs = @ptrCast(@alignCast(raw));
        self.count_calls += 1;
        return .{ .index = 3, .count = 7 };
    }
    fn random(raw: *anyopaque, _: css.random_values.CacheKey) Allocator.Error!f64 {
        const self: *Inputs = @ptrCast(@alignCast(raw));
        self.random_calls += 1;
        return 0.25;
    }
    fn container(raw: *anyopaque, _: math.Context.ContainerAxis) math.Context.ContainerEligibility {
        const self: *Inputs = @ptrCast(@alignCast(raw));
        self.container_calls += 1;
        return .no_eligible_container;
    }
    fn system(raw: ?*anyopaque, _: css.font_system.Keyword) ?css.font_system.SystemValues {
        const self: *Inputs = @ptrCast(@alignCast(raw.?));
        self.system_calls += 1;
        return null;
    }
    fn metric(raw: ?*anyopaque, _: css.font_request.View, _: css.font_size_adjust.Metric) ?f64 {
        const self: *Inputs = @ptrCast(@alignCast(raw.?));
        self.metric_calls += 1;
        return 0.5;
    }
};

/// The dependencies the cascade of `text` (one author block) records under
/// a parent styled by `parent_text`, every provider present.
fn dependenciesOf(comptime pseudo: ?[]const u8, parent_text: []const u8, text: []const u8, inputs: *Inputs) !cascade_mod.Dependencies {
    const allocator = testing.allocator;
    var parent_block = try DeclarationBlock.parse(.{ .allocator = allocator }, parent_text);
    defer parent_block.deinit();
    const parent = try cascade_mod.cascade(.{ .allocator = allocator, .parent = null, .is_root = true }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var block = try DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    var deps: cascade_mod.Dependencies = .{};
    const style = try cascade_mod.cascade(.{
        .allocator = allocator,
        .parent = parent,
        .pseudo = pseudo,
        .dependencies = &deps,
        .content_attributes = .{ .context = inputs, .get = Inputs.attribute },
        .tree_counts = .{ .context = inputs, .get = Inputs.counts },
        .random_base = .{ .context = inputs, .get = Inputs.random },
        .container = .{ .context = inputs, .get = Inputs.container, .note = &inputs.note },
        .system_fonts = .{ .context = inputs, .resolve = Inputs.system },
        .font_metric_ratios = .{ .context = inputs, .resolve = Inputs.metric },
    }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    style.destroy();
    return deps;
}

test "declarations that read nothing beyond the parent's inherited values are cacheable" {
    if (comptime !implemented()) return error.DependenciesNotRecorded;
    var inputs: Inputs = .{};
    const deps = try dependenciesOf(null, "font-size: 20px; color: blue", "display: flex; margin: 1em 2px; color: currentcolor; width: calc(50% - 1rem); transition: opacity 0.3s; font-weight: bolder; color: inherit", &inputs);
    try testing.expect(deps.cacheable());
    try testing.expect(!deps.parent_non_inherited);
    // No provider was asked anything.
    try testing.expectEqual(@as(usize, 0), inputs.attribute_calls + inputs.count_calls + inputs.random_calls + inputs.container_calls + inputs.system_calls + inputs.metric_calls);
}

test "attr() makes the style the element's own (Blink HasAttrFunction, WebKit hasAttrContent)" {
    if (comptime !implemented()) return error.DependenciesNotRecorded;
    var inputs: Inputs = .{};
    const deps = try dependenciesOf("before", "", "content: attr(data-label)", &inputs);
    try testing.expect(inputs.attribute_calls > 0);
    try testing.expect(deps.attr);
    try testing.expect(!deps.cacheable());
    var substituted: Inputs = .{};
    const in_value = try dependenciesOf(null, "", "width: attr(data-w type(<length>), 10px)", &substituted);
    try testing.expect(substituted.attribute_calls > 0);
    try testing.expect(in_value.attr);
}

test "sibling-index() makes the style the element's own (Blink HasSiblingFunctions, WebKit useTreeCountingFunctions)" {
    if (comptime !implemented()) return error.DependenciesNotRecorded;
    var inputs: Inputs = .{};
    const deps = try dependenciesOf(null, "", "width: calc(sibling-index() * 1px)", &inputs);
    try testing.expect(inputs.count_calls > 0);
    try testing.expect(deps.tree_counts);
    try testing.expect(!deps.cacheable());
}

test "an element-dependent random() makes the style the element's own (Blink HasElementDependentRandomFunctions)" {
    if (comptime !implemented()) return error.DependenciesNotRecorded;
    var inputs: Inputs = .{};
    const deps = try dependenciesOf(null, "", "left: random(0px, 100px)", &inputs);
    try testing.expect(inputs.random_calls > 0);
    try testing.expect(deps.random);
    try testing.expect(!deps.cacheable());
    // A fixed random() reads no input.
    var fixed: Inputs = .{};
    const fixed_deps = try dependenciesOf(null, "", "left: random(fixed .5, 0px, 100px)", &fixed);
    try testing.expect(fixed_deps.cacheable());
}

test "a container unit makes the style the element's own (Blink HasContainerRelativeValue, WebKit isContainerDependent)" {
    if (comptime !implemented()) return error.DependenciesNotRecorded;
    var inputs: Inputs = .{};
    const deps = try dependenciesOf(null, "", "width: 10cqw", &inputs);
    try testing.expect(inputs.container_calls > 0);
    try testing.expect(deps.container);
    try testing.expect(!deps.cacheable());
}

test "a system font and a font's own metrics make the style the element's own" {
    if (comptime !implemented()) return error.DependenciesNotRecorded;
    var inputs: Inputs = .{};
    const system = try dependenciesOf(null, "", "font: caption", &inputs);
    try testing.expect(inputs.system_calls > 0);
    try testing.expect(system.system_font);
    try testing.expect(!system.cacheable());
    var metrics: Inputs = .{};
    const from_font = try dependenciesOf(null, "", "font-family: Kept; font-size-adjust: cap-height from-font", &metrics);
    try testing.expect(from_font.font_metrics);
    try testing.expect(!from_font.cacheable());
}

test "explicit inheritance of a non-inherited property reads the parent's non-inherited values (Blink HasExplicitInheritance)" {
    if (comptime !implemented()) return error.DependenciesNotRecorded;
    var inputs: Inputs = .{};
    const explicit = try dependenciesOf(null, "margin-left: 7px", "margin-left: inherit", &inputs);
    try testing.expect(explicit.parent_non_inherited);
    // Still cacheable: a hit then needs the parent's non-inherited values too.
    try testing.expect(explicit.cacheable());
    const inherited = try dependenciesOf(null, "color: red", "color: inherit; font-size: inherit", &inputs);
    try testing.expect(!inherited.parent_non_inherited);
}
