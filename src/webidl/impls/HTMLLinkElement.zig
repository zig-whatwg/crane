//! Implementation for HTMLLinkElement interface
//!
//! Spec: HTML Standard § 4.2.4 The link element
//! https://html.spec.whatwg.org/multipage/semantics.html#the-link-element
//!
//! The reflected attributes are the generated interface's, but for the four
//! limited to only known values, which are here. What else is here is the
//! stylesheet link type (4.6.7.23), the preload link type (4.6.7.20) and
//! the modulepreload link type (4.6.7.12):
//! the appropriate times to fetch and process them - the element becoming
//! browsing-context connected, and its href, rel, crossorigin, as, type and
//! disabled attributes changing - and the fetch, whose load, with a style
//! sheet's critical subresources, and whose load or error event are
//! `style_sheet_loading`'s.
//!
//! Not modelled, stated: the other external resource link types (icon,
//! manifest, ...) fetch nothing; a preload fills no map of preloaded
//! resources, and a modulepreload no module map, so what they fetched is
//! fetched again by its consumer; alternative style sheets are fetched as any other;
//! a stylesheet link the parser made, or one whose blocking attribute says
//! `render`, blocks rendering while it loads (style_sheet_loading). `sheet`
//! is the sheet's CSSStyleSheet object
//! (dom.style.objects), which the element keeps until the sheet is removed. Parser-created enabled stylesheets enter
//! their document's script-blocking set until their load event finishes.
//!
//! The expect link type (4.6.8.6) is an internal resource link: "process
//! internal resource link" blocks rendering on the element until the element
//! its href indicates is connected and parsed. The element installs that
//! algorithm into dom.document_rendering, whose "process internal resource
//! links" the parser's pops, the HTML insertion steps, id and name changes
//! and the end of parsing run.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLLinkElement = interfaces.HTMLLinkElement;

// Everything the element reads of its HTMLElement, Element and Node state,
// it reads through the generated interfaces: no impl is named here. The
// load of its style sheet is HTML's (src/html/style_sheet_loading.zig).
const style_sheet_loading = @import("html").style_sheet_loading;

// The hooks the element installs its steps into: the attribute change steps
// (DOM 4.9), the insertion and removing steps (DOM 4.2.3), and the load
// delay its style sheets put on their document (dom.style_sheet_owners).
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

const log = std.log.scoped(.link);

pub const State = HTMLLinkElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// The element's own state. relList, the DOMTokenList, is the generated
/// interface's ([SameObject]).
pub const InternalState = struct {
    /// The stylesheet link's load (`style_sheet_loading`), by id, while it
    /// fetches or its event waits; 0 when there is none.
    load: u64 = 0,
    /// HTML 4.2.7: these are creation-time facts, unaffected by later rel
    /// or disabled changes. Adoption into another document is excluded.
    parser_document: ?*runtime.Instance = null,
    parser_document_generation: u64 = 0,
    enabled_at_creation: bool = false,
    explicitly_enabled: bool = false,
    /// The element's associated CSS style sheet (the stylesheet link type's
    /// "process the linked resource" step 4), owned; null when it has none.
    sheet: ?*dom_module.style.SheetRecord = null,
    /// The document whose style engine applies it, with its generation.
    sheet_document: ?*runtime.Instance = null,
    sheet_document_generation: u64 = 0,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    style_sheet_loading.installDocumentAbort();
    dom_module.attribute_change_steps.install("link", &attributeChangeSteps);
    dom_module.style_sheet_owners.installLoadDelay(.{ .delays = &style_sheet_loading.delaysLoadEvent, .blocks_scripts = &style_sheet_loading.blocksScripts });
    dom_module.style_sheet_owners.installLinkParserSteps(&createdByParser);
    // The CSS style sheet the element owns, which the style engine applies.
    dom_module.style.hooks.install(.{ .link_sheet_of = &sheetOf, .link_sheet_arrived = &sheetArrived });
    dom_module.mutation.registerPostConnectionStepsCallback(&insertionSteps) catch |err| {
        log.warn("link insertion steps not registered: {}", .{err});
    };
    dom_module.mutation.registerRemovingStepsCallback(&removingSteps) catch |err| {
        log.warn("link removing steps not registered: {}", .{err});
    };
    // The expect link type (4.6.8.6): its processing, reached from the
    // document's render-blocking set; the HTML insertion steps' step 3; and
    // the attribute change steps that keep expect links current with id and
    // name changes - on every element an expect link can indicate.
    dom_module.document_rendering.installInternalResourceLinks(.{ .process = &processFromSet });
    dom_module.mutation.registerInsertionStepsCallback(&htmlInsertionSteps) catch |err| {
        log.warn("expect link insertion steps not registered: {}", .{err});
    };
    dom_module.attribute_change_steps.installForAttribute(html_namespace, "id", .{ .change = &indicatorAttributeChanged });
    dom_module.attribute_change_steps.installForAttribute(svg_namespace, "id", .{ .change = &indicatorAttributeChanged });
    dom_module.attribute_change_steps.installForAttribute(html_namespace, "name", .{ .change = &indicatorAttributeChanged });
}

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";

