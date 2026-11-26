//! Pure-Zig `CSSMatchedStyles` cascade analyzer and `CssFormatter` for
//! `get_css_styles`.
//!
//! Reproduces Chromium DevTools Frontend `CSSMatchedStyles` (`NodeCascade`,
//! `DOMInheritanceCascade`, `cleanUserAgentPayload`, `DOMNode.simpleSelector`,
//! BSD-3-Clause) and `chrome-devtools-mcp@1.13.0` `src/formatters/CssFormatter.ts`
//! (Copyright 2026 Google LLC, Apache-2.0; THIRD_PARTY_NOTICES.md).

const std = @import("std");
const Allocator = std.mem.Allocator;
const css = @import("dom").style.css;
const session_mod = @import("session.zig");
const str = session_mod.str;

pub const NodeInfo = struct {
    selector: []const u8,
    uid: ?[]const u8 = null,
};

pub const ContainerDetail = struct {
    /// Keyed by pointer/index of the container query JSON object.
    query_ptr: usize,
    container: NodeInfo,
};

pub const Ancestor = union(enum) {
    layer: ?[]const u8,
    media: []const u8,
    container: struct {
        query: []const u8,
        name: ?[]const u8 = null,
        container: ?NodeInfo = null,
    },
    scope: ?[]const u8,
    supports: []const u8,
    starting_style: void,
    nesting: []const u8,
    navigation: []const u8,
};

pub const PropertyStatus = enum {
    active,
    overloaded,
    invalid,
    disabled,

    fn tag(self: PropertyStatus) []const u8 {
        return switch (self) {
            .active => "",
            .overloaded => "[overloaded] ",
            .invalid => "[invalid] ",
            .disabled => "[disabled] ",
        };
    }
};

pub const FormattedProperty = struct {
    name: []const u8,
    value: []const u8,
    important: bool = false,
    status: PropertyStatus = .active,
};

pub const KeyframeStep = struct {
    key_text: []const u8,
    properties: []const FormattedProperty,
};

pub const CascadeRule = struct {
    kind: enum {
        inline_style,
        attributes,
        matched,
        inherited,
        pseudo,
        keyframes,
        property,
        position_try,
    },
    selector: []const u8,
    source: ?[]const u8 = null,
    ancestors: []const Ancestor = &.{},
    properties: []const FormattedProperty = &.{},
    /// For `inherited` and inherited `pseudo`.
    node: ?NodeInfo = null,
    /// For `pseudo` (e.g. `"::before"`).
    pseudo_type: ?[]const u8 = null,
    /// For `keyframes`.
    keyframes: []const KeyframeStep = &.{},
    /// For `position_try`.
    active: bool = false,
};

/// Registered custom property inheritance lookup (from `@property` &
/// `CSS.registerProperty`).
const RegisteredProp = struct {
    name: []const u8,
    inherits: bool,
};

const LonghandRef = struct {
    name: []const u8,
    important: bool,
    overloaded: bool = false,
};

const WorkingProp = struct {
    name: []const u8,
    value: []const u8,
    important: bool = false,
    parsed_ok: bool = true,
    disabled: bool = false,
    has_range: bool = false,
    active_in_style: bool = true,
    status: PropertyStatus = .active,
    longhands: []LonghandRef = &.{},
};

const WorkingStyle = struct {
    kind: enum { inline_style, attributes, matched },
    selector: []const u8,
    source: ?[]const u8 = null,
    ancestors: []const Ancestor = &.{},
    layer_key: []const u8 = "",
    is_user_agent: bool = false,
    is_injected: bool = false,
    has_range: bool = false,
    style_sheet_id: ?[]const u8 = null,
    range_key: ?[]const u8 = null,
    props: []WorkingProp = &.{},
};

const NodeCascade = struct {
    is_inherited: bool,
    is_highlight: bool = false,
    node: ?NodeInfo = null,
    styles: []WorkingStyle,
};

pub const CollectContext = struct {
    arena: Allocator,
    sheets: *const std.StringArrayHashMapUnmanaged(session_mod.Page.CssSheetHeader),
    container_details: []const ContainerDetail,
    target_node: NodeInfo,
    ancestor_nodes: []const NodeInfo,
    target_tag: []const u8,
};

