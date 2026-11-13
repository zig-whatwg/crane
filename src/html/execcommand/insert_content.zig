//! The Editing spec's insertHTML and insertImage commands
//! (specs/w3c/execCommand.md): delete the selection, then insert at the
//! caret - a parsed fragment, or an <img>. Both "preserve overrides"
//! ("Block formatting command definitions"): the Document's overrides are
//! recorded before the action and, when the active range ends collapsed,
//! restored after it.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const common = @import("common.zig");
const delete = @import("delete.zig");
const overrides = @import("overrides.zig");
const block_formatting = @import("block.zig");
const dom_parser = @import("../dom_parser.zig");

const Edit = common.Edit;
const Instance = common.Instance;
const DOMString = runtime.DOMString;
const html_namespace = common.html_namespace;

/// "preserves overrides" around `action`.
fn preservingOverrides(edit: *Edit, comptime action: fn (*Edit, []const u8) anyerror!bool, value: []const u8) !bool {
    const recorded = try overrides.recordCurrentOverrides(edit);
    const result = try action(edit, value);
    if (try edit.rangeCollapsed()) try overrides.restoreStatesAndValues(edit, recorded);
    return result;
}

/// The insertHTML action, `value` already the Trusted Types compliant
/// string (step 1 ran in Document.execCommand, where the browsers run it).
pub fn insertHtml(edit: *Edit, value: []const u8) !bool {
    return try preservingOverrides(edit, insertHtmlSteps, value);
}

fn insertHtmlSteps(edit: *Edit, value: []const u8) anyerror!bool {
    // Step 2: "Delete the selection" (strip wrappers true).
    try delete.deleteTheSelection(edit, true, true, .forward);
    // Step 3: "If the active range's start node is neither editable nor an
    // editing host, return true."
    const start = (try edit.rangeStart()) orelse return true;
    if (!try common.isEditableOrEditingHost(start.node)) return true;
    // Step 4: "Let frag be the result of calling createContextualFragment
    // (value) on the active range" - its steps 2-7, without its Trusted
    // Types step: the value is the compliant string already.
    const fragment = try contextualFragment(start.node, value);
    defer dom.node_creation.destroyUninserted(fragment);
    // A plaintext-only editing host takes the HTML's text: what an
    // innerText-like reading of the fragment gives, with script, style,
    // noscript, noframes and title contents left out, white-space
    // collapsed outside pre, and block and br boundaries as line breaks
    // (editing/plaintext-only/insertHTML.html; Firefox passes it whole,
    // Chrome and Safari agree on every row this keeps: "", the script and
    // style rows, "plaintext"). No spec covers it: the Editing draft
    // predates plaintext-only's insertHTML.
    if (try hostIsPlaintextOnly(edit)) try replaceWithText(edit, fragment, start.node);
    // Steps 5-6: "Let last child be the lastChild of frag. If last child is
    // null, return true."
    const last_child = (try common.lastChild(fragment)) orelse return true;
    // Step 7: "Let descendants be all descendants of frag."
    var descendants: std.ArrayList(*Instance) = .empty;
    {
        var current = try common.firstChild(fragment);
        while (current) |c| {
            try descendants.append(edit.scratchAllocator(), c);
            current = try nextWithin(c, fragment);
        }
    }
    // Step 8: in a block, the editable collapsed block props at or after
    // the start offset go - so <div>[foo]</div> does not keep a <br> after
    // the inserted HTML.
    const point = (try edit.rangeStart()) orelse return true;
    if (common.isBlockNode(point.node)) {
        var props: std.ArrayList(*Instance) = .empty;
        var index: u32 = 0;
        var child = try common.firstChild(point.node);
        while (child) |c| : ({
            child = try common.nextSibling(c);
            index += 1;
        }) {
            if (index < point.offset) continue;
            if ((try common.isEditable(c)) and try common.isCollapsedBlockProp(c)) try props.append(edit.scratchAllocator(), c);
        }
        for (props.items) |prop| try edit.removeNode(prop);
    }
    // Before step 9: inline content goes in outside the styled inline
    // elements around the insertion point, splitting them there - the
    // browsers' behaviour, which the spec lacks (its step 12 only moves
    // content out of ancestors that disallow it). All three do it:
    // editing/other/inserthtml-do-not-preserve-inline-styles.html passes
    // 51 of 54 in Chrome, Firefox and Safari (its 3 others fail in all of
    // them alike: the test expects "rgb(0, 255, 255))"); Blink's
    // ReplaceSelectionCommand::DoApply (PositionAvoidingPrecedingNodes, then
    // SplitTreeToNode up to ElementToSplitToAvoidPastingIntoInlineElements
    // WithStyle), Gecko's HTMLEditor::InsertHTMLWithContextAsSubAction with
    // InlineStylesAtInsertionPoint::Clear (ClearStyleAt), WebKit's
    // ReplaceSelectionCommand. Kept to inline fragments: with a block in the
    // markup the spec's step 12 already splits the inline ancestors and
    // re-applies their style to the block's contents (editing/run/
    // inserthtml.html's "<font color=blue>foo[]bar</font>" + "<p>abc" rows,
    // which Crane passes). A plaintext-only host takes text and no split.
    const phrasing = !try hostIsPlaintextOnly(edit) and try isPhrasingFragment(fragment);
    if (phrasing) try avoidStyledInlineAncestors(edit);
    // Step 9: "Call insertNode(frag) on the active range."
    const range = (try edit.activeRange()) orelse return true;
    try interfaces.Range.call_insertNode(range, fragment);
    edit.modified = true;
    // Step 10: a block start node left with nothing visible gets a br.
    if (try edit.rangeStart()) |after| {
        if (common.isBlockNode(after.node) and !try hasVisibleChild(after.node)) {
            const br = try edit.createElement("br");
            try edit.appendChild(after.node, br);
        }
    }
    // Step 11: the caret just after last child - for inline content, at the
    // last position inside it, where the browsers leave it: Blink's
    // ReplaceSelectionCommand::CompleteHTMLReplacement collapses at the end
    // of the inserted content, canonicalized upstream into its last text
    // (CreateVisiblePosition().DeepEquivalent()), and Gecko's insertion
    // point ends inside the inserted inline content; so the inserted
    // content's style is the caret's (inserthtml-do-not-preserve-inline-
    // styles.html's queryCommandState/Value after each insertion: all
    // three browsers).
    if (phrasing) {
        const end = try lastPositionIn(last_child);
        try edit.collapse(end.node, end.offset);
    } else if (try common.parent(last_child)) |p| {
        const index = try common.indexOf(last_child);
        try edit.collapse(p, index + 1);
    }
    // Step 12: "Fix disallowed ancestors of each member of descendants."
    for (descendants.items) |descendant| try block_formatting.fixDisallowedAncestors(edit, descendant);
    // Step 13.
    return true;
}