/// Initialize instance: the chain to HTMLElement.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);
    // From the arena that holds the element's state, as every element's
    // internal state is: teardown does not always run `deinit`.
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its style sheet's load ends with it.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        style_sheet_loading.elementGone(instance);
        removeSheet(instance, internal);
        // Erase borrowed render-blocking membership before this element's
        // identity can end.
        dom_module.document_rendering.unblock(instance);
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
    // Chain to parent class (via interface per Golden Rule #13)
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &HTMLLinkElement.vtable, ctx);
    errdefer deinit(instance);
    return instance;
}

// ============================================================================
// The stylesheet link: when to fetch and process it
// ============================================================================

/// The "appropriate times to fetch and process" the element's external
/// resource link: whatever load the element had is stale - "it has become
/// appropriate to fetch it again", or the element "no longer creates an
/// external resource link that contributes to the styling processing model"
/// - and ends without its event; then, if the element is browsing-context
/// connected and creates a stylesheet link, "default fetch and process the
/// linked resource"; if it creates a preload link, the preload link type's
/// steps.
fn fetchAndProcess(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    // Establish the replacement before releasing the old blocker: releasing
    // can resume a parser script, which must see the new sheet's membership.
    const previous_load = internal.load;
    internal.load = 0;
    defer if (previous_load != 0) style_sheet_loading.cancel(previous_load);
    // A link that no longer creates a stylesheet link loses its sheet; one
    // that fetches again keeps it until the new one arrives (the stylesheet
    // link type's "process the linked resource" step 3).
    if (!createsStyleSheetLink(element)) removeSheet(element, internal);
    // "Browsing-context connected": connected, and its document has a
    // browsing context.
    if (!(interfaces.Node.get_isConnected(element) catch false)) return;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    // "Create link options from element": snapshot the request metadata.
    // A link with no href, or an empty one, defines no link.
    const href = attribute(element, "href") orelse return;
    if (href.len == 0) return;
    const options: style_sheet_loading.LinkOptions = .{
        .parser_created = parserCreated(internal, element),
        .href = href,
        .cors = style_sheet_loading.CorsSetting.fromAttribute(attribute(element, "crossorigin")),
        .referrer_policy = referrerPolicyState(attribute(element, "referrerpolicy")),
        .nonce = dom_module.attribute_change_steps.readForAttribute(element, "http://www.w3.org/1999/xhtml", "nonce") orelse "",
        .integrity = attribute(element, "integrity") orelse "",
        .fetch_priority = blk: {
            const priority = attribute(element, "fetchpriority") orelse break :blk .auto;
            if (std.ascii.eqlIgnoreCase(priority, "high")) break :blk .high;
            if (std.ascii.eqlIgnoreCase(priority, "low")) break :blk .low;
            break :blk .auto;
        },
    };
    switch (linkType(element)) {
        .none => {},
        .prefetch => internal.load = style_sheet_loading.startPrefetch(element, options) orelse 0,
        .stylesheet => {
            // 4.2.4.2: "If the UA does not support the given MIME type for
            // the given link relationship, then the UA should not fetch and
            // process the linked resource."
            if (!supportedType(attribute(element, "type"))) return;
            // The linked resource fetch setup steps, step 1: "If el's
            // disabled attribute is set, then return false."
            if (attribute(element, "disabled") != null) return;
            internal.load = style_sheet_loading.startLink(element, options, parserSheetEnabled(internal, document)) orelse 0;
        },
        .modulepreload => {
            // Step 2: "Let destination be the current state of el's as
            // attribute (a destination), or "script" if it is in no state."
            const destination = asDestination(attribute(element, "as")) orelse .script;
            // Modulepreload steps 9-10: only an absent integrity attribute
            // takes the import map's metadata for the resolved URL.
            var module_options = options;
            if (attribute(element, "integrity") == null) {
                const url = HTMLLinkElement.get_href(element) catch return;
                defer element.ctx.allocator.free(url);
                module_options.integrity = dom_module.document_modules.resolveModuleIntegrity(document, url) orelse "";
            }
            internal.load = style_sheet_loading.startModulePreload(element, module_options, destination) orelse 0;
        },
        .preload => {
            // Steps 3-4: "Let destination be the result of translating the
            // keyword representing the state of el's as attribute. If
            // destination is null, then return."
            const destination = preloadDestination(attribute(element, "as")) orelse return;
            // "Preload" step 1: "If options's type doesn't match options's
            // destination, then return."
            if (!typeMatches(attribute(element, "type"), destination)) return;
            internal.load = style_sheet_loading.startPreload(element, options, destination) orelse 0;
        },
    }
}

