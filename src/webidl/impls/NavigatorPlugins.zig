//! HTML 8.9.1.6 "PDF viewing support": the NavigatorPlugins mixin, on a
//! Window's Navigator. Its plugins and mimeTypes attributes are [SameObject]
//! (the generated Navigator caches what these getters make): "Each
//! NavigatorPlugins object has a plugins array, which is a new PluginArray,
//! and a mime types array, which is a new MimeTypeArray."
//!
//! The user agent's PDF viewer supported is the compiled-in platform's
//! `pdf_viewer` capability (html_core.navigator.pdf_viewer): on in Crane's
//! default platforms (the user, 2026-11-14), as in Chrome, Firefox and Safari.
//!
//! Spec: https://html.spec.whatwg.org/multipage/system-state.html#pdf-viewing-support

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const pdf_viewer = @import("html_core").navigator.pdf_viewer;

pub const State = interfaces.NavigatorPlugins.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// "The NavigatorPlugins mixin's plugins getter steps are to return this's
/// plugins array" - made here once; the generated getter keeps it.
pub fn get_plugins(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.PluginArray.init(instance.ctx.allocator, instance.ctx);
}

/// "The NavigatorPlugins mixin's mimeTypes getter steps are to return this's
/// mime types array" - made here once; the generated getter keeps it.
pub fn get_mimeTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.MimeTypeArray.init(instance.ctx.allocator, instance.ctx);
}

/// "The NavigatorPlugins mixin's pdfViewerEnabled getter steps are to return
/// the user agent's PDF viewer supported."
pub fn get_pdfViewerEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return pdf_viewer.supported();
}

/// "The NavigatorPlugins mixin's javaEnabled() method steps are to return
/// false."
pub fn call_javaEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return false;
}
