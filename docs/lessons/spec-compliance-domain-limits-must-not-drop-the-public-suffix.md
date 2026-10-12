# Spec compliance: A label limit must not discard the public suffix

**Date**: 2026-10-12
**Lesson**: Match a domain's rightmost labels directly. Truncating a hostname's label list can change its security boundary even when the hostname is within the DNS length limit.

**Why**: The public suffix determines the registrable domain used by cookies, agent clusters and navigation checks. Keeping a prefix of the labels loses exactly the part that determines that boundary.

**What Happened**: Cookie SameSite checks began using URL's shared PSL implementation. Its lookup split a host into 64 slots and stopped when they filled. Two hosts made from `x.` repeated 70 times followed by `a.example.com` or `b.example.com` were therefore treated as different sites: the helper lost `example.com` and returned no registrable domain. Both hosts were shorter than 253 bytes. The cookie regression failed, and native URL controls reproduced the loss for exact, private, wildcard, exception and unknown suffixes.

**Fix**:

1. Walk suffix slices from the right and keep the longest matching exact or wildcard rule; let an exception take precedence.
2. Return borrowed input slices internally. Keep the public APIs' owned return values unchanged.
3. Bound only the temporary rule key by the actual table's longest key, rather than bounding the input host or its label count.
4. Test many short labels as well as long serialized hosts, and cover private rules, wildcards, exceptions and trailing dots.

The design follows the [PSL formal algorithm](https://github.com/publicsuffix/list/wiki/Format#formal-algorithm). Chromium's [GetRegistryInTrimmedHost](https://github.com/chromium/chromium/blob/main/net/base/registry_controlled_domains/registry_controlled_domain.cc) also represents a matched registry as a slice of its input host.

**Takeaway**: **An implementation limit must not silently remove the part of an input that defines its security boundary.**