/// The external resource link the element's rel creates, of those this
/// engine fetches: a stylesheet link, else a preload link, else a
/// modulepreload link, else a prefetch. (Two at once - `rel="preload stylesheet"` - is
/// fetched as the first of those.)
fn linkType(element: *runtime.Instance) LinkType {
    return relLinkType(attribute(element, "rel"));
}

/// The attributes are the parser token's, before connection starts a load.
fn createdByParser(element: *runtime.Instance) void {
    const internal = getInternal(element) orelse return;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    internal.parser_document = document;
    internal.parser_document_generation = runtime.SlabAllocator.generationOf(document);
    internal.enabled_at_creation = linkType(element) == .stylesheet and
        attribute(element, "href") != null and attribute(element, "href").?.len != 0 and
        attribute(element, "disabled") == null and !isAlternate(element, internal);
}

/// The element was created by its node document's parser: a stylesheet
/// link is then implicitly potentially render-blocking (HTML 4.6.7.23).
fn parserCreated(internal: *const InternalState, element: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    return internal.parser_document == document and
        runtime.SlabAllocator.generationOf(document) == internal.parser_document_generation;
}

fn parserSheetEnabled(internal: *const InternalState, document: *runtime.Instance) bool {
    return internal.enabled_at_creation and internal.parser_document == document and
        runtime.SlabAllocator.generationOf(document) == internal.parser_document_generation;
}

fn isAlternate(element: *runtime.Instance, internal: *const InternalState) bool {
    const rel = attribute(element, "rel") orelse return false;
    const title = attribute(element, "title") orelse return false;
    return title.len != 0 and hasToken(rel, "alternate") and !internal.explicitly_enabled;
}

const LinkType = enum { none, stylesheet, preload, modulepreload, prefetch };

/// The `as` attribute's state, a potential destination, as a destination;
/// null when it is in no state. "fetch" is the empty destination, which is
/// not script-like.
fn asDestination(as: ?[]const u8) ?Destination {
    const value = as orelse return null;
    if (std.ascii.eqlIgnoreCase(value, "fetch")) return .empty;
    inline for (@typeInfo(Destination).@"enum".fields) |field| {
        if (field.value != @intFromEnum(Destination.empty) and keywordIs(field.name, value)) {
            return @field(Destination, field.name);
        }
    }
    return null;
}

/// HTML "translate a preload destination" for the `as` attribute's value:
/// its state (limited to the potential destinations, ASCII
/// case-insensitively), then "If destination is not "fetch", "font",
/// "image", "script", "style", or "track", then return null", and
/// "translating" it - "fetch" is the empty string.
fn preloadDestination(as: ?[]const u8) ?Destination {
    const value = as orelse return null;
    const preloadable = [_]struct { []const u8, Destination }{
        .{ "fetch", .empty },   .{ "font", .font },   .{ "image", .image },
        .{ "script", .script }, .{ "style", .style }, .{ "track", .track },
    };
    for (preloadable) |entry| {
        if (std.ascii.eqlIgnoreCase(value, entry[0])) return entry[1];
    }
    return null;
}

const Destination = @import("fetch").internal.Destination;

/// The preload link type's "matches": whether the type attribute's value
/// suits `destination`. Absent or empty, or for "fetch", it does; otherwise
/// by its essence - text/css for style, a JavaScript MIME type for script,
/// image/*, font/* and text/vtt for image, font and track.
fn typeMatches(type_attr: ?[]const u8, destination: Destination) bool {
    const value = type_attr orelse return true;
    if (value.len == 0 or destination == .empty) return true;
    const essence = std.mem.trim(u8, value[0 .. std.mem.indexOfScalar(u8, value, ';') orelse value.len], " \t\n\x0C\r");
    var buffer: [128]u8 = undefined;
    if (essence.len > buffer.len) return false;
    const lower = std.ascii.lowerString(&buffer, essence);
    return switch (destination) {
        .style => std.mem.eql(u8, lower, "text/css"),
        .script => @import("mimesniff").predicates.isJavaScriptMimeTypeEssenceMatch(lower),
        .image => std.mem.startsWith(u8, lower, "image/"),
        .font => std.mem.startsWith(u8, lower, "font/") or std.mem.startsWith(u8, lower, "application/font-"),
        .track => std.mem.eql(u8, lower, "text/vtt"),
        else => false,
    };
}

