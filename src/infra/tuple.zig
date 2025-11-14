//! WHATWG Infra Tuple Operations
//!
//! Spec: https://infra.spec.whatwg.org/#tuple
//!
//! A tuple is a finite ordered sequence of items. In Zig, Infra tuples
//! map to anonymous structs (Zig tuples) with indexed fields.
//!
//! # Design
//!
//! Infra tuples are compile-time defined types in Zig. The spec describes
//! tuples as "a finite ordered list of items", which maps naturally to
//! Zig's tuple type system (anonymous structs).
//!
//! # Usage
//!
//! ```zig
//! // Define a tuple (anonymous struct)
//! const tuple = .{ "hello", 42, true };
//!
//! // Access by index
//! const first = tuple[0];   // "hello"
//! const second = tuple[1];  // 42
//! const third = tuple[2];   // true
//!
//! // Type-safe tuples
//! const typed_tuple: struct { []const u8, u32, bool } = .{ "world", 100, false };
//! ```
//!
//! # Note
//!
//! Since Infra tuples map directly to Zig tuples (anonymous structs),
//! there's no need for additional wrapper types. This module exists
//! primarily for documentation and to provide helper utilities if needed.

const std = @import("std");