/// Collects all `CascadeRule`s from a CDP `CSS.getMatchedStylesForNode` JSON
/// payload in exact `chrome-devtools-mcp` `CssFormatter.collectRules` order.
pub fn collectRules(ctx: *const CollectContext, payload: std.json.ObjectMap) Allocator.Error![]const CascadeRule {
    const arena = ctx.arena;

    // 1. Collect registered custom properties (@property + CSS.registerProperty)
    // so inheritance checks know whether a custom property has `inherits: false`.
    var reg_props: std.ArrayList(RegisteredProp) = .empty;
    if (payload.get("cssPropertyRules")) |arr| if (arr == .array) {
        for (arr.array.items) |item| {
            if (item != .object) continue;
            const pname = nestedStr(item.object, "propertyName", "text");
            if (pname.len == 0) continue;
            var inh = true;
            if (item.object.get("style")) |st| if (st == .object) {
                if (st.object.get("cssProperties")) |ps| if (ps == .array) {
                    for (ps.array.items) |p| {
                        if (p != .object) continue;
                        if (std.mem.eql(u8, str(p.object.get("name")), "inherits")) {
                            inh = !std.mem.eql(u8, str(p.object.get("value")), "false");
                        }
                    }
                };
            };
            try reg_props.append(arena, .{ .name = pname, .inherits = inh });
        }
    };
    if (payload.get("cssPropertyRegistrations")) |arr| if (arr == .array) {
        for (arr.array.items) |item| {
            if (item != .object) continue;
            const pname = str(item.object.get("propertyName"));
            if (pname.len == 0) continue;
            const inh = if (item.object.get("inherits")) |v| (v == .bool and v.bool) else true;
            try reg_props.append(arena, .{ .name = pname, .inherits = inh });
        }
    };

    var rules_out: std.ArrayList(CascadeRule) = .empty;

    // 2. Build main DOMInheritanceCascade (target element + inherited ancestors).
    var main_cascades: std.ArrayList(NodeCascade) = .empty;
    var seen_rules: std.ArrayList([]const u8) = .empty;

    // Target element NodeCascade: inlineStyle, then matchedCSSRules reversed
    // with attributesStyle inserted before first UA/injected rule.
    {
        var styles: std.ArrayList(WorkingStyle) = .empty;
        if (payload.get("inlineStyle")) |inl| if (inl == .object) {
            const ws = try parseWorkingStyle(arena, .inline_style, "element.style", null, &.{}, "", false, false, inl.object);
            if (ws.props.len > 0) try styles.append(arena, ws);
        };

        const attrs_style_val = payload.get("attributesStyle");
        var added_attrs = false;
        const matched_cleaned = try cleanUserAgentMatches(arena, payload.get("matchedCSSRules"));
        var idx: usize = matched_cleaned.len;
        while (idx > 0) {
            idx -= 1;
            const rm = matched_cleaned[idx];
            const is_ua = std.mem.eql(u8, rm.origin, "user-agent");
            const is_inj = std.mem.eql(u8, rm.origin, "injected");
            if ((is_ua or is_inj) and !added_attrs) {
                added_attrs = true;
                if (attrs_style_val) |av| if (av == .object) {
                    const attr_sel = if (ctx.target_tag.len > 0)
                        try std.fmt.allocPrint(arena, "{s}[attributes style]", .{ctx.target_tag})
                    else
                        "[attributes style]";
                    const ws = try parseWorkingStyle(arena, .attributes, attr_sel, null, &.{}, "", false, false, av.object);
                    if (ws.props.len > 0) try styles.append(arena, ws);
                };
            }
            const ws = try buildRuleWorkingStyle(ctx, rm);
            if (ws.props.len > 0) {
                try styles.append(arena, ws);
                if (ruleDedupKey(arena, &ws)) |k| try seen_rules.append(arena, k);
            }
        }
        if (!added_attrs) {
            if (attrs_style_val) |av| if (av == .object) {
                const attr_sel = if (ctx.target_tag.len > 0)
                    try std.fmt.allocPrint(arena, "{s}[attributes style]", .{ctx.target_tag})
                else
                    "[attributes style]";
                const ws = try parseWorkingStyle(arena, .attributes, attr_sel, null, &.{}, "", false, false, av.object);
                if (ws.props.len > 0) try styles.append(arena, ws);
            };
        }

        try main_cascades.append(arena, .{
            .is_inherited = false,
            .node = ctx.target_node,
            .styles = styles.items,
        });
    }

    // Inherited NodeCascades (direct parent up to root).
    if (payload.get("inherited")) |inh_val| if (inh_val == .array) {
        for (inh_val.array.items, 0..) |entry_val, anc_idx| {
            if (entry_val != .object) continue;
            if (anc_idx >= ctx.ancestor_nodes.len) break;
            const anc_node = ctx.ancestor_nodes[anc_idx];
            var styles: std.ArrayList(WorkingStyle) = .empty;

            if (entry_val.object.get("inlineStyle")) |inl| if (inl == .object) {
                const ws = try parseWorkingStyle(arena, .inline_style, "element.style", null, &.{}, "", false, false, inl.object);
                if (hasInheritableProp(ws.props, reg_props.items, false)) {
                    try styles.append(arena, ws);
                }
            };

            const anc_matched = try cleanUserAgentMatches(arena, entry_val.object.get("matchedCSSRules"));
            var idx: usize = anc_matched.len;
            while (idx > 0) {
                idx -= 1;
                const ws = try buildRuleWorkingStyle(ctx, anc_matched[idx]);
                if (!hasInheritableProp(ws.props, reg_props.items, false)) continue;
                if (!hasCustomProp(ws.props)) {
                    if (ruleDedupKey(arena, &ws)) |k| {
                        var dup = false;
                        for (seen_rules.items) |prev| if (std.mem.eql(u8, prev, k)) {
                            dup = true;
                            break;
                        };
                        if (dup) continue;
                    }
                }
                if (ruleDedupKey(arena, &ws)) |k| try seen_rules.append(arena, k);
                try styles.append(arena, ws);
            }

            try main_cascades.append(arena, .{
                .is_inherited = true,
                .node = anc_node,
                .styles = styles.items,
            });
        }
    };

    try computeCascadeStates(arena, main_cascades.items, reg_props.items);

    // Emit CascadeRules for main cascade.
    for (main_cascades.items) |nc| {
        for (nc.styles) |ws| {
            if (nc.is_inherited) {
                const formatted = try formatProps(arena, ws.props, true, reg_props.items, false);
                if (formatted.len == 0) continue;
                try rules_out.append(arena, .{
                    .kind = .inherited,
                    .selector = ws.selector,
                    .source = ws.source,
                    .ancestors = ws.ancestors,
                    .properties = formatted,
                    .node = nc.node,
                });
            } else {
                const formatted = try formatProps(arena, ws.props, false, reg_props.items, false);
                if (formatted.len == 0) continue;
                try rules_out.append(arena, .{
                    .kind = switch (ws.kind) {
                        .inline_style => .inline_style,
                        .attributes => .attributes,
                        .matched => .matched,
                    },
                    .selector = ws.selector,
                    .source = ws.source,
                    .ancestors = ws.ancestors,
                    .properties = formatted,
                });
            }
        }
    }

    // 3. Pseudo-element styles.
    if (payload.get("pseudoElements")) |pe_val| if (pe_val == .array) {
        for (pe_val.array.items) |entry_val| {
            if (entry_val != .object) continue;
            const ptype = str(entry_val.object.get("pseudoType"));
            if (ptype.len == 0) continue;
            const label = try std.fmt.allocPrint(arena, "::{s}", .{ptype});
            const is_hl = isHighlightPseudo(ptype);
            const cleaned = try cleanUserAgentMatches(arena, entry_val.object.get("matches"));
            var styles: std.ArrayList(WorkingStyle) = .empty;
            var idx: usize = cleaned.len;
            while (idx > 0) {
                idx -= 1;
                const ws = try buildRuleWorkingStyle(ctx, cleaned[idx]);
                if (ws.props.len > 0) try styles.append(arena, ws);
            }
            var pc = [_]NodeCascade{.{
                .is_inherited = false,
                .is_highlight = is_hl,
                .styles = styles.items,
            }};
            try computeCascadeStates(arena, &pc, reg_props.items);
            for (pc[0].styles) |ws| {
                const formatted = try formatProps(arena, ws.props, false, reg_props.items, is_hl);
                if (formatted.len == 0) continue;
                try rules_out.append(arena, .{
                    .kind = .pseudo,
                    .selector = ws.selector,
                    .source = ws.source,
                    .ancestors = ws.ancestors,
                    .properties = formatted,
                    .pseudo_type = label,
                });
            }
        }
    };

    // 4. @keyframes rules.
    if (payload.get("cssKeyframesRules")) |kf_val| if (kf_val == .array) {
        for (kf_val.array.items) |kf_item| {
            if (kf_item != .object) continue;
            const anim_name = nestedStr(kf_item.object, "animationName", "text");
            const kframes = kf_item.object.get("keyframes") orelse continue;
            if (kframes != .array) continue;
            var steps: std.ArrayList(KeyframeStep) = .empty;
            var parent_source: ?[]const u8 = null;
            for (kframes.array.items) |kf| {
                if (kf != .object) continue;
                const style_val = kf.object.get("style") orelse continue;
                if (style_val != .object) continue;
                const key_text = nestedStr(kf.object, "keyText", "text");
                const origin = str(kf.object.get("origin"));
                const sid = str(kf.object.get("styleSheetId"));
                const src = try sourceLocationForNonStyleRule(arena, origin, sid, style_val.object, ctx.sheets);
                if (parent_source == null and src != null) parent_source = src;
                const ws = try parseWorkingStyle(arena, .matched, key_text, src, &.{}, "", false, false, style_val.object);
                const formatted = try formatProps(arena, ws.props, false, reg_props.items, false);
                if (formatted.len == 0) continue;
                try steps.append(arena, .{
                    .key_text = key_text,
                    .properties = formatted,
                });
            }
            if (steps.items.len == 0) continue;
            try rules_out.append(arena, .{
                .kind = .keyframes,
                .selector = try std.fmt.allocPrint(arena, "@keyframes {s}", .{anim_name}),
                .source = parent_source,
                .keyframes = steps.items,
            });
        }
    };

    // 5. @position-try rules.
    if (payload.get("cssPositionTryRules")) |pt_val| if (pt_val == .array) {
        for (pt_val.array.items) |pt_item| {
            if (pt_item != .object) continue;
            const style_val = pt_item.object.get("style") orelse continue;
            if (style_val != .object) continue;
            const name = nestedStr(pt_item.object, "name", "text");
            const active = if (pt_item.object.get("active")) |v| v == .bool and v.bool else false;
            const origin = str(pt_item.object.get("origin"));
            const sid = str(pt_item.object.get("styleSheetId"));
            const src = try sourceLocationForNonStyleRule(arena, origin, sid, style_val.object, ctx.sheets);
            const ws = try parseWorkingStyle(arena, .matched, name, src, &.{}, "", false, false, style_val.object);
            const formatted = try formatProps(arena, ws.props, false, reg_props.items, false);
            if (formatted.len == 0) continue;
            try rules_out.append(arena, .{
                .kind = .position_try,
                .selector = try std.fmt.allocPrint(arena, "@position-try {s}", .{name}),
                .source = src,
                .properties = formatted,
                .active = active,
            });
        }
    };

    // 6. Registered @property rules + CSS.registerProperty registrations.
    if (payload.get("cssPropertyRules")) |pr_val| if (pr_val == .array) {
        for (pr_val.array.items) |pr_item| {
            if (pr_item != .object) continue;
            const style_val = pr_item.object.get("style") orelse continue;
            if (style_val != .object) continue;
            const pname = nestedStr(pr_item.object, "propertyName", "text");
            const origin = str(pr_item.object.get("origin"));
            const sid = str(pr_item.object.get("styleSheetId"));
            const src = try sourceLocationForNonStyleRule(arena, origin, sid, style_val.object, ctx.sheets);
            const ws = try parseWorkingStyle(arena, .matched, pname, src, &.{}, "", false, false, style_val.object);
            const formatted = try formatProps(arena, ws.props, false, reg_props.items, false);
            if (formatted.len == 0) continue;
            try rules_out.append(arena, .{
                .kind = .property,
                .selector = try std.fmt.allocPrint(arena, "@property {s}", .{pname}),
                .source = src,
                .properties = formatted,
            });
        }
    };
    if (payload.get("cssPropertyRegistrations")) |reg_val| if (reg_val == .array) {
        for (reg_val.array.items) |reg_item| {
            if (reg_item != .object) continue;
            const pname = str(reg_item.object.get("propertyName"));
            if (pname.len == 0) continue;
            var props: std.ArrayList(FormattedProperty) = .empty;
            const syn = str(reg_item.object.get("syntax"));
            if (syn.len > 0) {
                try props.append(arena, .{
                    .name = "syntax",
                    .value = try std.fmt.allocPrint(arena, "\"{s}\"", .{syn}),
                    .status = .active,
                });
            }
            const inh = if (reg_item.object.get("inherits")) |v| v == .bool and v.bool else false;
            try props.append(arena, .{
                .name = "inherits",
                .value = if (inh) "true" else "false",
                .status = .active,
            });
            const init_val = nestedStr(reg_item.object, "initialValue", "text");
            if (init_val.len > 0) {
                try props.append(arena, .{
                    .name = "initial-value",
                    .value = init_val,
                    .status = .active,
                });
            }
            try rules_out.append(arena, .{
                .kind = .property,
                .selector = try std.fmt.allocPrint(arena, "@property {s}", .{pname}),
                .source = "CSS.registerProperty",
                .properties = props.items,
            });
        }
    };

    return rules_out.items;
}

