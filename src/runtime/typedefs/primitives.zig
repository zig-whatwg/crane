//! WebIDL primitive type aliases
//!
//! These type aliases provide clear names for WebIDL primitive types
//! and ensure consistent usage throughout the codebase.

/// WebIDL boolean type
pub const Boolean = bool;

/// WebIDL byte type (signed 8-bit integer)
pub const Byte = i8;

/// WebIDL octet type (unsigned 8-bit integer)
pub const Octet = u8;

/// WebIDL short type (signed 16-bit integer)
pub const Short = i16;

/// WebIDL unsigned short type (unsigned 16-bit integer)
pub const UnsignedShort = u16;

/// WebIDL long type (signed 32-bit integer)
pub const Long = i32;

/// WebIDL unsigned long type (unsigned 32-bit integer)
pub const UnsignedLong = u32;

/// WebIDL long long type (signed 64-bit integer)
pub const LongLong = i64;

/// WebIDL unsigned long long type (unsigned 64-bit integer)
pub const UnsignedLongLong = u64;

/// WebIDL float type (32-bit floating point)
pub const Float = f32;

/// WebIDL double type (64-bit floating point)
pub const Double = f64;

/// WebIDL unrestricted float type (allows NaN and Infinity)
pub const UnrestrictedFloat = f32;

/// WebIDL unrestricted double type (allows NaN and Infinity)
pub const UnrestrictedDouble = f64;

/// WebIDL 'any' type - type-erased value
/// Note: Actual implementation would need runtime type tagging
pub const Any = *anyopaque;

/// WebIDL 'object' type - opaque object reference
pub const Object = *anyopaque;
