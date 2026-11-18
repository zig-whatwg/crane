//! HTML 8.5.2 "HTML parsing and insertion methods": the algorithms setHTML,
//! appendHTML, prependHTML, beforeHTML, afterHTML, replaceWithHTML and
//! their Unsafe counterparts share - target and parent for HTML insertion,
//! "filter and set / pre-insert / replace with HTML", "parse HTML for
//! insertion" and the "fragment parsing algorithm steps" in the Safe and
//! Unsafe fragment parser modes - and 8.5.3's "parent for HTML streaming".
//!
//! The parse is html.dom_parser's HTML fragment parsing algorithm: with a
//! sanitizer configuration it builds in an inert document whose parser
//! sanitizes as it builds (dom_parser.FragmentOptions.inert_document,
//! .parser_sanitizer), and what the parser does not sanitize yet is
//! filtered after (html.sanitizer.sanitize); with runScripts its scripts are
//! left to run once inserted (dom_parser.ScriptingMode.fragment).
//!
//! Spec: https://html.spec.whatwg.org/#html-parsing-and-insertion-methods

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const sanitizer = @import("sanitizer.zig");
const parser_options = @import("parser_options.zig");
const dom_parser = @import("dom_parser.zig");
const custom_elements = @import("custom_elements.zig");

pub const ParserOptions = parser_options.ParserOptions;

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";

/// HTML "fragment parser mode".
pub const Mode = enum {
    /// Unsafe elements and attributes are removed; declarative shadow roots
    /// allowed; the HTML parser whatever the document.
    safe,
    /// Unsafe content kept unless a sanitizer is supplied; declarative
    /// shadow roots allowed; the HTML parser whatever the document.
    unsafe,
    /// innerHTML and friends (not reached here).
    legacy,
};

/// HTML "target for HTML insertion" given an element: its template contents
/// for a template element, else the element.
pub fn targetFor(element: *runtime.Instance) !*runtime.Instance {
    return dom.template_contents.insertionTarget(element);
}

/// Whether `node` is an `html` element (in the HTML namespace).
pub fn isHtmlElement(node: *runtime.Instance) bool {
    const names = dom.node_creation.elementNames(node) orelse return false;
    return std.mem.eql(u8, names.local_name, "html") and optionalEql(names.namespace, html_namespace);
}

/// Whether `node` is an HTML or SVG `script` element.
pub fn isScriptElement(node: *runtime.Instance) bool {
    const names = dom.node_creation.elementNames(node) orelse return false;
    return std.mem.eql(u8, names.local_name, "script") and
        (optionalEql(names.namespace, html_namespace) or optionalEql(names.namespace, svg_namespace));
}

/// Whether `node` is a template element (HTMLTemplateElement).
fn isTemplateElement(node: *runtime.Instance) bool {
    return node.stateAs(interfaces.HTMLTemplateElement.State) != null;
}

const element_node: u16 = 1;
const document_fragment_node: u16 = 11;

/// HTML "parent for HTML insertion" given `node`: its parent when that is
/// an element (not a template) or a DocumentFragment with a host; null when
/// it has none; a HierarchyRequestError otherwise.
pub fn parentFor(node: *runtime.Instance) !?*runtime.Instance {
    // 1-2. "Let parent be node's parent. If parent is null, then return null."
    const parent = (try interfaces.Node.get_parentNode(node)) orelse return null;
    // 3. "If parent is a template element, then throw a
    // HierarchyRequestError."
    if (isTemplateElement(parent)) return error.HierarchyRequestError;
    // 4. An Element, or a DocumentFragment with a non-null host.
    const node_type = try interfaces.Node.get_nodeType(parent);
    if (node_type == element_node) return parent;
    if (node_type == document_fragment_node and dom.template_contents.host(parent) != null) return parent;
    // 5. "Throw a HierarchyRequestError."
    return error.HierarchyRequestError;
}

/// HTML "parent for HTML streaming" given `node`.
pub fn parentForStreaming(node: *runtime.Instance) !*runtime.Instance {
    // 1. "Let parent be the parent for HTML insertion given node."
    const parent = (try parentFor(node)) orelse return error.HierarchyRequestError;
    // 2. "If parent is null or an html element, then throw a
    // HierarchyRequestError."
    if (isHtmlElement(parent)) return error.HierarchyRequestError;
    // 3. "Return parent."
    return parent;
}