/// Formats the paginated slice of `CascadeRule`s exactly like `CssFormatter.toString()`.
pub fn formatToString(
    arena: Allocator,
    element: NodeInfo,
    rules: []const CascadeRule,
) Allocator.Error![]const u8 {
    var w: Writer = .{ .arena = arena, .indent = 0 };
    try w.writeLine(try std.fmt.allocPrint(arena, "Styles for {s} (uid: \"{s}\"):", .{ element.selector, element.uid orelse "" }));
    if (rules.len == 0) {
        try w.writeEmptyLine();
        try w.writeLine("  (no styles)");
        return std.mem.join(arena, "\n", w.lines.items);
    }
    w.indent = 2;
    for (rules) |rule| {
        try w.writeEmptyLine();
        switch (rule.kind) {
            .inherited => {
                if (rule.node) |n| {
                    if (n.uid) |u| {
                        try w.writeLine(try std.fmt.allocPrint(arena, "Inherited from {s} (uid: \"{s}\"):", .{ n.selector, u }));
                    } else {
                        try w.writeLine(try std.fmt.allocPrint(arena, "Inherited from {s}:", .{n.selector}));
                    }
                }
                w.indent += 2;
                try appendRuleWithAncestors(&w, rule);
                w.indent -= 2;
            },
            .pseudo => {
                const ptype = rule.pseudo_type orelse "";
                if (rule.node) |n| {
                    if (n.uid) |u| {
                        try w.writeComment(try std.fmt.allocPrint(arena, "Pseudo {s} element (inherited from {s}, uid: \"{s}\")", .{ ptype, n.selector, u }));
                    } else {
                        try w.writeComment(try std.fmt.allocPrint(arena, "Pseudo {s} element (inherited from {s})", .{ ptype, n.selector }));
                    }
                } else {
                    try w.writeComment(try std.fmt.allocPrint(arena, "Pseudo {s} element", .{ptype}));
                }
                try appendRuleWithAncestors(&w, rule);
            },
            .keyframes => {
                const header = try cascadeRuleHeader(arena, rule);
                try w.writeLine(try std.fmt.allocPrint(arena, "{s} {{", .{header}));
                w.indent += 2;
                for (rule.keyframes) |step| {
                    try w.writeLine(try std.fmt.allocPrint(arena, "{s} {{", .{step.key_text}));
                    w.indent += 2;
                    for (step.properties) |prop| {
                        try w.writeLine(try formatPropLine(arena, prop));
                    }
                    w.indent -= 2;
                    try w.writeLine("}");
                }
                w.indent -= 2;
                try w.writeLine("}");
            },
            else => try appendRuleWithAncestors(&w, rule),
        }
    }
    return std.mem.join(arena, "\n", w.lines.items);
}

const Writer = struct {
    arena: Allocator,
    lines: std.ArrayList([]const u8) = .empty,
    indent: usize = 0,

    fn writeLine(self: *Writer, text: []const u8) Allocator.Error!void {
        if (self.indent == 0) {
            try self.lines.append(self.arena, text);
            return;
        }
        const buf = try self.arena.alloc(u8, self.indent + text.len);
        @memset(buf[0..self.indent], ' ');
        @memcpy(buf[self.indent..], text);
        try self.lines.append(self.arena, buf);
    }

    fn writeEmptyLine(self: *Writer) Allocator.Error!void {
        try self.lines.append(self.arena, "");
    }

    fn writeComment(self: *Writer, text: []const u8) Allocator.Error!void {
        try self.writeLine(try std.fmt.allocPrint(self.arena, "/* {s} */", .{text}));
    }
};