/// The last caret position inside `node`: the end of its last Text
/// descendant down its editable last children, or the point after its
/// deepest last element that has no children (a br, an img).
fn lastPositionIn(node: *Instance) !common.Point {
    var current = node;
    while (!common.isText(current)) {
        const last = (try common.lastChild(current)) orelse break;
        if (!common.isText(last) and !try common.isEditable(last)) break;
        current = last;
    }
    if (common.isText(current)) return .{ .node = current, .offset = try common.nodeLength(current) };
    const p = (try common.parent(current)) orelse return .{ .node = current, .offset = 0 };
    return .{ .node = p, .offset = try common.indexOf(current) + 1 };
}

/// Whether no element of `fragment` is a block (a prohibited paragraph
/// child: the fragment is uninserted, so it has no computed display).
fn isPhrasingFragment(fragment: *Instance) !bool {
    var current = try common.firstChild(fragment);
    while (current) |c| : (current = try nextWithin(c, fragment)) {
        if (common.isElement(c) and try common.isProhibitedParagraphChild(c)) return false;
    }
    return true;
}

/// Move the collapsed active range out of the styled inline elements
/// around it, splitting them at it (Blink's ReplaceSelectionCommand::
/// DoApply, the "!match_style_" branch).
fn avoidStyledInlineAncestors(edit: *Edit) !void {
    const start = (try edit.rangeStart()) orelse return;
    const host = (try common.editingHostOf(start.node)) orelse return;
    // PositionAvoidingPrecedingNodes: at the end of inline containers, the
    // same visible position after them.
    var point = try positionAvoidingPrecedingNodes(start, host);
    // ElementToSplitToAvoidPastingIntoInlineElementsWithStyle: the highest
    // enclosing styled inline element inside the point's block and host.
    if (try highestStyledInlineAncestor(point.node, host)) |element| {
        const stop = (try common.parent(element)) orelse return;
        // A point inside a Text node splits it: the insertion point is the
        // start of its second part.
        if (common.isText(point.node) and point.offset > 0 and point.offset < try common.nodeLength(point.node)) {
            const tail = try interfaces.Text.call_splitText(point.node, point.offset);
            point = .{ .node = tail, .offset = 0 };
        }
        if (point.node != stop) {
            const after: ?*Instance = if (common.isText(point.node)) null else try common.childAt(point.node, point.offset);
            const split_start = after orelse point.node;
            const before = try splitTreeToNode(edit, split_start, stop);
            point = .{ .node = stop, .offset = try common.indexOf(before) };
        }
    }
    try edit.collapse(point.node, point.offset);
}

