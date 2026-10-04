# Debugging: A V8 deserialization runs no script - not even to make its exception

**Date**: 2026-10-04
**Lesson**: Inside V8's ValueDeserializer (ReadHostObject and everything it calls) any JavaScript execution is a V8 FATAL, and constructing a DOMException through its JavaScript constructor is JavaScript execution.

**Why**: `ValueDeserializer::ReadObject` holds a `DisallowJavascriptExecutionScope` (jsengines/v8/v8/src/objects/value-serializer.cc). The serializer's delegate made its "DataCloneError" by looking up the global `DOMException` and calling `NewInstance` - which runs the binding's constructor callback, and Crane's runs a script to capture the exception's stack (`interface.zig` captureDOMExceptionStack). While SERIALIZING that is fine (serialization runs getters); while DESERIALIZING the first failure aborts the process: "Fatal error ... Invoke in DisallowJavascriptExecutionScope".

**What Happened**: The [Serializable] batch made ReadHostObject call the host's deserialization steps and, on an unknown interface or a malformed record, throw the same DataCloneError the serializer throws. Every round trip passed; tests/v8/serializable_objects_test.zig's case that renames a record's [[Type]] crashed the test binary with SIGTRAP. In WPT the same path is reached by any message that fails to deserialize (a CryptoKey posted to an insecure context: webmessaging/postMessage_CryptoKey_insecure) - a whole-runner crash, not a messageerror.

**Fix**: The read path throws an `Exception::Error` that V8's factory makes without running script (`v8_ThrowDeserializationError`). That is enough: every caller of a deserialization holds a TryCatch and reports the failure itself - the binding throws the DataCloneError DOMException after V8 returns, a message port fires messageerror. `v8_ThrowDataCloneError` stays for the write path only, and says so.

**Takeaway**: **Anything a V8 deserializer delegate calls - steps, wrapper creation, error reporting - must run no script; report a failure with an exception V8 makes itself, and let the caller turn it into the DOMException once V8 has returned.**