fn appendRuleWithAncestors(w: *Writer, rule: CascadeRule) Allocator.Error!void {
    const arena = w.arena;
    for (rule.ancestors) |anc| {
        switch (anc) {
            .layer => |name| {
                const h = if (name) |n| (if (n.len > 0) try std.fmt.allocPrint(arena, "@layer {s}", .{n}) else "@layer") else "@layer";
                try w.writeLine(try std.fmt.allocPrint(arena, "{s} {{", .{h}));
            },
            .media => |q| try w.writeLine(try std.fmt.allocPrint(arena, "@media {s} {{", .{q})),
            .container => |ct| {
                if (ct.container) |cinfo| {
                    if (cinfo.uid) |u| {
                        try w.writeComment(try std.fmt.allocPrint(arena, "container: {s} (uid: \"{s}\")", .{ cinfo.selector, u }));
                    } else if (cinfo.selector.len > 0) {
                        try w.writeComment(try std.fmt.allocPrint(arena, "container: {s}", .{cinfo.selector}));
                    }
                }
                const prepend_name = if (ct.name) |n| (n.len > 0 and !std.mem.startsWith(u8, ct.query, n)) else false;
                if (prepend_name) {
                    try w.writeLine(try std.fmt.allocPrint(arena, "@container {s} {s} {{", .{ ct.name.?, ct.query }));
                } else {
                    try w.writeLine(try std.fmt.allocPrint(arena, "@container {s} {{", .{ct.query}));
                }
            },
            .scope => |q| {
                const trimmed = if (q) |s| std.mem.trim(u8, s, " \t\n\r") else "";
                if (trimmed.len > 0) {
                    try w.writeLine(try std.fmt.allocPrint(arena, "@scope {s} {{", .{trimmed}));
                } else {
                    try w.writeLine("@scope {");
                }
            },
            .supports => |q| try w.writeLine(try std.fmt.allocPrint(arena, "@supports {s} {{", .{q})),
            .starting_style => try w.writeLine("@starting-style {"),
            .nesting => |sel| try w.writeLine(try std.fmt.allocPrint(arena, "{s} {{", .{sel})),
            .navigation => |q| try w.writeLine(try std.fmt.allocPrint(arena, "@navigation {s} {{", .{q})),
        }
        w.indent += 2;
    }

    const header = try cascadeRuleHeader(arena, rule);
    try w.writeLine(try std.fmt.allocPrint(arena, "{s} {{", .{header}));
    w.indent += 2;
    for (rule.properties) |prop| {
        try w.writeLine(try formatPropLine(arena, prop));
    }
    w.indent -= 2;
    try w.writeLine("}");

    for (rule.ancestors) |_| {
        w.indent -= 2;
        try w.writeLine("}");
    }
}

fn cascadeRuleHeader(arena: Allocator, rule: CascadeRule) Allocator.Error![]const u8 {
    const sel: []const u8 = switch (rule.kind) {
        .inherited => if (rule.selector.len > 0) rule.selector else "element.style",
        .pseudo => if (rule.selector.len > 0) rule.selector else (rule.pseudo_type orelse ""),
        .position_try => if (rule.active) rule.selector else try std.fmt.allocPrint(arena, "[inactive] {s}", .{rule.selector}),
        else => rule.selector,
    };
    if (rule.source) |src| {
        return std.fmt.allocPrint(arena, "{s} ({s})", .{ sel, src });
    }
    return sel;
}

fn formatPropLine(arena: Allocator, prop: FormattedProperty) Allocator.Error![]const u8 {
    const imp = if (prop.important and !endsWithImportant(prop.value)) " !important" else "";
    return std.fmt.allocPrint(arena, "{s}{s}: {s}{s};", .{ prop.status.tag(), prop.name, prop.value, imp });
}

fn endsWithImportant(value: []const u8) bool {
    const trimmed = std.mem.trimEnd(u8, value, " \t\r\n");
    if (trimmed.len < 10) return false;
    const s = trimmed.len - 9;
    if (!std.ascii.eqlIgnoreCase(trimmed[s..], "important")) return false;
    const before = std.mem.trimEnd(u8, trimmed[0..s], " \t\r\n");
    return before.len > 0 and before[before.len - 1] == '!';
}

// ============================================================================
// DOMNode.simpleSelector() reproduction (Chromium DevTools Frontend)
// ============================================================================

pub fn simpleSelector(arena: Allocator, node_obj: std.json.ObjectMap) Allocator.Error![]const u8 {
    const local_raw = str(node_obj.get("localName"));
    const node_name = str(node_obj.get("nodeName"));
    const lower = if (local_raw.len > 0) local_raw else try std.ascii.allocLowerString(arena, node_name);
    const node_type = intField(node_obj, "nodeType") orelse 1;
    if (node_type != 1) return lower;

    var attr_type: ?[]const u8 = null;
    var attr_id: ?[]const u8 = null;
    var attr_class: ?[]const u8 = null;
    if (node_obj.get("attributes")) |attrs| if (attrs == .array) {
        const items = attrs.array.items;
        var i: usize = 0;
        while (i + 1 < items.len) : (i += 2) {
            const k = str(items[i]);
            const v = str(items[i + 1]);
            if (std.mem.eql(u8, k, "type")) attr_type = v else if (std.mem.eql(u8, k, "id")) attr_id = v else if (std.mem.eql(u8, k, "class")) attr_class = v;
        }
    };

    if (std.mem.eql(u8, lower, "input") and attr_type != null and attr_type.?.len > 0 and (attr_id == null or attr_id.?.len == 0) and (attr_class == null or attr_class.?.len == 0)) {
        const esc = try cssEscape(arena, attr_type.?);
        return std.fmt.allocPrint(arena, "input[type=\"{s}\"]", .{esc});
    }
    if (attr_id) |id_val| if (id_val.len > 0) {
        const esc = try cssEscape(arena, id_val);
        return std.fmt.allocPrint(arena, "{s}#{s}", .{ lower, esc });
    };
    if (attr_class) |cls_val| {
        const trimmed = std.mem.trim(u8, cls_val, " \t\r\n");
        if (trimmed.len > 0) {
            var out: std.ArrayList(u8) = .empty;
            if (!std.mem.eql(u8, lower, "div")) try out.appendSlice(arena, lower);
            var it = std.mem.tokenizeAny(u8, trimmed, " \t\r\n");
            while (it.next()) |tok| {
                try out.append(arena, '.');
                try out.appendSlice(arena, try cssEscape(arena, tok));
            }
            return out.items;
        }
    }
    return lower;
}

