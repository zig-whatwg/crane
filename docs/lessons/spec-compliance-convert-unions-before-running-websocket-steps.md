# Spec Compliance: Convert unions before running WebSocket steps

**Date**: 2026-10-14
**Lesson**: A WebIDL union passed to an impl as JSValue still has to be converted before that API's algorithm starts.

**Why**: Conversion can run script. Its exception and side effects happen before constructor validation or an operation's first step. Checking the API's state first changes observable behavior even when every step inside the API algorithm looks correct.

**What Happened**: WebSocket parsed its URL before converting the protocols argument, and send checked CONNECTING before converting its data. A throwing protocol toString lost to the URL's SyntaxError; send lost the original exception to InvalidStateError and never ran a toString that called close. The local number formatter also counted 22 bytes for 1e21 instead of ECMAScript's five-byte "1e+21". A primitive BigInt was also mistaken for an object because it arrived as a handle, so the sequence converter threw TypeError. Isolated Crane tests reproduced each defect on the frozen base.

**Fix**: Convert protocol strings first, then run URL validation and token/duplicate validation in their specified order. Convert send's data before reading readyState. Use the existing engine string-conversion operations for numbers, and inspect the value type before probing a handle for an iterator. Keep temporary allocations owned until validation succeeds, then transfer them to the connection's existing owner.

The shared sequence converter still collects every iterator result before stringifying its items. Its per-item ordering regression remains an adapter follow-up; moving the WebSocket call does not fix that separate algorithm.

WebIDL §3.2.25 and the WebSockets constructor/send algorithms define the order. Blink's DOMWebSocket::Create converts the union before Connect, and its send overloads receive already-converted values: https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/modules/websockets/dom_websocket.cc . WebKit's WebSocket::create likewise takes a Vector<String> and its send methods take converted arguments: https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/websockets/WebSocket.cpp .

**Takeaway**: **Test conversion exceptions and side effects before testing the API's state or validation steps; JSValue is a representation, not proof that WebIDL conversion already happened.**
