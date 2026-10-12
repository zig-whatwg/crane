//! The CSSOM's model: what CSSStyleSheet, CSSRuleList and the CSSRule
//! objects wrap.
//!
//! Blink's split: a CSSStyleSheet wraps its StyleSheetContents, a
//! CSSStyleRule a StyleRule, and a CSSRuleList reads its sheet's rules. The
//! objects script sees are made on demand; the model is what they read. Here
//! the model is a `Sheet` - CSSOM's "CSS rules" of a CSSStyleSheet, and its
//! constructed / disallow-modification flags - and a `StyleRule` per CSS
//! style rule, shared by the sheet that holds it and the CSSStyleRule object
//! made for it. Each owning impl binds its object to its model here and
//! unbinds it in its deinit; the others read the model through this module,
//! never through another impl.
//!
//! A style sheet's rules come from src/css/rules.zig ("parse a stylesheet's
//! contents"); a style rule is kept only when its selector parses as a
//! selector list (src/selector/), as CSS drops a style rule whose selector is
//! invalid.
//!
//! TODO(cssom): at-rules. A constructed sheet's @import rules are dropped as
//! replaceSync() says; every other at-rule (@media - CSSMediaRule, @supports
//! - CSSSupportsRule, @font-face - CSSFontFaceRule, @keyframes -
//! CSSKeyframesRule, @page, @layer, @container, @namespace, ...) has no model
//! or CSSOM object yet, and is left out of the sheet's rules - so a sheet
//! with an @media rule reports a cssRules.length without it.
//!
//! An HTML element's inline style declarations are here too (`InlineStyle`):
//! the element keeps them - HTMLElement's state embeds one by value, so they
//! outlive the CSSStyleDeclaration object its `style` attribute returns, whose
//! wrapper the collector may take - and installs `inlineStyleOf`, through
//! which that object, getBoundingClientRect and getComputedStyle reach them.
//! WebKit keeps an element's inline style the same way, in its ElementData
//! (`m_inlineStyle`, Source/WebCore/dom/ElementData.h), with the
//! CSSStyleDeclaration a wrapper over it.
//!
//! lint-impls: hook for CSSStyleSheet, CSSRuleList, CSSRule, CSSStyleRule, HTMLElement
//!
//! Spec: https://drafts.csswg.org/cssom-1/#css-style-sheets
//! Spec: https://drafts.csswg.org/cssom-1/#css-rules

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const css = @import("css");
const selector = @import("selector");

/// The model lives as long as the objects that hold it, whichever realm
/// they are in.
const allocator = std.heap.c_allocator;

