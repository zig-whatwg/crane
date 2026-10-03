# Spec Compliance: An internal dictionary can still expose prototype getters

**Date**: 2026-10-02
**Lesson**: When an algorithm creates a dictionary and feeds its ECMAScript representation back into dictionary conversion, preserve the ordinary object's prototype and observable getters.

**Why**: Knowing the newly created dictionary's own members does not prove which members a subsequent JavaScript Get will find. WebIDL dictionary conversion searches the prototype chain.

**What Happened**: WebCrypto's string normalization shortcut looked up the algorithm name and treated every other parameter as absent. The full §18.4.4 algorithm creates an Algorithm dictionary and normalizes it again. WebKit's normalizeCryptoAlgorithmParameters constructs an ordinary object and recurses. New Crane tests showed that inherited length/hash getters were skipped and their thrown values were replaced with TypeError.

**Fix**: Use the engine protocol to construct the ordinary dictionary object in the current realm, with its own name property, and run the existing object normalization path. Release the temporary owned value after the synchronous conversions. The inherited-member and exact-exception tests then pass. This also let a string RSA input reach and expose a separate output-member ordering bug.

**Takeaway**: **An internal value's conversion can make prototypes observable; a native shortcut must preserve those effects.**
