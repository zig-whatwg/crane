//! WebIDL typedef: LanguageModelMessageValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const LanguageModelMessageValue = union(enum) {
    image_bitmap_source: typedefs.ImageBitmapSource,
    audio_buffer: *runtime.Instance,
    buffer_source: typedefs.BufferSource,
    domstring: runtime.DOMString,
};
