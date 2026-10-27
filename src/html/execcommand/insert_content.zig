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
    // Step 11: the caret just after last child.
    if (try common.parent(last_child)) |p| {
        const index = try common.indexOf(last_child);
        try edit.collapse(p, index + 1);
    }
    // Step 12: "Fix disallowed ancestors of each member of descendants."
    for (descendants.items) |descendant| try overrides.fixDisallowedAncestors(edit, descendant);
    // Step 13.
    return true;
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
    edit: *Edit,
    out: std.ArrayList(u8) = .empty,
    /// A line break is owed before the next text (a block boundary).
    pending_break: bool = false,
    /// The last character appended was collapsible white space.
    last_space: bool = true,

    fn breakLine(self: *TextBuilder) void {
        if (self.out.items.len > 0) self.pending_break = true;
    }

    fn appendText(self: *TextBuilder, data: []const u8, preformatted: bool) !void {
        const arena = self.edit.scratchAllocator();
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
            const arena = self.edit.scratchAllocator();
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

/// Replace `fragment`'s children with the text a plaintext-only host takes
/// from them: a Text node per line, joined by <br> where the host's
/// white-space collapses line feeds, one Text node with LFs where it keeps
/// them.
fn replaceWithText(edit: *Edit, fragment: *Instance, start_node: *Instance) !void {
    var builder: TextBuilder = .{ .edit = edit };
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