fn cssEscape(arena: Allocator, input: []const u8) Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (input, 0..) |c, idx| {
        if (c == 0) {
            try out.appendSlice(arena, "\xef\xbf\xbd");
        } else if ((c >= 0x01 and c <= 0x1F) or c == 0x7F or
            (idx == 0 and c >= '0' and c <= '9') or
            (idx == 1 and c >= '0' and c <= '9' and input[0] == '-'))
        {
            const hex = try std.fmt.allocPrint(arena, "\\{x} ", .{c});
            try out.appendSlice(arena, hex);
        } else if (idx == 0 and input.len == 1 and c == '-') {
            try out.appendSlice(arena, "\\-");
        } else if (c >= 0x80 or c == '-' or c == '_' or
            (c >= '0' and c <= '9') or
            (c >= 'A' and c <= 'Z') or
            (c >= 'a' and c <= 'z'))
        {
            try out.append(arena, c);
        } else {
            try out.append(arena, '\\');
            try out.append(arena, c);
        }
    }
    return out.items;
}

// ============================================================================
// cleanUserAgentPayload & RuleMatch parsing
// ============================================================================

const CleanedRuleMatch = struct {
    selector_text: []const u8,
    first_selector_start_line: ?i64,
    origin: []const u8,
    style_sheet_id: ?[]const u8,
    media_key: []const u8,
    rule_obj: std.json.ObjectMap,
    /// For merged UA rules: unioned property name/value pairs (overrides rule_obj.style).
    merged_ua_props: ?[]const WorkingProp = null,
};

fn cleanUserAgentMatches(arena: Allocator, maybe_arr: ?std.json.Value) Allocator.Error![]const CleanedRuleMatch {
    const arr = maybe_arr orelse return &.{};
    if (arr != .array) return &.{};

    var out: std.ArrayList(CleanedRuleMatch) = .empty;
    for (arr.array.items) |rm_val| {
        if (rm_val != .object) continue;
        const rule_val = rm_val.object.get("rule") orelse continue;
        if (rule_val != .object) continue;
        const rule_obj = rule_val.object;
        const origin = str(rule_obj.get("origin"));
        const is_ua = std.mem.eql(u8, origin, "user-agent");
        const sid_raw = str(rule_obj.get("styleSheetId"));
        const sid: ?[]const u8 = if (sid_raw.len > 0) sid_raw else null;

        var sel_text = nestedStr(rule_obj, "selectorList", "text");
        var first_line: ?i64 = null;
        if (rule_obj.get("selectorList")) |sl| if (sl == .object) {
            if (sl.object.get("selectors")) |sels| if (sels == .array and sels.array.items.len > 0) {
                if (is_ua) {
                    if (rm_val.object.get("matchingSelectors")) |ms| if (ms == .array and ms.array.items.len > 0) {
                        var joined: std.ArrayList(u8) = .empty;
                        for (ms.array.items, 0..) |idx_v, k| {
                            if (idx_v != .integer or idx_v.integer < 0) continue;
                            const si: usize = @intCast(idx_v.integer);
                            if (si >= sels.array.items.len) continue;
                            const s_obj = sels.array.items[si];
                            if (s_obj != .object) continue;
                            if (k > 0) try joined.appendSlice(arena, ", ");
                            try joined.appendSlice(arena, str(s_obj.object.get("text")));
                        }
                        if (joined.items.len > 0) sel_text = joined.items;
                    };
                }
                const first_sel = sels.array.items[0];
                if (first_sel == .object) {
                    if (first_sel.object.get("range")) |r| if (r == .object) {
                        first_line = intField(r.object, "startLine");
                    };
                }
            };
        };

        const mkey = try mediaKeyOf(arena, rule_obj);

        if (is_ua and out.items.len > 0) {
            const last = &out.items[out.items.len - 1];
            if (std.mem.eql(u8, last.origin, "user-agent") and
                std.mem.eql(u8, last.selector_text, sel_text) and
                std.mem.eql(u8, last.media_key, mkey))
            {
                // Merge consecutive UA rules with same cleaned selector & media.
                var merged: std.ArrayList(WorkingProp) = .empty;
                if (last.merged_ua_props) |existing| {
                    try merged.appendSlice(arena, existing);
                } else if (last.rule_obj.get("style")) |st| if (st == .object) {
                    const ws = try parseWorkingStyle(arena, .matched, sel_text, null, &.{}, "", true, false, st.object);
                    try merged.appendSlice(arena, ws.props);
                };
                if (rule_obj.get("style")) |st| if (st == .object) {
                    const ws = try parseWorkingStyle(arena, .matched, sel_text, null, &.{}, "", true, false, st.object);
                    for (ws.props) |np| {
                        var replaced = false;
                        for (merged.items) |*ep| {
                            if (std.mem.eql(u8, ep.name, np.name)) {
                                ep.* = np;
                                replaced = true;
                                break;
                            }
                        }
                        if (!replaced) try merged.append(arena, np);
                    }
                };
                last.merged_ua_props = merged.items;
                continue;
            }
        }

        try out.append(arena, .{
            .selector_text = sel_text,
            .first_selector_start_line = first_line,
            .origin = origin,
            .style_sheet_id = sid,
            .media_key = mkey,
            .rule_obj = rule_obj,
        });
    }
    return out.items;
}

fn mediaKeyOf(arena: Allocator, rule_obj: std.json.ObjectMap) Allocator.Error![]const u8 {
    const mval = rule_obj.get("media") orelse return "";
    if (mval != .array or mval.array.items.len == 0) return "";
    var out: std.ArrayList(u8) = .empty;
    for (mval.array.items, 0..) |m, i| {
        if (m != .object) continue;
        if (i > 0) try out.appendSlice(arena, ", ");
        try out.appendSlice(arena, str(m.object.get("text")));
    }
    return out.items;
}

fn buildRuleWorkingStyle(ctx: *const CollectContext, rm: CleanedRuleMatch) Allocator.Error!WorkingStyle {
    const arena = ctx.arena;
    const is_ua = std.mem.eql(u8, rm.origin, "user-agent");
    const is_inj = std.mem.eql(u8, rm.origin, "injected");
    const src = try sourceLocationForStyleRule(arena, rm.origin, rm.style_sheet_id, rm.first_selector_start_line, ctx.sheets);
    const ancestors = try collectAncestors(arena, rm.rule_obj, ctx.container_details);
    const layer_key = try buildLayerKey(arena, rm.rule_obj);

    if (rm.merged_ua_props) |merged| {
        const copy = try arena.dupe(WorkingProp, merged);
        return .{
            .kind = .matched,
            .selector = rm.selector_text,
            .source = src,
            .ancestors = ancestors,
            .layer_key = layer_key,
            .is_user_agent = true,
            .is_injected = false,
            .has_range = false,
            .style_sheet_id = rm.style_sheet_id,
            .props = copy,
        };
    }

    const st_val = rm.rule_obj.get("style") orelse return .{
        .kind = .matched,
        .selector = rm.selector_text,
        .source = src,
        .ancestors = ancestors,
        .layer_key = layer_key,
        .is_user_agent = is_ua,
        .is_injected = is_inj,
        .style_sheet_id = rm.style_sheet_id,
    };
    if (st_val != .object) return .{
        .kind = .matched,
        .selector = rm.selector_text,
        .source = src,
        .ancestors = ancestors,
        .layer_key = layer_key,
        .is_user_agent = is_ua,
        .is_injected = is_inj,
        .style_sheet_id = rm.style_sheet_id,
    };
    var ws = try parseWorkingStyle(arena, .matched, rm.selector_text, src, ancestors, layer_key, is_ua, is_inj, st_val.object);
    ws.style_sheet_id = rm.style_sheet_id;
    return ws;
}

