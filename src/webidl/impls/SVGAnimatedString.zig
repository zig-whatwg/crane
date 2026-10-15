//! SVG 2 4.6.7: a live reflection of a string attribute and, optionally,
//! its deprecated alternative. SVGURIReference supplies the association at
//! construction; the generated [SameObject] getter caches the result.
//!
//! The existing MemberHold keeps the reflected element alive for this
//! object's lifetime, including when script holds only the animated string.
//! Blink's SVGAnimatedPropertyBase likewise traces its context_element_.
//! https://svgwg.org/svg2-draft/types.html#InterfaceSVGAnimatedString

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const engine = @import("engine");

pub const State = interfaces.SVGAnimatedString.State;

/// Facts supplied by the reflecting getter through the construction chain.
pub const construction_args = .{ "reflected_element", "reflected_attribute", "deprecated_attribute_namespace" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    element: dom.node_holds.MemberHold = .{},
    attribute: []u8,
    deprecated_namespace: ?[]u8,
};

const element_slot: engine.TracedSlot = .{ .name = "svg-animated-string:element" };

/// Initialize only this interface's state; the generated chain owns storage.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const attribute = try allocator.dupe(u8, if (@hasField(@TypeOf(args), "reflected_attribute")) args.reflected_attribute else "");
    errdefer allocator.free(attribute);
    const deprecated_namespace: ?[]u8 = if (@hasField(@TypeOf(args), "deprecated_attribute_namespace"))
        try allocator.dupe(u8, args.deprecated_attribute_namespace)
    else
        null;
    errdefer if (deprecated_namespace) |ns| allocator.free(ns);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .attribute = attribute, .deprecated_namespace = deprecated_namespace };
    instance.getState(StateType).own._internal = internal;
    if (@hasField(@TypeOf(args), "reflected_element")) {
        internal.element.take(instance, args.reflected_element, element_slot);
    }
}

/// Release the association and strings, including an object never wrapped.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.element.release(instance, element_slot);
        internal.allocator.free(internal.attribute);
        if (internal.deprecated_namespace) |ns| internal.allocator.free(ns);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.stateAs(State) orelse return error.TypeError;
    return state.own._internal orelse error.InvalidStateError;
}

/// Getter steps 1-2: the primary attribute, then its deprecated alternative,
/// then the empty string (href has no nonempty initial value).
pub fn get_baseVal(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = try internalOf(instance);
    const element = internal.element.get() orelse return error.InvalidStateError;
    const data = dom.element_data.of(element) orelse return error.InvalidStateError;
    const primary = dom.element_data.getAttributeByNamespaceAndLocalName(data, null, internal.attribute);
    if (primary) |attribute| return runtime.DOMString.initDupe(instance.ctx.allocator, attribute.value);
    if (internal.deprecated_namespace) |ns| {
        if (dom.element_data.getAttributeByNamespaceAndLocalName(data, ns, internal.attribute)) |attribute| {
            return runtime.DOMString.initDupe(instance.ctx.allocator, attribute.value);
        }
    }
    return runtime.DOMString.initEmpty();
}

/// SVG 2 4.6.7 gives animVal the same non-animated value as baseVal.
pub fn get_animVal(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return get_baseVal(instance);
}

/// Setter steps 1-4, with the browser-majority ordering noted below.
pub fn set_baseVal(instance: *runtime.Instance, value: typedefs.DOMStringOrTrustedScriptURL) anyerror!void {
    const internal = try internalOf(instance);
    const element = internal.element.get() orelse return error.InvalidStateError;
    // Deviation from SVG 2 step 3: select the backing attribute before the
    // policy runs. Blink SVGAnimatedHref::setBaseVal calls BackingString()
    // first; Gecko SVGScriptElement::Href selects its string tearoff before
    // SVGAnimatedScriptHrefString::SetBaseValue invokes the policy. Thus
    // adding/removing href inside the callback does not retarget this write.
    // https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/svg/svg_animated_href.cc
    // https://raw.githubusercontent.com/mozilla-firefox/firefox/main/dom/svg/SVGScriptElement.cpp
    // https://raw.githubusercontent.com/mozilla-firefox/firefox/main/dom/svg/SVGAnimatedString.cpp
    const data = dom.element_data.of(element) orelse return error.InvalidStateError;
    const namespace: ?[]const u8 = if (dom.element_data.getAttributeByNamespaceAndLocalName(data, null, internal.attribute) == null)
        if (internal.deprecated_namespace) |ns|
            if (dom.element_data.getAttributeByNamespaceAndLocalName(data, ns, internal.attribute) != null) ns else null
        else
            null
    else
        null;
    // Steps 1-2. Limit the check to script href, as Blink's
    // SVGAnimatedString::setBaseVal does; the SVG prose omits the attribute
    // qualification. trusted-types-svg-script-set-href.html is 18/18 in
    // Chrome, Firefox and Safari (aligned stable runs 2026-10-06).
    // https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/svg/svg_animated_string.cc
    const compliant = try dom.trusted_types.getCompliantAttributeValue(internal.allocator, internal.attribute, null, element, dom.trusted_types.inputFrom(value));
    defer internal.allocator.free(compliant);

    // Steps 3-4. Set the chosen attribute after the policy has succeeded.
    // This is the attribute-update step, not setAttribute's IDL sink: the
    // default policy has already run. Recheck the hold's teardown net after
    // script; no borrowed attribute pointer survives the callback.
    const live_element = internal.element.get() orelse return error.InvalidStateError;
    try dom.element_attributes.set(live_element, internal.attribute, compliant, .{
        .namespace = namespace,
        .prefix = if (namespace != null) "xlink" else null,
    });
}
