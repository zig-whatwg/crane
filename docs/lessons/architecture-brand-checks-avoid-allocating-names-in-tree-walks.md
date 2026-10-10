# Architecture: Brand checks avoid allocating names in tree walks

**Date**: 2026-10-09
**Lesson**: Use an interface brand when a tree algorithm needs an HTML element kind; a localName getter can allocate even when its caller only compares the result.

**Why**: A select option-list walk runs again for each option's selectedness read. Cloning each visited node's local name turns an already repeated walk into quadratic allocation traffic. A name alone also ignores namespaces.

**What Happened**: Row 9 shared the option-list algorithm through forms/options.zig and called isElementNamed up to five times per visited element. Its Element.localName getter returned an owned copy. The review found the allocation and foreign-namespace errors; the generic node benchmarks contained no selects and missed this cost.

**Fix**: Check stateAs against the HTML interfaces, including ancestor optgroups. Native tests run the walk with an exhausted allocator and through a foreign option's subtree. A script test pins foreign-namespace behavior, and a separate scratch probe measures 1,000 options read 100 times against BASE before committing.

**Fixture trap**: A bare native Document starts as XML. Use createElementNS with the HTML namespace when constructing HTML controls in a native test; createElement on that document does not exercise an HTML interface brand.

**Takeaway**: **Borrow a type fact instead of allocating an API string, and benchmark the repeated caller of a shared walk.**
