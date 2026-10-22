//! Computed role (Core-AAM 3.4.2) and accessible name (AccName 4.3.2).
//! This is a semantic tree walk, with HTML-AAM 3.5/4.1 native semantics.
//! Blink AXNodeObject::{TextAlternative,NativeTextAlternative} separates
//! relation, native-label and content traversal in the same way. No browser
//! code is copied. Nothing is retained between computations.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const data = @import("element_data.zig");
const bridge = @import("instance_bridge.zig");
const references = @import("element_references.zig");
const custom = @import("custom_elements.zig");
const shadows = @import("shadow_hosts.zig");
const slots = @import("slot_helpers.zig");
const style = @import("style/engine.zig");
const Instance = runtime.Instance;
const Allocator = std.mem.Allocator;
const NodeBase = @import("node_base.zig").NodeBase;
const spaces = " \t\n\r\x0c";

/// The HTML focus algorithm is supplied by the host; DOM does not import
/// the full HTML implementation or duplicate its focusability rules.
pub const Options = struct { is_focusable: *const fn (*Instance) bool };

fn eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn oneOf(value: []const u8, comptime values: anytype) bool {
    inline for (values) |v| if (eq(value, v)) return true;
    return false;
}

fn attribute(node: *Instance, name: []const u8) ?[]const u8 {
    const element = data.of(node) orelse return null;
    return if (element.findAttribute(null, name)) |a| a.value else null;
}

fn localName(node: *Instance) []const u8 {
    return if (data.of(node)) |element| element.local_name.asSlice() else "";
}

fn isHtml(node: *Instance) bool {
    const element = data.of(node) orelse return false;
    return eq(element.namespaceSlice() orelse "", "http://www.w3.org/1999/xhtml");
}

fn instance(node: *NodeBase) ?*Instance {
    return bridge.getInstanceTyped(Instance, node);
}

fn parent(node: *Instance) ?*Instance {
    if (bridge.getNodeBase(node)) |base| {
        if (slots.slottable(base)) |slottable| if (slottable.state.assignedSlot()) |slot| return instance(slot);
        if (base.parent_node) |p| {
            const owner = instance(p) orelse return null;
            if (owner.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(owner) catch null;
            return owner;
        }
    }
    return null;
}

/// HTML 4.13.7.4: presence of an author attribute, even empty, overrides
/// the internals default. Returned bytes belong to the computation arena.
fn effective(allocator: Allocator, node: *Instance, comptime content: []const u8, comptime member: []const u8) !?[]const u8 {
    if (attribute(node, content)) |value| return value;
    const internals = custom.attachedInternals(node) orelse return null;
    var value = (try @field(interfaces.ElementInternals, "get_" ++ member)(internals)) orelse return null;
    defer value.deinit(internals.ctx.allocator);
    return try allocator.dupe(u8, value.asSlice());
}

const roles = .{
    "alert",        "alertdialog",         "application",   "article",      "banner",       "blockquote",      "button",           "caption",       "cell",        "checkbox",     "code",           "columnheader", "combobox",   "comment",     "complementary",  "contentinfo", "definition",   "deletion",     "dialog",       "document",   "emphasis",    "feed",         "figure",       "form",         "generic",      "grid",      "gridcell",         "group",       "heading",    "image",         "insertion",    "link",     "list",        "listbox",      "listitem",      "log",     "main",         "mark",    "marquee", "math",              "menu",            "menubar",         "menuitem", "menuitemcheckbox", "menuitemradio", "meter", "navigation", "none", "note", "option", "paragraph", "progressbar", "radio", "radiogroup", "region", "row", "rowgroup", "rowheader", "scrollbar", "search", "searchbox", "sectionfooter", "sectionheader", "separator", "slider", "spinbutton", "status", "strong", "subscript", "suggestion", "superscript", "switch", "tab", "table", "tablist", "tabpanel", "term", "textbox", "time", "timer", "toolbar", "tooltip", "tree", "treegrid", "treeitem",
    "doc-abstract", "doc-acknowledgments", "doc-afterword", "doc-appendix", "doc-backlink", "doc-biblioentry", "doc-bibliography", "doc-biblioref", "doc-chapter", "doc-colophon", "doc-conclusion", "doc-cover",    "doc-credit", "doc-credits", "doc-dedication", "doc-endnote", "doc-endnotes", "doc-epigraph", "doc-epilogue", "doc-errata", "doc-example", "doc-footnote", "doc-foreword", "doc-glossary", "doc-glossref", "doc-index", "doc-introduction", "doc-noteref", "doc-notice", "doc-pagebreak", "doc-pagelist", "doc-part", "doc-preface", "doc-prologue", "doc-pullquote", "doc-qna", "doc-subtitle", "doc-tip", "doc-toc", "graphics-document", "graphics-object", "graphics-symbol",
};

fn canonicalRole(token: []const u8) ?[]const u8 {
    if (std.ascii.eqlIgnoreCase(token, "presentation")) return "none";
    if (std.ascii.eqlIgnoreCase(token, "img")) return "image";
    if (std.ascii.eqlIgnoreCase(token, "directory")) return "list";
    inline for (roles) |name| if (std.ascii.eqlIgnoreCase(token, name)) return name;
    return null;
}

fn hasGlobalAria(node: *Instance) bool {
    inline for (.{ "aria-atomic", "aria-braillelabel", "aria-brailleroledescription", "aria-busy", "aria-controls", "aria-current", "aria-describedby", "aria-description", "aria-details", "aria-disabled", "aria-dropeffect", "aria-errormessage", "aria-flowto", "aria-grabbed", "aria-haspopup", "aria-hidden", "aria-invalid", "aria-keyshortcuts", "aria-label", "aria-labelledby", "aria-live", "aria-owns", "aria-relevant", "aria-roledescription" }) |a| if (attribute(node, a) != null) return true;
    return false;
}

fn authorNamed(allocator: Allocator, node: *Instance) !bool {
    if (try effective(allocator, node, "aria-label", "ariaLabel")) |value| if (std.mem.trim(u8, value, spaces).len > 0) return true;
    const labelled = try related(allocator, node, .labelledby);
    if (labelled.len > 0) return true;
    return if (attribute(node, "title")) |title| std.mem.trim(u8, title, spaces).len > 0 else false;
}

/// Returns a canonical static string; callers need not release it.
pub fn computedRole(allocator: Allocator, node: *Instance, options: Options) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    return role(arena.allocator(), node, options);
}