/// A link to an Instance that may be freed without telling the holder: the
/// slab reuses a freed Instance's address, and its generation says whether
/// the address still names the object the link was taken on.
pub const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    pub fn to(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// The instance, while it is still the object this link was taken on.
    pub fn get(self: Link) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

// ============================================================================
// Style rules
// ============================================================================

/// A CSS style rule: its selector list and its declarations - the model a
/// CSSStyleRule wraps. Held by the sheet whose rules include it and by the
/// CSSStyleRule object made for it: counted.
pub const StyleRule = struct {
    refs: u32 = 1,
    /// The selector, serialized.
    selector_text: []u8,
    /// Owned.
    declarations: []css.rules.Declaration,
    /// CSSOM "parent CSS style sheet": the sheet whose CSS rules hold this
    /// rule; null once it is removed from them.
    parent: ?Link = null,

    fn create(selector_text: []const u8, declarations: []const css.rules.Declaration) !*StyleRule {
        const self = try allocator.create(StyleRule);
        errdefer allocator.destroy(self);
        const text = try allocator.dupe(u8, selector_text);
        errdefer allocator.free(text);
        const copies = try allocator.alloc(css.rules.Declaration, declarations.len);
        var made: usize = 0;
        errdefer {
            for (copies[0..made]) |d| {
                allocator.free(d.name);
                allocator.free(d.value);
            }
            allocator.free(copies);
        }
        for (declarations, 0..) |d, i| {
            const name = try allocator.dupe(u8, d.name);
            errdefer allocator.free(name);
            copies[i] = .{ .name = name, .value = try allocator.dupe(u8, d.value), .important = d.important };
            made += 1;
        }
        self.* = .{ .selector_text = text, .declarations = copies };
        return self;
    }

    pub fn ref(self: *StyleRule) void {
        self.refs += 1;
    }

    pub fn unref(self: *StyleRule) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        for (self.declarations) |d| {
            allocator.free(d.name);
            allocator.free(d.value);
        }
        allocator.free(self.declarations);
        allocator.free(self.selector_text);
        allocator.destroy(self);
    }

    /// CSSOM "serialize a CSS declaration block" of the rule's declarations:
    /// each "name: value;" (with " !important" before the ";" when it is),
    /// joined by a space. Owned by `alloc`.
    pub fn declarationsText(self: *const StyleRule, alloc: std.mem.Allocator) ![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(alloc);
        for (self.declarations, 0..) |d, i| {
            if (i > 0) try out.append(alloc, ' ');
            try out.appendSlice(alloc, d.name);
            try out.appendSlice(alloc, ": ");
            try out.appendSlice(alloc, d.value);
            if (d.important) try out.appendSlice(alloc, " !important");
            try out.append(alloc, ';');
        }
        return out.toOwnedSlice(alloc);
    }

    /// CSSOM "serialize a CSS rule" for a CSSStyleRule: the selector, " {",
    /// the declaration block with a space either side when it has any, "}".
    /// Owned by `alloc`.
    pub fn cssText(self: *const StyleRule, alloc: std.mem.Allocator) ![]u8 {
        const block = try self.declarationsText(alloc);
        defer alloc.free(block);
        if (block.len == 0) return std.fmt.allocPrint(alloc, "{s} {{ }}", .{self.selector_text});
        return std.fmt.allocPrint(alloc, "{s} {{ {s} }}", .{ self.selector_text, block });
    }
};

// ============================================================================
// Style sheets
// ============================================================================

/// A CSSStyleSheet's model: its CSS rules and the flags CSSOM gives it.
pub const Sheet = struct {
    /// CSSOM "CSS rules", in order; each held (counted).
    rules: std.ArrayList(*StyleRule) = .empty,
    /// CSSOM "constructed flag".
    constructed: bool = false,
    /// CSSOM "disallow modification flag".
    disallow_modification: bool = false,

    /// Remove every rule: each one's parent CSS style sheet becomes null.
    fn clearRules(self: *Sheet) void {
        for (self.rules.items) |rule| {
            rule.parent = null;
            rule.unref();
        }
        self.rules.clearRetainingCapacity();
    }

    /// The number of CSS rules.
    pub fn length(self: *const Sheet) usize {
        return self.rules.items.len;
    }

    /// The CSS rule at `index`, or null past the end.
    pub fn ruleAt(self: *const Sheet, index: usize) ?*StyleRule {
        if (index >= self.rules.items.len) return null;
        return self.rules.items[index];
    }
};

/// Every sheet's model, by its CSSStyleSheet object: a sheet's impl binds it
/// at construction and unbinds it in its deinit, so an address is here only
/// while its object lives. Per thread: a sheet and its realm live on one.
threadlocal var sheets: std.AutoHashMapUnmanaged(*runtime.Instance, *Sheet) = .empty;

/// Bind a new CSSStyleSheet object to a new, empty model.
pub fn createSheet(instance: *runtime.Instance) !*Sheet {
    const sheet = try allocator.create(Sheet);
    errdefer allocator.destroy(sheet);
    sheet.* = .{};
    try sheets.put(allocator, instance, sheet);
    return sheet;
}

/// The model of the CSSStyleSheet object `instance`.
pub fn sheetOf(instance: *runtime.Instance) ?*Sheet {
    return sheets.get(instance);
}

/// The CSSStyleSheet object is going: its rules are removed, and its model
/// freed.
pub fn destroySheet(instance: *runtime.Instance) void {
    const entry = sheets.fetchRemove(instance) orelse return;
    const sheet = entry.value;
    sheet.clearRules();
    sheet.rules.deinit(allocator);
    allocator.destroy(sheet);
}

