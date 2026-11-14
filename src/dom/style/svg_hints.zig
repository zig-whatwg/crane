//! SVG 2 §6.6 "Presentation attributes": an SVG element's presentation
//! attributes as the cascade's presentational hints. "Presentation
//! attributes contribute to the author level of the cascade, followed by
//! all other author-level style sheets, and have specificity 0" - CSS
//! Cascade 5 §6.2's author presentational hint origin, as HTML's hints
//! (html-hints.css, font_hints.zig, the background hint). Which attribute
//! maps to which property, and how its value parses, is
//! css.svg_presentation's (an invalid value contributes no hint: all three
//! browsers agree, its file says). The hint enters the cascade as one
//! declaration block, cached on the element's style state in its hint slot
//! (element_style.Hint) and rebuilt only when an input changes, the way
//! font_hints.zig caches the font element's.
//!
//! A url() in a value resolves against the element's node document's base
//! URL, as the style attribute's does (resource_loading.inlineParseContext):
//! Blink's SVGElement::CollectStyleForPresentationAttribute parses the value
//! as the property's with the document's parser context.
//!
//! Spec: https://svgwg.org/svg2-draft/styling.html#PresentationAttributes

const std = @import("std");
const runtime = @import("runtime");
const css = @import("css");
const interfaces = @import("interfaces");
const element_style = @import("element_style.zig");
const resource_loading = @import("resource_loading.zig");
const element_data = @import("../element_data.zig");

const Allocator = std.mem.Allocator;
const DeclarationBlock = css.declarations.DeclarationBlock;
const ElementStyle = element_style.ElementStyle;
const Hint = element_style.Hint;

pub const svg_namespace = css.svg_presentation.svg_namespace;

/// One input: a presentation attribute's name and value, owned.
const Input = struct {
    name: []u8,
    value: []u8,
};

/// One SVG element's hint: the attributes it was built from (owned copies,
/// in the element's attribute order), the base URL its url() values
/// resolved against when any value has one, and the declarations. No DOM or
/// realm back link.
pub const SvgHint = struct {
    header: Hint = .{ .kind = .svg },
    allocator: Allocator,
    inputs: []Input,
    base: ?[]u8,
    block: DeclarationBlock,

    pub fn destroy(self: *SvgHint) void {
        self.block.deinit();
        freeInputs(self.allocator, self.inputs);
        if (self.base) |b| self.allocator.free(b);
        self.allocator.destroy(self);
    }
};

fn freeInputs(allocator: Allocator, inputs: []Input) void {
    for (inputs) |input| {
        allocator.free(input.name);
        allocator.free(input.value);
    }
    allocator.free(inputs);
}

/// Whether the cached hint was built from exactly these attributes.
fn sameInputs(hint: *const SvgHint, data: element_data.View, local: []const u8) bool {
    var index: usize = 0;
    var it = data.attributeIterator();
    while (it.next()) |entry| {
        if (entry.namespace_uri != null) continue;
        if (css.svg_presentation.lookup(svg_namespace, local, entry.local_name) == null) continue;
        if (index == hint.inputs.len) return false;
        const input = hint.inputs[index];
        if (!std.mem.eql(u8, input.name, entry.local_name) or !std.mem.eql(u8, input.value, entry.value)) return false;
        index += 1;
    }
    return index == hint.inputs.len;
}

/// The presentational hint block of the SVG element `element` (local name
/// `local`), cached on `state` and rebuilt only when a presentation
/// attribute or - for a hint with a url() - the base URL changed; null
/// when no presentation attribute gives a declaration (the cache is
/// dropped then).
pub fn svgHint(element: *runtime.Instance, state: *ElementStyle, data: element_data.View, local: []const u8) Allocator.Error!?*const DeclarationBlock {
    if (state.svgHint()) |old| {
        if (sameInputs(old, data, local)) {
            if (old.base) |base| {
                // A url() resolved against the base: a changed base (a new
                // base element) makes a new hint.
                const current = interfaces.Node.get_baseURI(element) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    else => "",
                };
                defer if (current.len != 0) element.ctx.allocator.free(current);
                if (std.mem.eql(u8, base, current)) return blockOf(old);
            } else return blockOf(old);
        }
    }
    const allocator = state.allocator;
    var inputs: std.ArrayList(Input) = .empty;
    errdefer {
        for (inputs.items) |input| {
            allocator.free(input.name);
            allocator.free(input.value);
        }
        inputs.deinit(allocator);
    }
    var block = DeclarationBlock.init(allocator);
    errdefer block.deinit();
    var base: ?[]u8 = null;
    errdefer if (base) |b| allocator.free(b);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer assignments.deinit(allocator);
    var it = data.attributeIterator();
    while (it.next()) |entry| {
        if (entry.namespace_uri != null) continue;
        const property = css.svg_presentation.lookup(svg_namespace, local, entry.local_name) orelse continue;
        try inputs.ensureUnusedCapacity(allocator, 1);
        const name = try allocator.dupe(u8, entry.local_name);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, entry.value);
        inputs.appendAssumeCapacity(.{ .name = name, .value = value });
        var context = try resource_loading.inlineParseContext(element, allocator, false, value);
        defer context.deinit();
        if (context.source) |source| {
            if (base == null) base = try allocator.dupe(u8, source.base_url);
        }
        assignments.clearRetainingCapacity();
        const parsed = try css.svg_presentation.parse(context.options(), svg_namespace, local, entry.local_name, value, &assignments);
        // The parsed values are ours; the block retains what it keeps.
        defer for (assignments.items) |a| a.value.release();
        if (!parsed) continue;
        _ = block.setValidatedProperty(property, assignments.items) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // A value the block refuses sets nothing, as an invalid one.
            error.Invalid => {},
        };
    }
    if (block.length() == 0) {
        block.deinit();
        for (inputs.items) |input| {
            allocator.free(input.name);
            allocator.free(input.value);
        }
        inputs.deinit(allocator);
        if (base) |b| allocator.free(b);
        state.dropSvgHint();
        return null;
    }
    const hint = try allocator.create(SvgHint);
    errdefer allocator.destroy(hint);
    const owned_inputs = try inputs.toOwnedSlice(allocator);
    hint.* = .{ .allocator = allocator, .inputs = owned_inputs, .base = base, .block = block };
    state.setHint(&hint.header);
    return &hint.block;
}

fn blockOf(hint: *const SvgHint) *const DeclarationBlock {
    return &hint.block;
}
