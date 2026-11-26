//! Implementation for GetSVGDocument interface mixin.
//!
//! No interface in the pinned webref IDL set includes GetSVGDocument
//! (HTMLIFrameElement, HTMLObjectElement, and HTMLEmbedElement declare
//! `Document? getSVGDocument()` directly in html.idl), so this impl defines
//! no API-named functions.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const GetSVGDocument = interfaces.GetSVGDocument;

pub const State = GetSVGDocument.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};