fn role(allocator: Allocator, node: *Instance, options: Options) anyerror![]const u8 {
    if (try effective(allocator, node, "role", "role")) |value| {
        var tokens = std.mem.tokenizeAny(u8, value, spaces);
        while (tokens.next()) |token| if (canonicalRole(token)) |found| {
            if (eq(found, "none") and (options.is_focusable(node) or hasGlobalAria(node))) break;
            if (oneOf(found, .{ "region", "form" }) and !try authorNamed(allocator, node)) continue;
            return found;
        };
    }
    return implicitRole(allocator, node, options);
}

fn implicitRole(allocator: Allocator, node: *Instance, options: Options) anyerror![]const u8 {
    const tag = localName(node);
    if (!isHtml(node)) {
        if (eq(tag, "svg")) return "graphics-document";
        if (eq(tag, "math")) return "math";
        return "generic";
    }
    // ARIA presentation inheritance removes required native child
    // semantics, but an explicit child role (handled in role()) interrupts
    // that chain. Chrome/Firefox also ignore globals on the inherited LI;
    // ARIA #2237 remains unmerged, so their shipping majority controls.
    if (!options.is_focusable(node)) if (parent(node)) |p| {
        if (requiredNativeChild(localName(p), tag) and eq(try role(allocator, p, options), "none")) return "none";
    };
    if (oneOf(tag, .{ "a", "area" })) return if (attribute(node, "href") != null) "link" else "generic";
    if (oneOf(tag, .{ "header", "footer", "aside" })) {
        var ancestor = parent(node);
        while (ancestor) |p| : (ancestor = parent(p)) {
            if (oneOf(localName(p), .{ "article", "aside", "nav", "section", "main" })) {
                if (eq(tag, "aside") and (eq(localName(p), "main") or try authorNamed(allocator, node))) return "complementary";
                return "generic";
            }
        }
        return if (eq(tag, "header")) "banner" else if (eq(tag, "footer")) "contentinfo" else "complementary";
    }
    if (oneOf(tag, .{ "form", "section" })) return if (try authorNamed(allocator, node)) (if (eq(tag, "form")) "form" else "region") else "generic";
    if (eq(tag, "img")) {
        if (attribute(node, "alt")) |alt| if (std.mem.trim(u8, alt, spaces).len == 0 and !options.is_focusable(node) and !hasGlobalAria(node)) return "none";
        return "image";
    }
    if (eq(tag, "input")) {
        var value = try interfaces.HTMLInputElement.get_type(node);
        defer value.deinit(node.ctx.allocator);
        const kind = value.asSlice();
        if (oneOf(kind, .{ "button", "submit", "reset", "image" })) return "button";
        if (oneOf(kind, .{ "checkbox", "radio" })) return if (eq(kind, "radio")) "radio" else "checkbox";
        if (eq(kind, "number")) return "spinbutton";
        if (eq(kind, "range")) return "slider";
        inline for (.{ "color", "date", "datetime-local", "file", "month", "password", "time", "week" }) |special| if (eq(kind, special)) return "html-input-" ++ special;
        if (eq(kind, "hidden")) return "none";
        if ((try interfaces.HTMLInputElement.get_list(node)) != null) return "combobox";
        return if (eq(kind, "search")) "searchbox" else "textbox";
    }
    if (eq(tag, "select")) return if ((try interfaces.HTMLSelectElement.get_multiple(node)) or (try interfaces.HTMLSelectElement.get_size(node)) > 1) "listbox" else "combobox";
    if (eq(tag, "summary")) {
        const p = parent(node) orelse return "generic";
        if (eq(localName(p), "details") and firstChildNamed(p, "summary") == node) return "html-summary";
        return "generic";
    }
    if (oneOf(tag, .{ "td", "th" })) {
        if (eq(tag, "th")) {
            const scope = attribute(node, "scope") orelse "";
            if (oneOf(scope, .{ "row", "rowgroup" })) return "rowheader";
            return "columnheader";
        }
        var ancestor = parent(node);
        while (ancestor) |p| : (ancestor = parent(p)) if (eq(localName(p), "table")) {
            const table_role = try role(allocator, p, options);
            return if (oneOf(table_role, .{ "grid", "treegrid" })) "gridcell" else "cell";
        };
        return "cell";
    }
    const map = .{
        .{ "address", "group" }, .{ "article", "article" }, .{ "blockquote", "blockquote" }, .{ "button", "button" }, .{ "caption", "caption" }, .{ "code", "code" }, .{ "datalist", "listbox" }, .{ "dd", "definition" }, .{ "del", "deletion" }, .{ "details", "group" }, .{ "dfn", "term" }, .{ "dialog", "dialog" }, .{ "dir", "list" }, .{ "dl", "list" }, .{ "dt", "term" }, .{ "em", "emphasis" }, .{ "fieldset", "group" }, .{ "figcaption", "caption" }, .{ "figure", "figure" }, .{ "hgroup", "group" }, .{ "hr", "separator" }, .{ "html", "document" }, .{ "ins", "insertion" }, .{ "li", "listitem" }, .{ "main", "main" }, .{ "mark", "mark" }, .{ "menu", "list" }, .{ "meter", "meter" }, .{ "nav", "navigation" }, .{ "ol", "list" }, .{ "optgroup", "group" }, .{ "option", "option" }, .{ "output", "status" }, .{ "p", "paragraph" }, .{ "progress", "progressbar" }, .{ "s", "deletion" }, .{ "search", "search" }, .{ "strong", "strong" }, .{ "sub", "subscript" }, .{ "sup", "superscript" }, .{ "table", "table" }, .{ "tbody", "rowgroup" }, .{ "textarea", "textbox" }, .{ "tfoot", "rowgroup" }, .{ "thead", "rowgroup" }, .{ "time", "time" }, .{ "tr", "row" }, .{ "ul", "list" },
    };
    inline for (map) |entry| if (eq(tag, entry[0])) return entry[1];
    if (tag.len == 2 and tag[0] == 'h' and tag[1] >= '1' and tag[1] <= '6') return "heading";
    inline for (.{ "abbr", "audio", "canvas", "cite", "embed", "iframe", "kbd", "label", "legend", "map", "object", "rp", "rt", "ruby", "var", "video" }) |special| if (eq(tag, special)) return "html-" ++ special;
    if (oneOf(tag, .{ "base", "br", "col", "colgroup", "head", "link", "meta", "noscript", "param", "picture", "script", "slot", "source", "style", "template", "title", "track", "wbr" })) return "none";
    return "generic";
}