/// Blink's PositionAvoidingPrecedingNodes: while `point` is at the end of an
/// inline container (and not on a line break), the point after that
/// container - the same visible position, outside the elements it ends -
/// stopping at the enclosing block and the editing host.
fn positionAvoidingPrecedingNodes(point_in: common.Point, host: *Instance) !common.Point {
    var point = point_in;
    while (point.node != host and !common.isBlockNode(point.node)) {
        if (try common.isHtmlElementIn(point.node, &.{ "br", "img" })) break;
        if (point.offset != try common.nodeLength(point.node)) break;
        const parent_node = (try common.parent(point.node)) orelse break;
        // The index before the assignment: a result location would read
        // the new node.
        const index = try common.indexOf(point.node);
        point = .{ .node = parent_node, .offset = index + 1 };
    }
    return point;
}

/// The highest inclusive ancestor of `node` below its block and the
/// editing host `host` that is a styled inline element (Blink's
/// IsInlineHTMLElementWithStyle), within editable content.
fn highestStyledInlineAncestor(node: *Instance, host: *Instance) !?*Instance {
    var found: ?*Instance = null;
    var current: ?*Instance = node;
    while (current) |c| : (current = try common.parent(c)) {
        if (c == host or common.isBlockNode(c)) break;
        if (!try common.isEditable(c)) break;
        if (try isStyledInlineElement(c)) found = c;
    }
    return found;
}

/// Blink's EditingStyle::ElementIsStyledSpanOrHTMLEquivalent: a span or an
/// HTML element equivalent of a style (b, strong, i, em, u, s, strike, sub,
/// sup) or a font, whose attributes are all style ones: a style attribute
/// of editing properties alone, font's color, face and size, and dir.
fn isStyledInlineElement(element: *Instance) !bool {
    if (!common.isElement(element)) return false;
    const equivalent = try common.isHtmlElementIn(element, &.{ "span", "b", "strong", "i", "em", "u", "s", "strike", "sub", "sup" });
    const is_font = try common.isHtmlElementNamed(element, "font");
    const attributes = try interfaces.Element.get_attributes(element);
    const count = try interfaces.NamedNodeMap.get_length(attributes);
    if (count == 0) return equivalent;
    var matched: u32 = 0;
    var index: u32 = 0;
    while (index < count) : (index += 1) {
        const attr = (try interfaces.NamedNodeMap.call_item(attributes, index)) orelse continue;
        var name = try interfaces.Attr.get_name(attr);
        defer name.deinit(element.ctx.allocator);
        const n = name.asSlice();
        if (std.mem.eql(u8, n, "dir")) {
            matched += 1;
        } else if (is_font and (std.mem.eql(u8, n, "color") or std.mem.eql(u8, n, "face") or std.mem.eql(u8, n, "size"))) {
            matched += 1;
        } else if (std.mem.eql(u8, n, "style")) {
            if (!try styleHasOnlyEditingProperties(element)) return false;
            matched += 1;
        }
    }
    if (!equivalent and !is_font) return false;
    return matched >= count;
}

