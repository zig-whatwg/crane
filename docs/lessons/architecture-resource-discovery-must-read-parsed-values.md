# Architecture: Resource discovery must read parsed values

**Date**: 2026-10-24
**Lesson**: When a value changes representation, update the resource-interest prefilter as well as the resource consumer.

**Why**: A parsed stylesheet can release its source text. A prefilter that recognizes only the old value representation can then prevent an otherwise capable loader from seeing resources introduced through CSSOM.

**What Happened**: Background images became typed layers and image graphs. The resource selector could read their text and URL records, but the parsed-rule interest check still recognized only text and generated content. Editing a resource-free parsed rule to contain two background URL layers left both images unfetched.

**Fix**: Query the typed value's existing resource URL records in the interest check. Keep candidate selection and fetching in their existing consumers. Native tests cover scalar URLs, layers, image-set, light-dark, resource-free values, retained source metadata and allocation failures; a CSSOM test observes the two newly introduced resource requests.

**Takeaway**: **A representation migration must preserve discovery paths before the final consumer, and a resource test must observe the request.**