fn requiredNativeChild(parent_tag: []const u8, tag: []const u8) bool {
    if (oneOf(parent_tag, .{ "ul", "ol", "menu", "dir" })) return eq(tag, "li");
    if (eq(parent_tag, "dl")) return oneOf(tag, .{ "dt", "dd" });
    if (eq(parent_tag, "table")) return oneOf(tag, .{ "thead", "tbody", "tfoot", "tr" });
    if (oneOf(parent_tag, .{ "thead", "tbody", "tfoot" })) return eq(tag, "tr");
    if (eq(parent_tag, "tr")) return oneOf(tag, .{ "td", "th" });
    if (eq(parent_tag, "select")) return oneOf(tag, .{ "option", "optgroup" });
    if (oneOf(parent_tag, .{ "optgroup", "datalist" })) return eq(tag, "option");
    return false;
}

const Relation = enum { labelledby, owns };

fn related(allocator: Allocator, node: *Instance, comptime relation: Relation) ![]*Instance {
    const attr_name = if (relation == .labelledby) "aria-labelledby" else "aria-owns";
    const member = if (relation == .labelledby) "ariaLabelledByElements" else "ariaOwnsElements";
    // Read the native reflected array, never a script-overridable property
    // or iterator. Its frozen own indices cannot invoke author code.
    const value = if (attribute(node, attr_name) != null)
        try @field(interfaces.Element, "get_" ++ member)(node)
    else if (custom.attachedInternals(node)) |internals|
        try @field(interfaces.ElementInternals, "get_" ++ member)(internals)
    else
        null;
    var result: std.ArrayList(*Instance) = .empty;
    if (value) |array| {
        defer (engine.Owned{ .value = array }).release();
        const length = try engine.getProperty(node.ctx, array, "length");
        defer length.release();
        const count: usize = @intFromFloat(try engine.convertToUnrestrictedDouble(node.ctx, length.borrow()));
        for (0..count) |i| {
            var buffer: [24]u8 = undefined;
            const item = try engine.getProperty(node.ctx, array, try std.fmt.bufPrint(&buffer, "{d}", .{i}));
            defer item.release();
            if (engine.convertToPlatformObject(node.ctx, item.borrow())) |target| try result.append(allocator, target);
        }
    } else if (relation == .labelledby and attribute(node, attr_name) == null) {
        // Blink and WebKit also accept this legacy spelling, after the
        // standard spelling. It affects names, not the reflected property.
        if (attribute(node, "aria-labeledby")) |legacy| {
            var tokens = std.mem.tokenizeAny(u8, legacy, spaces);
            while (tokens.next()) |id| if (references.byId(node, id)) |target| try result.append(allocator, target);
        }
    }
    return result.items;
}