/// CSSOM "synchronously replace the rules of a CSSStyleSheet", from its step
/// 2 on: "Let rules be the result of running parse a stylesheet's contents
/// from text. If rules contains one or more @import rules, remove those
/// rules from rules. Set sheet's CSS rules to rules." (Steps 1 - the
/// constructed and disallow-modification checks - are the caller's.)
///
/// Spec: https://drafts.csswg.org/cssom-1/#synchronously-replace-the-rules-of-a-cssstylesheet
pub fn replaceRules(sheet_instance: *runtime.Instance, text: []const u8) !void {
    const sheet = sheetOf(sheet_instance) orelse return error.InvalidStateError;
    var parsed = try css.rules.parseStyleSheetContents(allocator, text);
    defer parsed.deinit();

    var rules: std.ArrayList(*StyleRule) = .empty;
    errdefer {
        for (rules.items) |rule| rule.unref();
        rules.deinit(allocator);
    }
    for (parsed.items) |rule| {
        switch (rule.kind) {
            .qualified => {
                // A style rule whose selector list does not parse is invalid,
                // and dropped.
                if (!isValidSelectorList(rule.prelude)) continue;
                const style_rule = try StyleRule.create(rule.prelude, rule.declarations);
                errdefer style_rule.unref();
                try rules.append(allocator, style_rule);
            },
            // @import is removed by replaceSync itself. TODO(cssom): every
            // other at-rule - see this file's header.
            .at_rule => continue,
        }
    }

    sheet.clearRules();
    sheet.rules.deinit(allocator);
    sheet.rules = rules;
    const parent = Link.to(sheet_instance);
    for (sheet.rules.items) |rule| rule.parent = parent;
}

/// CSSStyleRule's selectorText setter: replace the rule's selectors with
/// `text` when it parses as a group of selectors; false, and nothing
/// changed, when it does not.
pub fn setSelectorText(model: *StyleRule, text: []const u8) !bool {
    const trimmed = std.mem.trim(u8, text, " \t\n\r\x0c");
    if (!isValidSelectorList(trimmed)) return false;
    const copy = try allocator.dupe(u8, trimmed);
    allocator.free(model.selector_text);
    model.selector_text = copy;
    return true;
}

/// Whether `text` parses as a <selector-list>, all of it.
fn isValidSelectorList(text: []const u8) bool {
    if (text.len == 0) return false;
    var tokens = selector.Tokenizer.init(allocator, text);
    var parser = selector.Parser.init(allocator, &tokens) catch return false;
    defer parser.deinit();
    var list = parser.parse() catch return false;
    list.deinit();
    // The parser stops at a token that continues no selector; the list is
    // valid only if that is the end of the input.
    while (parser.current_token) |token| {
        switch (token.tag) {
            .whitespace => parser.current_token = tokens.nextToken() catch return false,
            .eof => return true,
            else => return false,
        }
    }
    return true;
}

// ============================================================================
// Rule lists and rule objects
// ============================================================================

/// Each CSSRuleList object's sheet, while the list lives.
threadlocal var rule_lists: std.AutoHashMapUnmanaged(*runtime.Instance, Link) = .empty;

/// The CSSRuleList object `list` is the CSS rules of the CSSStyleSheet
/// object `sheet_instance`.
pub fn bindRuleList(list: *runtime.Instance, sheet_instance: *runtime.Instance) !void {
    try rule_lists.put(allocator, list, Link.to(sheet_instance));
}

pub fn unbindRuleList(list: *runtime.Instance) void {
    _ = rule_lists.remove(list);
}

/// The sheet model whose rules the CSSRuleList object `list` reads - null
/// once that sheet has gone.
pub fn ruleListSheet(list: *runtime.Instance) ?*Sheet {
    const link = rule_lists.get(list) orelse return null;
    const sheet_instance = link.get() orelse return null;
    return sheetOf(sheet_instance);
}