/// Whether the space-separated `value` has `keyword`, ASCII
/// case-insensitively.
fn hasToken(value: []const u8, keyword: []const u8) bool {
    var tokens = std.mem.tokenizeAny(u8, value, " \t\n\x0C\r");
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(token, keyword)) return true;
    }
    return false;
}

/// 4.2.4.2: whether the type attribute's value is a type the stylesheet
/// link type supports. Absent, it is the link type's default type,
/// text/css. The empty string is taken as the default too, as browsers do
/// (Blink's LinkStyle), and parameters do not change the type.
fn supportedType(value: ?[]const u8) bool {
    const v = value orelse return true;
    const essence = std.mem.trim(u8, v[0 .. std.mem.indexOfScalar(u8, v, ';') orelse v.len], " \t\n\x0C\r");
    return essence.len == 0 or std.ascii.eqlIgnoreCase(essence, "text/css");
}

/// A referrerpolicy attribute's state: a referrer policy keyword, ASCII
/// case-insensitively, else the empty string.
fn referrerPolicyState(value: ?[]const u8) ReferrerPolicy {
    const v = value orelse return .empty;
    inline for (@typeInfo(ReferrerPolicy).@"enum".fields) |field| {
        if (field.value != @intFromEnum(ReferrerPolicy.empty) and keywordIs(field.name, v)) {
            return @field(ReferrerPolicy, field.name);
        }
    }
    return .empty;
}

const ReferrerPolicy = @import("fetch").internal.ReferrerPolicy;

/// Whether `value` is the keyword an enum field `name` stands for - its
/// underscores hyphens - ASCII case-insensitively.
fn keywordIs(name: []const u8, value: []const u8) bool {
    if (name.len != value.len) return false;
    for (name, value) |n, c| {
        const want: u8 = if (n == '_') '-' else n;
        if (std.ascii.toLower(c) != want) return false;
    }
    return true;
}

const referrer_policies = [_][]const u8{
    "no-referrer",                     "no-referrer-when-downgrade", "same-origin",
    "origin",                          "strict-origin",              "origin-when-cross-origin",
    "strict-origin-when-cross-origin", "unsafe-url",
};

/// `element`'s attribute `name` in no namespace, or null. BORROWED: the
/// attribute's value, until the attribute changes.
fn attribute(element: *runtime.Instance, comptime name: []const u8) ?[]const u8 {
    const value = (interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned(name)) catch null) orelse return null;
    return value.asSlice();
}

fn eqlOptional(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.mem.eql(u8, a.?, b.?);
}

/// The attribute changes that are appropriate times to fetch and process
/// the element's link, for an element that is browsing-context connected
/// (`fetchAndProcess` checks): its href changing; its rel coming to create a
/// stylesheet or preload link, or ceasing to; its crossorigin or disabled
/// attribute set, changed or removed; its as attribute changing (a
/// preload's destination); its type changing between one that allows a
/// fetch and one that does not. Setting an attribute to the value it has is
/// no change: a load or error handler that writes `link.href = link.href`
/// fetches nothing again (Chromium issue 41436016).
fn attributeChangeSteps(
    element: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    if (namespace != null) return;
    // An SVG or other element named "link" is not this element.
    const internal = getInternal(element) orelse return;
    if (eqlOptional(old_value, value)) return;
    // The expect link type: a change to href, media, rel or blocking
    // processes the link once the change is made (`expectAttributeChanged`).
    // A rel that drops "expect" unblocks first, before a stylesheet link it
    // now creates starts its own blocking load.
    defer expectAttributeChanged(element, local_name);
    if (std.mem.eql(u8, local_name, "rel") and !hasToken(value orelse "", "expect")) unblockExpect(element);
    if (std.mem.eql(u8, local_name, "disabled") and old_value != null and value == null) internal.explicitly_enabled = true;
    const refetch = if (std.mem.eql(u8, local_name, "href") or
        std.mem.eql(u8, local_name, "crossorigin") or
        std.mem.eql(u8, local_name, "disabled") or
        std.mem.eql(u8, local_name, "as"))
        true
    else if (std.mem.eql(u8, local_name, "rel"))
        relLinkType(old_value) != relLinkType(value) or
            (old_value != null and value != null and hasToken(old_value.?, "alternate") != hasToken(value.?, "alternate"))
    else if (std.mem.eql(u8, local_name, "type"))
        typeAllows(element, old_value) != typeAllows(element, value)
    else
        false;
    if (!refetch) {
        // HTML 3.1.6: "Whenever a render-blocking element el ... el's
        // blocking attribute's value is changed so that el is no longer
        // potentially render-blocking, then unblock rendering on el."
        // Only a stylesheet link is implicitly potentially render-blocking
        // (4.6.7.23); a parser-made expect link is not (tests
        // element-render-blocking-005 and -016).
        if (std.mem.eql(u8, local_name, "blocking") and !style_sheet_loading.potentiallyRenderBlocking(element, parserCreated(internal, element) and linkType(element) == .stylesheet)) {
            dom_module.document_rendering.unblock(element);
        }
        if (std.mem.eql(u8, local_name, "media")) {
            // The associated CSS style sheet's media follows the attribute.
            if (internal.sheet) |record| {
                record.setMedia(value orelse "") catch {};
                if (internal.sheet_document) |document| dom_module.style.sheetsChanged(document);
            }
            if (interfaces.Node.get_ownerDocument(element) catch null) |document| style_sheet_loading.queueBlockingMayHaveEnded(document);
        }
        return;
    }
    if (!(interfaces.Node.get_isConnected(element) catch false)) return;
    fetchAndProcess(element);
}