fn parseWorkingStyle(
    arena: Allocator,
    kind: @FieldType(WorkingStyle, "kind"),
    selector: []const u8,
    source: ?[]const u8,
    ancestors: []const Ancestor,
    layer_key: []const u8,
    is_ua: bool,
    is_inj: bool,
    style_obj: std.json.ObjectMap,
) Allocator.Error!WorkingStyle {
    const has_style_range = if (style_obj.get("range")) |r| r == .object else false;
    var range_key: ?[]const u8 = null;
    if (style_obj.get("range")) |r| if (r == .object) {
        range_key = try std.fmt.allocPrint(arena, "{d}:{d}:{d}:{d}", .{
            intField(r.object, "startLine") orelse 0,
            intField(r.object, "startColumn") orelse 0,
            intField(r.object, "endLine") orelse 0,
            intField(r.object, "endColumn") orelse 0,
        });
    };

    var props_list: std.ArrayList(WorkingProp) = .empty;
    if (style_obj.get("cssProperties")) |arr| if (arr == .array) {
        for (arr.array.items) |p_val| {
            if (p_val != .object) continue;
            const p = p_val.object;
            const name = str(p.get("name"));
            if (name.len == 0) continue;
            const has_prop_range = if (p.get("range")) |r| r == .object else false;
            // CSSStyleDeclaration.leadingProperties(): when the style has a source
            // range, only properties with a source range are leading properties!
            if (has_style_range and !has_prop_range) continue;

            var value = str(p.get("value"));
            const imp = if (p.get("important")) |v| v == .bool and v.bool else false;
            if (imp) {
                value = stripTrailingImportant(value);
            }
            const parsed_ok = if (p.get("parsedOk")) |v| (if (v == .bool) v.bool else true) else true;
            const disabled = if (p.get("disabled")) |v| (v == .bool and v.bool) else false;

            var lhs: std.ArrayList(LonghandRef) = .empty;
            if (p.get("longhandProperties")) |lh_arr| if (lh_arr == .array) {
                for (lh_arr.array.items) |lh_val| {
                    if (lh_val != .object) continue;
                    const lh_name = str(lh_val.object.get("name"));
                    if (lh_name.len == 0) continue;
                    const lh_imp = if (lh_val.object.get("important")) |v| v == .bool and v.bool else imp;
                    try lhs.append(arena, .{ .name = lh_name, .important = lh_imp });
                }
            };
            // If shorthand without explicit longhandProperties (e.g. UA/parsed without source),
            // expand longhands from css.properties so shorthand overload checks still work.
            if (lhs.items.len == 0 and parsed_ok and !std.mem.startsWith(u8, name, "--")) {
                if (css.properties.lookup(name)) |lookup| {
                    if (lookup == .shorthand) {
                        for (lookup.shorthand.longhands()) |lh| {
                            try lhs.append(arena, .{ .name = lh.name(), .important = imp });
                        }
                    }
                }
            }

            try props_list.append(arena, .{
                .name = name,
                .value = value,
                .important = imp,
                .parsed_ok = parsed_ok,
                .disabled = disabled,
                .has_range = has_prop_range,
                .longhands = lhs.items,
            });
        }
    };

    // Compute active_in_style within this declaration block (last winning declaration wins).
    var seen_in_style: std.StringArrayHashMapUnmanaged(usize) = .empty;
    for (props_list.items, 0..) |*prop, idx| {
        if (!prop.parsed_ok or prop.disabled) {
            prop.active_in_style = false;
            continue;
        }
        if (seen_in_style.get(prop.name)) |prev_idx| {
            const prev = &props_list.items[prev_idx];
            if (!prev.important or prop.important) {
                prev.active_in_style = false;
                try seen_in_style.put(arena, prop.name, idx);
            } else {
                prop.active_in_style = false;
            }
        } else {
            try seen_in_style.put(arena, prop.name, idx);
        }
    }

    return .{
        .kind = kind,
        .selector = selector,
        .source = source,
        .ancestors = ancestors,
        .layer_key = layer_key,
        .is_user_agent = is_ua,
        .is_injected = is_inj,
        .has_range = has_style_range,
        .range_key = range_key,
        .props = props_list.items,
    };
}

fn stripTrailingImportant(value: []const u8) []const u8 {
    const trimmed = std.mem.trimEnd(u8, value, " \t\r\n");
    if (trimmed.len < 10) return value;
    const s = trimmed.len - 9;
    if (!std.ascii.eqlIgnoreCase(trimmed[s..], "important")) return value;
    const before = std.mem.trimEnd(u8, trimmed[0..s], " \t\r\n");
    if (before.len == 0 or before[before.len - 1] != '!') return value;
    return std.mem.trimEnd(u8, before[0 .. before.len - 1], " \t\r\n");
}

// ============================================================================
// Cascade propertyState computation (NodeCascade + DOMInheritanceCascade)
// ============================================================================

const ActiveEntry = struct {
    important: bool,
    is_user_agent: bool,
    layer_key: []const u8,
    prop_ptr: *WorkingProp,
    longhand_ptr: ?*LonghandRef = null,
};

