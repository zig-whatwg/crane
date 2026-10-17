//! Implementation for the HTMLHyperlinkElementUtils mixin: href and
//! target of HTML's `a` and `area` elements, and their hyperlink "extract an
//! origin" steps. The URL decomposition members (origin ... hash) are
//! HyperlinkElementUtils', which SVG's and MathML's `a` include too.
//!
//! Spec: https://html.spec.whatwg.org/multipage/links.html#api-for-a-and-area-elements
//!
//! The element's "url" is its href content attribute parsed relative to its
//! node document ("set the url"), parsed afresh on every access.
//!
//! Its includers - HTMLAnchorElement, HTMLAreaElement - inherit these members
//! by alias; `this` is the element. target is [Reflect]: the generated mixin
//! reflects it.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLHyperlinkElementUtils = interfaces.HTMLHyperlinkElementUtils;

// The element's href attribute, read in place (dom.element_data, which
// Element installs).
const element_data = @import("dom").element_data;
const html = @import("html");

pub const State = HTMLHyperlinkElementUtils.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data. None: the url is
/// recomputed from the href attribute on every access.
pub const InternalState = struct {};

pub fn installHooks() void {
    @import("dom").extract_origin.install(.hyperlink, .{ .owns = &ownsOriginExtraction, .extract = &extractOrigin });
}

fn ownsOriginExtraction(instance: *runtime.Instance) bool {
    return instance.stateAs(interfaces.HTMLAnchorElement.State) != null or
        instance.stateAs(interfaces.HTMLAreaElement.State) != null;
}

/// HTML hyperlink extract-an-origin steps 1-2: null for no URL, otherwise
/// its origin. Reuse "set the url"'s encoding parse without a URL wrapper.
fn extractOrigin(instance: *runtime.Instance) !?*@import("dom").origin_record.OriginRecord {
    const href = hrefAttribute(instance) orelse return null;
    const serialized = (try html.encoding_parse.encodingParseAndSerialize(instance, href)) orelse return null;
    defer instance.ctx.allocator.free(serialized);
    return @import("dom").extract_origin.ownedRecordForUrl(instance.ctx.allocator, serialized);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

// =============================================================================
// The element's url
// =============================================================================

/// The href content attribute's value, borrowed from the attribute, or null.
fn hrefAttribute(element: *runtime.Instance) ?[]const u8 {
    const data = element_data.of(element) orelse return null;
    const entry = element_data.getAttributeByNamespaceAndLocalName(data, null, "href") orelse return null;
    return entry.value;
}

// =============================================================================
// Getters
// =============================================================================

/// Getter for href: "1. Reinitialize url. 2. Let url be this's url. 3. If url
/// is null and this has no href content attribute, return the empty string.
/// 4. Otherwise, if url is null, return this's href content attribute's
/// value. 5. Return url, serialized."
///
/// The url, serialized, is the href attribute encoding-parsed relative to the
/// node document and serialized ("set the url" then step 5).
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const href = hrefAttribute(instance) orelse return instance.ctx.allocator.dupe(u8, "");
    if (html.encoding_parse.encodingParseAndSerialize(instance, href) catch null) |serialized| return serialized;
    return instance.ctx.allocator.dupe(u8, href);
}

// =============================================================================
// Setters
// =============================================================================

/// Setter for href: "set this's href content attribute's value to the given
/// value."
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("href"), .{ .domstring = runtime.DOMString.initInterned(value) });
}
