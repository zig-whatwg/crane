# Spec Compliance: A Dictionary Forwarder Must Preserve Its Receiver

**Date**: 2026-10-21
**Lesson**: Adapting a dictionary member by inheriting from the caller's object changes the receiver of every inherited getter.

**Why**: WebIDL dictionary conversion (§3.2.17, step 4.1.3.1) calls `Get(jsDict, key)`. JavaScript property lookup through another object's prototype chain invokes an accessor with that other object as `this`.

**What Happened**: Crane's V8 13.1 address adapter translated the newer `address` member to the older `index` spelling by constructing an object whose prototype was the supplied descriptor. Memory and Table constructors then read `initial` through that object. An accessor checking `this === descriptor` failed in Window and worker realms; the six BASE cases in `crane/wj1-descriptor-receiver.any.js` all failed. Ordinary data properties had hidden the defect.

**Fix**: Read and convert `address` on the original descriptor. Use an empty private proxy target and a strict JavaScript `get` trap that returns the translated address for `index` and forwards every other read with captured `Reflect.get(original, key, original)`. The target must not be the original descriptor: a nonconfigurable user `index` property would otherwise impose a proxy invariant on a name that is not a dictionary member. A proxy shared by synchronous constructors must save and restore its current descriptor in `finally`, so nested constructors and thrown getters preserve the outer call. Leave the native constructor responsible for the other conversions and their order.

**Takeaway**: **A property-forwarding adapter must preserve both the lookup target and the getter receiver; matching property values alone is insufficient.**
