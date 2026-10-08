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
//! fetched again by its consumer; alternative style sheets are fetched as any other; the style
//! sheet itself is not parsed into CSSOM, so `sheet` is null;
//! render-blocking is not kept. Parser-created enabled stylesheets enter
//! their document's script-blocking set until their load event finishes.

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
    dom_module.mutation.registerPostConnectionStepsCallback(&insertionSteps) catch |err| {
        log.warn("link insertion steps not registered: {}", .{err});
    };
    dom_module.mutation.registerRemovingStepsCallback(&removingSteps) catch |err| {
        log.warn("link removing steps not registered: {}", .{err});
    };
}

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
    const internal = try runtime.ArenaAllocator.get().create(InternalState);
    internal.* = .{};
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its style sheet's load ends with it.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        style_sheet_loading.elementGone(instance);
        if (runtime.ArenaAllocator.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
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
    // "Browsing-context connected": connected, and its document has a
    // browsing context.
    if (!(interfaces.Node.get_isConnected(element) catch false)) return;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    // "Create link options from element": href, crossorigin and
    // referrerpolicy. A link with no href, or an empty one, defines no link.
    const href = attribute(element, "href") orelse return;
    if (href.len == 0) return;
    const options: style_sheet_loading.LinkOptions = .{
        .href = href,
        .cors = style_sheet_loading.CorsSetting.fromAttribute(attribute(element, "crossorigin")),
        .referrer_policy = referrerPolicyState(attribute(element, "referrerpolicy")),
    };
    switch (linkType(element)) {
        .none => {},
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
            internal.load = style_sheet_loading.startModulePreload(element, options, destination) orelse 0;
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
/// modulepreload link. (Two at once - `rel="preload stylesheet"` - is
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

fn parserSheetEnabled(internal: *const InternalState, document: *runtime.Instance) bool {
    return internal.enabled_at_creation and internal.parser_document == document and
        runtime.SlabAllocator.generationOf(document) == internal.parser_document_generation;
}

fn isAlternate(element: *runtime.Instance, internal: *const InternalState) bool {
    const rel = attribute(element, "rel") orelse return false;
    const title = attribute(element, "title") orelse return false;
    return title.len != 0 and hasToken(rel, "alternate") and !internal.explicitly_enabled;
}

const LinkType = enum { none, stylesheet, preload, modulepreload };

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
        if (std.mem.eql(u8, local_name, "media")) {
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
    return .none;
}

/// Whether a type attribute of `type_attr` lets the element's link be
/// fetched.
fn typeAllows(element: *runtime.Instance, type_attr: ?[]const u8) bool {
    return switch (linkType(element)) {
        .none, .modulepreload => true,
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
}

/// The element is no longer connected: it no longer creates a link that
/// contributes to the styling processing model, and its load ends. Called
/// for every node removed.
fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.node_type != 1) return;
    const instance = linkOf(node) orelse return;
    const internal = getInternal(instance) orelse return;
    if (internal.load == 0) return;
    const load = internal.load;
    internal.load = 0;
    style_sheet_loading.cancel(load);
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

/// Getter for sheet: the associated CSS style sheet. Style sheets are not
/// parsed into CSSOM (see the file comment), so there is none.
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
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
