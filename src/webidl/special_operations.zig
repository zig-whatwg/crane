//! WebIDL 2.5.6 special operations, as codegen records them for the binding.
//!
//! An interface that declares (or inherits) an indexed or named property
//! getter, setter or deleter is a legacy platform object (WebIDL 3.9), and the
//! engine adapter installs its exotic internal methods from this table, which
//! codegen writes into the interface's Meta:
//!
//!     pub const special_operations: webidl.SpecialOperations = .{
//!         .named_getter = .{ .function = "call_getItem" },
//!         .named_setter = .{ .function = "call_setItem" },
//!         .named_deleter = .{ .function = "call_removeItem" },
//!     };
//!
//! An interface with none has no `special_operations` at all. Each entry
//! names the generated function that runs the operation - `call_<identifier>`
//! for one declared with an identifier (WebIDL 2.5.6: "equivalent to
//! separating the special operation out into its own declaration without an
//! identifier"; it is also a regular operation), and for an anonymous one
//! `call_<keyword>`, numbered `call_<keyword>__<k>` when an interface declares
//! more than one anonymous operation of that keyword (HTMLFormElement's
//! indexed and named getters). The names are the binding map's own; this
//! table only says which of them is special, and of what variety.

/// One special operation: the generated function that implements it.
pub const Operation = struct {
    /// The generated interface's function: `call_item`, `call_getItem`,
    /// `call_getter`, `call_getter__1`.
    function: []const u8,
    /// Whether the impl implements it. A special operation declared with an
    /// identifier is a regular operation the impl always has; an anonymous
    /// one's delegate is gated - it answers error.NotImplemented until the
    /// impl declares it - and this is the impl's `@hasDecl`, so the binding
    /// installs nothing through a function that cannot run.
    implemented: bool = true,
};

/// An interface's special operations - its own and those it inherits, the
/// derived-most of each (WebIDL 3.9: "The indexed property getter that is
/// defined on the derived-most interface that the legacy platform object
/// implements is the one that defines the behavior") - and the extended
/// attributes that change how its named properties behave.
pub const SpecialOperations = struct {
    /// `getter T (unsigned long index)` (2.5.6.1).
    indexed_getter: ?Operation = null,
    /// `setter undefined (unsigned long index, T value)` (2.5.6.1).
    indexed_setter: ?Operation = null,
    /// `getter T (DOMString name)` (2.5.6.2).
    named_getter: ?Operation = null,
    /// `setter undefined (DOMString name, T value)` (2.5.6.2).
    named_setter: ?Operation = null,
    /// `deleter undefined (DOMString name)` (2.5.6.2).
    named_deleter: ?Operation = null,
    /// [LegacyOverrideBuiltIns] (3.4.7) on the interface or an ancestor:
    /// named properties shadow the prototype chain.
    legacy_override_built_ins: bool = false,
    /// [LegacyUnenumerableNamedProperties] (3.4.9) on the interface or an
    /// ancestor ("it applies to all its derived interfaces"): named
    /// properties are not enumerable.
    legacy_unenumerable_named_properties: bool = false,
    /// [[OwnPropertyKeys]] (3.9.6) step 3 lists the visible supported property
    /// names - the default, the spec's. False for the browsers' exception
    /// (AGENTS.md golden rule 2), recorded by codegen: HTMLFormElement, whose
    /// names every browser leaves out of `Object.getOwnPropertyNames` while
    /// named lookup finds them (whatwg/html#1731; Blink's `[NotEnumerable]`
    /// named getter, bind_gen installing no named enumerator). Lookup still
    /// reads the supported property names; only the key list leaves them out.
    named_properties_in_own_keys: bool = true,
    /// The named getter and setter are Crane's, not the IDL's: they stand in
    /// for CSSOM's camel-cased attributes of a CSS declaration interface
    /// (CSSOM 6.7.1, `_camel_cased_attribute`; codegen's
    /// writeCSSPropertyNamedHandlers). Assignment reaches them as it would an
    /// attribute's setter - through the prototype chain - never as WebIDL
    /// 3.9.2 [[Set]] step 1.2's named setter, which takes every string first
    /// (`style.cssText = ...` is the prototype's accessor).
    crane_css_properties: bool = false,
};