fn computeCascadeStates(
    arena: Allocator,
    cascades: []NodeCascade,
    registered: []const RegisteredProp,
) Allocator.Error!void {
    var global_active: std.StringArrayHashMapUnmanaged(void) = .empty;

    for (cascades) |*nc| {
        var node_active: std.StringArrayHashMapUnmanaged(ActiveEntry) = .empty;

        // NodeCascade.computeActiveProperties: iterate styles from LOWEST to HIGHEST
        // precedence (reverse of display order).
        var si: usize = nc.styles.len;
        while (si > 0) {
            si -= 1;
            const ws = &nc.styles[si];
            for (ws.props) |*prop| {
                if (!prop.parsed_ok) {
                    prop.status = .invalid;
                    continue;
                }
                if (prop.disabled) {
                    prop.status = .disabled;
                    continue;
                }
                if (nc.is_inherited and !isInheritable(prop.name, registered, nc.is_highlight)) {
                    continue;
                }
                if (!prop.active_in_style) {
                    prop.status = .overloaded;
                    continue;
                }
                if (prop.longhands.len > 0) {
                    // Shorthand: update each longhand independently; shorthand is active
                    // as long as at least one longhand stays active.
                    var any_active = false;
                    for (prop.longhands) |*lh| {
                        const won = try updateActive(&node_active, arena, lh.name, .{
                            .important = lh.important,
                            .is_user_agent = ws.is_user_agent,
                            .layer_key = ws.layer_key,
                            .prop_ptr = prop,
                            .longhand_ptr = lh,
                        });
                        if (won) any_active = true else lh.overloaded = true;
                    }
                    prop.status = if (any_active) .active else .overloaded;
                } else {
                    const won = try updateActive(&node_active, arena, prop.name, .{
                        .important = prop.important,
                        .is_user_agent = ws.is_user_agent,
                        .layer_key = ws.layer_key,
                        .prop_ptr = prop,
                    });
                    prop.status = if (won) .active else .overloaded;
                }
            }
        }

        // Re-check shorthands whose longhands were all later overloaded inside this NodeCascade.
        for (nc.styles) |*ws| {
            for (ws.props) |*prop| {
                if (prop.status != .active or prop.longhands.len == 0) continue;
                var any_active = false;
                for (prop.longhands) |lh| if (!lh.overloaded) {
                    any_active = true;
                    break;
                };
                if (!any_active) prop.status = .overloaded;
            }
        }

        // DOMInheritanceCascade: check against nearer cascades' active properties.
        if (nc.is_inherited) {
            for (nc.styles) |*ws| {
                for (ws.props) |*prop| {
                    if (prop.status != .active) continue;
                    if (prop.longhands.len > 0) {
                        var any_unshadowed = false;
                        for (prop.longhands) |lh| {
                            if (!lh.overloaded and !global_active.contains(lh.name)) {
                                any_unshadowed = true;
                                break;
                            }
                        }
                        if (!any_unshadowed) prop.status = .overloaded;
                    } else if (global_active.contains(prop.name)) {
                        prop.status = .overloaded;
                    }
                }
            }
        }

        // Record this cascade's active canonical property names into global_active.
        for (node_active.keys()) |k| {
            try global_active.put(arena, k, {});
        }
    }
}

fn updateActive(
    map: *std.StringArrayHashMapUnmanaged(ActiveEntry),
    arena: Allocator,
    canonical_name: []const u8,
    challenger: ActiveEntry,
) Allocator.Error!bool {
    if (map.get(canonical_name)) |existing| {
        if (shouldOverloadChallenger(existing, challenger)) {
            return false;
        }
        // Challenger beats existing.
        if (existing.longhand_ptr) |lh| {
            lh.overloaded = true;
        } else {
            existing.prop_ptr.status = .overloaded;
        }
    }
    try map.put(arena, canonical_name, challenger);
    return true;
}

/// Reproduces `NodeCascade.#shouldOverload(activeProperty, propertyWithHigherSpecificity)`
/// from Chromium DevTools Frontend (`CSSMatchedStyles.ts`).
fn shouldOverloadChallenger(existing: ActiveEntry, higher: ActiveEntry) bool {
    if (existing.important != higher.important) {
        return existing.important;
    }
    if (!existing.important) {
        return false;
    }
    // Both !important: UA !important beats author !important.
    if (existing.is_user_agent != higher.is_user_agent) {
        return existing.is_user_agent;
    }
    // Both !important in different cascade layers: earlier layer wins.
    if (!std.mem.eql(u8, existing.layer_key, higher.layer_key)) {
        return true;
    }
    return false;
}

fn formatProps(
    arena: Allocator,
    props: []const WorkingProp,
    filter_inheritable: bool,
    registered: []const RegisteredProp,
    is_highlight: bool,
) Allocator.Error![]const FormattedProperty {
    var out: std.ArrayList(FormattedProperty) = .empty;
    for (props) |p| {
        if (filter_inheritable and !isInheritable(p.name, registered, is_highlight)) continue;
        try out.append(arena, .{
            .name = p.name,
            .value = p.value,
            .important = p.important,
            .status = p.status,
        });
    }
    return out.items;
}

fn hasInheritableProp(props: []const WorkingProp, registered: []const RegisteredProp, is_highlight: bool) bool {
    for (props) |p| if (isInheritable(p.name, registered, is_highlight)) return true;
    return false;
}

fn hasCustomProp(props: []const WorkingProp) bool {
    for (props) |p| if (std.mem.startsWith(u8, p.name, "--")) return true;
    return false;
}

fn isInheritable(name: []const u8, registered: []const RegisteredProp, is_highlight: bool) bool {
    if (std.mem.startsWith(u8, name, "--")) {
        if (is_highlight) return false;
        for (registered) |r| {
            if (std.mem.eql(u8, r.name, name)) return r.inherits;
        }
        return true;
    }
    if (is_highlight) return true;
    const lookup = css.properties.lookup(name) orelse return false;
    return switch (lookup) {
        .longhand => |l| l.info().inherited,
        .shorthand => |s| blk: {
            for (s.longhands()) |lh| if (lh.info().inherited) break :blk true;
            break :blk false;
        },
    };
}

fn isHighlightPseudo(ptype: []const u8) bool {
    return std.mem.eql(u8, ptype, "selection") or
        std.mem.eql(u8, ptype, "target-text") or
        std.mem.eql(u8, ptype, "spelling-error") or
        std.mem.eql(u8, ptype, "grammar-error") or
        std.mem.eql(u8, ptype, "highlight");
}

fn ruleDedupKey(arena: Allocator, ws: *const WorkingStyle) ?[]const u8 {
    const sid = ws.style_sheet_id orelse return null;
    const rk = ws.range_key orelse return null;
    return std.fmt.allocPrint(arena, "{s}@{s}", .{ sid, rk }) catch null;
}

// ============================================================================
// Ancestor wrapper collection & source location formatting
// ============================================================================

