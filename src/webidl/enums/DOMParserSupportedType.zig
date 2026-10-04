//! WebIDL enum: DOMParserSupportedType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const DOMParserSupportedType = enum {
    _text_html_,
    _text_xml_,
    _application_xml_,
    _application_xhtml_xml_,
    _image_svg_xml_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "text/html", "text/xml", "application/xml", "application/xhtml+xml", "image/svg+xml" };
};