/// The link type a rel value makes the element fetch (`linkType`).
fn relLinkType(rel: ?[]const u8) LinkType {
    const value = rel orelse return .none;
    if (hasToken(value, "stylesheet")) return .stylesheet;
    if (hasToken(value, "preload")) return .preload;
    if (hasToken(value, "modulepreload")) return .modulepreload;
    if (hasToken(value, "prefetch")) return .prefetch;
    return .none;
}

/// Whether a type attribute of `type_attr` lets the element's link be
/// fetched.
fn typeAllows(element: *runtime.Instance, type_attr: ?[]const u8) bool {
    return switch (linkType(element)) {
        .none, .modulepreload, .prefetch => true,
        .stylesheet => supportedType(type_attr),
        .preload => typeMatches(type_attr, preloadDestination(attribute(element, "as")) orelse return true),
    };
}

/// The element becomes connected: an appropriate time to fetch and process
/// its stylesheet link. Called for every node inserted.
fn insertionSteps(node: *NodeBase) void {
    if (node.node_type != 1 or !node.is_connected) return;
    const instance = linkOf(node) orelse return;
    fetchAndProcess(instance);
    // 4.6.8.6: "an expect internal resource link has been created on el and
    // el becomes browsing-context connected".
    processExpect(instance);
}

/// The element is no longer connected: it no longer creates a link that
/// contributes to the styling processing model, and its load ends. Called
/// for every node removed.
fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.node_type != 1) return;
    const instance = linkOf(node) orelse return;
    const internal = getInternal(instance) orelse return;
    // HTML 3.1.6: a render-blocking element that becomes browsing-context
    // disconnected is unblocked - as an expect link here; a stylesheet
    // link's load, cancelled below, unblocks its own.
    unblockExpect(instance);
    // No longer connected: the link no longer contributes to styling, and
    // its sheet goes.
    removeSheet(instance, internal);
    if (internal.load == 0) return;
    const load = internal.load;
    internal.load = 0;
    style_sheet_loading.cancel(load);
}

/// Whether the element creates a stylesheet link that contributes to the
/// styling processing model: connected, rel stylesheet, a supported type,
/// an href, and no disabled attribute.
fn createsStyleSheetLink(element: *runtime.Instance) bool {
    if (!(interfaces.Node.get_isConnected(element) catch false)) return false;
    if (linkType(element) != .stylesheet) return false;
    if (!supportedType(attribute(element, "type"))) return false;
    if (attribute(element, "disabled") != null) return false;
    const href = attribute(element, "href") orelse return false;
    return href.len != 0;
}

/// dom.style's `link_sheet_arrived`: the stylesheet link type's "process
/// the linked resource" steps 2-4 for a resource that succeeded. "If el no
/// longer creates an external resource link that contributes to the
/// styling processing model ... return. If el has an associated CSS style
/// sheet, remove the CSS style sheet. If success is true, then: create a
/// CSS style sheet" - type text/css, location the response's URL, owner
/// node el, media its media attribute, title its title attribute (in a
/// document tree), the alternate flag for an alternative style sheet that
/// is not explicitly enabled, the origin-clean flag for a CORS-same-origin
/// response.
fn sheetArrived(element: *runtime.Instance, text: []const u8, url: []const u8, origin_clean: bool) void {
    const internal = getInternal(element) orelse return;
    if (!createsStyleSheetLink(element)) return;
    removeSheet(element, internal);
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    var root = instance_bridge.getNodeBase(element);
    while (root) |r| : (root = r.parent_node) if (r.parent_node == null) break;
    const in_document_tree = if (root) |r| r.node_type == NodeBase.DOCUMENT_NODE else false;
    const record = dom_module.style.SheetRecord.create(element.ctx.allocator, text, .{
        .owner_node = element,
        .title = if (in_document_tree) attribute(element, "title") orelse "" else "",
        .alternate = isAlternate(element, internal),
        .media = attribute(element, "media") orelse "",
        .location = url,
        .base_url = url,
        .origin_clean = origin_clean,
        .mode = .{ .quirks = dom_module.document_internals.getMode(document) == .quirks },
    }) catch |err| {
        log.warn("link style sheet not created: {}", .{err});
        return;
    };
    internal.sheet = record;
    internal.sheet_document = document;
    internal.sheet_document_generation = runtime.SlabAllocator.generationOf(document);
    if (dom_module.style.engine.engineOf(document)) |engine| engine.addOwner(element) catch {};
}