fn collectAncestors(
    arena: Allocator,
    rule_obj: std.json.ObjectMap,
    container_details: []const ContainerDetail,
) Allocator.Error![]const Ancestor {
    const rt_val = rule_obj.get("ruleTypes") orelse return &.{};
    if (rt_val != .array or rt_val.array.items.len == 0) return &.{};

    var list: std.ArrayList(Ancestor) = .empty;
    var media_i: usize = 0;
    var container_i: usize = 0;
    var scope_i: usize = 0;
    var supports_i: usize = 0;
    var nesting_i: usize = 0;
    var layer_i: usize = 0;
    var nav_i: usize = 0;

    for (rt_val.array.items) |rt| {
        const kind = str(rt);
        if (std.mem.eql(u8, kind, "MediaRule")) {
            if (arrayElem(rule_obj.get("media"), media_i)) |m| {
                media_i += 1;
                const txt = str(m.object.get("text"));
                if (txt.len > 0) try list.append(arena, .{ .media = txt });
            }
        } else if (std.mem.eql(u8, kind, "ContainerRule")) {
            if (arrayElemPtr(rule_obj.get("containerQueries"), container_i)) |cq_ptr| {
                container_i += 1;
                const cq = cq_ptr.object;
                const qtext = str(cq.get("text"));
                const cname = str(cq.get("name"));
                var cnode: ?NodeInfo = null;
                for (container_details) |cd| {
                    if (cd.query_ptr == @intFromPtr(cq_ptr)) {
                        cnode = cd.container;
                        break;
                    }
                }
                try list.append(arena, .{ .container = .{
                    .query = qtext,
                    .name = if (cname.len > 0) cname else null,
                    .container = cnode,
                } });
            }
        } else if (std.mem.eql(u8, kind, "LayerRule")) {
            if (arrayElem(rule_obj.get("layers"), layer_i)) |l| {
                layer_i += 1;
                const lname = str(l.object.get("text"));
                try list.append(arena, .{ .layer = if (lname.len > 0) lname else null });
            }
        } else if (std.mem.eql(u8, kind, "ScopeRule")) {
            if (arrayElem(rule_obj.get("scopes"), scope_i)) |s| {
                scope_i += 1;
                const stext = str(s.object.get("text"));
                try list.append(arena, .{ .scope = if (stext.len > 0) stext else null });
            }
        } else if (std.mem.eql(u8, kind, "SupportsRule")) {
            if (arrayElem(rule_obj.get("supports"), supports_i)) |s| {
                supports_i += 1;
                const stext = str(s.object.get("text"));
                if (stext.len > 0) try list.append(arena, .{ .supports = stext });
            }
        } else if (std.mem.eql(u8, kind, "StartingStyleRule")) {
            try list.append(arena, .starting_style);
        } else if (std.mem.eql(u8, kind, "StyleRule")) {
            if (rule_obj.get("nestingSelectors")) |ns| if (ns == .array and nesting_i < ns.array.items.len) {
                const nsel = str(ns.array.items[nesting_i]);
                nesting_i += 1;
                if (nsel.len > 0) try list.append(arena, .{ .nesting = nsel });
            };
        } else if (std.mem.eql(u8, kind, "NavigationRule")) {
            if (arrayElem(rule_obj.get("navigations"), nav_i)) |n| {
                nav_i += 1;
                const ntext = str(n.object.get("text"));
                if (ntext.len > 0) try list.append(arena, .{ .navigation = ntext });
            }
        }
    }

    // CDP gives ancestors innermost-to-outermost; CssFormatter reverses to outermost-to-innermost.
    std.mem.reverse(Ancestor, list.items);
    return list.items;
}

fn buildLayerKey(arena: Allocator, rule_obj: std.json.ObjectMap) Allocator.Error![]const u8 {
    const lval = rule_obj.get("layers") orelse return "";
    if (lval != .array or lval.array.items.len == 0) return "";
    var out: std.ArrayList(u8) = .empty;
    for (lval.array.items, 0..) |l, i| {
        if (l != .object) continue;
        if (i > 0) try out.append(arena, '.');
        const txt = str(l.object.get("text"));
        if (txt.len > 0) {
            try out.appendSlice(arena, txt);
        } else {
            try out.appendSlice(arena, "anonymous");
        }
    }
    return out.items;
}

fn sourceLocationForStyleRule(
    arena: Allocator,
    origin: []const u8,
    sheet_id: ?[]const u8,
    sel_start_line: ?i64,
    sheets: *const std.StringArrayHashMapUnmanaged(session_mod.Page.CssSheetHeader),
) Allocator.Error!?[]const u8 {
    if (std.mem.eql(u8, origin, "user-agent")) return "user agent stylesheet";
    if (std.mem.eql(u8, origin, "injected")) return "injected stylesheet";
    if (std.mem.eql(u8, origin, "inspector")) return "via inspector";
    const sid = sheet_id orelse return "<style>";
    const hdr = sheets.get(sid) orelse return "<style>";
    if (hdr.is_constructed and hdr.source_url.len == 0) return "constructed stylesheet";
    const line_opt: ?i64 = if (sel_start_line) |sl| hdr.start_line + sl + 1 else null;
    return try formatSourceUrlWithLine(arena, hdr.source_url, line_opt);
}

fn sourceLocationForNonStyleRule(
    arena: Allocator,
    origin: []const u8,
    sheet_id: []const u8,
    style_obj: std.json.ObjectMap,
    sheets: *const std.StringArrayHashMapUnmanaged(session_mod.Page.CssSheetHeader),
) Allocator.Error!?[]const u8 {
    if (std.mem.eql(u8, origin, "user-agent")) return "user agent stylesheet";
    if (std.mem.eql(u8, origin, "injected")) return "injected stylesheet";
    if (std.mem.eql(u8, origin, "inspector")) return "via inspector";
    if (sheet_id.len == 0) return "<style>";
    const hdr = sheets.get(sheet_id) orelse return "<style>";
    if (hdr.is_constructed and hdr.source_url.len == 0) return "constructed stylesheet";
    var line_opt: ?i64 = null;
    if (style_obj.get("range")) |r| if (r == .object) {
        if (intField(r.object, "startLine")) |sl| {
            line_opt = hdr.start_line + sl + 1;
        }
    };
    return try formatSourceUrlWithLine(arena, hdr.source_url, line_opt);
}

fn formatSourceUrlWithLine(arena: Allocator, url: []const u8, line_1based: ?i64) Allocator.Error![]const u8 {
    const file = filenameFromUrl(url);
    if (line_1based) |ln| {
        return std.fmt.allocPrint(arena, "{s}:{d}", .{ file, ln });
    }
    return file;
}

fn filenameFromUrl(url: []const u8) []const u8 {
    if (url.len == 0) return "<style>";
    if (std.mem.startsWith(u8, url, "data:")) return "data-uri";
    if (std.mem.startsWith(u8, url, "blob:")) return "blob";
    // Strip query and fragment.
    var end = url.len;
    if (std.mem.indexOfScalar(u8, url[0..end], '#')) |i| end = i;
    if (std.mem.indexOfScalar(u8, url[0..end], '?')) |i| end = i;
    const path_part = url[0..end];
    // Skip scheme://host
    const after_scheme = if (std.mem.indexOf(u8, path_part, "://")) |s| blk: {
        const rest = path_part[s + 3 ..];
        const slash = std.mem.indexOfScalar(u8, rest, '/') orelse return "index";
        break :blk rest[slash + 1 ..];
    } else path_part;
    const last_slash = std.mem.lastIndexOfScalar(u8, after_scheme, '/');
    const comp = if (last_slash) |ls| after_scheme[ls + 1 ..] else after_scheme;
    return if (comp.len > 0) comp else "index";
}

fn arrayElem(val: ?std.json.Value, index: usize) ?std.json.Value {
    const a = val orelse return null;
    if (a != .array or index >= a.array.items.len) return null;
    const item = a.array.items[index];
    if (item != .object) return null;
    return item;
}

fn arrayElemPtr(val: ?std.json.Value, index: usize) ?*const std.json.Value {
    const a = val orelse return null;
    if (a != .array or index >= a.array.items.len) return null;
    if (a.array.items[index] != .object) return null;
    return &a.array.items[index];
}

fn nestedStr(obj: std.json.ObjectMap, outer: []const u8, inner: []const u8) []const u8 {
    const v = obj.get(outer) orelse return "";
    if (v != .object) return "";
    return str(v.object.get(inner));
}

fn intField(obj: std.json.ObjectMap, key: []const u8) ?i64 {
    const v = obj.get(key) orelse return null;
    return switch (v) {
        .integer => v.integer,
        .float => @intFromFloat(v.float),
        else => null,
    };
}