/// HTML "determine the parser context element" given `target`: the element
/// itself, or a DocumentFragment's host (a shadow root's host, or the
/// template whose contents it is).
pub fn contextElementFor(target: *runtime.Instance) !*runtime.Instance {
    // 1. "If target is an Element, then return target."
    if ((try interfaces.Node.get_nodeType(target)) == element_node) return target;
    // 2-3. "Return target's host."
    return dom.template_contents.host(target) orelse error.InvalidStateError;
}

/// What dom_parser's fragment parse takes as its target: a shadow root (it
/// supplies the registry, its host the context) or an element; a
/// template's contents parse in the template's context, as setHTML on the
/// template itself does (the template element supplies no registry there:
/// dom_parser.parseFragmentWith).
fn parseTarget(target: *runtime.Instance) !*runtime.Instance {
    if (target.stateAs(interfaces.ShadowRoot.State) != null) return target;
    return contextElementFor(target);
}

/// HTML "filter and set HTML" given `target`, `html`, `options` and `mode`.
pub fn filterAndSet(target: *runtime.Instance, html: []const u8, options: *const ParserOptions, mode: Mode) !void {
    // 1. "Let fragment be the result of parsing HTML for insertion given
    // target, html, options, and mode."
    const fragment = (try parseForInsertion(target, html, options, mode)) orelse return;
    defer dom.node_creation.destroyUninserted(fragment);
    // 2. "If fragment is non-null, then replace all with fragment within
    // target."
    const parent = dom.instance_bridge.getNodeBase(target) orelse return error.InvalidStateError;
    const contents = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, contents), parent);
}

/// HTML "filter and pre-insert HTML" given `parent`, `child`, `html`,
/// `options` and `mode`.
pub fn filterAndPreInsert(parent: *runtime.Instance, child: ?*runtime.Instance, html: []const u8, options: *const ParserOptions, mode: Mode) !void {
    // 1. "If parent is an html element, then throw a HierarchyRequestError."
    if (isHtmlElement(parent)) return error.HierarchyRequestError;
    // 2. "Let fragment be the result of parsing HTML for insertion given
    // parent, html, options, and mode."
    const fragment = (try parseForInsertion(parent, html, options, mode)) orelse return;
    defer dom.node_creation.destroyUninserted(fragment);
    // 3. "If fragment is non-null, then pre-insert fragment into parent
    // before child."
    const parent_node = dom.instance_bridge.getNodeBase(parent) orelse return error.InvalidStateError;
    const fragment_node = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    const child_node: ?*dom.NodeBase = if (child) |c| dom.instance_bridge.getNodeBase(c) orelse return error.InvalidStateError else null;
    _ = try dom.mutation.preInsert(fragment_node, parent_node, child_node);
}

/// HTML "filter and replace with HTML" given `parent`, `node`, `html`,
/// `options` and `mode`.
pub fn filterAndReplaceWith(parent: *runtime.Instance, node: *runtime.Instance, html: []const u8, options: *const ParserOptions, mode: Mode) !void {
    // 1. "If parent is an html element, then throw a HierarchyRequestError."
    if (isHtmlElement(parent)) return error.HierarchyRequestError;
    // 2. Parse HTML for insertion given parent, html, options and mode.
    const fragment = (try parseForInsertion(parent, html, options, mode)) orelse return;
    defer dom.node_creation.destroyUninserted(fragment);
    // 3. "If fragment is non-null, then replace node with fragment within
    // parent."
    const parent_node = dom.instance_bridge.getNodeBase(parent) orelse return error.InvalidStateError;
    const fragment_node = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    const old_node = dom.instance_bridge.getNodeBase(node) orelse return error.InvalidStateError;
    _ = try dom.mutation.replace(old_node, fragment_node, parent_node);
}

/// HTML "parse HTML for insertion" given `target`, `html`, `options` and
/// `mode` (Safe or Unsafe): a DocumentFragment not yet inserted (the
/// caller's, destroyUninserted), or null.
pub fn parseForInsertion(target: *runtime.Instance, html: []const u8, options: *const ParserOptions, mode: Mode) !?*runtime.Instance {
    std.debug.assert(mode != .legacy);
    // 1. In Safe mode, a script context parses nothing: return null.
    if (mode == .safe) {
        const context = try contextElementFor(target);
        if (isScriptElement(context)) return null;
    }
    // 2. "Return the result of invoking the fragment parsing algorithm
    // steps given target, html, options, and mode."
    return try fragmentParsingAlgorithmSteps(target, html, options, mode);
}

