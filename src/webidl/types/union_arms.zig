//! What each member type of a generated union is, as codegen tells the
//! binding (lane bind1 batch B).
//!
//! WebIDL 3.2.25 converts a JavaScript value to a union by asking questions
//! of the union's flattened member types - "if types includes an interface
//! type that V implements", "if types includes a sequence type", "if types
//! includes a string type" - in a fixed order. The Zig type of a generated
//! union cannot answer them: every interface type is `*runtime.Instance`,
//! `object`, `bigint` and the typed arrays are all `runtime.JSValue`, and a
//! dictionary and a callback value are both structs. So codegen writes the
//! answer beside the union: `pub const arms`, one `Arm` per field, naming the
//! field and its member type's kind, and the binding's union conversion reads
//! only that - never a Zig type's shape, never an arm's name.
//!
//! ```zig
//! pub const NodeOrString = union(enum) {
//!     node: *runtime.Instance,
//!     domstring: runtime.DOMString,
//!     pub const arms = [_]webidl.UnionArm{
//!         .{ .field = "node", .kind = .{ .interface = "Node" } },
//!         .{ .field = "domstring", .kind = .string },
//!     };
//! };
//! ```

/// A union member type's kind - the categories 3.2.25's steps ask about
/// (WebIDL 2.13.32 "flattened member types"; 3.2.25 steps 4-19).
pub const Kind = union(enum) {
    /// An interface type, by its WebIDL name - a typedef of one resolved to
    /// it (WindowProxy is Window). Step 5.1: "an interface type that V
    /// implements".
    interface: []const u8,
    /// A callback function type (step 10.1).
    callback_function,
    /// A callback interface type (step 11.6).
    callback_interface,
    /// A dictionary type (steps 4.1 and 11.4).
    dictionary,
    /// A sequence type (step 11.2): its element type's interface, by name,
    /// when that is an interface type (each element converts to it, 3.2.15),
    /// else null.
    sequence: ?[]const u8,
    /// A frozen array type (step 11.3), its element interface as a
    /// sequence's.
    frozen_array: ?[]const u8,
    /// An async sequence type (step 11.1).
    async_sequence,
    /// A record type (step 11.5).
    record,
    /// `object` (steps 5.2, 6.2, 7.2, 8.2, 9.2, 10.2 and 11.7).
    object,
    /// `ArrayBuffer` (step 6.1).
    array_buffer,
    /// `SharedArrayBuffer` (step 7.1).
    shared_array_buffer,
    /// `DataView` (step 8.1).
    data_view,
    /// A typed array type, by its [[TypedArrayName]] - "Float32Array"
    /// (step 9.1).
    typed_array: []const u8,
    /// BufferSource, (ArrayBufferView or ArrayBuffer): its flattened member
    /// types are ArrayBuffer, DataView and the typed arrays (steps 6, 8 and
    /// 9), converted by webidl.buffer_sources.BufferSource's own rules.
    buffer_source,
    /// AllowSharedBufferSource, (ArrayBuffer or SharedArrayBuffer or
    /// [AllowShared] ArrayBufferView) (steps 6-9).
    allow_shared_buffer_source,
    /// ArrayBufferView, (DataView or the typed arrays) (steps 8 and 9).
    array_buffer_view,
    /// A string type: DOMString, USVString or ByteString (step 15).
    string,
    /// An enumeration type - WebIDL 2.13 counts every enumeration among the
    /// string types (step 15).
    enumeration,
    /// A numeric type (steps 13, 16 and 17).
    numeric,
    /// `bigint` (steps 14, 16 and 19).
    bigint,
    /// `boolean` (steps 12 and 18).
    boolean,
    /// `undefined` (step 1).
    undefined,
    /// A union typedef among the member types: the field's own type is a
    /// generated union with its own `arms`, whose member types are this
    /// union's too (2.13.32: the flattened member types include a member
    /// union's flattened member types).
    @"union",
};

/// One field of a generated union and the kind of member type it holds.
pub const Arm = struct {
    /// The union's field for this member type.
    field: []const u8,
    kind: Kind,
};
