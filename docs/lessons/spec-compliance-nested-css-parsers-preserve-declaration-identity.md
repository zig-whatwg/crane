# Spec Compliance: Nested CSS parsers preserve declaration identity

**Date**: 2026-10-25
**Lesson**: A nested value grammar must borrow the original declaration's random scope and source slice instead of parsing its substring without context.

**Why**: CSS Values5 §9.4.1 derives omitted and automatic random keys from the containing property and the function's position in the whole declaration. The math owner already indexes those functions before parsing nested grammars. Replacing that scope, losing it, or copying the substring changes which declaration occurrence a nested function denotes.

**What Happened**: Generated content accepted a plain gradient and gradients with fixed or named random keys, but rejected omitted, automatic and property-dependent keys. The ordinary numeric-property control passed. Content's image parser forwarded its resource source but dropped the declaration's random scope, so the failure depended on the key form rather than the image grammar. The same issue affected nested image-set values and retries in radial-gradient parsing.

**Fix**: Forward the existing borrowed ParseScope through the content parser's stack-local state and its image ParseOptions. Preserve the original-buffer substring and the existing rewind behavior. Keep context-free parser wrappers passing null. Retained values own their normalized keys and never retain the borrowed scope. Pin caller-supplied offsets, ordinals across multiple nested functions, comments and strings, parser retries, destruction of all source owners, and allocation-failure cleanup.

**Takeaway**: **Context belongs to the declaration; nested grammar boundaries must forward it without inventing a new identity.**