fn firstChildNamed(node: *Instance, name: []const u8) ?*Instance {
    const base = bridge.getNodeBase(node) orelse return null;
    var child = base.first_child;
    while (child) |at| : (child = at.next_sibling) if (instance(at)) |candidate| if (eq(localName(candidate), name)) return candidate;
    return null;
}

fn nextInTree(node: *NodeBase, boundary: *NodeBase) ?*NodeBase {
    if (node.first_child) |child| return child;
    var at = node;
    while (at != boundary) {
        if (at.next_sibling) |sibling| return sibling;
        at = at.parent_node orelse return null;
    }
    return null;
}

/// HTML 4.8.14 and 2.3.9: the first image whose hash-name reference
/// resolves to an ancestor map. Like Blink's AXObject hidden-style check,
/// an area's accessibility visibility comes from that image's CSS box.
fn imageForArea(node: *Instance) ?*Instance {
    const base = bridge.getNodeBase(node) orelse return null;
    var map: ?*Instance = null;
    var at = base.parent_node;
    while (at) |ancestor| : (at = ancestor.parent_node) {
        const candidate = instance(ancestor) orelse continue;
        if (isHtml(candidate) and eq(localName(candidate), "map")) {
            map = candidate;
            break;
        }
    }
    const wanted = map orelse return null;
    var root = base;
    while (root.parent_node) |p| root = p;
    at = root;
    while (at) |current| : (at = nextInTree(current, root)) {
        const image = instance(current) orelse continue;
        if (!isHtml(image) or !eq(localName(image), "img")) continue;
        const usemap = attribute(image, "usemap") orelse continue;
        const hash = std.mem.indexOfScalar(u8, usemap, '#') orelse continue;
        const name = usemap[hash + 1 ..];
        if (name.len == 0) continue;
        var possible: ?*NodeBase = root;
        while (possible) |entry| : (possible = nextInTree(entry, root)) {
            const candidate = instance(entry) orelse continue;
            if (!isHtml(candidate) or !eq(localName(candidate), "map")) continue;
            if (!eq(attribute(candidate, "id") orelse "", name) and !eq(attribute(candidate, "name") orelse "", name)) continue;
            if (candidate == wanted) return image;
            break;
        }
    }
    return null;
}

/// HTML 3.2.5.2.2, restricted to descendants of a figure. A main there
/// cannot be hierarchically correct; the other conditional categories
/// still depend on their own attributes and ancestors.
fn isFlowWithinFigure(node: *Instance) bool {
    const tag = localName(node);
    if (!isHtml(node)) {
        const element = data.of(node) orelse return false;
        const ns = element.namespaceSlice() orelse return false;
        return (eq(tag, "svg") and eq(ns, "http://www.w3.org/2000/svg")) or
            (eq(tag, "math") and eq(ns, "http://www.w3.org/1998/Math/MathML"));
    }
    if (eq(tag, "meta")) return attribute(node, "itemprop") != null;
    if (eq(tag, "link")) {
        if (attribute(node, "itemprop") != null) return true;
        var tokens = std.mem.tokenizeAny(u8, attribute(node, "rel") orelse return false, spaces);
        while (tokens.next()) |token| {
            var body_ok = false;
            inline for (.{ "dns-prefetch", "modulepreload", "pingback", "preconnect", "prefetch", "preload", "stylesheet" }) |allowed| if (std.ascii.eqlIgnoreCase(token, allowed)) {
                body_ok = true;
            };
            if (!body_ok) return false;
        }
        return true;
    }
    if (eq(tag, "area")) {
        var at = (bridge.getNodeBase(node) orelse return false).parent_node;
        while (at) |ancestor| : (at = ancestor.parent_node) if (instance(ancestor)) |element| {
            if (isHtml(element) and eq(localName(element), "map")) return true;
        };
        return false;
    }
    return @import("names.zig").isValidCustomElementName(tag) or oneOf(tag, .{
        "a", "abbr", "address", "article", "aside", "audio", "b", "bdi", "bdo", "blockquote", "br", "button", "canvas", "cite", "code", "data", "datalist", "del", "details", "dfn", "dialog", "div", "dl", "em", "embed", "fieldset", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hgroup", "hr", "i", "iframe", "img", "input", "ins", "kbd", "label", "map", "mark", "menu", "meter", "nav", "noscript", "object", "ol", "output", "p", "picture", "pre", "progress", "q", "ruby", "s", "samp", "script", "search", "section", "select", "slot", "small", "span", "strong", "style", "sub", "sup", "table", "template", "textarea", "time", "u", "ul", "var", "video", "wbr",
    });
}

fn visibilityHidden(node: *Instance) anyerror!bool {
    if (isHtml(node) and eq(localName(node), "area")) return visibilityHidden(imageForArea(node) orelse return true);
    // Visibility is inherited, but a visible descendant can override it.
    const element = if (data.of(node) != null) node else parent(node) orelse return false;
    if (try style.computedStyle(element, null)) |computed| return computed.keyword(.visibility) == .hidden or computed.keyword(.visibility) == .collapse;
    return false;
}