/// HTML "fragment parsing algorithm steps" for the Safe and Unsafe modes
/// (step 1's XML case is Legacy's only).
fn fragmentParsingAlgorithmSteps(target: *runtime.Instance, markup: []const u8, options: *const ParserOptions, mode: Mode) !*runtime.Instance {
    const realm = target.ctx;
    // 2-3. "Let sanitizerConfig be the result of getting a sanitizer config
    // from options given options and safe" - Safe's remove-unsafe applied.
    var config = try options.sanitizerConfig(realm, mode == .safe);
    defer if (config) |*held| held.deinit();
    // 4-5. runScripts, which Safe never passes.
    const run_scripts = options.runScripts();
    std.debug.assert(!run_scripts or mode != .safe);
    // 6. allowDeclarativeShadowRoots: true outside Legacy.
    // 7. The HTML fragment parsing algorithm given target, markup,
    // allowDeclarativeShadowRoots, runScripts and sanitizerConfig. Its
    // scripts run once inserted when runScripts (Fragment), never otherwise
    // (Inert).
    const scripting_mode: dom_parser.ScriptingMode = if (run_scripts) .fragment else .inert;
    const parse_target = try parseTarget(target);
    const filter: ?sanitizer.ParseFilter = if (config) |*held| .{ .data = &held.data, .allocator = realm.allocator } else null;
    // A parser failure other than OOM is a NotSupportedError, as
    // setHTMLUnsafe mapped it before the Sanitizer (row 41 review N5).
    const parsed = if (filter) |*parse_filter|
        custom_elements.parseFragmentToFilter(parse_target, markup, scripting_mode, parse_filter.parserSanitizer())
    else
        custom_elements.parseFragmentUnsafeIn(parse_target, markup, scripting_mode);
    const fragment = parsed catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.NotSupportedError,
    };
    errdefer dom.node_creation.destroyUninserted(fragment);
    // What the parser does not sanitize yet is filtered after the parse
    // (the configuration already has Safe's remove-unsafe applied).
    if (config) |*held| try sanitizer.sanitize(fragment, held, false);
    return fragment;
}

/// HTML "fragment parsing algorithm steps" in the Legacy mode, for
/// createContextualFragment(): `target` is the context element.
pub fn legacyFragmentParsingAlgorithmSteps(target: *runtime.Instance, markup: []const u8, options: *const ParserOptions) !*runtime.Instance {
    const realm = target.ctx;
    const allocator = realm.allocator;
    // 1. "If mode is Legacy and target's node document is an XML document,
    // then return the result of invoking the XML fragment parsing algorithm
    // given target and markup" (dom_parser.parseFragmentIn picks it for an
    // XML document; sanitization is not supported there).
    const document = try interfaces.Node.get_ownerDocument(target);
    const is_xml = if (document) |d| dom.document_internals.getDocumentType(d) == .xml else false;
    // 4-5. runScripts.
    const scripting_mode: dom_parser.ScriptingMode = if (options.runScripts()) .fragment else .inert;
    if (is_xml) return dom_parser.parseFragmentIn(allocator, realm, markup, target, scripting_mode);
    // 2-3. The sanitizer configuration (Unsafe's: none unless a sanitizer
    // was supplied - here only by a Trusted Types default policy).
    var config = try options.sanitizerConfig(realm, false);
    defer if (config) |*held| held.deinit();
    const held = if (config) |*c| c else return dom_parser.parseFragmentIn(allocator, realm, markup, target, scripting_mode);
    // 6-7. The HTML fragment parsing algorithm given target, markup, false
    // (Legacy), runScripts and sanitizerConfig: a sanitizing parse builds in
    // an inert document.
    const filter: sanitizer.ParseFilter = .{ .data = &held.data, .allocator = allocator };
    const fragment = try dom_parser.parseFragmentWith(allocator, realm, markup, target, .{
        .scripting_mode = scripting_mode,
        .inert_document = true,
        .parser_sanitizer = filter.parserSanitizer(),
    });
    errdefer dom.node_creation.destroyUninserted(fragment);
    try sanitizer.sanitize(fragment, held, false);
    return fragment;
}

/// The legacy sinks' fragment parse (innerHTML, outerHTML,
/// insertAdjacentHTML: "fragment parsing algorithm steps" given `context`,
/// the markup, compliantOptions and Legacy): with no options from a default
/// policy, the HTML fragment parsing algorithm as these sinks always ran it
/// (dom_parser.parseFragment: Inert, no sanitizer); with them, their
/// runScripts and sanitizer configuration.
pub fn legacyParse(context: *runtime.Instance, markup: []const u8, options: ?*const ParserOptions) !*runtime.Instance {
    if (options) |given| return legacyFragmentParsingAlgorithmSteps(context, markup, given);
    return dom_parser.parseFragment(context.ctx.allocator, context.ctx, markup, context);
}

