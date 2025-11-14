//! WHATWG Infra Struct Operations
//!
//! Spec: https://infra.spec.whatwg.org/#struct
//!
//! A struct is a specification type with named fields. In Zig, Infra structs
//! map directly to Zig structs with named fields.
//!
//! # Design
//!
//! Infra structs are compile-time defined types in Zig. The spec describes
//! structs as "a specification type consisting of named fields", which maps
//! naturally to Zig's struct type system.
//!
//! # Usage
//!
//! ```zig
//! // Define an Infra struct
//! const Person = struct {
//!     name: []const u8,
//!     age: u32,
//! };
//!
//! // Create instance
//! const person = Person{
//!     .name = "Alice",
//!     .age = 30,
//! };
//!
//! // Access fields
//! const name = person.name;
//! const age = person.age;
//! ```
//!
//! # Note
//!
//! Since Infra structs map directly to Zig structs, there's no need for
//! additional wrapper types or operations. This module exists primarily
//! for documentation and to provide helper utilities if needed.

const std = @import("std");