/// CSSOM "remove a CSS style sheet" of the element's sheet, if it has one.
fn removeSheet(element: *runtime.Instance, internal: *InternalState) void {
    const record = internal.sheet orelse return;
    internal.sheet = null;
    if (internal.sheet_document) |document| {
        if (runtime.SlabAllocator.generationOf(document) == internal.sheet_document_generation) {
            if (dom_module.style.engine.engineOf(document)) |engine| engine.removeOwner(element);
        }
    }
    internal.sheet_document = null;
    // CSSOM "remove a CSS style sheet" step 2: its owner node goes; the
    // element no longer keeps the sheet's object, which script may still
    // hold (and with it the sheet).
    record.detach();
    dom_module.style.objects.ownerReleased(element);
    record.unref();
}

/// dom.style's `link_sheet_of`.
fn sheetOf(element: *runtime.Instance) ?*dom_module.style.SheetRecord {
    const internal = getInternal(element) orelse return null;
    return internal.sheet;
}

// ============================================================================
// The expect link type (HTML 4.6.8.6)
// ============================================================================

/// The expect link type's conditions for processing, after an attribute
/// change: "an expect internal resource link is created on el that is
/// already browsing-context connected" (rel gains "expect"), and an expect
/// link's href or media "is set, changed, or removed". Two more the spec
/// does not list, as Chrome and Safari do (golden rule 2; Firefox ships no
/// expect link type): the blocking attribute changing re-processes - gaining
/// `render` blocks (Blink HTMLLinkElement::HandleExpectBlockingChanges,
/// WebKit's blockingAttr case; element-render-blocking-006) - and rel losing
/// "expect" unblocks (Blink RemoveExpectRenderBlockingLink on a rel change;
/// -010, -020).
fn expectAttributeChanged(element: *runtime.Instance, local_name: []const u8) void {
    const relevant = [_][]const u8{ "href", "media", "rel", "blocking" };
    for (relevant) |name| {
        if (std.mem.eql(u8, local_name, name)) return processExpect(element);
    }
}

/// Process the element's expect link if it has one or had one: rel
/// contains "expect", or the element is one of its document's expect links.
fn processExpect(element: *runtime.Instance) void {
    if (hasToken(attribute(element, "rel") orelse "", "expect")) return processInternalResourceLink(element, null);
    unblockExpect(element);
}

/// dom.document_rendering's "process internal resource links": process
/// `link`, an expect link of the set, for `candidate`'s change.
fn processFromSet(link: *runtime.Instance, candidate: ?*runtime.Instance) void {
    if (getInternal(link) == null) return;
    processInternalResourceLink(link, candidate);
}

/// "Unblock rendering" on the element as an expect link: a membership its
/// stylesheet load holds is that load's to end.
fn unblockExpect(element: *runtime.Instance) void {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    if (dom_module.document_rendering.isExpectLink(document, element)) dom_module.document_rendering.remove(document, element);
}

