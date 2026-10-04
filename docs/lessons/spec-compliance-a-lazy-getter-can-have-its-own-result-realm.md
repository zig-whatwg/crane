# Spec Compliance: A lazy getter can have its own result realm

**Date**: 2026-10-03
**Lesson**: Follow each allocation algorithm separately: a platform object's realm, an operation's result realm, and a lazy getter's realm can differ.

**Why**: Capturing a realm for one algorithm does not make it the realm of every value later observed on the result. A getter can run its own conversion algorithm, then cache the converted object.

**What Happened**: IndexedDB cursor iteration takes a target realm for StructuredDeserialize of the record value. It stores native keys separately. The key and primaryKey getters invoke “convert a key to a value,” which has no target-realm parameter and creates objects in the getter's current realm. Applying the iteration realm to the keys would make a normal getter return the wrong Array prototype after a borrowed foreign continue(). Conversely, always using the cursor's realm fails when the first getter itself is borrowed from a foreign realm. An initial interpretation conflated those cases; the fixture expectations were corrected before changing either getter.

**Fix**: Read the complete chain of algorithms: IndexedDB 4.9 getters, 6.7 iteration, and 7.3 key conversion. Test a foreign iteration with a normal getter separately from a foreign getter's first read. Keep the converted key's identity until it changes, using a traced slot and a separately saved Context whose liveness is checked before returning the cached value. Keep the value's iteration realm independent. WebKit's [JSIDBCursor key getters](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/bindings/js/JSIDBCursorCustom.cpp#L34-L46) use their lexical global object; Blink's [key getters](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/modules/indexeddb/idb_cursor.cc#L304-L324) use their ScriptState. These are design references, not copied code.

**Takeaway**: **A borrowed method does not borrow a later getter; identify the allocation step that actually creates each observable object.**