/// Each CSSRule object's model, held (counted) while the object lives.
threadlocal var rule_objects: std.AutoHashMapUnmanaged(*runtime.Instance, *StyleRule) = .empty;

/// The CSSStyleRule object `rule_instance` wraps `model`, which it holds.
pub fn bindRule(rule_instance: *runtime.Instance, model: *StyleRule) !void {
    try rule_objects.put(allocator, rule_instance, model);
    model.ref();
}

pub fn unbindRule(rule_instance: *runtime.Instance) void {
    const entry = rule_objects.fetchRemove(rule_instance) orelse return;
    entry.value.unref();
}

/// The model the CSSRule object `rule_instance` wraps.
pub fn ruleOf(rule_instance: *runtime.Instance) ?*StyleRule {
    return rule_objects.get(rule_instance);
}

/// The CSSStyleSheet object a rule's parent CSS style sheet is, while it
/// lives.
pub fn parentSheetOf(model: *const StyleRule) ?*runtime.Instance {
    const link = model.parent orelse return null;
    return link.get();
}

// ============================================================================
// Inline style
// ============================================================================

/// An element's inline style declarations, as its `style` CSSStyleDeclaration
/// sees them: each property's value by name, and the cssText last set.
///
/// TODO(cssom): the declarations are not parsed into a CSS declaration block
/// - cssText is split on ";" and ":" - nor kept in step with the style
/// content attribute (CSSOM 6.7 "update style attribute for" and its
/// attribute change steps).
pub const InlineStyle = struct {
    allocator: std.mem.Allocator,
    /// Property name -> value, both owned.
    properties: std.StringHashMapUnmanaged([]const u8) = .{},
    /// The cssText last set, owned; null once a property changes.
    css_text: ?[]const u8 = null,

    pub fn init(alloc: std.mem.Allocator) InlineStyle {
        return .{ .allocator = alloc };
    }

    pub fn deinit(self: *InlineStyle) void {
        self.clearProperties();
        self.properties.deinit(self.allocator);
        self.forgetCssText();
    }

    fn clearProperties(self: *InlineStyle) void {
        var iter = self.properties.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.properties.clearRetainingCapacity();
    }

    fn forgetCssText(self: *InlineStyle) void {
        if (self.css_text) |text| self.allocator.free(text);
        self.css_text = null;
    }

    /// The value of property `name`, borrowed; null when it is not set.
    pub fn getProperty(self: *const InlineStyle, name: []const u8) ?[]const u8 {
        return self.properties.get(name);
    }

    /// Set property `name` to `value` (both copied).
    pub fn setProperty(self: *InlineStyle, name: []const u8, value: []const u8) !void {
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);
        if (self.properties.getPtr(name)) |existing| {
            self.allocator.free(existing.*);
            existing.* = value_copy;
        } else {
            const name_copy = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(name_copy);
            try self.properties.put(self.allocator, name_copy, value_copy);
        }
        self.forgetCssText();
    }

    /// Remove property `name`, if it is set.
    pub fn removeProperty(self: *InlineStyle, name: []const u8) void {
        const entry = self.properties.fetchRemove(name) orelse return;
        self.allocator.free(entry.key);
        self.allocator.free(entry.value);
        self.forgetCssText();
    }

    /// The cssText last set, borrowed; empty when none is.
    pub fn cssText(self: *const InlineStyle) []const u8 {
        return self.css_text orelse "";
    }

    /// Replace every declaration with those of `text`: "property: value"
    /// pairs separated by semicolons.
    pub fn setCssText(self: *InlineStyle, text: []const u8) !void {
        self.clearProperties();
        self.forgetCssText();
        self.css_text = try self.allocator.dupe(u8, text);

        var declarations = std.mem.splitScalar(u8, text, ';');
        while (declarations.next()) |decl| {
            const trimmed = std.mem.trim(u8, decl, " \t\n\r");
            if (trimmed.len == 0) continue;
            const colon_pos = std.mem.indexOf(u8, trimmed, ":") orelse continue;
            const prop_name = std.mem.trim(u8, trimmed[0..colon_pos], " \t");
            const prop_value = std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \t");
            if (prop_name.len == 0) continue;
            const name_copy = try self.allocator.dupe(u8, prop_name);
            errdefer self.allocator.free(name_copy);
            const value_copy = try self.allocator.dupe(u8, prop_value);
            errdefer self.allocator.free(value_copy);
            // A property given twice keeps its last value.
            const slot = try self.properties.getOrPut(self.allocator, name_copy);
            if (slot.found_existing) {
                self.allocator.free(name_copy);
                self.allocator.free(slot.value_ptr.*);
            }
            slot.value_ptr.* = value_copy;
        }
    }

    /// How many properties are set.
    pub fn propertyCount(self: *const InlineStyle) u32 {
        return @intCast(self.properties.count());
    }
};