/// HTML "process internal resource link" given the link element `element`.
/// With a `candidate` - the element whose pop, insertion, id or name change
/// caused this - a link whose fragment `candidate` cannot indicate keeps its
/// result, as in WebKit (HTMLLinkElement::processInternalResourceLink's
/// element path) and Blink (pending links keyed by ID).
///
/// Golden rule 2 (Chrome and Safari; Firefox ships no expect link type): a
/// URL whose fragment is null or empty unblocks, where step 4 would select
/// nothing or the top of the document and step 5 would block - Blink's
/// ParseSameDocumentIdFromHref yields no ID and adds no pending link, WebKit
/// unblocks an empty href (element-render-blocking-013 and -023).
fn processInternalResourceLink(element: *runtime.Instance, candidate: ?*runtime.Instance) void {
    const allocator = element.ctx.allocator;
    // Step 1: "Let doc be el's node document."
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    // Step 2: "Let url be the result of encoding-parsing a URL given el's
    // href attribute's value, relative to doc."
    const href = attribute(element, "href") orelse "";
    const url = (dom_module.encoding_parse.encodingParseAndSerialize(element, href) catch return) orelse return unblockExpect(element);
    defer allocator.free(url);
    // Step 3: "If this fails, or if url does not equal doc's URL with
    // exclude fragments set to true, then unblock rendering on el and
    // return."
    const document_url = interfaces.Document.get_URL(document) catch return;
    defer document.ctx.allocator.free(document_url);
    if (!std.mem.eql(u8, withoutFragment(url), withoutFragment(document_url))) return unblockExpect(element);
    const fragment = fragmentOf(url) orelse return unblockExpect(element);
    if (fragment.len == 0) return unblockExpect(element);
    if (candidate) |changed| if (!mayIndicate(changed, fragment)) return;
    // Step 4: "Let indicatedElement be the result of selecting the indicated
    // part given doc and url" (its step 1 is step 3 above).
    const indicated = dom_module.fragment_scroll.selectTheIndicatedPart(document, fragment);
    // Steps 5-6.
    if (blocksRendering(element, document, indicated)) {
        dom_module.document_rendering.blockExpectLink(element) catch {};
    } else {
        unblockExpect(element);
    }
}

/// Step 5's conditions, all of which make the element block rendering.
fn blocksRendering(element: *runtime.Instance, document: *runtime.Instance, indicated: dom_module.fragment_scroll.IndicatedPart) bool {
    // "doc's current document readiness is "loading"".
    if ((interfaces.Document.get_readyState(document) catch return false) != ._loading_) return false;
    // "el creates an internal resource link" and "el's rel attribute
    // contains expect": the expect link type is the internal resource link.
    if (!hasToken(attribute(element, "rel") orelse "", "expect")) return false;
    // "el is browsing-context connected".
    if (!(interfaces.Node.get_isConnected(element) catch false)) return false;
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return false;
    // "el is potentially render-blocking": its blocking attribute has
    // `render` (an expect link is never implicitly so).
    if (!dom_module.document_rendering.hasRenderToken(attribute(element, "blocking") orelse "")) return false;
    // "el's media attribute matches the environment".
    if (!mediaMatches(element, document)) return false;
    // "indicatedElement is not an element, or is on a stack of open
    // elements of an HTML parser whose associated Document is doc".
    return switch (indicated) {
        .element => |target| dom_module.document_rendering.onParserStack(document, target),
        .none, .top_of_the_document => true,
    };
}

/// Whether the media attribute's value matches `document`'s environment
/// (Media Queries 5; absent or empty matches).
fn mediaMatches(element: *runtime.Instance, document: *runtime.Instance) bool {
    const text = attribute(element, "media") orelse return true;
    const values = dom_module.style.hooks.mediaValues(document);
    return @import("css").media_queries.MediaQueryList.matchesQuery(element.ctx.allocator, text, &values) catch true;
}

/// Whether `candidate` may be what `fragment` indicates: its ID, or an HTML
/// `a` element's name, is the fragment. A fragment with a percent sign may
/// match in its decoded form ("select the indicated part" steps 6-9), which
/// the full processing checks.
fn mayIndicate(candidate: *runtime.Instance, fragment: []const u8) bool {
    if (std.mem.indexOfScalar(u8, fragment, '%') != null) return true;
    const data = dom_module.element_data.of(candidate) orelse return false;
    if (std.mem.eql(u8, data.id.asSlice(), fragment)) return true;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "a")) return false;
    if (!std.mem.eql(u8, data.namespaceSlice() orelse return false, html_namespace)) return false;
    const name = data.findAttribute(null, "name") orelse return false;
    return std.mem.eql(u8, name.value, fragment);
}

/// A serialized URL without its fragment.
fn withoutFragment(url: []const u8) []const u8 {
    return url[0 .. std.mem.indexOfScalar(u8, url, '#') orelse url.len];
}

/// A serialized URL's fragment, or null when it has none.
fn fragmentOf(url: []const u8) ?[]const u8 {
    const hash = std.mem.indexOfScalar(u8, url, '#') orelse return null;
    return url[hash + 1 ..];
}