/// Whether every property of `element`'s inline style is an editing
/// property (Blink's IsEditingProperty: the inheritable editing properties
/// and background-color, text-decoration-line).
fn styleHasOnlyEditingProperties(element: *Instance) !bool {
    // The longhands CSSStyleDeclaration.item() lists (Blink's
    // kInheritableEditingProperties, then kStaticEditingProperties).
    const editing = [_][]const u8{
        "color",                  "font-family",             "font-size",                 "font-style",
        "font-variant-ligatures", "font-variant-caps",       "font-weight",               "letter-spacing",
        "orphans",                "text-align",              "text-indent",               "text-transform",
        "white-space-collapse",   "text-wrap-mode",          "widows",                    "word-spacing",
        "caret-color",            "-webkit-text-fill-color", "-webkit-text-stroke-color", "-webkit-text-stroke-width",
        "background-color",       "text-decoration-line",
    };
    const style = try interfaces.HTMLElement.get_style(element);
    const length = try interfaces.CSSStyleDeclaration.get_length(style);
    var index: u32 = 0;
    while (index < length) : (index += 1) {
        var property = try interfaces.CSSStyleDeclaration.call_item(style, index);
        defer property.deinit(element.ctx.allocator);
        if (!common.nameIn(property.asSlice(), &editing)) return false;
    }
    return true;
}

/// Blink's CompositeEditCommand::SplitTreeToNode(start, stop): from `start`
/// up to the child of `stop`, split each parent element before the node
/// when visible content precedes it there (Blink: "Do not split a node
/// when doing so introduces an empty node"). The child of `stop` the
/// insertion goes before.
fn splitTreeToNode(edit: *Edit, start: *Instance, stop: *Instance) !*Instance {
    var node = start;
    while (true) {
        const parent_node = (try common.parent(node)) orelse break;
        if (parent_node == stop or !common.isElement(parent_node)) break;
        if (try hasVisiblePreviousSibling(node)) try splitElement(edit, parent_node, node);
        node = parent_node;
    }
    return node;
}

fn hasVisiblePreviousSibling(node: *Instance) !bool {
    var sibling = try common.previousSibling(node);
    while (sibling) |s| : (sibling = try common.previousSibling(s)) {
        if (common.isText(s) and (try common.nodeLength(s)) == 0) continue;
        if (try common.isVisible(s)) return true;
    }
    return false;
}

/// Blink's SplitElement(element, at_child): a shallow clone of `element`
/// before it takes the children before `at_child`.
fn splitElement(edit: *Edit, element: *Instance, at_child: *Instance) !void {
    const parent_node = (try common.parent(element)) orelse return;
    const prefix = try common.cloneNode(element, false);
    try edit.insertBefore(parent_node, prefix, element);
    while (try common.firstChild(element)) |child| {
        if (child == at_child) break;
        try edit.movePreservingRanges(child, prefix, try common.childCount(prefix));
    }
}

/// The node after `node` in tree order inside `root`, or null.
fn nextWithin(node: *Instance, root: *Instance) !?*Instance {
    if (try common.firstChild(node)) |child| return child;
    var current: *Instance = node;
    while (current != root) {
        if (try common.nextSibling(current)) |sibling| return sibling;
        current = (try common.parent(current)) orelse return null;
    }
    return null;
}

fn hasVisibleChild(node: *Instance) !bool {
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (try common.isVisible(c)) return true;
    }
    return false;
}

/// DOM Parsing's createContextualFragment(value) on a range starting in
/// `node`, steps 2-7: the context element (node, or the parent element of
/// a Text or Comment; a body for none or an HTML document's html), then the
/// fragment parsing algorithm in Fragment mode. The caller owns the
/// fragment (dom.node_creation.destroyUninserted).
fn contextualFragment(node: *Instance, value: []const u8) !*Instance {
    var element: ?*Instance = null;
    if (common.isElement(node)) {
        element = node;
    } else if (common.isText(node) or (try common.nodeType(node)) == interfaces.Node.get_COMMENT_NODE()) {
        element = try interfaces.Node.get_parentElement(node);
    }
    const document = if (common.isDocument(node)) node else (try interfaces.Node.get_ownerDocument(node)) orelse return error.InvalidStateError;
    const replace = if (element) |e| (try common.isHtmlElementNamed(e, "html")) and isHtmlDocument(document) else true;
    var created: ?*Instance = null;
    defer if (created) |body| dom.node_creation.destroyUninserted(body);
    if (replace) {
        created = try interfaces.Document.call_createElementNS(document, DOMString.initInterned(html_namespace), DOMString.initInterned("body"), .notPassed());
        element = created;
    }
    // Inert, not createContextualFragment's Fragment mode: no browser runs
    // a script that insertHTML inserts (editing/plaintext-only/
    // insertHTML.html's <script> row passes in Chrome, Firefox and Safari
    // only because the script never runs; Blink's ReplaceSelectionCommand
    // takes the markup from an inert document).
    return try dom_parser.parseFragmentIn(node.ctx.allocator, node.ctx, value, element.?, .inert);
}

