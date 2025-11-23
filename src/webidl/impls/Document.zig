//! Implementation for Document interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Document = interfaces.Document;

pub const State = Document.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &Document.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for implementation
pub fn get_implementation(instance: *runtime.Instance) ImplError!interfaces.DOMImplementation {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for URL
pub fn get_URL(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for documentURI
pub fn get_documentURI(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for compatMode
pub fn get_compatMode(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for characterSet
pub fn get_characterSet(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for charset
pub fn get_charset(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for inputEncoding
pub fn get_inputEncoding(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for contentType
pub fn get_contentType(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for doctype
pub fn get_doctype(instance: *runtime.Instance) ImplError!interfaces.DocumentType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for documentElement
pub fn get_documentElement(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fragmentDirective
pub fn get_fragmentDirective(instance: *runtime.Instance) ImplError!interfaces.FragmentDirective {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for prerendering
pub fn get_prerendering(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onprerenderingchange
pub fn get_onprerenderingchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fullscreenEnabled
pub fn get_fullscreenEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fullscreen
pub fn get_fullscreen(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfullscreenchange
pub fn get_onfullscreenchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfullscreenerror
pub fn get_onfullscreenerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for timeline
pub fn get_timeline(instance: *runtime.Instance) ImplError!interfaces.DocumentTimeline {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pictureInPictureEnabled
pub fn get_pictureInPictureEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerlockchange
pub fn get_onpointerlockchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerlockerror
pub fn get_onpointerlockerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfreeze
pub fn get_onfreeze(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onresume
pub fn get_onresume(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for wasDiscarded
pub fn get_wasDiscarded(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for namedFlows
pub fn get_namedFlows(instance: *runtime.Instance) ImplError!interfaces.NamedFlowMap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rootElement
pub fn get_rootElement(instance: *runtime.Instance) ImplError!interfaces.SVGSVGElement {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for activeViewTransition
pub fn get_activeViewTransition(instance: *runtime.Instance) ImplError!interfaces.ViewTransition {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for location
pub fn get_location(instance: *runtime.Instance) ImplError!interfaces.Location {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for domain
pub fn get_domain(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for referrer
pub fn get_referrer(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for cookie
pub fn get_cookie(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lastModified
pub fn get_lastModified(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for readyState
pub fn get_readyState(instance: *runtime.Instance) ImplError!enums.DocumentReadyState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for title
pub fn get_title(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for dir
pub fn get_dir(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for body
pub fn get_body(instance: *runtime.Instance) ImplError!interfaces.HTMLElement {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for head
pub fn get_head(instance: *runtime.Instance) ImplError!interfaces.HTMLHeadElement {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for images
pub fn get_images(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for embeds
pub fn get_embeds(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for plugins
pub fn get_plugins(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for links
pub fn get_links(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for forms
pub fn get_forms(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scripts
pub fn get_scripts(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for currentScript
pub fn get_currentScript(instance: *runtime.Instance) ImplError!typedefs.HTMLOrSVGScriptElement {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for defaultView
pub fn get_defaultView(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for designMode
pub fn get_designMode(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hidden
pub fn get_hidden(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for visibilityState
pub fn get_visibilityState(instance: *runtime.Instance) ImplError!enums.DocumentVisibilityState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onreadystatechange
pub fn get_onreadystatechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onvisibilitychange
pub fn get_onvisibilitychange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fgColor
pub fn get_fgColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for linkColor
pub fn get_linkColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for vlinkColor
pub fn get_vlinkColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for alinkColor
pub fn get_alinkColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for bgColor
pub fn get_bgColor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for anchors
pub fn get_anchors(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for applets
pub fn get_applets(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for all
pub fn get_all(instance: *runtime.Instance) ImplError!interfaces.HTMLAllCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrollingElement
pub fn get_scrollingElement(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for permissionsPolicy
pub fn get_permissionsPolicy(instance: *runtime.Instance) ImplError!interfaces.PermissionsPolicy {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fonts
pub fn get_fonts(instance: *runtime.Instance) ImplError!interfaces.FontFaceSet {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for customElementRegistry
pub fn get_customElementRegistry(instance: *runtime.Instance) ImplError!interfaces.CustomElementRegistry {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fullscreenElement
pub fn get_fullscreenElement(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pictureInPictureElement
pub fn get_pictureInPictureElement(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pointerLockElement
pub fn get_pointerLockElement(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for styleSheets
pub fn get_styleSheets(instance: *runtime.Instance) ImplError!interfaces.StyleSheetList {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for adoptedStyleSheets
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for activeElement
pub fn get_activeElement(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for children
pub fn get_children(instance: *runtime.Instance) ImplError!interfaces.HTMLCollection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for firstElementChild
pub fn get_firstElementChild(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lastElementChild
pub fn get_lastElementChild(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for childElementCount
pub fn get_childElementCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onauxclick
pub fn get_onauxclick(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforeinput
pub fn get_onbeforeinput(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforematch
pub fn get_onbeforematch(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforetoggle
pub fn get_onbeforetoggle(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onblur
pub fn get_onblur(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncancel
pub fn get_oncancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncanplay
pub fn get_oncanplay(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncanplaythrough
pub fn get_oncanplaythrough(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onclick
pub fn get_onclick(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncommand
pub fn get_oncommand(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncontextlost
pub fn get_oncontextlost(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncontextmenu
pub fn get_oncontextmenu(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncontextrestored
pub fn get_oncontextrestored(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncopy
pub fn get_oncopy(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncuechange
pub fn get_oncuechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncut
pub fn get_oncut(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondblclick
pub fn get_ondblclick(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondrag
pub fn get_ondrag(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragend
pub fn get_ondragend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragenter
pub fn get_ondragenter(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragleave
pub fn get_ondragleave(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragover
pub fn get_ondragover(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondragstart
pub fn get_ondragstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondrop
pub fn get_ondrop(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondurationchange
pub fn get_ondurationchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onemptied
pub fn get_onemptied(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onended
pub fn get_onended(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) ImplError!typedefs.OnErrorEventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfocus
pub fn get_onfocus(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onformdata
pub fn get_onformdata(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oninput
pub fn get_oninput(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oninvalid
pub fn get_oninvalid(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onkeydown
pub fn get_onkeydown(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onkeypress
pub fn get_onkeypress(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onkeyup
pub fn get_onkeyup(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadeddata
pub fn get_onloadeddata(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadedmetadata
pub fn get_onloadedmetadata(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmousedown
pub fn get_onmousedown(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseenter
pub fn get_onmouseenter(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseleave
pub fn get_onmouseleave(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmousemove
pub fn get_onmousemove(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseout
pub fn get_onmouseout(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseover
pub fn get_onmouseover(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmouseup
pub fn get_onmouseup(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpaste
pub fn get_onpaste(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpause
pub fn get_onpause(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onplay
pub fn get_onplay(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onplaying
pub fn get_onplaying(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onratechange
pub fn get_onratechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onreset
pub fn get_onreset(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onresize
pub fn get_onresize(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onscroll
pub fn get_onscroll(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onscrollend
pub fn get_onscrollend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsecuritypolicyviolation
pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onseeked
pub fn get_onseeked(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onseeking
pub fn get_onseeking(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselect
pub fn get_onselect(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onslotchange
pub fn get_onslotchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onstalled
pub fn get_onstalled(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsubmit
pub fn get_onsubmit(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsuspend
pub fn get_onsuspend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontimeupdate
pub fn get_ontimeupdate(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontoggle
pub fn get_ontoggle(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onvolumechange
pub fn get_onvolumechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwaiting
pub fn get_onwaiting(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwebkitanimationend
pub fn get_onwebkitanimationend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwebkitanimationiteration
pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwebkitanimationstart
pub fn get_onwebkitanimationstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwebkittransitionend
pub fn get_onwebkittransitionend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwheel
pub fn get_onwheel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselectstart
pub fn get_onselectstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onselectionchange
pub fn get_onselectionchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onanimationstart
pub fn get_onanimationstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onanimationiteration
pub fn get_onanimationiteration(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onanimationend
pub fn get_onanimationend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onanimationcancel
pub fn get_onanimationcancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontransitionrun
pub fn get_ontransitionrun(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontransitionstart
pub fn get_ontransitionstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontransitionend
pub fn get_ontransitionend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontransitioncancel
pub fn get_ontransitioncancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbeforexrselect
pub fn get_onbeforexrselect(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerover
pub fn get_onpointerover(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerenter
pub fn get_onpointerenter(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerdown
pub fn get_onpointerdown(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointermove
pub fn get_onpointermove(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerrawupdate
pub fn get_onpointerrawupdate(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerup
pub fn get_onpointerup(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointercancel
pub fn get_onpointercancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerout
pub fn get_onpointerout(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpointerleave
pub fn get_onpointerleave(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ongotpointercapture
pub fn get_ongotpointercapture(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onlostpointercapture
pub fn get_onlostpointercapture(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontouchstart
pub fn get_ontouchstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontouchend
pub fn get_ontouchend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontouchmove
pub fn get_ontouchmove(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ontouchcancel
pub fn get_ontouchcancel(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onfencedtreeclick
pub fn get_onfencedtreeclick(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsnapchanged
pub fn get_onsnapchanged(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onsnapchanging
pub fn get_onsnapchanging(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onprerenderingchange
pub fn set_onprerenderingchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfullscreenchange
pub fn set_onfullscreenchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfullscreenerror
pub fn set_onfullscreenerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerlockchange
pub fn set_onpointerlockchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerlockerror
pub fn set_onpointerlockerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfreeze
pub fn set_onfreeze(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onresume
pub fn set_onresume(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for domain
pub fn set_domain(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for cookie
pub fn set_cookie(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for title
pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for dir
pub fn set_dir(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for body
pub fn set_body(instance: *runtime.Instance, value: interfaces.HTMLElement) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for designMode
pub fn set_designMode(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onreadystatechange
pub fn set_onreadystatechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onvisibilitychange
pub fn set_onvisibilitychange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fgColor
pub fn set_fgColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for linkColor
pub fn set_linkColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for vlinkColor
pub fn set_vlinkColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for alinkColor
pub fn set_alinkColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for bgColor
pub fn set_bgColor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for adoptedStyleSheets
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onauxclick
pub fn set_onauxclick(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforeinput
pub fn set_onbeforeinput(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforematch
pub fn set_onbeforematch(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforetoggle
pub fn set_onbeforetoggle(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onblur
pub fn set_onblur(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncancel
pub fn set_oncancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncanplay
pub fn set_oncanplay(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncanplaythrough
pub fn set_oncanplaythrough(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onclick
pub fn set_onclick(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncommand
pub fn set_oncommand(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncontextlost
pub fn set_oncontextlost(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncontextmenu
pub fn set_oncontextmenu(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncontextrestored
pub fn set_oncontextrestored(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncopy
pub fn set_oncopy(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncuechange
pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncut
pub fn set_oncut(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondblclick
pub fn set_ondblclick(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondrag
pub fn set_ondrag(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragend
pub fn set_ondragend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragenter
pub fn set_ondragenter(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragleave
pub fn set_ondragleave(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragover
pub fn set_ondragover(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondragstart
pub fn set_ondragstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondrop
pub fn set_ondrop(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ondurationchange
pub fn set_ondurationchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onemptied
pub fn set_onemptied(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onended
pub fn set_onended(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.OnErrorEventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfocus
pub fn set_onfocus(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onformdata
pub fn set_onformdata(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oninput
pub fn set_oninput(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oninvalid
pub fn set_oninvalid(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onkeydown
pub fn set_onkeydown(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onkeypress
pub fn set_onkeypress(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onkeyup
pub fn set_onkeyup(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onload
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadeddata
pub fn set_onloadeddata(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadedmetadata
pub fn set_onloadedmetadata(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onloadstart
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmousedown
pub fn set_onmousedown(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseenter
pub fn set_onmouseenter(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseleave
pub fn set_onmouseleave(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmousemove
pub fn set_onmousemove(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseout
pub fn set_onmouseout(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseover
pub fn set_onmouseover(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmouseup
pub fn set_onmouseup(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpaste
pub fn set_onpaste(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpause
pub fn set_onpause(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onplay
pub fn set_onplay(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onplaying
pub fn set_onplaying(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onratechange
pub fn set_onratechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onreset
pub fn set_onreset(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onresize
pub fn set_onresize(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onscroll
pub fn set_onscroll(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onscrollend
pub fn set_onscrollend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsecuritypolicyviolation
pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onseeked
pub fn set_onseeked(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onseeking
pub fn set_onseeking(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselect
pub fn set_onselect(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onslotchange
pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onstalled
pub fn set_onstalled(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsubmit
pub fn set_onsubmit(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsuspend
pub fn set_onsuspend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontimeupdate
pub fn set_ontimeupdate(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontoggle
pub fn set_ontoggle(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onvolumechange
pub fn set_onvolumechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwaiting
pub fn set_onwaiting(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwebkitanimationend
pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwebkitanimationiteration
pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwebkitanimationstart
pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwebkittransitionend
pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwheel
pub fn set_onwheel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselectstart
pub fn set_onselectstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onselectionchange
pub fn set_onselectionchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onanimationstart
pub fn set_onanimationstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onanimationiteration
pub fn set_onanimationiteration(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onanimationend
pub fn set_onanimationend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onanimationcancel
pub fn set_onanimationcancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontransitionrun
pub fn set_ontransitionrun(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontransitionstart
pub fn set_ontransitionstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontransitionend
pub fn set_ontransitionend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontransitioncancel
pub fn set_ontransitioncancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbeforexrselect
pub fn set_onbeforexrselect(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerover
pub fn set_onpointerover(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerenter
pub fn set_onpointerenter(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerdown
pub fn set_onpointerdown(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointermove
pub fn set_onpointermove(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerrawupdate
pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerup
pub fn set_onpointerup(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointercancel
pub fn set_onpointercancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerout
pub fn set_onpointerout(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpointerleave
pub fn set_onpointerleave(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ongotpointercapture
pub fn set_ongotpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onlostpointercapture
pub fn set_onlostpointercapture(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontouchstart
pub fn set_ontouchstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontouchend
pub fn set_ontouchend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontouchmove
pub fn set_ontouchmove(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ontouchcancel
pub fn set_ontouchcancel(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onfencedtreeclick
pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsnapchanged
pub fn set_onsnapchanged(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onsnapchanging
pub fn set_onsnapchanging(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: exitPointerLock
pub fn call_exitPointerLock(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: queryCommandState
pub fn call_queryCommandState(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: parseHTMLUnsafe
pub fn call_parseHTMLUnsafe(instance: *runtime.Instance, html: *const anyopaque) ImplError!interfaces.Document {
    _ = instance;
    _ = html;
    return error.NotImplemented;
}

/// Operation: exitPictureInPicture
pub fn call_exitPictureInPicture(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createExpression
pub fn call_createExpression(instance: *runtime.Instance, expression: runtime.DOMString, resolver: interfaces.XPathNSResolver) ImplError!interfaces.XPathExpression {
    _ = instance;
    _ = expression;
    _ = resolver;
    return error.NotImplemented;
}

/// Operation: elementFromPoint
pub fn call_elementFromPoint(instance: *runtime.Instance, x: f64, y: f64) ImplError!interfaces.Element {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: createElement
pub fn call_createElement(instance: *runtime.Instance, localName: runtime.DOMString, options: *const anyopaque) ImplError!interfaces.Element {
    _ = instance;
    _ = localName;
    _ = options;
    return error.NotImplemented;
}

/// Operation: releaseEvents
pub fn call_releaseEvents(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: prepend
pub fn call_prepend(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: convertQuadFromNode
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!interfaces.DOMQuad {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: queryCommandSupported
pub fn call_queryCommandSupported(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: hasPrivateToken
pub fn call_hasPrivateToken(instance: *runtime.Instance, issuer: runtime.USVString) ImplError!*const anyopaque {
    _ = instance;
    _ = issuer;
    return error.NotImplemented;
}

/// Operation: requestStorageAccessFor
pub fn call_requestStorageAccessFor(instance: *runtime.Instance, requestedOrigin: runtime.USVString) ImplError!*const anyopaque {
    _ = instance;
    _ = requestedOrigin;
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance, unused1: runtime.DOMString, unused2: runtime.DOMString) ImplError!interfaces.Document {
    _ = instance;
    _ = unused1;
    _ = unused2;
    return error.NotImplemented;
}

/// Operation: hasUnpartitionedCookieAccess
pub fn call_hasUnpartitionedCookieAccess(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: hasRedemptionRecord
pub fn call_hasRedemptionRecord(instance: *runtime.Instance, issuer: runtime.USVString) ImplError!*const anyopaque {
    _ = instance;
    _ = issuer;
    return error.NotImplemented;
}

/// Operation: execCommand
pub fn call_execCommand(instance: *runtime.Instance, commandId: runtime.DOMString, showUI: bool, value: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    _ = showUI;
    _ = value;
    return error.NotImplemented;
}

/// Operation: measureElement
pub fn call_measureElement(instance: *runtime.Instance, element: interfaces.Element) ImplError!interfaces.FontMetrics {
    _ = instance;
    _ = element;
    return error.NotImplemented;
}

/// Operation: write
pub fn call_write(instance: *runtime.Instance, text: *const anyopaque) ImplError!void {
    _ = instance;
    _ = text;
    return error.NotImplemented;
}

/// Operation: createAttribute
pub fn call_createAttribute(instance: *runtime.Instance, localName: runtime.DOMString) ImplError!interfaces.Attr {
    _ = instance;
    _ = localName;
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: queryCommandIndeterm
pub fn call_queryCommandIndeterm(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: getElementsByTagNameNS
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!interfaces.HTMLCollection {
    _ = instance;
    _ = namespace;
    _ = localName;
    return error.NotImplemented;
}

/// Operation: elementsFromPoint
pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) ImplError!*const anyopaque {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: createProcessingInstruction
pub fn call_createProcessingInstruction(instance: *runtime.Instance, target: runtime.DOMString, data: runtime.DOMString) ImplError!interfaces.ProcessingInstruction {
    _ = instance;
    _ = target;
    _ = data;
    return error.NotImplemented;
}

/// Operation: createEvent
pub fn call_createEvent(instance: *runtime.Instance, interface: runtime.DOMString) ImplError!interfaces.Event {
    _ = instance;
    _ = interface;
    return error.NotImplemented;
}

/// Operation: replaceChildren
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: getBoxQuads
pub fn call_getBoxQuads(instance: *runtime.Instance, options: dictionaries.BoxQuadOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: convertPointFromNode
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!interfaces.DOMPoint {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getAnimations
pub fn call_getAnimations(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getElementsByClassName
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) ImplError!interfaces.HTMLCollection {
    _ = instance;
    _ = classNames;
    return error.NotImplemented;
}

/// Operation: getElementsByTagName
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!interfaces.HTMLCollection {
    _ = instance;
    _ = qualifiedName;
    return error.NotImplemented;
}

/// Operation: evaluate
pub fn call_evaluate(instance: *runtime.Instance, expression: runtime.DOMString, contextNode: interfaces.Node, resolver: interfaces.XPathNSResolver, @"type": u16, result: interfaces.XPathResult) ImplError!interfaces.XPathResult {
    _ = instance;
    _ = expression;
    _ = contextNode;
    _ = resolver;
    _ = @"type";
    _ = result;
    return error.NotImplemented;
}

/// Operation: querySelector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!interfaces.Element {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: hasStorageAccess
pub fn call_hasStorageAccess(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: importNode
pub fn call_importNode(instance: *runtime.Instance, node: interfaces.Node, options: *const anyopaque) ImplError!interfaces.Node {
    _ = instance;
    _ = node;
    _ = options;
    return error.NotImplemented;
}

/// Operation: createCDATASection
pub fn call_createCDATASection(instance: *runtime.Instance, data: runtime.DOMString) ImplError!interfaces.CDATASection {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: queryCommandEnabled
pub fn call_queryCommandEnabled(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: createRange
pub fn call_createRange(instance: *runtime.Instance) ImplError!interfaces.Range {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getElementById
pub fn call_getElementById(instance: *runtime.Instance, elementId: runtime.DOMString) ImplError!interfaces.Element {
    _ = instance;
    _ = elementId;
    return error.NotImplemented;
}

/// Operation: createAttributeNS
pub fn call_createAttributeNS(instance: *runtime.Instance, namespace: runtime.DOMString, qualifiedName: runtime.DOMString) ImplError!interfaces.Attr {
    _ = instance;
    _ = namespace;
    _ = qualifiedName;
    return error.NotImplemented;
}

/// Operation: hasFocus
pub fn call_hasFocus(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: exitFullscreen
pub fn call_exitFullscreen(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: adoptNode
pub fn call_adoptNode(instance: *runtime.Instance, node: interfaces.Node) ImplError!interfaces.Node {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: createTextNode
pub fn call_createTextNode(instance: *runtime.Instance, data: runtime.DOMString) ImplError!interfaces.Text {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: createTreeWalker
pub fn call_createTreeWalker(instance: *runtime.Instance, root: interfaces.Node, whatToShow: u32, filter: interfaces.NodeFilter) ImplError!interfaces.TreeWalker {
    _ = instance;
    _ = root;
    _ = whatToShow;
    _ = filter;
    return error.NotImplemented;
}

/// Operation: getElementsByName
pub fn call_getElementsByName(instance: *runtime.Instance, elementName: runtime.DOMString) ImplError!interfaces.NodeList {
    _ = instance;
    _ = elementName;
    return error.NotImplemented;
}

/// Operation: writeln
pub fn call_writeln(instance: *runtime.Instance, text: *const anyopaque) ImplError!void {
    _ = instance;
    _ = text;
    return error.NotImplemented;
}

/// Operation: append
pub fn call_append(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: moveBefore
pub fn call_moveBefore(instance: *runtime.Instance, node: interfaces.Node, child: interfaces.Node) ImplError!void {
    _ = instance;
    _ = node;
    _ = child;
    return error.NotImplemented;
}

/// Operation: convertRectFromNode
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: interfaces.DOMRectReadOnly, from: typedefs.GeometryNode, options: dictionaries.ConvertCoordinateOptions) ImplError!interfaces.DOMQuad {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    return error.NotImplemented;
}

/// Operation: queryCommandValue
pub fn call_queryCommandValue(instance: *runtime.Instance, commandId: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = commandId;
    return error.NotImplemented;
}

/// Operation: caretPositionFromPoint
pub fn call_caretPositionFromPoint(instance: *runtime.Instance, x: f64, y: f64, options: dictionaries.CaretPositionFromPointOptions) ImplError!interfaces.CaretPosition {
    _ = instance;
    _ = x;
    _ = y;
    _ = options;
    return error.NotImplemented;
}

/// Operation: startViewTransition
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: *const anyopaque) ImplError!interfaces.ViewTransition {
    _ = instance;
    _ = callbackOptions;
    return error.NotImplemented;
}

/// Operation: createComment
pub fn call_createComment(instance: *runtime.Instance, data: runtime.DOMString) ImplError!interfaces.Comment {
    _ = instance;
    _ = data;
    return error.NotImplemented;
}

/// Operation: createDocumentFragment
pub fn call_createDocumentFragment(instance: *runtime.Instance) ImplError!interfaces.DocumentFragment {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getSelection
pub fn call_getSelection(instance: *runtime.Instance) ImplError!interfaces.Selection {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: requestStorageAccess
pub fn call_requestStorageAccess(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createElementNS
pub fn call_createElementNS(instance: *runtime.Instance, namespace: runtime.DOMString, qualifiedName: runtime.DOMString, options: *const anyopaque) ImplError!interfaces.Element {
    _ = instance;
    _ = namespace;
    _ = qualifiedName;
    _ = options;
    return error.NotImplemented;
}

/// Operation: captureEvents
pub fn call_captureEvents(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: querySelectorAll
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!interfaces.NodeList {
    _ = instance;
    _ = selectors;
    return error.NotImplemented;
}

/// Operation: browsingTopics
pub fn call_browsingTopics(instance: *runtime.Instance, options: dictionaries.BrowsingTopicsOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: createNSResolver
pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: interfaces.Node) ImplError!interfaces.Node {
    _ = instance;
    _ = nodeResolver;
    return error.NotImplemented;
}

/// Operation: createNodeIterator
pub fn call_createNodeIterator(instance: *runtime.Instance, root: interfaces.Node, whatToShow: u32, filter: interfaces.NodeFilter) ImplError!interfaces.NodeIterator {
    _ = instance;
    _ = root;
    _ = whatToShow;
    _ = filter;
    return error.NotImplemented;
}

/// Operation: measureText
pub fn call_measureText(instance: *runtime.Instance, text: runtime.DOMString, styleMap: interfaces.StylePropertyMapReadOnly) ImplError!interfaces.FontMetrics {
    _ = instance;
    _ = text;
    _ = styleMap;
    return error.NotImplemented;
}