/// The HTML insertion steps, step 3: "If insertedNode is an Element that is
/// not on the stack of open elements of an HTML parser, then process
/// internal resource links given insertedNode's node document." An element
/// the parser inserts counts as on its stack (DocumentParser
/// .isOnStackOfOpenElements): it unblocks when the parser pops it.
fn htmlInsertionSteps(node: *NodeBase) void {
    if (node.node_type != 1 or !node.is_connected) return;
    const ptr = instance_bridge.getInstance(node) orelse return;
    const element: *runtime.Instance = @ptrCast(@alignCast(ptr));
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    if (!dom_module.document_rendering.hasExpectLinks(document)) return;
    if (!dom_module.document_rendering.canBeIndicated(element)) return;
    if (dom_module.document_rendering.onParserStack(document, element)) return;
    dom_module.document_rendering.processInternalResourceLinks(document, element);
}

/// The attribute change steps 4.6.8.6 gives every element, so that expect
/// links respond to dynamic id and name changes.
fn indicatorAttributeChanged(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    _ = old_value;
    _ = value;
    // Step 1: "If namespace is not null, then return."
    if (namespace != null) return;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    if (!dom_module.document_rendering.hasExpectLinks(document)) return;
    if (!dom_module.document_rendering.canBeIndicated(element)) return;
    // Step 2: "If element is in a stack of open elements of an HTML parser,
    // then return."
    if (dom_module.document_rendering.onParserStack(document, element)) return;
    // Step 3: localName is id, or name on an a element (the hook installs
    // name for HTML elements; the candidate check reads the a element's).
    _ = local_name;
    dom_module.document_rendering.processInternalResourceLinks(document, element);
}

/// The link element `node` is, if it is one: a brand check on its instance,
/// not its node name (which is "" for most elements).
fn linkOf(node: *NodeBase) ?*runtime.Instance {
    const ptr = instance_bridge.getInstance(node) orelse return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
    if (getInternal(instance) == null) return null;
    return instance;
}

// ============================================================================
// Attributes limited to only known values
// ============================================================================

/// Getter for crossOrigin: reflects the crossorigin content attribute,
/// limited to only known values - null when absent, "use-credentials", or
/// "anonymous" for any other value (its invalid value default).
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const value = attribute(instance, "crossorigin") orelse return null;
    if (std.ascii.eqlIgnoreCase(value, "use-credentials")) return runtime.DOMString.initInterned("use-credentials");
    return runtime.DOMString.initInterned("anonymous");
}

/// Getter for as: reflects the as content attribute, limited to only known
/// values - the potential destinations; "" when absent or invalid.
pub fn get_as(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return knownValue(attribute(instance, "as"), &potential_destinations, "");
}

/// Getter for referrerPolicy: reflects the referrerpolicy content attribute,
/// limited to only known values; "" when absent or invalid.
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return knownValue(attribute(instance, "referrerpolicy"), &referrer_policies, "");
}

/// Getter for fetchPriority: reflects the fetchpriority content attribute,
/// limited to only known values; "auto" when absent or invalid.
pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return knownValue(attribute(instance, "fetchpriority"), &.{ "high", "low", "auto" }, "auto");
}

/// Getter for sheet (LinkStyle, CSSOM 6.3.2): "the associated CSS style
/// sheet of the node or null if there is no associated CSS style sheet" -
/// its CSSStyleSheet object, made on first read and kept by the element.
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const record = internal.sheet orelse return null;
    return try dom_module.style.objects.sheetObject(record, instance.ctx);
}

/// Setter for crossOrigin: null removes the content attribute; any other
/// value sets it.
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (value) |v| {
        try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("crossorigin"), .{ .domstring = v });
    } else {
        try interfaces.Element.call_removeAttribute(instance, runtime.DOMString.initInterned("crossorigin"));
    }
}

/// Setter for as: sets the content attribute.
pub fn set_as(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("as"), .{ .domstring = value });
}

/// Setter for referrerPolicy: sets the content attribute.
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("referrerpolicy"), .{ .domstring = value });
}

/// Setter for fetchPriority: sets the content attribute.
pub fn set_fetchPriority(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("fetchpriority"), .{ .domstring = value });
}

/// Fetch's potential destinations: "fetch" and the destinations.
const potential_destinations = [_][]const u8{
    "fetch",  "audio",         "audioworklet", "document", "embed",  "font",         "frame",
    "iframe", "image",         "json",         "manifest", "object", "paintworklet", "report",
    "script", "serviceworker", "sharedworker", "style",    "track",  "video",        "webidentity",
    "worker", "xslt",
};

/// An enumerated attribute's state as the keyword it is, ASCII
/// case-insensitively; `default` when absent or not a keyword.
fn knownValue(value: ?[]const u8, keywords: []const []const u8, default: []const u8) runtime.DOMString {
    if (value) |v| {
        for (keywords) |keyword| {
            if (std.ascii.eqlIgnoreCase(v, keyword)) return runtime.DOMString.initInterned(keyword);
        }
    }
    return runtime.DOMString.initInterned(default);
}
