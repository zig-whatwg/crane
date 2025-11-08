//! Single-Byte Encodings Module
//!
//! WHATWG Encoding Standard § 9
//! https://encoding.spec.whatwg.org/#legacy-single-byte-encodings
//!
//! All 28 single-byte encodings share the same decoder/encoder logic,
//! differing only in their index tables.

pub const index_generator = @import("single_byte/index_generator.zig");
pub const decoder = @import("single_byte/decoder.zig");
pub const encoder = @import("single_byte/encoder.zig");

// Encoding-specific indexes (all 28 single-byte encodings)
pub const ibm866 = @import("single_byte/ibm866.zig");
pub const iso_8859_2 = @import("single_byte/iso_8859_2.zig");
pub const iso_8859_3 = @import("single_byte/iso_8859_3.zig");
pub const iso_8859_4 = @import("single_byte/iso_8859_4.zig");
pub const iso_8859_5 = @import("single_byte/iso_8859_5.zig");
pub const iso_8859_6 = @import("single_byte/iso_8859_6.zig");
pub const iso_8859_7 = @import("single_byte/iso_8859_7.zig");
pub const iso_8859_8 = @import("single_byte/iso_8859_8.zig");
pub const iso_8859_8_i = @import("single_byte/iso_8859_8_i.zig");
pub const iso_8859_10 = @import("single_byte/iso_8859_10.zig");
pub const iso_8859_13 = @import("single_byte/iso_8859_13.zig");
pub const iso_8859_14 = @import("single_byte/iso_8859_14.zig");
pub const iso_8859_15 = @import("single_byte/iso_8859_15.zig");
pub const iso_8859_16 = @import("single_byte/iso_8859_16.zig");
pub const koi8_r = @import("single_byte/koi8_r.zig");
pub const koi8_u = @import("single_byte/koi8_u.zig");
pub const macintosh = @import("single_byte/macintosh.zig");
pub const windows_874 = @import("single_byte/windows_874.zig");
pub const windows_1250 = @import("single_byte/windows_1250.zig");
pub const windows_1251 = @import("single_byte/windows_1251.zig");
pub const windows_1252 = @import("single_byte/windows_1252.zig");
pub const windows_1253 = @import("single_byte/windows_1253.zig");
pub const windows_1254 = @import("single_byte/windows_1254.zig");
pub const windows_1255 = @import("single_byte/windows_1255.zig");
pub const windows_1256 = @import("single_byte/windows_1256.zig");
pub const windows_1257 = @import("single_byte/windows_1257.zig");
pub const windows_1258 = @import("single_byte/windows_1258.zig");
pub const x_mac_cyrillic = @import("single_byte/x_mac_cyrillic.zig");

// Re-export main types
pub const Index = index_generator.Index;
pub const parseIndex = index_generator.parseIndex;
pub const decode = decoder.decode;
pub const encode = encoder.encode;