fn optionalEql(a: ?[]const u8, b: []const u8) bool {
    return if (a) |value| std.mem.eql(u8, value, b) else false;
}

// ============================================================================
// The methods' steps, shared by Element, ShadowRoot and
// NonDocumentTypeChildNode
// ============================================================================

/// Where a container method (Element's or ShadowRoot's) puts the result.
pub const ContainerPosition = enum { set, append, prepend };

/// Where a NonDocumentTypeChildNode method puts the result, relative to
/// `this`.
pub const ChildPosition = enum { before, after, replace_with };

/// The node a container method acts on: Element's "target for HTML
/// insertion given this", ShadowRoot's this.
fn containerTarget(this: *runtime.Instance) !*runtime.Instance {
    if (this.stateAs(interfaces.ShadowRoot.State) != null) return this;
    return targetFor(this);
}

/// Element's and ShadowRoot's setHTML, appendHTML and prependHTML (Safe):
/// the target, then filter and set / pre-insert HTML - before the first
/// child for prepend, null (the end) for append.
pub fn containerSafe(this: *runtime.Instance, position: ContainerPosition, html: []const u8, options: *const ParserOptions) !void {
    const target = try containerTarget(this);
    switch (position) {
        .set => try filterAndSet(target, html, options, .safe),
        .append => try filterAndPreInsert(target, null, html, options, .safe),
        .prepend => try filterAndPreInsert(target, try interfaces.Node.get_firstChild(target), html, options, .safe),
    }
}

/// Element's and ShadowRoot's setHTMLUnsafe, appendHTMLUnsafe and
/// prependHTMLUnsafe: 1. get trusted type compliant input with this's
/// relevant global object, html, options and `sink`; then as containerSafe,
/// in Unsafe mode with the compliant input.
pub fn containerUnsafe(this: *runtime.Instance, position: ContainerPosition, html: dom.trusted_types.Input, options: ParserOptions, sink: []const u8) !void {
    const allocator = this.ctx.allocator;
    const compliant = try parser_options.compliantInput(allocator, dom.trusted_types.relevantGlobalOf(this), html, options, sink, .html, true);
    defer allocator.free(compliant.html);
    var compliant_options = compliant.options;
    defer compliant_options.deinit();
    const target = try containerTarget(this);
    switch (position) {
        .set => try filterAndSet(target, compliant.html, &compliant_options, .unsafe),
        .append => try filterAndPreInsert(target, null, compliant.html, &compliant_options, .unsafe),
        .prepend => try filterAndPreInsert(target, try interfaces.Node.get_firstChild(target), compliant.html, &compliant_options, .unsafe),
    }
}

/// NonDocumentTypeChildNode's beforeHTML, afterHTML and replaceWithHTML
/// (Safe): the parent for HTML insertion (null: return), then filter and
/// pre-insert before this / before this's next sibling, or filter and
/// replace this.
pub fn childSafe(this: *runtime.Instance, position: ChildPosition, html: []const u8, options: *const ParserOptions) !void {
    const parent = (try parentFor(this)) orelse return;
    try childSteps(this, parent, position, html, options, .safe);
}

/// NonDocumentTypeChildNode's beforeHTMLUnsafe, afterHTMLUnsafe and
/// replaceWithHTMLUnsafe: get trusted type compliant input first ("Node
/// <method>" is the sink: mixin names are not observable), then as
/// childSafe in Unsafe mode.
pub fn childUnsafe(this: *runtime.Instance, position: ChildPosition, html: dom.trusted_types.Input, options: ParserOptions, sink: []const u8) !void {
    const allocator = this.ctx.allocator;
    const compliant = try parser_options.compliantInput(allocator, dom.trusted_types.relevantGlobalOf(this), html, options, sink, .html, true);
    defer allocator.free(compliant.html);
    var compliant_options = compliant.options;
    defer compliant_options.deinit();
    const parent = (try parentFor(this)) orelse return;
    try childSteps(this, parent, position, compliant.html, &compliant_options, .unsafe);
}

fn childSteps(this: *runtime.Instance, parent: *runtime.Instance, position: ChildPosition, html: []const u8, options: *const ParserOptions, mode: Mode) !void {
    switch (position) {
        .before => try filterAndPreInsert(parent, this, html, options, mode),
        .after => try filterAndPreInsert(parent, try interfaces.Node.get_nextSibling(this), html, options, mode),
        .replace_with => try filterAndReplaceWith(parent, this, html, options, mode),
    }
}