/// Rendering follows the flat DOM tree even when ARIA changes ownership.
fn displayHidden(node: *Instance) anyerror!bool {
    if (isHtml(node) and eq(localName(node), "area")) {
        return displayHidden(imageForArea(node) orelse return true);
    }
    var at: ?*Instance = node;
    while (at) |element| : (at = parent(element)) {
        if (try style.computedStyle(element, null)) |computed| {
            if (computed.display().box == .none) return true;
        } else if (attribute(element, "hidden") != null) return true;
    }
    return false;
}

fn nameFromContent(role_name: []const u8) bool {
    return oneOf(role_name, .{ "button", "cell", "checkbox", "columnheader", "gridcell", "heading", "link", "menuitem", "menuitemcheckbox", "menuitemradio", "option", "radio", "row", "rowheader", "switch", "tab", "tooltip", "treeitem", "html-summary" });
}

const Walk = struct { relation: bool = false, native_label: bool = false, include_hidden: bool = false, recursive: bool = false };
const Name = struct {
    allocator: Allocator,
    root: *Instance,
    options: Options,
    seen: std.AutoHashMapUnmanaged(*Instance, void) = .empty,
    self_labels: std.AutoHashMapUnmanaged(*Instance, void) = .empty,
    /// ARIA 6.8 aria-owns / 7.3: one accessibility parent, in DOM order.
    /// Like Blink AXRelationCache's child-to-owner map, but arena-only and
    /// rebuilt for this computation; no node survives a task through it.
    owners: std.AutoHashMapUnmanaged(*Instance, *Instance) = .empty,

    fn accessibilityParent(self: *const Name, node: *Instance) ?*Instance {
        return self.owners.get(node) orelse parent(node);
    }

    fn ariaHidden(self: *Name, node: *Instance) !bool {
        var at: ?*Instance = node;
        while (at) |element| : (at = self.accessibilityParent(element)) {
            if (try effective(self.allocator, element, "aria-hidden", "ariaHidden")) |value| {
                if (std.ascii.eqlIgnoreCase(value, "true")) return true;
            }
        }
        return false;
    }

    fn subtreeHidden(self: *Name, node: *Instance) !bool {
        if (try displayHidden(node)) return true;
        if (isHtml(node) and eq(localName(node), "area")) {
            if (try effective(self.allocator, node, "aria-hidden", "ariaHidden")) |value| if (std.ascii.eqlIgnoreCase(value, "true")) return true;
            return self.ariaHidden(imageForArea(node) orelse return true);
        }
        return self.ariaHidden(node);
    }

    fn hidden(self: *Name, node: *Instance) !bool {
        return try visibilityHidden(node) or try self.subtreeHidden(node);
    }

    fn ownershipCycle(self: *const Name, owner: *Instance, target: *Instance) bool {
        // Reject both DOM ancestry and ancestry through previously accepted
        // owners (Blink AXRelationCache::ContainsCycle).
        var at: ?*Instance = owner;
        while (at) |node| : (at = parent(node)) if (node == target) return true;
        at = owner;
        while (at) |node| : (at = self.accessibilityParent(node)) if (node == target) return true;
        return false;
    }

    fn collectOwners(self: *Name, node: *Instance) anyerror!void {
        if (data.of(node) != null and (attribute(node, "aria-owns") != null or custom.attachedInternals(node) != null)) {
            // ARIA #1839: hidden owners cannot relocate children. A target's
            // rendering visibility still follows its DOM ancestry; only its
            // inherited aria-hidden state changes with ownership.
            if (!try self.hidden(node)) for (try related(self.allocator, node, .owns)) |target| {
                if (self.owners.contains(target) or self.ownershipCycle(node, target)) continue;
                if (try displayHidden(target) or try visibilityHidden(target)) continue;
                try self.owners.put(self.allocator, target, node);
            };
        }
        if (shadows.rootForHost(node)) |shadow| try self.collectOwners(shadow);
        const base = bridge.getNodeBase(node) orelse return;
        var at = base.first_child;
        while (at) |current| : (at = current.next_sibling) {
            if (instance(current)) |element| try self.collectOwners(element);
        }
    }

    fn text(self: *Name, node: *Instance, walk: Walk) anyerror![]const u8 {
        if (node == self.root and walk.native_label) return "";
        const entry = try self.seen.getOrPut(self.allocator, node);
        if (entry.found_existing) return "";
        return self.alternative(node, walk);
    }

    fn alternative(self: *Name, node: *Instance, walk: Walk) anyerror![]const u8 {
        const base = bridge.getNodeBase(node) orelse return "";
        if (!walk.include_hidden) {
            if (try self.subtreeHidden(node)) return "";
            if (try visibilityHidden(node)) {
                // A hidden visibility ancestor has no text of its own, but
                // unlike display:none it can contain visible descendants.
                return if (base.node_type == NodeBase.ELEMENT_NODE) self.contents(node, walk) else "";
            }
        }
        if (base.node_type == NodeBase.TEXT_NODE or base.node_type == NodeBase.CDATA_SECTION_NODE) {
            var value = try interfaces.CharacterData.get_data(node);
            defer value.deinit(node.ctx.allocator);
            return try self.allocator.dupe(u8, value.asSlice());
        }
        if (base.node_type != NodeBase.ELEMENT_NODE) return "";
        const tag = localName(node);
        if (oneOf(tag, .{ "script", "style", "template" })) return "";
        // AccName 2B: a relation traversal never follows another labelledby.
        if (!walk.relation) {
            const targets = try related(self.allocator, node, .labelledby);
            var labelled: std.ArrayList(u8) = .empty;
            for (targets) |target| {
                const relation_walk: Walk = .{ .relation = true, .include_hidden = try self.hidden(target) };
                const text_value = if (target == node) blk: {
                    // AccName 2D example 5 permits one self reference to
                    // obtain its own aria-label without following 2B again.
                    const self_entry = try self.self_labels.getOrPut(self.allocator, node);
                    if (self_entry.found_existing) continue;
                    break :blk try self.alternative(target, relation_walk);
                } else try self.text(target, relation_walk);
                try self.append(&labelled, text_value, true);
            }
            if (std.mem.trim(u8, labelled.items, spaces).len > 0) return labelled.items;
        }
        const role_name = try role(self.allocator, node, self.options);
        // 2C: embedded values precede labels (including editable text).
        if (node != self.root and (walk.relation or walk.native_label or walk.recursive)) {
            if (try self.embedded(node, role_name, walk)) |value| return value;
        }
        // 2D. A slot's ARIA label does not replace its assigned nodes.
        if (!eq(tag, "slot")) if (try effective(self.allocator, node, "aria-label", "ariaLabel")) |value| if (std.mem.trim(u8, value, spaces).len > 0) return value;
        // HTML-AAM 4.1.10: an explicitly empty image alternative suppresses
        // title even when it makes the image presentational (Chrome/Safari).
        if (isHtml(node) and eq(tag, "img")) if (attribute(node, "alt")) |value| return value;
        // 2E: host-language text alternatives, through public interfaces.
        if (!eq(role_name, "none")) if (try self.native(node, walk)) |value| return value;
        // 2F/2H: rendered children, not textContent's light-DOM traversal.
        const native_row = isHtml(node) and eq(tag, "tr") and attribute(node, "role") == null;
        if ((!native_row and nameFromContent(role_name)) or walk.relation or walk.native_label or walk.recursive) {
            const content = try self.contents(node, walk);
            if (content.len > 0) return content;
        }
        // 2I / HTML-AAM 4.1.1: tooltip, then text-input placeholders.
        if (attribute(node, "title")) |value| if (value.len > 0) return value;
        if (oneOf(role_name, .{ "textbox", "searchbox", "html-input-password" })) {
            if (attribute(node, "placeholder")) |value| if (value.len > 0) return value;
            if (try effective(self.allocator, node, "aria-placeholder", "ariaPlaceholder")) |value| return value;
        }
        return "";
    }

    fn append(self: *Name, out: *std.ArrayList(u8), value: []const u8, separate: bool) !void {
        if (value.len == 0) return;
        if (separate and out.items.len > 0) try out.append(self.allocator, ' ');
        try out.appendSlice(self.allocator, value);
    }

    fn contents(self: *Name, node: *Instance, inherited: Walk) anyerror![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        // AccName 2F.2 / Content 3 1.2: generated text and slash alternatives.
        try self.generated(&out, node, "marker");
        try self.generated(&out, node, "before");
        var walk = inherited;
        walk.recursive = true;
        const base = bridge.getNodeBase(node) orelse return "";
        if (shadows.rootForHost(node)) |shadow| {
            try self.children(&out, bridge.getNodeBase(shadow) orelse return "", walk);
        } else if (slots.slotState(base)) |slot| {
            if (slot.hasAssignedNodes()) {
                for (slot.assigned_nodes.items) |ref| if (ref.get()) |assigned| if (instance(assigned)) |assigned_node| try self.child(&out, assigned_node, walk, false);
            } else try self.children(&out, base, walk);
        } else try self.children(&out, base, walk);
        // Owned nodes are removed from natural-child traversal, including
        // when explicitly reordered by their existing parent. First owner
        // wins; seen prevents repeated IDREFs from contributing twice.
        for (try related(self.allocator, node, .owns)) |owned| {
            if (self.owners.get(owned) == node) try self.child(&out, owned, walk, true);
        }
        try self.generated(&out, node, "after");
        return out.items;
    }

    fn generated(self: *Name, out: *std.ArrayList(u8), node: *Instance, pseudo: []const u8) !void {
        if (eq(pseudo, "marker")) {
            const own = (try style.computedStyle(node, null)) orelse return;
            if (!own.display().list_item) return;
        }
        const computed = (try style.computedStyle(node, pseudo)) orelse return;
        if (computed.display().box == .none or computed.keyword(.visibility) == .hidden or computed.keyword(.visibility) == .collapse) return;
        const value = computed.get(.content);
        if (value == .content) try value.content.appendAccessible(out, self.allocator);
    }

    fn children(self: *Name, out: *std.ArrayList(u8), base: *NodeBase, walk: Walk) !void {
        var at = base.first_child;
        while (at) |current| : (at = current.next_sibling) if (instance(current)) |element| try self.child(out, element, walk, false);
    }

    fn child(self: *Name, out: *std.ArrayList(u8), node: *Instance, walk: Walk, from_owns: bool) anyerror!void {
        if (!from_owns and self.owners.contains(node)) return;
        var separate = eq(localName(node), "br");
        if (try style.computedStyle(node, null)) |computed| {
            const display = computed.display();
            // Shipping engines separate atomic inline boxes as well as
            // block boxes; AccName #225 tracks the whitespace prose.
            separate = separate or display.outer == .block or display.box == .internal or display.inner == .flow_root or display.inner == .flex or display.inner == .grid or display.inner == .table;
        }
        const value = try self.text(node, walk);
        if (separate and out.items.len > 0) try out.append(self.allocator, ' ');
        try self.append(out, value, false);
        if (separate) try out.append(self.allocator, ' ');
    }

    fn native(self: *Name, node: *Instance, walk: Walk) anyerror!?[]const u8 {
        const tag = localName(node);
        if (isHtml(node)) {
            var labels: ?*Instance = null;
            if (eq(tag, "input")) {
                labels = try interfaces.HTMLInputElement.get_labels(node);
            } else {
                inline for (.{ .{ "button", interfaces.HTMLButtonElement }, .{ "select", interfaces.HTMLSelectElement }, .{ "textarea", interfaces.HTMLTextAreaElement }, .{ "output", interfaces.HTMLOutputElement }, .{ "meter", interfaces.HTMLMeterElement }, .{ "progress", interfaces.HTMLProgressElement } }) |item| if (eq(tag, item[0])) {
                    labels = try item[1].get_labels(node);
                };
                if (labels == null) {
                    if (custom.attachedInternals(node)) |internals| labels = interfaces.ElementInternals.get_labels(internals) catch null;
                }
            }
            if (labels) |list| {
                var out: std.ArrayList(u8) = .empty;
                const count = try interfaces.NodeList.get_length(list);
                for (0..count) |i| if (try interfaces.NodeList.call_item(list, @intCast(i))) |label| {
                    try self.append(&out, try self.text(label, .{ .native_label = true, .relation = walk.relation, .include_hidden = try self.hidden(label) }), true);
                };
                if (std.mem.trim(u8, out.items, spaces).len > 0) return out.items;
            }
            if (oneOf(tag, .{ "img", "area" })) if (attribute(node, "alt")) |value| return value;
            if (eq(tag, "input")) {
                var kind = try interfaces.HTMLInputElement.get_type(node);
                defer kind.deinit(node.ctx.allocator);
                if (oneOf(kind.asSlice(), .{ "button", "submit", "reset" })) {
                    if (attribute(node, "value")) |value| {
                        if (value.len > 0) return value;
                    } else if (eq(kind.asSlice(), "submit")) return "Submit" else if (eq(kind.asSlice(), "reset")) return "Reset";
                }
                if (eq(kind.asSlice(), "image")) {
                    if (attribute(node, "alt")) |value| if (std.mem.trim(u8, value, spaces).len > 0) return value;
                    if (attribute(node, "title")) |value| if (value.len > 0) return value;
                    // HTML-AAM 4.1.3 permits a localized default. Chrome
                    // and Safari use Submit; Firefox uses Submit Query.
                    return "Submit";
                }
                if (oneOf(kind.asSlice(), .{ "text", "password", "number", "search", "tel", "email", "url" })) {
                    // HTML-AAM 4.1.1 steps 3-5 apply to number as well as
                    // textbox roles, and survive an author role override.
                    if (attribute(node, "title")) |value| if (value.len > 0) return value;
                    if (attribute(node, "placeholder")) |value| if (value.len > 0) return value;
                    if (try effective(self.allocator, node, "aria-placeholder", "ariaPlaceholder")) |value| return value;
                }
            }
            if (eq(tag, "img") and attribute(node, "alt") == null and attribute(node, "title") == null) {
                if (try self.imageCaption(node, walk)) |value| return value;
            }
            if (oneOf(tag, .{ "fieldset", "table" })) if (firstChildNamed(node, if (eq(tag, "table")) "caption" else "legend")) |label| {
                const value = try self.text(label, .{ .native_label = true, .relation = walk.relation, .include_hidden = try self.hidden(label) });
                if (std.mem.trim(u8, value, spaces).len > 0) return value;
            };
            if (oneOf(tag, .{ "option", "optgroup" })) if (attribute(node, "label")) |value| if (value.len > 0) return value;
        } else if (firstChildNamed(node, "title")) |title| {
            return try self.text(title, .{ .native_label = true, .include_hidden = true });
        }
        return null;
    }

    /// HTML-AAM 4.1.10 step 4 (ARIA PR2224, 2025-07-25; shipped by WebKit).
    fn imageCaption(self: *Name, node: *Instance, walk: Walk) anyerror!?[]const u8 {
        var at = (bridge.getNodeBase(node) orelse return null).parent_node;
        while (at) |ancestor| : (at = ancestor.parent_node) {
            const figure = instance(ancestor) orelse continue;
            if (!isHtml(figure) or !eq(localName(figure), "figure")) continue;
            const caption = firstChildNamed(figure, "figcaption") orelse return null;
            if (try self.otherFlowContent(ancestor, node, caption)) return null;
            return try self.text(caption, .{ .native_label = true, .relation = walk.relation, .include_hidden = try self.hidden(caption) });
        }
        return null;
    }

    fn otherFlowContent(self: *Name, base: *NodeBase, image: *Instance, caption: *Instance) anyerror!bool {
        var at = base.first_child;
        while (at) |current| : (at = current.next_sibling) {
            const node = instance(current) orelse continue;
            if (node == image or node == caption) continue;
            if (current.node_type == NodeBase.TEXT_NODE or current.node_type == NodeBase.CDATA_SECTION_NODE) {
                var value = try interfaces.CharacterData.get_data(node);
                defer value.deinit(node.ctx.allocator);
                if (std.mem.trim(u8, value.asSlice(), spaces).len > 0) return true;
            } else if (isFlowWithinFigure(node)) return true;
            if (try self.otherFlowContent(current, image, caption)) return true;
        }
        return false;
    }

    fn embedded(self: *Name, node: *Instance, role_name: []const u8, walk: Walk) anyerror!?[]const u8 {
        if (node.stateAs(interfaces.HTMLElement.State) != null and try interfaces.HTMLElement.get_isContentEditable(node)) return try self.contents(node, walk);
        if (oneOf(role_name, .{ "textbox", "searchbox", "html-input-password" })) {
            if (node.stateAs(interfaces.HTMLInputElement.State) != null) {
                var value = try interfaces.HTMLInputElement.get_value(node);
                defer value.deinit(node.ctx.allocator);
                return try self.allocator.dupe(u8, value.asSlice());
            }
            if (node.stateAs(interfaces.HTMLTextAreaElement.State) != null) {
                var value = try interfaces.HTMLTextAreaElement.get_value(node);
                defer value.deinit(node.ctx.allocator);
                return try self.allocator.dupe(u8, value.asSlice());
            }
            return try self.contents(node, walk);
        }
        if (oneOf(role_name, .{ "slider", "spinbutton", "scrollbar", "progressbar", "meter" })) {
            if (try effective(self.allocator, node, "aria-valuetext", "ariaValueText")) |value| return value;
            if (try effective(self.allocator, node, "aria-valuenow", "ariaValueNow")) |value| return value;
            if (node.stateAs(interfaces.HTMLInputElement.State) != null) {
                var value = try interfaces.HTMLInputElement.get_value(node);
                defer value.deinit(node.ctx.allocator);
                return try self.allocator.dupe(u8, value.asSlice());
            }
            return attribute(node, "value") orelse "";
        }
        if (oneOf(role_name, .{ "combobox", "listbox" })) {
            if (node.stateAs(interfaces.HTMLInputElement.State) != null) {
                var value = try interfaces.HTMLInputElement.get_value(node);
                defer value.deinit(node.ctx.allocator);
                return try self.allocator.dupe(u8, value.asSlice());
            }
            var out: std.ArrayList(u8) = .empty;
            if (node.stateAs(interfaces.HTMLSelectElement.State) != null) {
                const selected = try interfaces.HTMLSelectElement.get_selectedOptions(node);
                const count = try interfaces.HTMLCollection.get_length(selected);
                for (0..count) |i| if (try interfaces.HTMLCollection.call_item(selected, @intCast(i))) |option| try self.append(&out, try self.text(option, .{ .recursive = true, .relation = walk.relation, .include_hidden = walk.include_hidden }), true);
            } else {
                try self.selectedOptions(node, &out, walk);
                if (out.items.len == 0 and eq(role_name, "combobox")) return try self.contents(node, walk);
            }
            return out.items;
        }
        return null;
    }

    fn selectedOptions(self: *Name, node: *Instance, out: *std.ArrayList(u8), walk: Walk) anyerror!void {
        const base = bridge.getNodeBase(node) orelse return;
        var at = base.first_child;
        while (at) |current| : (at = current.next_sibling) if (instance(current)) |element| {
            if (eq(try role(self.allocator, element, self.options), "option") and std.ascii.eqlIgnoreCase(attribute(element, "aria-selected") orelse "", "true")) {
                try self.append(out, try self.text(element, .{ .recursive = true, .relation = walk.relation, .include_hidden = walk.include_hidden }), true);
            } else try self.selectedOptions(element, out, walk);
        };
    }
};

/// Caller owns the flattened UTF-8 name. All traversal state is temporary.
pub fn computedName(allocator: Allocator, node: *Instance, options: Options) ![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var computation: Name = .{ .allocator = arena.allocator(), .root = node, .options = options };
    var scope = node;
    while (parent(scope)) |ancestor| scope = ancestor;
    try computation.collectOwners(scope);
    const value = try computation.text(node, .{});
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    var pending_space = false;
    for (value) |byte| {
        if (std.mem.indexOfScalar(u8, spaces, byte) != null) {
            pending_space = result.items.len > 0;
        } else {
            if (pending_space) try result.append(allocator, ' ');
            pending_space = false;
            try result.append(allocator, byte);
        }
    }
    return result.toOwnedSlice(allocator);
}

test "computed roles reject abstract and invalid tokens and canonicalize synonyms" {
    try std.testing.expect(canonicalRole("widget") == null);
    try std.testing.expect(canonicalRole("button,") == null);
    try std.testing.expectEqualStrings("button", canonicalRole("BUTTON").?);
    try std.testing.expectEqualStrings("image", canonicalRole("img").?);
    try std.testing.expectEqualStrings("list", canonicalRole("directory").?);
}
