## Goals

- Deduplicate boilerplate in standards.

- Align standards on conventions, terminology, and data structures.

- Be a place for concepts used by multiple standards without a good home.

- Help write clear and readable algorithmic prose by clarifying otherwise ambiguous concepts.

Suggestions for more goals welcome.


## Usage

To make use of this standard in a document titled X, use:

X depends on Infra. [[Infra]](#biblio-infra "Infra Standard")

Additionally, cross-referencing all terminology is strongly encouraged to avoid ambiguity.


## Conventions


### Conformance

All assertions, diagrams, examples, and notes are non-normative, as are all sections explicitly marked non-normative. Everything else is normative.

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" are to be interpreted as described in RFC 2119. [RFC2119]

These keywords have equivalent meaning when written in lowercase and cannot appear in non-normative content.

This is a willful violation of RFC 8174, motivated by legibility and a desire to preserve long-standing practice in many non-IETF-published pre-RFC 8174 documents. [RFC8174]

All of the above is applicable to both this standard and any document that uses this standard. Documents using this standard are encouraged to limit themselves to "must", "must not", "should", and "may", and to use these in their lowercase form as that is generally considered to be more readable.

For non-normative content "strongly encouraged", "strongly discouraged", "encouraged", "discouraged", "can", "cannot", "could", "could not", "might", and "might not" can be used instead.


### Compliance with other specifications

In general, specifications interact with and rely on a wide variety of other specifications. In certain circumstances, unfortunately, conflicting needs require a specification to violate the requirements of other specifications. When this occurs, a document using the Infra Standard should denote such transgressions as a willful violation, and note the reason for that violation.

The previous section, § 2.1 Conformance, documents a willful violation of RFC 8174 committed by Infra.


### Terminology

The word "or", in cases where both inclusive "or" and exclusive "or" are possible (e.g., "if either width or height is zero"), means an inclusive "or" (implying "or both"), unless it is called out as being exclusive (with "but not both").

------------------------------------------------------------------------

A user agent is any software entity that acts on behalf of a user, for example by retrieving and rendering web content and facilitating end user interaction with it. In specifications using the Infra Standard, the user agent is generally an instance of the client software that implements the specification. The client software itself is known as an implementation. A person can use many different user agents in their day-to-day life, including by configuring an implementation to act as several user agents at once, for example by using multiple profiles or the implementation's private browsing mode.

If something is said to be implementation-defined, the particulars of what is said to be implementation-defined are up to the implementation. In the absence of such language, the reverse holds: implementations have to follow the rules laid out in documents using this standard.

Insert U+000A (LF) code points into `input` in an implementation-defined manner such that each resulting line has no more than `width` code points. For the purposes of this requirement, lines are delimited by the start of `input`, the end of `input`, and U+000A (LF).


### Privacy concerns

Some features that are defined in documents using the Infra Standard might trade user convenience for a measure of user privacy.

In general, due to the internet's architecture, a user can be distinguished from another by the user's IP address. IP addresses do not perfectly match to a user; as a user moves from device to device, or from network to network, their IP address will change; similarly, NAT routing, proxy servers, and shared computers enable packets that appear to all come from a single IP address to actually map to multiple users. Technologies such as onion routing can be used to further anonymize requests so that requests from a single user at one node on the internet appear to come from many disparate parts of the network. [RFC791]

However, the IP address used for a user's requests is not the only mechanism by which a user's requests could be related to each other. Cookies, for example, are designed specifically to enable this, and are the basis of most of the web's session features that enable you to log into a site with which you have an account. More generally, any kind of cache mechanism or shared state, including but not limited to HSTS, the HTTP cache, grouping of connections, storage APIs, can and ought to be expected to be abused. [COOKIES] [RFC6797] [STORAGE]

There are other mechanisms that are more subtle. Certain characteristics of a user's system can be used to distinguish groups of users from each other. By collecting enough such information, an individual user's browser's "digital fingerprint" can be computed, which can be better than an IP address in ascertaining which requests are from the same user.

Grouping requests in this manner, especially across multiple sites, can be used for malevolent purposes, e.g., governments combining information such as the person's home address (determined from the addresses they use when getting driving directions on one site) with their apparent political affiliations (determined by examining the forum sites that they participate in) to determine whether the person should be prevented from voting in an election.

Since the malevolent purposes can be remarkably evil, user agent implementors and specification authors are strongly encouraged to minimize leaking information that could be used to fingerprint or track a user.

Unfortunately, as the first paragraph in this section implies, sometimes there is great benefit to be derived from exposing APIs that can also be abused for fingerprinting and tracking purposes, so it's not as easy as blocking all possible leaks. For instance, the ability to log into a site to post under a specific identity requires that the user's requests be identifiable as all being from the same user, more or less by definition. More subtly, though, information such as how wide text is, which is necessary for many effects that involve drawing text onto a canvas (e.g., any effect that involves drawing a border around the text) also leaks information that can be used to group a user's requests. (In this case, by potentially exposing, via a brute force search, which fonts a user has installed, information which can vary considerably from user to user.)

Features that are defined in documents using the Infra Standard that can be used as a tracking vector are marked as this paragraph is.

Other features in the platform can be used for the same purpose, including, but not limited to:

- The exact list of which features a user agents supports.
- The maximum allowed stack depth for recursion in script.
- Features that describe the user's environment.
- The user's time zone.
- HTTP request headers.


## Algorithms


### Conformance

Algorithms, and requirements phrased in the imperative as part of algorithms (such as "strip any leading spaces" or "return false") are to be interpreted with the meaning of the keyword (e.g., "must") used in introducing the algorithm or step. If no such keyword is used, must is implied.

For example, were the spec to say:

To eat an orange, the user must:

1.  Peel the orange.
2.  Separate each slice of the orange.
3.  Eat the orange slices.

it would be equivalent to the following:

To eat an orange:

1.  The user must peel the orange.
2.  The user must separate each slice of the orange.
3.  The user must eat the orange slices.

Here the key word is "must".

Modifying the above example, if the algorithm was introduced only with "To eat an orange:", it would still have the same meaning, as "must" is implied.

Conformance requirements phrased as algorithms or specific steps may be implemented in any manner, so long as the end result is equivalent. (In particular, the algorithms are intended to be easy to follow, and not intended to be performant.)

Performance is tricky to get correct as it is influenced by user perception, computer architectures, and different types of input that can change over time in how common they are. For instance, a JavaScript engine likely has many different code paths for what is standardized as a single algorithm, in order to optimize for speed or memory consumption. Standardizing all those code paths would be an insurmountable task and not productive as they would not stand the test of time as well as the single algorithm would. Therefore performance is best left as a field to compete over.


### Avoid limits on algorithm inputs

A document using the Infra Standard generally should not enforce specific limits on algorithm inputs with regards to their size, resource usage, or equivalent. This allows for competition among user agents and avoids constraining the potential computing needs of the future.

Nevertheless, user agents may impose implementation-defined limits on otherwise unconstrained inputs. E.g., to prevent denial of service attacks, to guard against running out of memory, or to work around platform-specific limitations.

Global resource limits can be used as side channels through a variant on a resource exhaustion attack, whereby the attacker can observe whether a victim application reaches the global limit. Limits could also be used to fingerprint the user agent, but only if they make the user agent more unique in some manner, e.g., if they are specific to the underlying hardware.

An API that allows creating an in-memory bitmap might be specified to allow any dimensions, or any dimensions up to some large limit like JavaScript's `Number.MAX_SAFE_INTEGER`. However, implementations can choose to impose some implementation-defined (and thus not specified) limit on the dimensions, instead of attempting to allocate huge amounts of memory.

A programming language might not have a maximum call stack size specified. However, implementations could choose to impose one for practical reasons.

As code can end up depending on a particular limit, it can be useful to define a limit for interoperability. Sometimes, embracing that is not problematic for the future, and can make the code run in more user agents.

It can also be useful to constrain an implementation-defined limit with a lower limit. I.e., ensuring all implementations can handle inputs of a given minimum size.


### Declaration

Algorithm names are usually verb phrases, but sometimes are given names that emphasize their standalone existence, so that standards and readers can refer to the algorithm more idiomatically.

Some algorithm names in the latter category include "attribute change steps", "internal module script graph fetching procedure", and "overload resolution algorithm".

Declare algorithms by stating their name, parameters, and return type, in the following form:

To [algorithm name], given a [type1] `parameter1`, a [type2] `parameter2`, ..., perform the following steps. They return a [return type].

(For non-verb phrase algorithm names, use "To perform the [algorithm name]...". See also § 3.4 Parameters for more complicated parameter-declaration forms.)

To parse an awesome format given a byte sequence `bytes`, perform the following steps. They return a string or null.

Algorithms which do not return a value use a shorter form. This same shorter form can be used even for algorithms that do return a value if the return type is relatively easy to infer from the algorithm steps:

To [algorithm name], given a [type1] `parameter1`, a [type2] `parameter2`, ...:

To parse an awesome format given a byte sequence `bytes`:

Very short algorithms can be declared and specified using a single sentence:

To parse an awesome format given a byte sequence `bytes`, return the result of ASCII uppercasing the isomorphic decoding of `bytes`.

Types should be included in algorithm declarations, but may be omitted if the parameter name is clear enough, or if they are otherwise clear from context. (For example, because the algorithm is a simple wrapper around another one.)

To load a classic script given `url`, return the result of performing the internal script-loading algorithm given `url` and "`classic`".


### Parameters

Algorithm parameters are usually listed sequentially, in the fashion described in § 3.3 Declaration. However, there are some more complicated cases.

Algorithm parameters can be optional, in which case the algorithm declaration must list them as such, and list them after any non-optional parameters. They can either be given a default value, or the algorithm body can check whether or not the argument was given. Concretely, use the following forms:

... an optional [type] `parameter` ...

... an optional [type] `parameter` (default [default value]) ...

Optional boolean parameters must have a default value specified, and that default must be false.

To navigate to a resource `resource`, with an optional string `navigationType` and an optional boolean `exceptionsEnabled` (default false):

1.  ...
2.  If `navigationType` was given, then do something with `navigationType`.
3.  ...

To call algorithms with such optional positional parameters, the optional argument values can be omitted, but only the trailing ones.

Call sites to the previous example's algorithm would look like one of:

- Navigate to `resource`.
- Navigate to `resource` with "`form submission`".
- Navigate to `resource` with "`form submission`" and true.

But, there would be no way to supply a non-default value for the third (`exceptionsEnabled`) argument, while leaving the second (`navigationType`) argument as not-given. Additionally, the last of these calls is fairly unclear for readers, as the fact that "true" means "exceptions enabled" requires going back to the algorithm's declaration and counting parameters. Read on for how to fix these issues!

Optional named parameters, instead of positional ones, can be used to increase clarity and flexibility at the call site. Such parameters are marked up as both variables and definitions, and linked to from their call sites.

To navigate to a resource `resource`, with an optional string `navigationType` and an optional boolean `exceptionsEnabled` (default false):

1.  ...
2.  If `navigationType` was given, then do something with `navigationType`.
3.  ...

Call sites would then look like one of:

- Navigate to `resource`.
- Navigate to `resource` with *navigationType* set to "`form-submission`".
- Navigate to `resource` with *exceptionsEnabled* set to true.
- Navigate to `resource` with *navigationType* set to "`form-submission`" and *exceptionsEnabled* set to true.

Note how within the algorithm steps, the argument value is not linked to the parameter declaration; it remains just a variable reference. Linking to the parameter declaration is done only at the call sites.

Non-optional named parameters may also be used, using the same convention of marking them up as both variables and definitions, and linking to them from call sites. This can improve clarity at the call sites.

Boolean parameters are a case where naming the parameter can be significantly clearer than leaving it as positional, regardless of optionality. See [The Pitfalls of Boolean Trap](https://ariya.io/2011/08/hall-of-api-shame-boolean-trap) for discussion of this in the context of programming languages.

Another complementary technique for improving clarity is to package up related values into a struct, and pass that struct as a parameter. This is especially applicable when the same set of related values is used as the input to multiple algorithms.


### Variables

A variable is declared with "let" and changed with "set".

Let `list` be a new list.

1.  Let `value` be null.

2.  If `input` is a string, then set `value` to `input`.

3.  Otherwise, set `value` to `input`, UTF-8 decoded.

4.  Assert: `value` is a string.

Let `activationTarget` be `target` if `isActivationEvent` is true and `target` has activation behavior; otherwise null.

Variables must not be used before they are declared. Variables are [block scoped](https://en.wikipedia.org/wiki/Scope_(computer_science)#Block_scope). Variables must not be declared more than once per algorithm.

A multiple assignment syntax can be used to assign multiple variables to the tuple's items, by surrounding the variable names with parenthesis and separating each variable name by a comma. The number of variables assigned cannot differ from the number of items in the tuple.

1.  Let `statusInstance` be the status (200, `OK`).

2.  Let (`status`, `statusMessage`) be `statusInstance`.

Assigning `status` and `statusMessage` could be written as two separate steps that use an index or name to access the tuple's items.


### Control flow

The control flow of algorithms is such that a requirement to "return" or "throw" terminates the algorithm the statement was in. "Return" will hand the given value, if any, to its caller. "Throw" will make the caller automatically rethrow the given value, if any, and thereby terminate the caller's algorithm. Using prose the caller has the ability to "catch" the exception and perform another action.


### Conditional abort

Sometimes it is useful to stop performing a series of steps once a condition becomes true.

To do this, state that a given series of steps will **abort when** a specific `condition` is reached. This indicates that the specified steps must be evaluated, not as-written, but by additionally inserting a step before each of them that evaluates `condition`, and if `condition` evaluates to true, skips the remaining steps.

In such algorithms, the subsequent step can be annotated to run **if aborted**, in which case it must run if any of the preceding steps were skipped due to the `condition` of the preceding abort when step evaluated to true.

The following algorithm

1.  Let `result` be an empty list.

2.  Run these steps, but abort when the user clicks the "Cancel" button:

    1.  Compute the first million digits of `π`, and append the result to `result`.

    2.  Compute the first million digits of `e`, and append the result to `result`.

    3.  Compute the first million digits of `φ`, and append the result to `result`.

3.  If aborted, append "`Didn't finish!`" to `result`.

is equivalent to the more verbose formulation

1.  Let `result` be an empty list.

2.  If the user has not clicked the "Cancel" button:

    1.  Compute the first million digits of `π`, and append the result to `result`.

    2.  If the user has not clicked the "Cancel" button:

        1.  Compute the first million digits of `e`, and append the result to `result`.

        2.  If the user has not clicked the "Cancel" button, then compute the first million digits of `φ`, and append the result to `result`.

3.  If the user clicked the "Cancel" button, then append "`Didn't finish!`" to `result`.

Whenever this construct is used, implementations are allowed to evaluate `condition` during the specified steps rather than before and after each step, as long as the end result is indistinguishable. For instance, as long as `result` in the above example is not mutated during a compute operation, the user agent could stop the computation.


### Conditional statements

Algorithms with conditional statements should use the keywords "if", "then", and "otherwise".

1.  Let `value` be null.

2.  If `input` is a string, then set `value` to `input`.

3.  Return `value`.

Once the keyword "otherwise" is used, the keyword "then" is omitted.

1.  Let `value` be null.

2.  If `input` is a string, then set `value` to `input`.

3.  Otherwise, set `value` to failure.

4.  Return `value`.

1.  Let `value` be null.

2.  If `input` is a string, then set `value` to `input`.

3.  Otherwise, if `input` is a list of strings, set `value` to `input`[0].

4.  Otherwise, throw a `TypeError`.

5.  Return `value`.


### Iteration

There's a variety of ways to repeat a set of steps until a condition is reached.

The Infra Standard is not (yet) exhaustive on this; please file an issue if you need something.

For each

:   As defined for lists (and derivatives) and maps.

**While**

:   An instruction to repeat a set of steps as long as a condition is met.

    While `condition` is "`met`":

    1.  ...

An iteration's flow can be controlled via requirements to **continue** or **break**. Continue will skip over any remaining steps in an iteration, proceeding to the next item. If no further items remain, the iteration will stop. Break will skip over any remaining steps in an iteration, and skip over any remaining items as well, stopping the iteration.

Let `example` be the list « 1, 2, 3, 4 ». The following prose would perform `operation` upon 1, then 2, then 3, then 4:

1.  For each `item` of `example`:

    1.  Perform `operation` on `item`.

The following prose would perform `operation` upon 1, then 2, then 4. 3 would be skipped.

1.  For each `item` of `example`:

    1.  If `item` is 3, then continue.
    2.  Perform `operation` on `item`.

The following prose would perform `operation` upon 1, then 2. 3 and 4 would be skipped.

1.  For each `item` of `example`:

    1.  If `item` is 3, then break.
    2.  Perform `operation` on `item`.


### Assertions

To improve readability, it can sometimes help to add assertions to algorithms, stating invariants. To do this, write "**Assert**:", followed by a statement that must be true. If the statement ends up being false that indicates an issue with the document using the Infra Standard that should be reported and addressed.

Since the statement can only ever be true, it has no implications for implementations.

1.  Let `x` be "`Aperture Science`".

2.  Assert: `x` is "`Aperture Science`".


## Primitive data types


### Nulls

The value null is used to indicate the lack of a value. It can be used interchangeably with the JavaScript **null** value.

Let `element` be null.

If `input` is the empty string, then return null.


### Booleans

A **boolean** is either true or false.

Let `elementSeen` be false.


### Numbers

Numbers are complicated; please see [issue #87](https://github.com/whatwg/infra/issues/87). In due course we hope to offer more guidance here around types and mathematical operations. Help appreciated!

An **8-bit unsigned integer** is an integer in the range 0 to 255 (0 to 2^8^ − 1), inclusive.

A **16-bit unsigned integer** is an integer in the range 0 to 65535 (0 to 2^16^ − 1), inclusive.

A **32-bit unsigned integer** is an integer in the range 0 to 4294967295 (0 to 2^32^ − 1), inclusive.

A **64-bit unsigned integer** is an integer in the range 0 to 18446744073709551615 (0 to 2^64^ − 1), inclusive.

A **128-bit unsigned integer** is an integer in the range 0 to 340282366920938463463374607431768211455 (0 to 2^128^ − 1), inclusive.

An IPv6 address is an 128-bit unsigned integer.

An **8-bit signed integer** is an integer in the range −128 to 127 (−2^7^ to 2^7^ − 1), inclusive.

A **16-bit signed integer** is an integer in the range −32768 to 32767 (−2^15^ to 2^15^ − 1), inclusive.

A **32-bit signed integer** is an integer in the range −2147483648 to 2147483647 (−2^31^ to 2^31^ − 1), inclusive.

A **64-bit signed integer** is an integer in the range −9223372036854775808 to 9223372036854775807 (−2^63^ to 2^63^ − 1), inclusive.


### Bytes

A **byte** is a sequence of eight bits and is represented as "`0x`" followed by two ASCII upper hex digits, in the range 0x00 to 0xFF, inclusive. A byte's **value** is its underlying number.

0x40 is a byte whose value is 64.

An **ASCII byte** is a byte in the range 0x00 (NUL) to 0x7F (DEL), inclusive. As illustrated, an ASCII byte, excluding 0x28 and 0x29, may be followed by the representation outlined in the [Standard Code](https://tools.ietf.org/html/rfc20#section-2) section of ASCII format for Network Interchange, between parentheses.

0x28 may be followed by "(left parenthesis)" and 0x29 by "(right parenthesis)".

0x49 (I) when UTF-8 decoded becomes the code point U+0049 (I).


### Byte sequences

A **byte sequence** is a sequence of bytes, represented as a space-separated sequence of bytes. Byte sequences with bytes in the range 0x20 (SP) to 0x7E (~), inclusive, can alternately be written as a string, but using backticks instead of quotation marks, to avoid confusion with an actual string.

0x48 0x49 can also be represented as ``HI``.

Headers, such as ``Content-Type``, are byte sequences.

To get a byte sequence out of a string, using UTF-8 encode from Encoding is encouraged. In rare circumstances isomorphic encode might be needed.

A byte sequence's **length** is the number of bytes it contains.

To **byte-lowercase** a byte sequence, increase each byte it contains, in the range 0x41 (A) to 0x5A (Z), inclusive, by 0x20.

To **byte-uppercase** a byte sequence, subtract each byte it contains, in the range 0x61 (a) to 0x7A (z), inclusive, by 0x20.

A byte sequence `A` is a **byte-case-insensitive** match for a byte sequence `B`, if the byte-lowercase of `A` is the byte-lowercase of `B`.

A byte sequence `potentialPrefix` is a **prefix** of a byte sequence `input` if the following steps return true:

1. Let `i` be 0.

2. While true:

   1. If `i` is greater than or equal to `potentialPrefix`'s length, then return true.

   2. If `i` is greater than or equal to `input`'s length, then return false.

   3. Let `potentialPrefixByte` be the `i`th byte of `potentialPrefix`.

   4. Let `inputByte` be the `i`th byte of `input`.

   5. Return false if `potentialPrefixByte` is not `inputByte`.

   6. Set `i` to `i` + 1.

"`input` **starts with** `potentialPrefix`" can be used as a synonym for "`potentialPrefix` is a prefix of `input`".

A byte sequence `a` is **byte less than** a byte sequence `b` if the following steps return true:

1. If `b` is a prefix of `a`, then return false.

2. If `a` is a prefix of `b`, then return true.

3. Let `n` be the smallest index such that the `n`th byte of `a` is different from the `n`th byte of `b`. (There has to be such an index, since neither byte sequence is a prefix of the other.)

4. If the `n`th byte of `a` is less than the `n`th byte of `b`, then return true.

5. Return false.

To **isomorphic decode** a byte sequence `input`, return a string whose code point length is equal to `input`'s length and whose code points have the same values as the values of `input`'s bytes, in the same order.


### Code points

A **code point** is a Unicode code point and is represented as "U+" followed by four-to-six ASCII upper hex digits, in the range U+0000 to U+10FFFF, inclusive. A code point's **value** is its underlying number.

A code point may be followed by its name, by its rendered form between parentheses when it is not U+0028 or U+0029, or by both. Documents using the Infra Standard are encouraged to follow code points by their name when they cannot be rendered or are U+0028 or U+0029; otherwise, follow them by their rendered form between parentheses, for legibility.

A code point's name is defined in Unicode and represented in ASCII uppercase.

The code point rendered as 🤔 is represented as U+1F914.

When referring to that code point, we might say "U+1F914 (🤔)", to provide extra context. Documents are allowed to use "U+1F914 THINKING FACE (🤔)" as well, though this is somewhat verbose.

Code points that are difficult to render unambigiously, such as U+000A, can be referred to as "U+000A LF". U+0029 can be referred to as "U+0029 RIGHT PARENTHESIS", because even though it renders, this avoids unmatched parentheses.

Code points are sometimes referred to as **characters** and in certain contexts are prefixed with "0x" rather than "U+".

A **leading surrogate** is a code point that is in the range U+D800 to U+DBFF, inclusive.

A **trailing surrogate** is a code point that is in the range U+DC00 to U+DFFF, inclusive.

A **surrogate** is a leading surrogate or a trailing surrogate.

A **scalar value** is a code point that is not a surrogate.

A **noncharacter** is a code point that is in the range U+FDD0 to U+FDEF, inclusive, or U+FFFE, U+FFFF, U+1FFFE, U+1FFFF, U+2FFFE, U+2FFFF, U+3FFFE, U+3FFFF, U+4FFFE, U+4FFFF, U+5FFFE, U+5FFFF, U+6FFFE, U+6FFFF, U+7FFFE, U+7FFFF, U+8FFFE, U+8FFFF, U+9FFFE, U+9FFFF, U+AFFFE, U+AFFFF, U+BFFFE, U+BFFFF, U+CFFFE, U+CFFFF, U+DFFFE, U+DFFFF, U+EFFFE, U+EFFFF, U+FFFFE, U+FFFFF, U+10FFFE, or U+10FFFF.

An **ASCII code point** is a code point in the range U+0000 NULL to U+007F DELETE, inclusive.

An **ASCII tab or newline** is U+0009 TAB, U+000A LF, or U+000D CR.

**ASCII whitespace** is U+0009 TAB, U+000A LF, U+000C FF, U+000D CR, or U+0020 SPACE.

"Whitespace" is a mass noun.

Note: The XML, JSON, and parts of the HTTP specifications exclude U+000C FF in their definition of whitespace:

- [XML's S production](https://www.w3.org/TR/xml/#NT-S)
- [JSON's ws production](https://www.rfc-editor.org/rfc/rfc8259#section-2)
- [HTTP whitespace](https://fetch.spec.whatwg.org/#http-whitespace)

Prefer using Infra's ASCII whitespace definition for new features, unless your specification deals exclusively with XML/JSON/HTTP.

A **C0 control** is a code point in the range U+0000 NULL to U+001F INFORMATION SEPARATOR ONE, inclusive.

A **C0 control or space** is a C0 control or U+0020 SPACE.

A **control** is a C0 control or a code point in the range U+007F DELETE to U+009F APPLICATION PROGRAM COMMAND, inclusive.

An **ASCII digit** is a code point in the range U+0030 (0) to U+0039 (9), inclusive.

An **ASCII upper hex digit** is an ASCII digit or a code point in the range U+0041 (A) to U+0046 (F), inclusive.

An **ASCII lower hex digit** is an ASCII digit or a code point in the range U+0061 (a) to U+0066 (f), inclusive.

An **ASCII hex digit** is an ASCII upper hex digit or ASCII lower hex digit.

An **ASCII upper alpha** is a code point in the range U+0041 (A) to U+005A (Z), inclusive.

An **ASCII lower alpha** is a code point in the range U+0061 (a) to U+007A (z), inclusive.

An **ASCII alpha** is an ASCII upper alpha or ASCII lower alpha.

An **ASCII alphanumeric** is an ASCII digit or ASCII alpha.


### Strings

A **string** is a sequence of 16-bit unsigned integers, also known as **code units**. A string is also known as a **JavaScript string**. Strings are denoted by double quotes and monospace font.

"`Hello, world!`" is a string.

This is different from how Unicode defines "code unit". In particular it refers exclusively to how Unicode defines it for Unicode 16-bit strings.

A string can also be interpreted as containing code points, per the conversion defined in [The String Type](https://tc39.github.io/ecma262/#sec-ecmascript-language-types-string-type) section of the JavaScript specification.

This conversion process converts surrogate pairs into their corresponding scalar value and maps any remaining surrogates to their corresponding code point, leaving them effectively as-is.

A string consisting of the code units 0xD83D, 0xDCA9, and 0xD800, when interpreted as containing code points, would consist of the code points U+1F4A9 and U+D800.

A string's **length** is the number of code units it contains.

A string's **code point length** is the number of code points it contains.

To signify strings with additional restrictions on the code points they can contain this specification defines ASCII strings, isomorphic strings, and scalar value strings. Using these improves clarity in specifications.

An **ASCII string** is a string whose code points are all ASCII code points.

An **isomorphic string** is a string whose code points are all in the range U+0000 NULL to U+00FF (ÿ), inclusive.

A **scalar value string** is a string whose code points are all scalar values.

A scalar value string is useful for any kind of I/O or other kind of operation where UTF-8 encode comes into play.

To **convert** a string into a scalar value string, replace any surrogates with U+FFFD (�).

Note: The replaced surrogates are never part of surrogate pairs, since the process of interpreting the string as containing code points will have converted surrogate pairs into scalar values.

A scalar value string can always be used as a string implicitly since every scalar value string is a string. On the other hand, a string can only be implicitly used as a scalar value string if it is known to not contain surrogates; otherwise a conversion is to be performed.

An implementation likely has to perform explicit conversion, depending on how it actually ends up representing strings and scalar value strings. It is fairly typical for implementations to have multiple implementations of strings alone for performance and memory reasons.

A string `a` **is** or is **identical to** a string `b` if it consists of the same sequence of code units.

Except where otherwise stated, all string comparisons use is.

This type of string comparison was formerly known as a "case-sensitive" comparison in HTML. Strings that compare as identical to one another are not only sensitive to case variation (such as UPPER and lower case), but also to other code point encoding choices, such as normalization form or the order of combining marks. Two strings that are visually or even canonically equivalent according to Unicode might still not be identical to each other.

A string `potentialPrefix` is a **code unit prefix** of a string `input` if the following steps return true:

1. Let `i` be 0.

2. While true:

   1. If `i` is greater than or equal to `potentialPrefix`'s length, then return true.

   2. If `i` is greater than or equal to `input`'s length, then return false.

   3. Let `potentialPrefixCodeUnit` be the `i`th code unit of `potentialPrefix`.

   4. Let `inputCodeUnit` be the `i`th code unit of `input`.

   5. Return false if `potentialPrefixCodeUnit` is not `inputCodeUnit`.

   6. Set `i` to `i` + 1.

When it is clear from context that code units are in play, e.g., because one of the strings is a literal containing only characters that are in the range U+0020 SPACE to U+007E (~), "`input` **starts with** `potentialPrefix`" can be used as a synonym for "`potentialPrefix` is a code unit prefix of `input`".

With unknown values, it is good to be explicit: `targetString` is a code unit prefix of `userInput`. But with a literal, we can use plainer language: `userInput` starts with "`!`".

A string `potentialSuffix` is a **code unit suffix** of a string `input` if the following steps return true:

1. Let `i` be 1.

2. While true:

   1. Let `potentialSuffixIndex` be `potentialSuffix`'s length − `i`.

   2. Let `inputIndex` be `input`'s length − `i`.

   3. If `potentialSuffixIndex` is less than 0, then return true.

   4. If `inputIndex` is less than 0, then return false.

   5. Let `potentialSuffixCodeUnit` be the `potentialSuffixIndex`th code unit of `potentialSuffix`.

   6. Let `inputCodeUnit` be the `inputIndex`th code unit of `input`.

   7. Return false if `potentialSuffixCodeUnit` is not `inputCodeUnit`.

   8. Set `i` to `i` + 1.

When it is clear from context that code units are in play, e.g., because one of the strings is a literal containing only characters that are in the range U+0020 SPACE to U+007E (~), "`input` **ends with** `potentialSuffix`" can be used as a synonym for "`potentialSuffix` is a code unit suffix of `input`".

With unknown values, it is good to be explicit: `targetString` is a code unit suffix of `domain`. But with a literal, we can use plainer language: `domain` ends with "`.`".

A string `a` is **code unit less than** a string `b` if the following steps return true:

1. If `b` is a code unit prefix of `a`, then return false.

2. If `a` is a code unit prefix of `b`, then return true.

3. Let `n` be the smallest index such that the `n`th code unit of `a` is different from the `n`th code unit of `b`. (There has to be such an index, since neither string is a prefix of the other.)

4. If the `n`th code unit of `a` is less than the `n`th code unit of `b`, then return true.

5. Return false.

This matches the ordering used by JavaScript's `<` operator, and its `sort()` method on an array of strings. This ordering compares the 16-bit code units in each string, producing a highly efficient, consistent, and deterministic sort order. The resulting ordering will not match any particular alphabet or lexicographic order, particularly for code points represented by a surrogate pair.

For example, the code point U+FF5E FULLWIDTH TILDE (～) is obviously less than the code point U+1F600 (😀), but the tilde is composed of a single code unit 0xFF5E, while the smiley is composed of two code units 0xD83D and 0XDE00, so the smiley is code unit less than the tilde.

The **code unit substring** from `start` with length `length` within a string `string` is determined as follows:

1. Assert: `start` and `length` are nonnegative.

2. Assert: `start` + `length` is less than or equal to `string`'s length.

3. Let `result` be the empty string.

4. For each `i` in the range from `start` to `start` + `length`, exclusive: append the `i`th code unit of `string` to `result`.

5. Return `result`.

The **code unit substring by positions** from `start` to `end` within a string `string` is the code unit substring from `start` with length `end` − `start` within `string`.

The **code unit substring to the end of the string** from `start` to the end of a string `string` is the code unit substring from `start` to `string`'s length within `string`.

The code unit substring from 1 with length 3 within "`Hello world`" is "`ell`". This can also be expressed as the code unit substring from 1 to 4.

The numbers given to these algorithms are best thought of as positions *between* code units, not indices of the code units themselves. The substring returned is then formed by the code units between these positions. That explains why, for example, the code unit substring from 0 to 0 within the empty string is the empty string, even though there is no code unit at index 0 within the empty string.

The **code point substring** within a string `string` from `start` with length `length` is determined as follows:

1. Assert: `start` and `length` are nonnegative.

2. Assert: `start` + `length` is less than or equal to `string`'s code point length.

3. Let `result` be the empty string.

4. For each `i` in the range from `start` to `start` + `length`, exclusive: append the `i`th code point of `string` to `result`.

5. Return `result`.

The **code point substring by positions** from `start` to `end` within a string `string` is the code point substring within `string` from `start` with length `end` − `start`.

The **code point substring to the end of the string** from `start` to the end of a string `string` is the code point substring from `start` to `string`'s code point length within `string`.

Generally, code unit substring is used when given developer-supplied positions or lengths, since that is how string indexing works in JavaScript. See, for example, the methods of the `CharacterData` class.

Otherwise, code point substring is likely to be better. For example, the code point substring from 0 with length 1 within "`👽`" is "`👽`", whereas the code unit substring from 0 with length 1 within "`👽`" is the string containing the single surrogate U+D83B.

To **isomorphic encode** an isomorphic string `input`: return a byte sequence whose length is equal to `input`'s code point length and whose bytes have the same values as the values of `input`'s code points, in the same order.

To **ASCII lowercase** a string, replace all ASCII upper alphas in the string with their corresponding code point in ASCII lower alpha.

To **ASCII uppercase** a string, replace all ASCII lower alphas in the string with their corresponding code point in ASCII upper alpha.

A string `A` is an **ASCII case-insensitive** match for a string `B`, if the ASCII lowercase of `A` is the ASCII lowercase of `B`.

To **ASCII encode** an ASCII string `input`: return the isomorphic encoding of `input`.

Isomorphic encode and UTF-8 encode return the same byte sequence for `input`.

To **ASCII decode** a byte sequence `input`, run these steps:

1. Assert: all bytes in `input` are ASCII bytes.

   Note: This precondition ensures that isomorphic decode and UTF-8 decode return the same string for this input.

2. Return the isomorphic decoding of `input`.

To **strip newlines** from a string, remove any U+000A LF and U+000D CR code points from the string.

To **normalize newlines** in a string, replace every U+000D CR U+000A LF code point pair with a single U+000A LF code point, and then replace every remaining U+000D CR code point with a U+000A LF code point.

To **strip leading and trailing ASCII whitespace** from a string, remove all ASCII whitespace that are at the start or the end of the string.

To **strip and collapse ASCII whitespace** in a string, replace any sequence of one or more consecutive code points that are ASCII whitespace in the string with a single U+0020 SPACE code point, and then remove any leading and trailing ASCII whitespace from that string.

To **collect a sequence of code points** meeting a condition `condition` from a string `input`, given a **position variable** `position` tracking the position of the calling algorithm within `input`:

1. Let `result` be the empty string.

2. While `position` doesn't point past the end of `input` and the code point at `position` within `input` meets the condition `condition`:

   1. Append that code point to the end of `result`.

   2. Advance `position` by 1.

3. Return `result`.

In addition to returning the collected code points, this algorithm updates the position variable in the calling algorithm.

To **skip ASCII whitespace** within a string `input` given a position variable `position`, collect a sequence of code points that are ASCII whitespace from `input` given `position`. The collected code points are not used, but `position` is still updated.

To **strictly split** a string `input` on a particular delimiter code point `delimiter`:

1. Let `position` be a position variable for `input`, initially pointing at the start of `input`.

2. Let `tokens` be a list of strings, initially empty.

3. Let `token` be the result of collecting a sequence of code points that are not equal to `delimiter` from `input`, given `position`.

4. Append `token` to `tokens`.

5. While `position` is not past the end of `input`:

   1. Assert: the code point at `position` within `input` is `delimiter`.

   2. Advance `position` by 1.

   3. Let `token` be the result of collecting a sequence of code points that are not equal to `delimiter` from `input`, given `position`.

   4. Append `token` to `tokens`.

6. Return `tokens`.

This algorithm is a "strict" split, as opposed to the commonly-used variants for ASCII whitespace and for commas below, which are both more lenient in various ways involving interspersed ASCII whitespace.

To **split a string `input` on ASCII whitespace**:

1. Let `position` be a position variable for `input`, initially pointing at the start of `input`.

2. Let `tokens` be a list of strings, initially empty.

3. Skip ASCII whitespace within `input` given `position`.

4. While `position` is not past the end of `input`:

   1. Let `token` be the result of collecting a sequence of code points that are not ASCII whitespace from `input`, given `position`.

   2. Append `token` to `tokens`.

   3. Skip ASCII whitespace within `input` given `position`.

5. Return `tokens`.

To **split a string `input` on commas**:

1. Let `position` be a position variable for `input`, initially pointing at the start of `input`.

2. Let `tokens` be a list of strings, initially empty.

3. While `position` is not past the end of `input`:

   1. Let `token` be the result of collecting a sequence of code points that are not U+002C (,) from `input`, given `position`.

      `token` might be the empty string.

   2. Strip leading and trailing ASCII whitespace from `token`.

   3. Append `token` to `tokens`.

   4. If `position` is not past the end of `input`:

      1. Assert: the code point at `position` within `input` is U+002C (,).

      2. Advance `position` by 1.

4. Return `tokens`.

To **concatenate** a list of strings `list`, using an optional separator string `separator`, run these steps:

1. If `list` is empty, then return the empty string.

2. If `separator` is not given, then set `separator` to the empty string.

3. Return a string whose contents are `list`'s items, in order, separated from each other by `separator`.

To serialize a set `set`, return the concatenation of `set` using U+0020 SPACE.


### Time

Represent time using the [moment](https://w3c.github.io/hr-time/#dfn-moment) and [duration](https://w3c.github.io/hr-time/#dfn-duration) specification types. Follow the advice in [High Resolution Time § 3 Tools for Specification Authors](https://w3c.github.io/hr-time/#sec-tools) when creating these and exchanging them with JavaScript.


## Data structures

Conventionally, specifications have operated on a variety of vague specification-level data structures, based on shared understanding of their semantics. This generally works well, but can lead to ambiguities around edge cases, such as iteration order or what happens when you append an item to an ordered set that the set already contains. It has also led to a variety of divergent notation and phrasing, especially around more complex data structures such as maps.

This standard provides a small set of common data structures, along with notation and phrasing for working with them, in order to create common ground.


### Lists

A **list** is a specification type consisting of a finite ordered sequence of **items**.

For notational convenience, a literal syntax can be used to express lists, by surrounding the list by « » characters and separating its items with a comma. An indexing syntax can be used by providing a zero-based index into a list inside square brackets. The index cannot be out-of-bounds, except when used with exists.

Let `example` be the list « "`a`", "`b`", "`c`", "`a`" ». Then `example`[1] is the string "`b`".

For notational convenience, a multiple assignment syntax may be used to assign multiple variables to the list's items, by surrounding the variables to be assigned by « » characters and separating each variable name with a comma. The list's size must be the same as the number of variables to be assigned. Each variable given is then set to the value of the list's item at the corresponding index.

1.  Let `value` be the list « "`a`", "`b`", "`c`" ».

2.  Let « `a`, `b`, `c` » be `value`.

3.  Assert: `a` is "`a`".

4.  Assert: `b` is "`b`".

5.  Assert: `c` is "`c`".

When a list's contents are not fully controlled, as is the case for lists from user input, the list's size should be checked to ensure it is the expected size before list multiple assignment syntax is used.

1.  If `list`'s size is not `3`, then return failure.

2.  Let « `a`, `b`, `c` » be `list`.

------------------------------------------------------------------------

To **append** to a list that is not an ordered set is to add the given item to the end of the list.

To **extend** a list that is not an ordered set `A` with a list `B`, for each `item` of `B`, append `item` to `A`.

1.  Let `ghostbusters` be « "`Erin Gilbert`", "`Abby Yates`" ».

2.  Extend `ghostbusters` with « "`Jillian Holtzmann`", "`Patty Tolan`" ».

3.  Assert: `ghostbusters`'s size is 4.

4.  Assert: `ghostbusters`[2] is "`Jillian Holtzmann`".

To **prepend** to a list that is not an ordered set is to add the given item to the beginning of the list.

To **replace** within a list that is not an ordered set is to replace all items from the list that match a given condition with the given item, or do nothing if none do.

The above definitions are modified when the list is an ordered set; see below for ordered set append, prepend, and replace.

To **insert** an item into a list before an index is to add the given item to the list between the given index − 1 and the given index. If the given index is 0, then prepend the given item to the list.

To **remove** zero or more items from a list is to remove all items from the list that match a given condition, or do nothing if none do.

Removing `x` from the list « `x`, `y`, `z`, `x` » is to remove all items from the list that are equal to `x`. The list now is equivalent to « `y`, `z` ».

Removing all items that start with the string "`a`" from the list « "`a`", "`b`", "`ab`", "`ba`" » is to remove the items "`a`" and "`ab`". The list is now equivalent to « "`b`", "`ba`" ».

To **empty** a list is to remove all of its items.

A list **contains** an item if it appears in the list. We can also denote this by saying that, for a list `list` and an index `index`, "`list`[`index`] **exists**".

A list's **size** is the number of items the list contains.

A list **is empty** if its size is zero.

To **get the indices** of a list, return the range from 0 to the list's size, exclusive.

To **iterate** over a list, performing a set of steps on each item in order, use phrasing of the form "**For each** `item` of `list`", and then operate on `item` in the subsequent prose.

To **clone** a list `list` is to create a new list `clone`, of the same designation, and, for each `item` of `list`, append `item` to `clone`, so that `clone` contains the same items, in the same order as `list`.

This is a "shallow clone", as the items themselves are not cloned in any way.

Let `original` be the ordered set « "`a`", "`b`", "`c`" ». Cloning `original` creates a new ordered set `clone`, so that replacing "`a`" with "`foo`" in `clone` gives « "`foo`", "`b`", "`c`" », while `original`[0] is still the string "`a`".

To **sort in ascending order** a list `list`, with a less than algorithm `lessThanAlgo`, is to create a new list `sorted`, containing the same items as `list` but sorted so that according to `lessThanAlgo`, each item is less than the one following it, if any. For items that sort the same (i.e., for which `lessThanAlgo` returns false for both comparisons), their relative order in `sorted` must be the same as it was in `list`.

To **sort in descending order** a list `list`, with a less than algorithm `lessThanAlgo`, is to create a new list `sorted`, containing the same items as `list` but sorted so that according to `lessThanAlgo`, each item is less than the one preceding it, if any. For items that sort the same (i.e., for which `lessThanAlgo` returns false for both comparisons), their relative order in `sorted` must be the same as it was in `list`.

Let `original` be the list « (200, "`OK`"), (404, "`Not Found`"), (null, "`OK`") ». Sorting `original` in ascending order, with `a` being less than `b` if `a`'s second item is code unit less than `b`'s second item, gives the result « (404, "`Not Found`"), (200, "`OK`"), (null, "`OK`") ».

------------------------------------------------------------------------

The list type originates from the JavaScript specification (where it is capitalized, as List); we repeat some elements of its definition here for ease of reference, and provide an expanded vocabulary for manipulating lists. Whenever JavaScript expects a List, a list as defined here can be used; they are the same type. [ECMA-262]


#### Stacks

Some lists are designated as **stacks**. A stack is a list, but conventionally, the following operations are used to operate on it, instead of using append, prepend, or remove.

To **push** onto a stack is to append to it.

To **pop** from a stack: if the stack is not empty, then remove its last item and return it; otherwise, return nothing.

To **peek** into a stack: if the stack is not empty, then return its last item; otherwise, return nothing.

Although stacks are lists, for each must not be used with them; instead, a combination of while and pop is more appropriate.


#### Queues

Some lists are designated as **queues**. A queue is a list, but conventionally, the following operations are used to operate on it, instead of using append, prepend, or remove.

To **enqueue** in a queue is to append to it.

To **dequeue** from a queue is to remove its first item and return it, if the queue is not empty, or to return nothing if it is.

Although queues are lists, for each must not be used with them; instead, a combination of while and dequeue is more appropriate.


#### Sets

Some lists are designated as **ordered sets**. An ordered set is a list with the additional semantic that it must not contain the same item twice.

Almost all cases on the web platform require an *ordered* set, instead of an unordered one, since interoperability requires that any developer-exposed enumeration of the set's contents be consistent between browsers. In those cases where order is not important, we still use ordered sets; implementations can optimize based on the fact that the order is not observable.

To **create** a set, given a list `input`:

1.  Let `result` be an empty set.

2.  For each `item` of `input`, append `item` to `result`.

3.  Return `result`.

To **append** to an ordered set: if the set contains the given item, then do nothing; otherwise, perform the normal list append operation.

To **extend** an ordered set `A` with a list `B`, for each `item` of `B`, append `item` to `A`.

To **prepend** to an ordered set: if the set contains the given item, then do nothing; otherwise, perform the normal list prepend operation.

To **replace** within an ordered set `set`, given `item` and `replacement`: if `set` contains `item` or `replacement`, then replace the first instance of either with `replacement` and remove all other instances.

Replacing "a" with "c" within the ordered set « "a", "b", "c" » gives « "c", "b" ». Within « "c", "b", "a" » it gives « "c", "b" » as well.

An ordered set `set` is a **subset** of another ordered set `superset` (and conversely, `superset` is a **superset** of `set`) if, for each `item` of `set`, `superset` contains `item`.

This implies that an ordered set is both a subset and a superset of itself.

A set `A` is **equal** to a set `B` if `A` is a subset of `B` and `A` is a superset of `B`.

The **intersection** of ordered sets `A` and `B`, is the result of creating a new ordered set `set` and, for each `item` of `A`, if `B` contains `item`, appending `item` to `set`.

The **union** of ordered sets `A` and `B`, is the result of cloning `A` as `set` and, for each `item` of `B`, appending `item` to `set`.

The **difference** of ordered sets `A` and `B`, is the result of creating a new ordered set `set` and, for each `item` of `A`, if `B` does not contain `item`, appending `item` to `set`.

------------------------------------------------------------------------

**The range** `n` to `m`, inclusive, creates a new ordered set containing all of the integers from `n` up to and including `m` in consecutively increasing order, as long as `m` is greater than or equal to `n`.

**The range** `n` to `m`, exclusive, creates a new ordered set containing all of the integers from `n` up to and including `m` − 1 in consecutively increasing order, as long as `m` is greater than `n`. If `m` equals `n`, then it creates an empty ordered set.

For each `n` of the range 1 to 4, inclusive, ...


### Maps

An **ordered map**, or sometimes just "map", is a specification type consisting of a finite ordered sequence of tuples, each consisting of a **key** and a **value**, with no key appearing twice. Each such tuple is called an **entry**.

As with ordered sets, by default we assume that maps need to be ordered for interoperability among implementations.

A literal syntax can be used to express ordered maps, by surrounding the ordered map with «[ ]» characters, denoting each of its entries as `key` → `value`, and separating its entries with a comma.

Let `example` be the ordered map «[ "`a`" → `x`, "`b`" → `y` ]». Then `example`["`a`"] is the byte sequence `x`.

------------------------------------------------------------------------

To **get the value of an entry** in an ordered map `map` given a key `key` and an optional `default`:

1.  If `map` does not contain `key` and `default` is given, then return `default`.

2.  Assert: `map` contains `key`.

3.  Return the value of the entry in `map` whose key is `key`.

We can also denote getting the value of an entry using an indexing syntax, by providing a key inside square brackets directly following a map. A default can be given by adding the phrase **with default** followed by the default value.

If `map`["`test`"] exists, then return `map`["`test`"].

Let `example` be the ordered map «[ "`a`" → "`x`", "`b`" → "`y`" ]». Then `example`["`a`"] is the same as `example`["`a`"] with default "`z`", namely "`x`". `example`["`c`"] would hit an assert. `example`["`c`"] with default "`z`" is "`z`".

To **set the value of an entry** in an ordered map to a given value is to update the value of any existing entry if the map contains an entry with the given key, or if none such exists, to add a new entry with the given key/value to the end of the map. We can also denote this by saying, for an ordered map `map`, key `key`, and value `value`, "set `map`[`key`] to `value`".

To **remove an entry** from an ordered map is to remove all entries from the map that match a given condition, or do nothing if none do. If the condition is having a certain key, then we can also denote this by saying, for an ordered map `map` and key `key`, "remove `map`[`key`]".

To **clear** an ordered map is to remove all entries from the map.

An ordered map **contains an entry with a given key** if there exists an entry with that key. We can also denote this by saying that, for an ordered map `map` and key `key`, "`map`[`key`] **exists**".

To **get the keys** of an ordered map, return a new ordered set whose items are each of the keys in the map's entries.

To **get the values** of an ordered map, return a new list whose items are each of the values in the map's entries.

An ordered map's **size** is the size of the result of running get the keys on the map.

An ordered map **is empty** if its size is zero.

To **iterate** over an ordered map, performing a set of steps on each entry in order, use phrasing of the form "**For each** `key` → `value` of `map`", and then operate on `key` and `value` in the subsequent prose.

To **clone** an ordered map `map` is to create a new ordered map `clone`, and, for each `key` → `value` of `map`, set `clone`[`key`] to `value`.

This is a "shallow clone", as the keys and values themselves are not cloned in any way.

Let `original` be the ordered map «[ "`a`" → «1, 2, 3», "`b`" → «» ]». Cloning `original` creates a new ordered map `clone`, so that setting `clone`["`a`"] to «-1, -2, -3» gives «[ "`a`" → «-1, -2, -3», "`b`" → «» ]» and leaves `original` unchanged. However, appending 4 to `clone`["`b`"] will modify the corresponding value in both `clone` and `original`, as they both point to the same list.

To **sort in ascending order** a map `map`, with a less than algorithm `lessThanAlgo`, is to create a new map `sorted`, containing the same entries as `map` but sorted so that according to `lessThanAlgo`, each entry is less than the one following it, if any. For entries that sort the same (i.e., for which `lessThanAlgo` returns false for both comparisons), their relative order in `sorted` must be the same as it was in `map`.

To **sort in descending order** a map `map`, with a less than algorithm `lessThanAlgo`, is to create a new map `sorted`, containing the same entries as `map` but sorted so that according to `lessThanAlgo`, each entry is less than the one preceding it, if any. For entries that sort the same (i.e., for which `lessThanAlgo` returns false for both comparisons), their relative order in `sorted` must be the same as it was in `map`.


### Structs

A **struct** is a specification type consisting of a finite set of **items**, each of which has a unique and immutable **name**. An item holds a value of a defined type.

An **email** is an example struct consisting of a **local part** (a string) and a **host** (a host).

A nonsense algorithm might use this definition as follows:

1.  Let `email` be an email whose local part is "`hostmaster`" and host is `infra.example`.
2.  ...


#### Tuples

A **tuple** is a struct whose items are ordered. For notational convenience, a literal syntax can be used to express tuples, by surrounding the tuple with parenthesis and separating its items with a comma. To use this notation, the names need to be clear from context. This can be done by preceding the first instance with the name given to the tuple. An indexing syntax can be used by providing a zero-based index into a tuple inside square brackets. The index cannot be out-of-bounds.

A **status** is an example tuple consisting of a **code** (a number) and **text** (a byte sequence).

A nonsense algorithm that manipulates status tuples for the purpose of demonstrating their usage is:

1.  Let `statusInstance` be the status (200, `OK`).
2.  Set `statusInstance` to (301, `FOO BAR`).
3.  If `statusInstance`'s code is 404, then ...

The last step could also be written as "If `statusInstance`[0] is 404, then ...". This might be preferable if the tuple names do not have explicit definitions.

It is intentional that not all structs are tuples. Documents using the Infra Standard might need the flexibility to add new names to their struct without breaking literal syntax used by their dependencies. In that case a tuple is not appropriate.


## JSON

The conventions used in the algorithms in this section are those of the JavaScript specification. [ECMA-262]

To **parse a JSON string to a JavaScript value**, given a string `string`:

1.  Return ? [Call](%JSON.parse%, undefined, « `string` »).

To **parse JSON bytes to a JavaScript value**, given a byte sequence `bytes`:

1.  Let `string` be the result of running [UTF-8 decode](https://encoding.spec.whatwg.org/#utf-8-decode) on `bytes`. [ENCODING]

2.  Return the result of parsing a JSON string to a JavaScript value given `string`.

To **serialize a JavaScript value to a JSON string**, given a JavaScript value `value`:

1.  Let `result` be ? [Call](%JSON.stringify%, undefined, « `value` »).

    Since no additional arguments are passed to %JSON.stringify%, the resulting string will have no whitespace inserted.

2.  If `result` is undefined, then throw a `TypeError`.

    This can happen if `value` does not have a JSON representation, e.g., if it is undefined or a function.

3.  Assert: `result` is a string.

4.  Return `result`.

To **serialize a JavaScript value to JSON bytes**, given a JavaScript value `value`:

1.  Let `string` be the result of serializing a JavaScript value to a JSON string given `value`.

2.  Return the result of running [UTF-8 encode](https://encoding.spec.whatwg.org/#utf-8-encode) on `string`. [ENCODING]


The above operations operate on JavaScript values directly; in particular, this means that the involved objects or arrays are tied to a particular [JavaScript realm](https://tc39.github.io/ecma262/#realm). In standards, it is often more convenient to convert between JSON and realm-independent maps, lists, strings, booleans, numbers, and nulls.

To **parse a JSON string to an Infra value**, given a string `string`:

1.  Let `jsValue` be ? [Call](%JSON.parse%, undefined, « `string` »).

2.  Return the result of converting a JSON-derived JavaScript value to an Infra value, given `jsValue`.

To **parse JSON bytes to an Infra value**, given a byte sequence `bytes`:

1.  Let `string` be the result of running [UTF-8 decode](https://encoding.spec.whatwg.org/#utf-8-decode) on `bytes`. [ENCODING]

2.  Return the result of parsing a JSON string to an Infra value given `string`.

To **convert a JSON-derived JavaScript value to an Infra value**, given a JavaScript value `jsValue`:

1.  If `jsValue` is null, `jsValue` [is a Boolean](https://tc39.github.io/ecma262/#sec-ecmascript-language-types-boolean-type), `jsValue` [is a String](https://tc39.github.io/ecma262/#sec-ecmascript-language-types-string-type), or `jsValue` [is a Number](https://tc39.github.io/ecma262/#sec-ecmascript-language-types-number-type), then return `jsValue`.

2.  If [IsArray](https://tc39.github.io/ecma262/#sec-isarray)(`jsValue`) is true:

    1.  Let `result` be an empty list.

    2.  Let `length` be ! [ToLength](https://tc39.github.io/ecma262/#sec-tolength)(! [Get](https://tc39.github.io/ecma262/#sec-get-o-p)(`jsValue`, "`length`")).

    3.  For each `index` of the range 0 to `length` − 1, inclusive:

        1.  Let `indexName` be ! [ToString](https://tc39.github.io/ecma262/#sec-tostring)(`index`).

        2.  Let `jsValueAtIndex` be ! [Get](https://tc39.github.io/ecma262/#sec-get-o-p)(`jsValue`, `indexName`).

        3.  Let `infraValueAtIndex` be the result of converting a JSON-derived JavaScript value to an Infra value, given `jsValueAtIndex`.

        4.  Append `infraValueAtIndex` to `result`.

    4.  Return `result`.

3.  Let `result` be an empty ordered map.

4.  For each `key` of ! `jsValue`.[[OwnPropertyKeys]]():

    1.  Let `jsValueAtKey` be ! [Get](https://tc39.github.io/ecma262/#sec-get-o-p)(`jsValue`, `key`).

    2.  Let `infraValueAtKey` be the result of converting a JSON-derived JavaScript value to an Infra value, given `jsValueAtKey`.

    3.  Set `result`[`key`] to `infraValueAtKey`.

5.  Return `result`.

To **serialize an Infra value to a JSON string**, given a string, boolean, number, null, list, or string-keyed map `value`:

1.  Let `jsValue` be the result of converting an Infra value to a JSON-compatible JavaScript value, given `value`.

2.  Return ! [Call](%JSON.stringify%, undefined, « `jsValue` »).

    Since no additional arguments are passed to %JSON.stringify%, the resulting string will have no whitespace inserted.

To **serialize an Infra value to JSON bytes**, given a string, boolean, number, null, list, or string-keyed map `value`:

1.  Let `string` be the result of serializing an Infra value to a JSON string, given `value`.

2.  Return the result of running [UTF-8 encode](https://encoding.spec.whatwg.org/#utf-8-encode) on `string`. [ENCODING]

To **convert an Infra value to a JSON-compatible JavaScript value**, given `value`:

1.  If `value` is a string, boolean, number, or null, then return `value`.

2.  If `value` is a list:

    1.  Let `jsValue` be ! [ArrayCreate](https://tc39.github.io/ecma262/#sec-arraycreate)(0).

    2.  Let `i` be 0.

    3.  For each `listItem` of `value`:

        1.  Let `listItemJSValue` be the result of converting an Infra value to a JSON-compatible JavaScript value, given `listItem`.

        2.  Perform ! [CreateDataPropertyOrThrow](https://tc39.github.io/ecma262/#sec-createdatapropertyorthrow)(`jsValue`, ! [ToString](https://tc39.github.io/ecma262/#sec-tostring)(`i`), `listItemJSValue`).

        3.  Set `i` to `i` + 1.

    4.  Return `jsValue`.

3.  Assert: `value` is a map.

4.  Let `jsValue` be ! [OrdinaryObjectCreate](https://tc39.github.io/ecma262/#sec-ordinaryobjectcreate)(null).

5.  For each `mapKey` → `mapValue` of `value`:

    1.  Assert: `mapKey` is a string.

    2.  Let `mapValueJSValue` be the result of converting an Infra value to a JSON-compatible JavaScript value, given `mapValue`.

    3.  Perform ! [CreateDataPropertyOrThrow](https://tc39.github.io/ecma262/#sec-createdatapropertyorthrow)(`jsValue`, `mapKey`, `mapValueJSValue`).

6.  Return `jsValue`.

Because it is rarely appropriate to manipulate JavaScript values directly in specifications, prefer using serialize an Infra value to a JSON string or serialize an Infra value to JSON bytes instead of using this algorithm. Please [file an issue](https://github.com/whatwg/infra/issues/new) to discuss your use case if you believe you need to use convert an Infra value to a JSON-compatible JavaScript value.


# Forgiving base64

To [forgiving-base64 encode](#forgiving-base64-encode) given a byte sequence `data`, apply the base64 algorithm defined in section 4 of RFC 4648 to `data` and return the result. [RFC4648]

This is named forgiving-base64 encode for symmetry with forgiving-base64 decode, which is different from the RFC as it defines error handling for certain inputs.

To [forgiving-base64 decode](#forgiving-base64-decode) given a string `data`, run these steps:

1. Remove all ASCII whitespace from `data`.

2. If `data`'s code point length divides by 4 leaving no remainder:

    1. If `data` ends with one or two U+003D (=) code points, then remove them from `data`.

3. If `data`'s code point length divides by 4 leaving a remainder of 1, then return failure.

4. If `data` contains a code point that is not one of

    - U+002B (+)
    - U+002F (/)
    - ASCII alphanumeric

    then return failure.

5. Let `output` be an empty byte sequence.

6. Let `buffer` be an empty buffer that can have bits appended to it.

7. Let `position` be a position variable for `data`, initially pointing at the start of `data`.

8. While `position` does not point past the end of `data`:

    1. Find the code point pointed to by `position` in the second column of Table 1: The Base 64 Alphabet of RFC 4648. Let `n` be the number given in the first cell of the same row. [RFC4648]

    2. Append the six bits corresponding to `n`, most significant bit first, to `buffer`.

    3. If `buffer` has accumulated 24 bits, interpret them as three 8-bit big-endian numbers. Append three bytes with values equal to those numbers to `output`, in the same order, and then empty `buffer`.

    4. Advance `position` by 1.

9. If `buffer` is not empty, it contains either 12 or 18 bits. If it contains 12 bits, then discard the last four and interpret the remaining eight as an 8-bit big-endian number. If it contains 18 bits, then discard the last two and interpret the remaining 16 as two 8-bit big-endian numbers. Append the one or two bytes with values equal to those one or two numbers to `output`, in the same order.

    The discarded bits mean that, for instance, "`YQ`" and "`YR`" both return ``a``.

10. Return `output`.


## Namespaces

The **HTML namespace** is "`http://www.w3.org/1999/xhtml`".

The **MathML namespace** is "`http://www.w3.org/1998/Math/MathML`".

The **SVG namespace** is "`http://www.w3.org/2000/svg`".

The **XLink namespace** is "`http://www.w3.org/1999/xlink`".

The **XML namespace** is "`http://www.w3.org/XML/1998/namespace`".

The **XMLNS namespace** is "`http://www.w3.org/2000/xmlns/`".