//! The Streams interfaces' members are bound to their impls.
//!
//! Each check takes the address of a generated interface member. That
//! analyses the member's body, which calls the impl's function of the same
//! name - or, for init and deinit, runs the generated construction and
//! destruction chains through the impl's own steps - so an impl that loses a
//! member, or changes its signature, fails to compile here. Tests reach an
//! impl only through its interface (AGENTS.md "The impls boundary").
//!
//! Here, not in tests/streams/: emitting those bodies links the engine, and
//! tests/streams is built without V8. Nothing here runs: no isolate is made
//! and no per-thread state is touched, so sharing this directory's
//! executable changes nothing for the other files in it.

const interfaces = @import("interfaces");

test "Streams: ReadableStream's members reach its impl" {
    // The abstract operations live in streams_readable.zig, behind the
    // interface; pipeTo, pipeThrough, tee and from are the members that reach them.
    _ = &interfaces.ReadableStream.init;
    _ = &interfaces.ReadableStream.deinit;
    _ = &interfaces.ReadableStream.call_constructor;
    _ = &interfaces.ReadableStream.get_locked;
    _ = &interfaces.ReadableStream.call_cancel;
    _ = &interfaces.ReadableStream.call_getReader;
    _ = &interfaces.ReadableStream.call_pipeTo;
    _ = &interfaces.ReadableStream.call_pipeThrough;
    _ = &interfaces.ReadableStream.call_tee;
    _ = &interfaces.ReadableStream.call_static_from;
}

test "Streams: ReadableStreamDefaultController's members reach its impl" {
    _ = &interfaces.ReadableStreamDefaultController.init;
    _ = &interfaces.ReadableStreamDefaultController.deinit;
    _ = &interfaces.ReadableStreamDefaultController.get_desiredSize;
    _ = &interfaces.ReadableStreamDefaultController.call_close;
    _ = &interfaces.ReadableStreamDefaultController.call_enqueue;
    _ = &interfaces.ReadableStreamDefaultController.call_error;
}

test "Streams: ReadableByteStreamController's members reach its impl" {
    _ = &interfaces.ReadableByteStreamController.init;
    _ = &interfaces.ReadableByteStreamController.deinit;
    _ = &interfaces.ReadableByteStreamController.get_desiredSize;
    _ = &interfaces.ReadableByteStreamController.call_close;
    _ = &interfaces.ReadableByteStreamController.call_enqueue;
    _ = &interfaces.ReadableByteStreamController.call_error;
    _ = &interfaces.ReadableByteStreamController.get_byobRequest;
}

test "Streams: WritableStream's members reach its impl" {
    _ = &interfaces.WritableStream.init;
    _ = &interfaces.WritableStream.deinit;
    _ = &interfaces.WritableStream.call_constructor;
    _ = &interfaces.WritableStream.get_locked;
    _ = &interfaces.WritableStream.call_abort;
    _ = &interfaces.WritableStream.call_close;
    _ = &interfaces.WritableStream.call_getWriter;
}

test "Streams: WritableStreamDefaultController's members reach its impl" {
    // get_desiredSize: not in WritableStreamDefaultController's IDL.
    _ = &interfaces.WritableStreamDefaultController.init;
    _ = &interfaces.WritableStreamDefaultController.deinit;
    _ = &interfaces.WritableStreamDefaultController.call_error;
}

test "Streams: TransformStream's members reach its impl" {
    _ = &interfaces.TransformStream.init;
    _ = &interfaces.TransformStream.deinit;
    _ = &interfaces.TransformStream.call_constructor;
    _ = &interfaces.TransformStream.get_readable;
    _ = &interfaces.TransformStream.get_writable;
}

test "Streams: TransformStreamDefaultController's members reach its impl" {
    _ = &interfaces.TransformStreamDefaultController.init;
    _ = &interfaces.TransformStreamDefaultController.deinit;
    _ = &interfaces.TransformStreamDefaultController.get_desiredSize;
    _ = &interfaces.TransformStreamDefaultController.call_enqueue;
    _ = &interfaces.TransformStreamDefaultController.call_error;
    _ = &interfaces.TransformStreamDefaultController.call_terminate;
}

test "Streams: ReadableStreamDefaultReader's members reach its impl" {
    _ = &interfaces.ReadableStreamDefaultReader.call_read;
    _ = &interfaces.ReadableStreamDefaultReader.call_releaseLock;
}

test "Streams: ReadableStreamBYOBReader's members reach its impl" {
    _ = &interfaces.ReadableStreamBYOBReader.call_read;
    _ = &interfaces.ReadableStreamBYOBReader.call_releaseLock;
}

test "Streams: ReadableStreamGenericReader's members reach its impl" {
    // The mixin both readers include (closed, cancel()), bound to its own impl.
    _ = &interfaces.ReadableStreamGenericReader.get_closed;
    _ = &interfaces.ReadableStreamGenericReader.call_cancel;
}

test "Streams: WritableStreamDefaultWriter's members reach its impl" {
    _ = &interfaces.WritableStreamDefaultWriter.call_write;
    _ = &interfaces.WritableStreamDefaultWriter.call_close;
    _ = &interfaces.WritableStreamDefaultWriter.call_abort;
    _ = &interfaces.WritableStreamDefaultWriter.call_releaseLock;
    _ = &interfaces.WritableStreamDefaultWriter.get_desiredSize;
}
