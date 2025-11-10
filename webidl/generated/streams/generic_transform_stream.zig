//! GenericTransformStream mixin per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#gts-mixin
//!
//! This mixin is intended for use by OTHER SPECIFICATIONS (like CompressionStream,
//! TextDecoderStream) to create custom transform stream classes without directly
//! subclassing TransformStream.
//!
//! IDL:
//! ```webidl
//! interface mixin GenericTransformStream {
//!   readonly attribute ReadableStream readable;
//!   readonly attribute WritableStream writable;
//! };
//! ```
//!
//! NOTE: This mixin is NOT included by TransformStream itself. It's for external
//! specifications to use when they want to create custom transform streams with
//! their own interface names and behaviors.

const std = @import("std");
const webidl = @import("webidl");

const ReadableStream = @import("readable_stream").ReadableStream;
const WritableStream = @import("writable_stream").WritableStream;
const TransformStream = @import("transform_stream").TransformStream;

/// GenericTransformStream mixin
///
/// This mixin provides the standard readable/writable property pair for
/// transform streams. Any platform object that includes this mixin has an
/// associated [[transform]] internal slot containing an actual TransformStream.
///
/// Usage pattern (in another spec):
/// ```zig
/// pub const CompressionStream = webidl.interface(struct {
///     mixin: GenericTransformStream,
///
///     // Custom constructor and methods...
/// });
/// ```
pub const GenericTransformStream = webidl.mixin(struct {
    /// [[transform]]: The actual TransformStream backing this object
    ///
    /// Spec: "Any platform object that includes the GenericTransformStream
    /// mixin has an associated transform, which is an actual TransformStream."
    transform: *TransformStream,

    // ============================================================================
    // WebIDL Mixin Methods
    // ============================================================================

    /// readable attribute getter
    ///
    /// IDL: readonly attribute ReadableStream readable;
    ///
    /// Spec: § 6.4.3.3 "The readable getter steps are to return
    /// this's transform.[[readable]]."
    pub fn readable(self: *const GenericTransformStream) *ReadableStream {
        return self.transform.readableStream;
    }

    /// writable attribute getter
    ///
    /// IDL: readonly attribute WritableStream writable;
    ///
    /// Spec: § 6.4.3.3 "The writable getter steps are to return
    /// this's transform.[[writable]]."
    pub fn writable(self: *const GenericTransformStream) *WritableStream {
        return self.transform.writableStream;
    }
});
