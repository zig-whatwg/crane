# Testing: A failed assertion can hide a later operation

**Date**: 2026-10-12
**Lesson**: Give independent API paths independent subtests when one path can fail before the other is reached.

**Why**: testharness assertions throw. A file can finish normally while never executing a later operation in a failing subtest, including an operation that would crash the engine.

**What Happened**: The form enumeration regression checked Object.getOwnPropertyNames and then Object.keys in one subtest. The first assertion failed because named properties were exposed in own-key enumeration. That prevented Object.keys from running. Lane bindlpo found that the latter call reached an adapter integer-versus-name CHECK once a form had both indexed and named getters. The isolated regression confirmed it: BASE bbedc4deaf failed normally (0/1), while the feature at f72460eccd crashed with `Check failed: IsName(*element)` and signal TRAP.

**Fix**: Add an independent one-assertion Object.keys(form) regression with a named input. Record its isolated result before and after the binding fix. Keep the whole-file enumeration test as well; neither an OK harness nor a list of failing subtest names proves every operation in a test ran.

**Takeaway**: **Coverage follows executed operations, not assertions written below an earlier failure.**
