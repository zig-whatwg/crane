//! Implementation for MathMLAnchorElement interface: MathML Core 3.6,
//! "Linking <a>".
//!
//! "The href, target, download, ping, rel, hreflang, type and referrerpolicy
//! attributes have the same syntax and semantics as defined for the HTML a
//! element": a MathML a with an href creates a hyperlink, and its activation
//! behaviour is the HTML a element's (HTML 4.6.4) - it audits the hyperlink
//! (ping) and follows it, or downloads it. Its href's url is HTML's
//! hyperlink url (HyperlinkElementUtils, inherited by alias), set by
//! MathML Core's own "set the url" and "update href" steps, which are the
//! HTML a element's with the href content attribute.
//!
//! Spec: https://w3c.github.io/mathml-core/#linking-a

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const MathMLAnchorElement = interfaces.MathMLAnchorElement;

pub const State = MathMLAnchorElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data. None: the url is the
/// href attribute's, parsed on every access (HyperlinkElementUtils does
/// the same: "reinitialize url" has nothing cached to reinitialize).
pub const InternalState = struct {};

const element_data = dom.element_data;

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Its activation behaviour: the HTML a element's (dom.activation).
    dom.activation.install(.{ .has = &hasActivationBehavior, .run = &runActivationBehavior });
}

/// dom.activation: every MathML a element has activation behaviour, as
/// every HTML a element does; its steps return at once without an href.
fn hasActivationBehavior(target: *runtime.Instance) bool {
    return target.stateAs(State) != null;
}

/// dom.activation: the HTML a element's activation behaviour (HTML 4.6.4),
/// which MathML Core 3.6 gives the MathML a: "1. If element has no href
/// attribute, then return." Then hyperlink auditing (4.6.6, its ping
/// attribute) as the hyperlink is followed, and: "If element has a download
/// attribute ... download the hyperlink created by element ... with
/// userInvolvement"; otherwise "follow the hyperlink created by element
/// with userInvolvement" - "event's user navigation involvement".
/// Not modelled for a MathML a: HTML's editable-link check (Blink's
/// IsLiveLink reads an HTML element's isContentEditable) and an ismap
/// image's coordinates.
fn runActivationBehavior(target: *runtime.Instance, event: *runtime.Instance) void {
    const data = element_data.of(target) orelse return;
    if (element_data.getAttributeByNamespaceAndLocalName(data, null, "href") == null) return;
    // HTML 4.6.6: following it sends the element's pings, before the
    // navigation starts (Blink HTMLAnchorElement::NavigateToHyperlink).
    @import("html").hyperlink_auditing.audit(target);
    const user_involvement = @import("html").user_activation.userNavigationInvolvement(event);
    if (element_data.getAttributeByNamespaceAndLocalName(data, null, "download") != null) return dom.navigables.downloadHyperlink(target, user_involvement);
    dom.navigables.followHyperlink(target, user_involvement);
}

/// Getter for href (MathML Core 3.6): "1. Reinitialize url. 2. Let url be
/// this's url. 3. If url is null and this has no href content attribute,
/// then return the empty string. 4. Otherwise, if url is null, then return
/// this's href content attribute's value. 5. Return url, serialized."
///
/// The url is "set the url" for a MathMLAnchorElement: the href attribute's
/// value encoding-parsed relative to the node document, null on failure.
/// The setter is [ReflectSetter]: the generated interface sets the href
/// content attribute.
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const data = element_data.of(instance) orelse return instance.ctx.allocator.dupe(u8, "");
    // 3. No href content attribute (and so no url): the empty string.
    const href = (element_data.getAttributeByNamespaceAndLocalName(data, null, "href") orelse return instance.ctx.allocator.dupe(u8, "")).value;
    // 5. The url, serialized.
    if (try dom.encoding_parse.encodingParseAndSerialize(instance, href)) |serialized| return serialized;
    // 4. The value did not parse: the attribute's value.
    return instance.ctx.allocator.dupe(u8, href);
}