fn isHtmlDocument(document: *Instance) bool {
    var content_type = interfaces.Document.get_contentType(document) catch return true;
    defer content_type.deinit(document.ctx.allocator);
    return std.mem.eql(u8, content_type.asSlice(), "text/html");
}

fn hostIsPlaintextOnly(edit: *Edit) !bool {
    // In design mode the whole document is rich text: a plaintext-only
    // element inside still takes the HTML (editing/plaintext-only/
    // plaintext-only-in-designMode.html "should not suppress style of
    // inserting HTML": Chrome 156, Firefox 158 and Safari 27 pass).
    var mode = try interfaces.Document.get_designMode(edit.document);
    defer mode.deinit(edit.document.ctx.allocator);
    if (std.mem.eql(u8, mode.asSlice(), "on")) return false;
    const start = (try edit.rangeStart()) orelse return false;
    const host = (try common.editingHostOf(start.node)) orelse return false;
    if (!try common.isHtmlElement(host)) return false;
    var state = try interfaces.HTMLElement.get_contentEditable(host);
    defer state.deinit(host.ctx.allocator);
    return std.mem.eql(u8, state.asSlice(), "plaintext-only");
}

const skipped_names = [_][]const u8{ "script", "style", "noscript", "noframes", "template", "title", "head", "meta", "link" };
const preformatted_names = [_][]const u8{ "pre", "listing", "xmp", "plaintext", "textarea" };
const block_names = [_][]const u8{ "address", "article", "aside", "blockquote", "center", "dd", "details", "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hgroup", "hr", "li", "listing", "main", "menu", "nav", "ol", "p", "plaintext", "pre", "section", "summary", "table", "tbody", "td", "tfoot", "th", "thead", "tr", "ul", "xmp" };

/// The text a plaintext-only host takes from `fragment`, LF between lines.
const TextBuilder = struct {
    /// The scratch allocator the text is built in (an edit's arena).
    arena: std.mem.Allocator,
    out: std.ArrayList(u8) = .empty,
    /// A line break is owed before the next text (a block boundary).
    pending_break: bool = false,
    /// The last character appended was collapsible white space.
    last_space: bool = true,

    fn breakLine(self: *TextBuilder) void {
        if (self.out.items.len > 0) self.pending_break = true;
    }

    fn appendText(self: *TextBuilder, data: []const u8, preformatted: bool) !void {
        const arena = self.arena;
        for (data) |byte| {
            const is_space = byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r' or byte == 0x0c;
            if (!preformatted and is_space) {
                if (self.last_space or self.pending_break) continue;
                try self.out.append(arena, ' ');
                self.last_space = true;
                continue;
            }
            if (self.pending_break) {
                // A line ends without its trailing collapsible space.
                if (self.out.items.len > 0 and self.out.items[self.out.items.len - 1] == ' ') self.out.items.len -= 1;
                try self.out.append(arena, '\n');
                self.pending_break = false;
            }
            try self.out.append(arena, byte);
            self.last_space = byte == '\n';
        }
    }

    fn walk(self: *TextBuilder, node: *Instance, preformatted: bool) anyerror!void {
        if (common.isText(node)) {
            var data = try common.textData(node);
            defer data.deinit(node.ctx.allocator);
            try self.appendText(data.asSlice(), preformatted);
            return;
        }
        if (!common.isElement(node) and !common.isDocumentFragment(node)) return;
        if (try common.isHtmlElementIn(node, &skipped_names)) return;
        if (try common.isHtmlElementNamed(node, "br")) {
            const arena = self.arena;
            if (self.out.items.len > 0 and self.out.items[self.out.items.len - 1] == ' ') self.out.items.len -= 1;
            try self.out.append(arena, '\n');
            self.last_space = true;
            return;
        }
        const block = try common.isHtmlElementIn(node, &block_names);
        const pre = preformatted or try common.isHtmlElementIn(node, &preformatted_names);
        if (block) self.breakLine();
        var child = try common.firstChild(node);
        while (child) |c| : (child = try common.nextSibling(c)) try self.walk(c, pre);
        if (block) self.breakLine();
    }

    fn text(self: *TextBuilder) []const u8 {
        var t = self.out.items;
        while (t.len > 0 and (t[t.len - 1] == ' ')) t = t[0 .. t.len - 1];
        return t;
    }
};