/// What HTMLElement supplies.
pub const InlineStyleSteps = struct {
    /// `element`'s inline style, or null when it has none (no HTMLElement
    /// part).
    of: *const fn (element: *runtime.Instance) ?*InlineStyle,
};

// process-wide: an immutable function pointer HTMLElement installs once at process start (crane.Process); it reads only the element it is given, so one serves every Browser and thread
var inline_style_steps: ?InlineStyleSteps = null;

/// Called by HTMLElement's installHooks, once, at process start (process_start.zig).
pub fn installInlineStyle(steps: InlineStyleSteps) void {
    process_start.assertInstalling();
    inline_style_steps = steps;
}

/// `element`'s inline style declarations, kept by the element; null for an
/// element with none (or before HTMLElement installed the step).
pub fn inlineStyleOf(element: *runtime.Instance) ?*InlineStyle {
    const steps = inline_style_steps orelse return null;
    return steps.of(element);
}

// ============================================================================
// Tests
// ============================================================================

test "InlineStyle keeps each property's last value and forgets cssText on a change" {
    var style = InlineStyle.init(std.testing.allocator);
    defer style.deinit();
    try style.setCssText("color: red; width : 1px; color: blue;;");
    try std.testing.expectEqual(@as(u32, 2), style.propertyCount());
    try std.testing.expectEqualStrings("blue", style.getProperty("color").?);
    try std.testing.expectEqualStrings("1px", style.getProperty("width").?);
    try std.testing.expectEqualStrings("color: red; width : 1px; color: blue;;", style.cssText());
    try style.setProperty("width", "2px");
    try std.testing.expectEqualStrings("2px", style.getProperty("width").?);
    try std.testing.expectEqualStrings("", style.cssText());
    style.removeProperty("color");
    style.removeProperty("absent");
    try std.testing.expectEqual(@as(u32, 1), style.propertyCount());
}

test "StyleRule serializes its declaration block and its rule" {
    const declarations = [_]css.rules.Declaration{
        .{ .name = @constCast("color"), .value = @constCast("red"), .important = false },
        .{ .name = @constCast("content"), .value = @constCast("\"x\""), .important = true },
    };
    const rule = try StyleRule.create("div > p", &declarations);
    defer rule.unref();
    const block = try rule.declarationsText(std.testing.allocator);
    defer std.testing.allocator.free(block);
    try std.testing.expectEqualStrings("color: red; content: \"x\" !important;", block);
    const text = try rule.cssText(std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("div > p { color: red; content: \"x\" !important; }", text);

    const empty = try StyleRule.create("p", &.{});
    defer empty.unref();
    const empty_text = try empty.cssText(std.testing.allocator);
    defer std.testing.allocator.free(empty_text);
    try std.testing.expectEqualStrings("p { }", empty_text);
}

test "isValidSelectorList: the whole prelude must be a selector list" {
    try std.testing.expect(isValidSelectorList("div"));
    try std.testing.expect(isValidSelectorList("#test4b"));
    try std.testing.expect(isValidSelectorList("div > p.x, #id"));
    try std.testing.expect(!isValidSelectorList("#test4 }"));
    try std.testing.expect(!isValidSelectorList(""));
}