/// The text a plaintext-only host takes from `markup` parsed as
/// createContextualFragment does on a range in `node` (an inert fragment):
/// what insertHTML puts into a focused text control (root.execCommand).
/// Allocated in `arena`.
pub fn plainTextOf(node: *Instance, markup: []const u8, arena: std.mem.Allocator) ![]const u8 {
    const fragment = try contextualFragment(node, markup);
    defer dom.node_creation.destroyUninserted(fragment);
    var builder: TextBuilder = .{ .arena = arena };
    try builder.walk(fragment, false);
    return builder.text();
}

/// Replace `fragment`'s children with the text a plaintext-only host takes
/// from them: a Text node per line, joined by <br> where the host's
/// white-space collapses line feeds, one Text node with LFs where it keeps
/// them.
fn replaceWithText(edit: *Edit, fragment: *Instance, start_node: *Instance) !void {
    var builder: TextBuilder = .{ .arena = edit.scratchAllocator() };
    try builder.walk(fragment, false);
    const text = builder.text();
    while (try common.firstChild(fragment)) |child| _ = try interfaces.Node.call_removeChild(fragment, child);
    if (text.len == 0) return;
    const keeps_newlines = (try common.whiteSpaceAround(start_node)).preservesNewlines();
    if (keeps_newlines) {
        const node = try interfaces.Document.call_createTextNode(edit.document, DOMString.initInterned(text));
        _ = try interfaces.Node.call_appendChild(fragment, node);
        return;
    }
    var lines = std.mem.splitScalar(u8, text, '\n');
    var first = true;
    while (lines.next()) |line| {
        if (!first) {
            const br = try edit.createElement("br");
            _ = try interfaces.Node.call_appendChild(fragment, br);
        }
        first = false;
        if (line.len == 0) continue;
        const node = try interfaces.Document.call_createTextNode(edit.document, DOMString.initInterned(line));
        _ = try interfaces.Node.call_appendChild(fragment, node);
    }
}

/// The insertImage action.
pub fn insertImage(edit: *Edit, value: []const u8) !bool {
    // Step 1: "If value is the empty string, return false."
    if (value.len == 0) return false;
    return try preservingOverrides(edit, insertImageSteps, value);
}

fn insertImageSteps(edit: *Edit, value: []const u8) anyerror!bool {
    // Step 2: "Delete the selection, with strip wrappers false."
    try delete.deleteTheSelection(edit, true, false, .forward);
    // Step 3: "Let range be the active range."
    const range = (try edit.activeRange()) orelse return true;
    // Step 4: "If the active range's start node is neither editable nor an
    // editing host, return true."
    const start = (try edit.rangeStart()) orelse return true;
    if (!try common.isEditableOrEditingHost(start.node)) return true;
    // Step 5: a block whose sole child is a br, at offset 0: the br goes.
    if (common.isBlockNode(start.node) and start.offset == 0 and (try common.childCount(start.node)) == 1) {
        const only = (try common.firstChild(start.node)).?;
        if (try common.isHtmlElementNamed(only, "br")) try edit.removeNode(only);
    }
    // Steps 6-7: "Let img be the result of calling createElement("img")",
    // its src set to value.
    const img = try edit.createElement("img");
    try common.setAttribute(img, "src", value);
    // Step 8: "Run insertNode(img) on range."
    try interfaces.Range.call_insertNode(range, img);
    edit.modified = true;
    // Steps 9-10: the caret just after img.
    if (try common.parent(img)) |p| {
        const index = try common.indexOf(img);
        try edit.collapse(p, index + 1);
    }
    // Step 11.
    return true;
}
