## Goals

The URL standard takes the following approach towards making URLs fully interoperable:

- Align RFC 3986 and RFC 3987 with contemporary implementations and obsolete the RFCs in the process. (E.g., spaces, other "illegal" code points, query encoding, equality, canonicalization, are all concepts not entirely shared, or defined.) URL parsing needs to become as solid as HTML parsing. [RFC3986] [RFC3987]

- Standardize on the term URL. URI and IRI are just confusing. In practice a single algorithm is used for both so keeping them distinct is not helping anyone. URL also easily wins the [search result popularity contest](https://trends.google.com/trends/explore?q=url,uri).

- Supplanting [Origin of a URI \[sic\]](https://tools.ietf.org/html/rfc6454#section-4). [RFC6454]

- Define URL's existing JavaScript API in full detail and add enhancements to make it easier to work with. Add a new `URL` object as well for URL manipulation without usage of HTML elements. (Useful for JavaScript worker environments.)

- Ensure the combination of parser, serializer, and API guarantee idempotence. For example, a non-failure result of a parse-then-serialize operation will not change with any further parse-then-serialize operations applied to it. Similarly, manipulating a non-failure result through the API will not change from applying any number of serialize-then-parse operations to it.

As the editors learn more about the subject matter the goals might increase in scope somewhat.


## Infrastructure

This specification depends on Infra. [INFRA]

Some terms used in this specification are defined in the following standards and specifications:

- Encoding [ENCODING]
- File API [FILEAPI]
- HTML [HTML]
- Unicode IDNA Compatibility Processing [UTS46]
- Web IDL [WEBIDL]

To **serialize an integer**, represent it as the shortest possible decimal number.


### Writing

A **validation error** indicates a mismatch between input and valid input. User agents, especially conformance checkers, are encouraged to report them somewhere.

A validation error does not mean that the parser terminates. Termination of a parser is always stated explicitly, e.g., through a return statement.

It is useful to signal validation errors as error-handling can be non-intuitive, legacy user agents might not implement correct error-handling, and the intent of what is written might be unclear to other developers.

Error type | Error description | Failure
--- | --- | ---
IDNA | **domain-to-ASCII** | Yes
| Unicode ToASCII records an error or returns the empty string. [UTS46]<br><br>If details about Unicode ToASCII errors are recorded, user agents are encouraged to pass those along. |
| **domain-invalid-code-point** | Yes
| The input's host contains a forbidden domain code point.<br><br>Hosts are percent-decoded before being processed when the URL is special, which would result in the following host portion becoming "`exa#mple.org`" and thus triggering this error.<br><br>"`https://exa%23mple.org`" |
| **domain-to-Unicode** | ·
| Unicode ToUnicode records an error. [UTS46]<br><br>The same considerations as with domain-to-ASCII apply. |
Host parsing | **host-invalid-code-point** | Yes
| An opaque host (in a URL that is not special) contains a forbidden host code point.<br><br>"`foo://exa[mple.org`" |
| **IPv4-empty-part** | ·
| An IPv4 address ends with a U+002E (.).<br><br>"`https://127.0.0.1./`" |
| **IPv4-too-many-parts** | Yes
| An IPv4 address does not consist of exactly 4 parts.<br><br>"`https://1.2.3.4.5/`" |
| **IPv4-non-numeric-part** | Yes
| An IPv4 address part is not numeric.<br><br>"`https://test.42`" |
| **IPv4-non-decimal-part** | ·
| The IPv4 address contains numbers expressed using hexadecimal or octal digits.<br><br>"`https://127.0.0x0.1`" |
| **IPv4-out-of-range-part** | Yes (only if applicable to the last part)
| An IPv4 address part exceeds 255.<br><br>"`https://255.255.4000.1`" |
| **IPv6-unclosed** | Yes
| An IPv6 address is missing the closing U+005D (]).<br><br>"`https://[::1`" |
| **IPv6-invalid-compression** | Yes
| An IPv6 address begins with improper compression.<br><br>"`https://[:1]`" |
| **IPv6-too-many-pieces** | Yes
| An IPv6 address contains more than 8 pieces.<br><br>"`https://[1:2:3:4:5:6:7:8:9]`" |
| **IPv6-multiple-compression** | Yes
| An IPv6 address is compressed in more than one spot.<br><br>"`https://[1::1::1]`" |
| **IPv6-invalid-code-point** | Yes
| An IPv6 address contains a code point that is neither an ASCII hex digit nor a U+003A (:). Or it unexpectedly ends.<br><br>"`https://[1:2:3!:4]`"<br><br>"`https://[1:2:3:]`" |
| **IPv6-too-few-pieces** | Yes
| An uncompressed IPv6 address contains fewer than 8 pieces.<br><br>"`https://[1:2:3]`" |
| **IPv4-in-IPv6-too-many-pieces** | Yes
| An IPv6 address with IPv4 address syntax: the IPv6 address has more than 6 pieces.<br><br>"`https://[1:1:1:1:1:1:1:127.0.0.1]`" |
| **IPv4-in-IPv6-invalid-code-point** | Yes
| An IPv6 address with IPv4 address syntax:<br><br>- An IPv4 part is empty or contains a non-ASCII digit.<br>- An IPv4 part contains a leading 0.<br>- There are too many IPv4 parts.<br><br>"`https://[ffff::.0.0.1]`"<br><br>"`https://[ffff::127.0.xyz.1]`"<br><br>"`https://[ffff::127.0xyz]`"<br><br>"`https://[ffff::127.00.0.1]`"<br><br>"`https://[ffff::127.0.0.1.2]`" |
| **IPv4-in-IPv6-out-of-range-part** | Yes
| An IPv6 address with IPv4 address syntax: an IPv4 part exceeds 255.<br><br>"`https://[ffff::127.0.0.4000]`" |
| **IPv4-in-IPv6-too-few-parts** | Yes
| An IPv6 address with IPv4 address syntax: an IPv4 address contains too few parts.<br><br>"`https://[ffff::127.0.0]`" |
URL parsing | **invalid-URL-unit** | ·
| A code point is found that is not a URL unit.<br><br>"`https://example.org/>`"<br><br>"` https://example.org `"<br><br>"`ht`<br>`tps://example.org`"<br><br>"`https://example.org/%s`" |
| **special-scheme-missing-following-solidus** | ·
| The input's scheme is not followed by "`//`".<br><br>"`file:c:/my-secret-folder`"<br><br>"`https:example.org`"<br><br>```javascript<br>const url = new URL("https:foo.html", "https://example.org/");<br>``` |
| **missing-scheme-non-relative-URL** | Yes
| The input is missing a scheme, because it does not begin with an ASCII alpha, and either no base URL was provided or the base URL cannot be used as a base URL because it has an opaque path.<br><br>Input's scheme is missing and no base URL is given:<br><br>```javascript<br>const url = new URL("💩");<br>```<br><br>Input's scheme is missing, but the base URL has an opaque path.<br><br>```javascript<br>const url = new URL("💩", "mailto:user@example.org");<br>``` |
| **invalid-reverse-solidus** | ·
| The URL has a special scheme and it uses U+005C (\\) instead of U+002F (/).<br><br>"`https://example.org\path\to\file`" |
| **invalid-credentials** | ·
| The input includes credentials.<br><br>"`https://user@example.org`"<br><br>"`ssh://user@example.org`" |
| **host-missing** | Yes
| The input has a special scheme, but does not contain a host.<br><br>"`https://#fragment`"<br><br>"`https://:443`"<br><br>"`https://user:pass@`" |
| **port-out-of-range** | Yes
| The input's port is too big.<br><br>"`https://example.org:70000`" |
| **port-invalid** | Yes
| The input's port is invalid.<br><br>"`https://example.org:7z`" |
| **file-invalid-Windows-drive-letter** | ·
| The input is a relative-URL string that starts with a Windows drive letter and the base URL's scheme is "`file`".<br><br>```javascript<br>const url = new URL("/c:/path/to/file", "file:///c:/");<br>``` |
| **file-invalid-Windows-drive-letter-host** | ·
| A `file:` URL's host is a Windows drive letter.<br><br>"`file://c:`" |


### Parsers

The **EOF code point** is a conceptual code point that signifies the end of a string or code point stream.

A **pointer** for a string `input` is an integer that points to a code point within `input`. Initially it points to the start of `input`. If it is −1 it points nowhere. If it is greater than or equal to `input`'s code point length, it points to the EOF code point.

When a pointer is used, **c** references the code point the pointer points to as long as it does not point nowhere. When the pointer points to nowhere c cannot be used.

When a pointer is used, **remaining** references the code point substring from the pointer + 1 to the end of the string, as long as c is not the EOF code point. When c is the EOF code point remaining cannot be used.

If "`mailto:username@example`" is a string being processed and a pointer points to @, c is U+0040 (@) and remaining is "`example`".

If the empty string is being processed and a pointer points to the start and is then decreased by 1, using c or remaining would be an error.


### Percent-encoded bytes

A **percent-encoded byte** is U+0025 (%), followed by two ASCII hex digits.

It is generally a good idea for sequences of percent-encoded bytes to be such that, when percent-decoded and then passed to UTF-8 decode without BOM or fail, they do not end up as failure. How important this is depends on where the percent-encoded bytes are used. E.g., for the host parser not following this advice is fatal, whereas for URL rendering the percent-encoded bytes would not be rendered percent-decoded.

To **percent-encode** a byte `byte`, return a string consisting of U+0025 (%), followed by two ASCII upper hex digits representing `byte`.

To **percent-decode** a byte sequence `input`, run these steps:

Using anything but UTF-8 decode without BOM when `input` contains bytes that are not ASCII bytes might be insecure and is not recommended.

1. Let `output` be an empty byte sequence.

2. For each byte `byte` in `input`:

   1. If `byte` is not 0x25 (%), then append `byte` to `output`.

   2. Otherwise, if `byte` is 0x25 (%) and the next two bytes after `byte` in `input` are not in the ranges 0x30 (0) to 0x39 (9), 0x41 (A) to 0x46 (F), and 0x61 (a) to 0x66 (f), all inclusive, append `byte` to `output`.

   3. Otherwise:

      1. Let `bytePoint` be the two bytes after `byte` in `input`, decoded, and then interpreted as hexadecimal number.

      2. Append a byte whose value is `bytePoint` to `output`.

      3. Skip the next two bytes in `input`.

3. Return `output`.

To **percent-decode** a scalar value string `input`:

1. Let `bytes` be the UTF-8 encoding of `input`.

2. Return the percent-decoding of `bytes`.

In general, percent-encoding results in a string with more U+0025 (%) code points than the input, and percent-decoding results in a byte sequence with less 0x25 (%) bytes than the input.

The **C0 control percent-encode set** are the C0 controls and all code points greater than U+007E (~).

The **fragment percent-encode set** is the C0 control percent-encode set and U+0020 SPACE, U+0022 ("), U+003C (<), U+003E (>), and U+0060 (`).

The **query percent-encode set** is the C0 control percent-encode set and U+0020 SPACE, U+0022 ("), U+0023 (#), U+003C (<), and U+003E (>).

The query percent-encode set cannot be defined in terms of the fragment percent-encode set due to the omission of U+0060 (`).

The **special-query percent-encode set** is the query percent-encode set and U+0027 (').

The **path percent-encode set** is the query percent-encode set and U+003F (?), U+005E (^), U+0060 (`), U+007B ({), and U+007D (}).

The **userinfo percent-encode set** is the path percent-encode set and U+002F (/), U+003A (:), U+003B (;), U+003D (=), U+0040 (@), U+005B ([) to U+005D (]), inclusive, and U+007C (|).

The **component percent-encode set** is the userinfo percent-encode set and U+0024 ($) to U+0026 (&), inclusive, U+002B (+), and U+002C (,).

This is used by HTML for `registerProtocolHandler()`, and could also be used by other standards to percent-encode data that can then be embedded in a URL's path, query, or fragment; or in an opaque host. Using it with UTF-8 percent-encode gives identical results to JavaScript's `encodeURIComponent()` [sic]. [HTML] [ECMA-262]

The **`application/x-www-form-urlencoded` percent-encode set** is the component percent-encode set and U+0021 (!), U+0027 (') to U+0029 RIGHT PARENTHESIS, inclusive, and U+007E (~).

The `application/x-www-form-urlencoded` percent-encode set contains all code points, except the ASCII alphanumeric, U+002A (*), U+002D (-), U+002E (.), and U+005F (_).

To **percent-encode after encoding**, given an encoding `encoding`, scalar value string `input`, a `percentEncodeSet`, and an optional boolean `spaceAsPlus` (default false):

1. Let `encoder` be the result of getting an encoder from `encoding`.

2. Let `inputQueue` be `input` converted to an I/O queue.

3. Let `output` be the empty string.

4. Let `potentialError` be 0.

   This needs to be a non-null value to initiate the subsequent while loop.

5. While `potentialError` is non-null:

   1. Let `encodeOutput` be an empty I/O queue.

   2. Set `potentialError` to the result of running encode or fail with `inputQueue`, `encoder`, and `encodeOutput`.

   3. For each `byte` of `encodeOutput` converted to a byte sequence:

      1. If `spaceAsPlus` is true and `byte` is 0x20 (SP), then append U+002B (+) to `output` and continue.

      2. Let `isomorph` be a code point whose value is `byte`'s value.

      3. Assert: `percentEncodeSet` includes all non-ASCII code points.

      4. If `isomorph` is not in `percentEncodeSet`, then append `isomorph` to `output`.

      5. Otherwise, percent-encode `byte` and append the result to `output`.

   4. If `potentialError` is non-null, then append "`%26%23`", followed by the shortest sequence of ASCII digits representing `potentialError` in base ten, followed by "`%3B`", to `output`.

      This can happen when `encoding` is not UTF-8.

6. Return `output`.

Of the possible values for the `percentEncodeSet` argument only two end up encoding U+0025 (%) and thus give "roundtripable data": component percent-encode set and `application/x-www-form-urlencoded` percent-encode set. The other values for the `percentEncodeSet` argument — which happen to be used by the URL parser — leave U+0025 (%) untouched and as such it needs to be percent-encoded first in order to be properly represented.

To **UTF-8 percent-encode** a scalar value `scalarValue` using a `percentEncodeSet`, return the result of running percent-encode after encoding with UTF-8, `scalarValue` as a string, and `percentEncodeSet`.

To **UTF-8 percent-encode** a scalar value string `input` using a `percentEncodeSet`, return the result of running percent-encode after encoding with UTF-8, `input`, and `percentEncodeSet`.

Here is a summary, by way of example, of the operations defined above:

Operation | Input | Output
--- | --- | ---
Percent-encode `input` | 0x23 | "`%23`"
| 0x7F | "`%7F`"
Percent-decode `input` | `%25%s%1G` | `%%s%1G`
Percent-decode `input` | "`‽%25%2E`" | 0xE2 0x80 0xBD 0x25 0x2E
Percent-encode after encoding with Shift_JIS, `input`, and the userinfo percent-encode set | "` `" | "`%20`"
| "`≡`" | "`%81%DF`"
| "`‽`" | "`%26%238253%3B`"
Percent-encode after encoding with ISO-2022-JP, `input`, and the userinfo percent-encode set | "`¥`" | "`%1B(J\%1B(B`"
Percent-encode after encoding with Shift_JIS, `input`, the userinfo percent-encode set, and true | "`1+1 ≡ 2%20‽`" | "`1+1+%81%DF+2%20%26%238253%3B`"
UTF-8 percent-encode `input` using the userinfo percent-encode set | U+2261 (≡) | "`%E2%89%A1`"
| U+203D (‽) | "`%E2%80%BD`"
UTF-8 percent-encode `input` using the userinfo percent-encode set | "`Say what‽`" | "`Say%20what%E2%80%BD`"


## Security considerations

The security of a URL is a function of its environment. Care is to be taken when rendering, interpreting, and passing URLs around.

When rendering and allocating new URLs "spoofing" needs to be considered. An attack whereby one host or URL can be confused for another. For instance, consider how 1/l/I, m/rn/rri, 0/O, and а/a can all appear eerily similar. Or worse, consider how U+202A LEFT-TO-RIGHT EMBEDDING and similar code points are invisible. [[UTR36]](#biblio-utr36)

When passing a URL from party A to B, both need to carefully consider what is happening. A might end up leaking data it does not want to leak. B might receive input it did not expect and take an action that harms the user. In particular, B should never trust A, as at some point URLs from A can come from untrusted sources.


## Hosts (domains and IP addresses)

At a high level, a host, valid host string, host parser, and host serializer relate as follows:

- The host parser takes an arbitrary scalar value string and returns either failure or a host.

- A host can be seen as the in-memory representation.

- A valid host string defines what input would not trigger a validation error or failure when given to the host parser. I.e., input that would be considered conforming or valid.

- The host serializer takes a host and returns an ASCII string. (If that string is then parsed, the result will equal the host that was serialized.)

A parse-serialize roundtrip gives the following results, depending on the `isOpaque` argument to the host parser:

Input | Output (`isOpaque` = false) | Output (`isOpaque` = true)
--- | --- | ---
`EXAMPLE.COM` | `example.com` (domain) | `EXAMPLE.COM` (opaque host)
`example%2Ecom` | `example%2Ecom` (opaque host) | `example%2Ecom` (opaque host)
`faß.example` | `xn--fa-hia.example` (domain) | `fa%C3%9F.example` (opaque host)
`0` | `0.0.0.0` (IPv4) | `0` (opaque host)
`%30` | `%30` (opaque host) | `%30` (opaque host)
`0x` | `0x` (opaque host) | `0x` (opaque host)
`0xffffffff` | `255.255.255.255` (IPv4) | `0xffffffff` (opaque host)
`[0:0::1]` | `[::1]` (IPv6) | `[0:0::1]` (IPv6)
`[0:0::1%5D` | Failure | Failure
`[0:0::%31]` | Failure | Failure
`09` | Failure | `09` (opaque host)
`example.255` | `example.255` (opaque host) | `example.255` (opaque host)
`example^example` | Failure | Failure


### Host representation

A host is a domain, an IP address, an opaque host, or an empty host. Typically a host serves as a network address, but it is sometimes used as opaque identifier in URLs where a network address is not necessary.

A typical URL whose host is an opaque host is `git://github.com/whatwg/url.git`.

The RFCs referenced in the paragraphs below are for informative purposes only. They have no influence on host writing, parsing, and serialization. Unless stated otherwise in the sections that follow.

A domain is a non-empty ASCII string that identifies a realm within a network. [RFC1034]

The domain labels of a domain `domain` are the result of strictly splitting `domain` on U+002E (.).

The `example.com` and `example.com.` domains are not equivalent and typically treated as distinct.

An IP address is an IPv4 address or an IPv6 address.

An IPv4 address is a 32-bit unsigned integer that identifies a network address. [RFC791]

An IPv6 address is a 128-bit unsigned integer that identifies a network address. This integer is composed of a list of 8 16-bit unsigned integers, also known as an IPv6 address's pieces. [RFC4291]

Support for `<zone_id>` is intentionally omitted.

An opaque host is a non-empty ASCII string that can be used for further processing.

An empty host is the empty string.


### Host miscellaneous

A forbidden host code point is U+0000 NULL, U+0009 TAB, U+000A LF, U+000D CR, U+0020 SPACE, U+0023 (#), U+002F (/), U+003A (:), U+003C (<), U+003E (>), U+003F (?), U+0040 (@), U+005B ([), U+005C (\), U+005D (]), U+005E (^), or U+007C (|).

A forbidden domain code point is a forbidden host code point, a C0 control, U+0025 (%), or U+007F DELETE.

To obtain the public suffix of a host `host`, run these steps. They return null or a domain representing a portion of `host` that is included on the Public Suffix List. [PSL]

1. If `host` is not a domain, then return null.

2. Let `trailingDot` be "`.`" if `host` ends with "`.`"; otherwise the empty string.

3. Let `publicSuffix` be the public suffix determined by running the Public Suffix List algorithm with `host` as domain. [PSL]

4. Assert: `publicSuffix` is an ASCII string that does not end with "`.`".

5. Return `publicSuffix` and `trailingDot` concatenated.

To obtain the registrable domain of a host `host`, run these steps. They return null or a domain formed by `host`'s public suffix and the domain label preceding it, if any.

1. If `host`'s public suffix is null or `host`'s public suffix equals `host`, then return null.

2. Let `trailingDot` be "`.`" if `host` ends with "`.`"; otherwise the empty string.

3. Let `registrableDomain` be the registrable domain determined by running the Public Suffix List algorithm with `host` as domain. [PSL]

4. Assert: `registrableDomain` is an ASCII string that does not end with "`.`".

5. Return `registrableDomain` and `trailingDot` concatenated.

Host input | Public suffix | Registrable domain
--- | --- | ---
`com` | `com` | null
`example.com` | `com` | `example.com`
`www.example.com` | `com` | `example.com`
`sub.www.example.com` | `com` | `example.com`
`EXAMPLE.COM` | `com` | `example.com`
`example.com.` | `com.` | `example.com.`
`github.io` | `github.io` | null
`whatwg.github.io` | `github.io` | `whatwg.github.io`
`إختبار` | `xn--kgbechtv` | null
`example.إختبار` | `xn--kgbechtv` | `example.xn--kgbechtv`
`sub.example.إختبار` | `xn--kgbechtv` | `example.xn--kgbechtv`
`[2001:0db8:85a3:0000:0000:8a2e:0370:7334]` | null | null

Specifications should prefer the origin concept for security decisions. The notion of "public suffix" and "registrable domain" cannot be relied-upon to provide a hard security boundary, as the public suffix list will diverge from client to client. Specifications which ignore this advice are encouraged to carefully consider whether URLs' schemes ought to be incorporated into any decisions made, i.e. whether to use the same site or schemelessly same site concepts.


### IDNA

The domain to ASCII algorithm, given a string `domain` and a boolean `beStrict`, runs these steps:

1. Let `result` be the result of running Unicode ToASCII with *domain_name* set to `domain`, *CheckHyphens* set to `beStrict`, *CheckBidi* set to true, *CheckJoiners* set to true, *UseSTD3ASCIIRules* set to `beStrict`, *Transitional_Processing* set to false, *VerifyDnsLength* set to `beStrict`, and *IgnoreInvalidPunycode* set to false. [UTS46]

   If `beStrict` is false, `domain` is an ASCII string, and strictly splitting `domain` on U+002E (.) does not produce any item that starts with an ASCII case-insensitive match for "`xn--`", this step is equivalent to ASCII lowercasing `domain`.

2. If `result` is a failure value, domain-to-ASCII validation error, return failure.

3. If `beStrict` is false:

   1. If `result` is the empty string, domain-to-ASCII validation error, return failure.

   2. If `result` contains a forbidden domain code point, domain-invalid-code-point validation error, return failure.

      Due to web compatibility and compatibility with non-DNS-based systems the forbidden domain code points are a subset of those disallowed when *UseSTD3ASCIIRules* is true. See also issue #397.

4. Assert: `result` is not the empty string and does not contain a forbidden domain code point.

   Unicode IDNA Compatibility Processing guarantees this holds when `beStrict` is true. [UTS46]

5. Return `result`.

This document and the web platform at large use Unicode IDNA Compatibility Processing and not IDNA2008. For instance, `☕.example` becomes `xn--53h.example` and not failure. [UTS46] [RFC5890]

The domain to Unicode algorithm, given a domain `domain` and a boolean `beStrict`, runs these steps:

1. Let `result` be the result of running Unicode ToUnicode with *domain_name* set to `domain`, *CheckHyphens* set to `beStrict`, *CheckBidi* set to true, *CheckJoiners* set to true, *UseSTD3ASCIIRules* set to `beStrict`, *Transitional_Processing* set to false, and *IgnoreInvalidPunycode* set to false. [UTS46]

2. Signify domain-to-Unicode validation errors for any returned errors, and then, return `result`.


### Host writing

A valid host string must be a valid domain string, a valid IPv4-address string, or: U+005B ([), followed by a valid IPv6-address string, followed by U+005D (]).

A string `input` is a valid domain if these steps return true:

1. Let `domain` be the result of running domain to ASCII with `input` and true.

2. Return false if `domain` is failure; otherwise true.

Ideally we define this in terms of a sequence of code points that make up a valid domain rather than through a whack-a-mole: issue 245.

A valid domain string must be a string that is a valid domain.

A valid IPv4-address string must be four shortest possible strings of ASCII digits, representing a decimal number in the range 0 to 255, inclusive, separated from each other by U+002E (.).

A valid IPv6-address string is defined in the "Text Representation of Addresses" chapter of IP Version 6 Addressing Architecture. [RFC4291]

A valid opaque-host string must be one of the following:

- one or more URL units excluding forbidden host code points

- U+005B ([), followed by a valid IPv6-address string, followed by U+005D (]).

This is not part of the definition of valid host string as it requires context to be distinguished.


### Host parsing

The host parser takes a scalar value string `input` with an optional boolean `isOpaque` (default false), and then runs these steps. They return failure or a host.

1. If `input` starts with U+005B ([), then:

   1. If `input` does not end with U+005D (]), IPv6-unclosed validation error, return failure.

   2. Return the result of IPv6 parsing `input` with its leading U+005B ([) and trailing U+005D (]) removed.

2. If `isOpaque` is true, then return the result of opaque-host parsing `input`.

3. Assert: `input` is not the empty string.

4. Let `domain` be the result of running UTF-8 decode without BOM on the percent-decoding of `input`.

   Alternatively UTF-8 decode without BOM or fail can be used, coupled with an early return for failure, as domain to ASCII fails on U+FFFD (�).

5. Let `asciiDomain` be the result of running domain to ASCII with `domain` and false.

6. If `asciiDomain` is failure, then return failure.

7. If `asciiDomain` ends in a number, then return the result of IPv4 parsing `asciiDomain`.

8. Return `asciiDomain`.

The ends in a number checker takes an ASCII string `input` and then runs these steps. They return a boolean.

1. Let `parts` be the result of strictly splitting `input` on U+002E (.).

2. If the last item in `parts` is the empty string, then:

   1. If `parts`'s size is 1, then return false.

   2. Remove the last item from `parts`.

3. Let `last` be the last item in `parts`.

4. If `last` is non-empty and contains only ASCII digits, then return true.

   The erroneous input "`09`" will be caught by the IPv4 parser at a later stage.

5. If parsing `last` as an IPv4 number does not return failure, then return true.

   This is equivalent to checking that `last` is "`0X`" or "`0x`", followed by zero or more ASCII hex digits.

6. Return false.

The IPv4 parser takes an ASCII string `input` and then runs these steps. They return failure or an IPv4 address.

The IPv4 parser is not to be invoked directly. Instead check that the return value of the host parser is an IPv4 address.

1. Let `parts` be the result of strictly splitting `input` on U+002E (.).

2. If the last item in `parts` is the empty string, then:

   1. IPv4-empty-part validation error.

   2. If `parts`'s size is greater than 1, then remove the last item from `parts`.

3. If `parts`'s size is greater than 4, IPv4-too-many-parts validation error, return failure.

4. Let `numbers` be an empty list.

5. For each `part` of `parts`:

   1. Let `result` be the result of parsing `part`.

   2. If `result` is failure, IPv4-non-numeric-part validation error, return failure.

   3. If `result`[1] is true, IPv4-non-decimal-part validation error.

   4. Append `result`[0] to `numbers`.

6. If any item in `numbers` is greater than 255, IPv4-out-of-range-part validation error.

7. If any but the last item in `numbers` is greater than 255, then return failure.

8. If the last item in `numbers` is greater than or equal to 256^(5 − `numbers`'s size)^, then return failure.

9. Let `ipv4` be the last item in `numbers`.

10. Remove the last item from `numbers`.

11. Let `counter` be 0.

12. For each `n` of `numbers`:

    1. Increment `ipv4` by `n` × 256^(3 − `counter`)^.

    2. Increment `counter` by 1.

13. Return `ipv4`.

The IPv4 number parser takes an ASCII string `input` and then runs these steps. They return failure or a tuple of a number and a boolean.

1. If `input` is the empty string, then return failure.

2. Let `validationError` be false.

3. Let `R` be 10.

4. If `input` contains at least two code points and the first two code points are either "`0X`" or "`0x`", then:

   1. Set `validationError` to true.

   2. Remove the first two code points from `input`.

   3. Set `R` to 16.

5. Otherwise, if `input` contains at least two code points and the first code point is U+0030 (0), then:

   1. Set `validationError` to true.

   2. Remove the first code point from `input`.

   3. Set `R` to 8.

6. If `input` is the empty string, then return (0, true).

7. If `input` contains a code point that is not a radix-`R` digit, then return failure.

8. Let `output` be the mathematical integer value that is represented by `input` in radix-`R` notation, using ASCII hex digits for digits with values 0 through 15.

9. Return (`output`, `validationError`).

The IPv6 parser takes a scalar value string `input` and then runs these steps. They return failure or an IPv6 address.

The IPv6 parser could in theory be invoked directly, but please discuss actually doing that with the editors of this document first.

1. Let `address` be a new IPv6 address whose pieces are all 0.

2. Let `pieceIndex` be 0.

3. Let `compress` be null.

4. Let `pointer` be a pointer for `input`.

5. If c is U+003A (:), then:

   1. If remaining does not start with U+003A (:), IPv6-invalid-compression validation error, return failure.

   2. Increase `pointer` by 2.

   3. Increase `pieceIndex` by 1 and then set `compress` to `pieceIndex`.

6. While c is not the EOF code point:

   1. If `pieceIndex` is 8, IPv6-too-many-pieces validation error, return failure.

   2. If c is U+003A (:), then:

      1. If `compress` is non-null, IPv6-multiple-compression validation error, return failure.

      2. Increase `pointer` and `pieceIndex` by 1, set `compress` to `pieceIndex`, and then continue.

   3. Let `value` and `length` be 0.

   4. While `length` is less than 4 and c is an ASCII hex digit, set `value` to `value` × 0x10 + c interpreted as hexadecimal number, and increase `pointer` and `length` by 1.

   5. If c is U+002E (.), then:

      1. If `length` is 0, IPv4-in-IPv6-invalid-code-point validation error, return failure.

      2. Decrease `pointer` by `length`.

      3. If `pieceIndex` is greater than 6, IPv4-in-IPv6-too-many-pieces validation error, return failure.

      4. Let `numbersSeen` be 0.

      5. While c is not the EOF code point:

         1. Let `ipv4Piece` be null.

         2. If `numbersSeen` is greater than 0, then:

            1. If c is a U+002E (.) and `numbersSeen` is less than 4, then increase `pointer` by 1.

            2. Otherwise, IPv4-in-IPv6-invalid-code-point validation error, return failure.

         3. If c is not an ASCII digit, IPv4-in-IPv6-invalid-code-point validation error, return failure.

         4. While c is an ASCII digit:

            1. Let `number` be c interpreted as decimal number.

            2. If `ipv4Piece` is null, then set `ipv4Piece` to `number`.

               Otherwise, if `ipv4Piece` is 0, IPv4-in-IPv6-invalid-code-point validation error, return failure.

               Otherwise, set `ipv4Piece` to `ipv4Piece` × 10 + `number`.

            3. If `ipv4Piece` is greater than 255, IPv4-in-IPv6-out-of-range-part validation error, return failure.

            4. Increase `pointer` by 1.

         5. Set `address`[`pieceIndex`] to `address`[`pieceIndex`] × 0x100 + `ipv4Piece`.

         6. Increase `numbersSeen` by 1.

         7. If `numbersSeen` is 2 or 4, then increase `pieceIndex` by 1.

      6. If `numbersSeen` is not 4, IPv4-in-IPv6-too-few-parts validation error, return failure.

      7. Break.

   6. Otherwise, if c is U+003A (:):

      1. Increase `pointer` by 1.

      2. If c is the EOF code point, IPv6-invalid-code-point validation error, return failure.

   7. Otherwise, if c is not the EOF code point, IPv6-invalid-code-point validation error, return failure.

   8. Set `address`[`pieceIndex`] to `value`.

   9. Increase `pieceIndex` by 1.

7. If `compress` is non-null, then:

   1. Let `swaps` be `pieceIndex` − `compress`.

   2. Set `pieceIndex` to 7.

   3. While `pieceIndex` is not 0 and `swaps` is greater than 0, swap `address`[`pieceIndex`] with `address`[`compress` + `swaps` − 1], and then decrease both `pieceIndex` and `swaps` by 1.

8. Otherwise, if `compress` is null and `pieceIndex` is not 8, IPv6-too-few-pieces validation error, return failure.

9. Return `address`.

The opaque-host parser takes a scalar value string `input`, and then runs these steps. They return failure or an opaque host.

1. If `input` contains a forbidden host code point, host-invalid-code-point validation error, return failure.

2. If `input` contains a code point that is not a URL code point and not U+0025 (%), invalid-URL-unit validation error.

3. If `input` contains a U+0025 (%) and the two code points following it are not ASCII hex digits, invalid-URL-unit validation error.

4. Return the result of running UTF-8 percent-encode on `input` using the C0 control percent-encode set.


### Host serializing

The host serializer takes a host `host` and then runs these steps. They return an ASCII string.

1. If `host` is an IPv4 address, return the result of running the IPv4 serializer on `host`.

2. Otherwise, if `host` is an IPv6 address, return U+005B ([), followed by the result of running the IPv6 serializer on `host`, followed by U+005D (]).

3. Otherwise, `host` is a domain, opaque host, or empty host, return `host`.

The IPv4 serializer takes an IPv4 address `address` and then runs these steps. They return an ASCII string.

1. Let `output` be the empty string.

2. Let `n` be the value of `address`.

3. For each `i` in the range 1 to 4, inclusive:

   1. Prepend `n` % 256, serialized, to `output`.

   2. If `i` is not 4, then prepend U+002E (.) to `output`.

   3. Set `n` to floor(`n` / 256).

4. Return `output`.

The IPv6 serializer takes an IPv6 address `address` and then runs these steps. They return an ASCII string.

1. Let `output` be the empty string.

2. Let `compress` be the result of finding the IPv6 address compressed piece index given `address`.

3. Let `ignore0` be false.

4. For each `pieceIndex` of `address`'s pieces's indices:

   1. If `ignore0` is true and `address`[`pieceIndex`] is 0, then continue.

   2. Otherwise, if `ignore0` is true, set `ignore0` to false.

   3. If `compress` is `pieceIndex`, then:

      1. Let `separator` be "`::` if `pieceIndex` is 0; otherwise U+003A (:).

      2. Append `separator` to `output`.

      3. Set `ignore0` to true and continue.

   4. Append `address`[`pieceIndex`], represented as the shortest possible lowercase hexadecimal number, to `output`.

   5. If `pieceIndex` is not 7, then append U+003A (:) to `output`.

5. Return `output`.

This algorithm requires the recommendation from A Recommendation for IPv6 Address Text Representation. [RFC5952]

To find the IPv6 address compressed piece index given an IPv6 address `address`:

1. Let `longestIndex` be null.

2. Let `longestSize` be 1.

3. Let `foundIndex` be null.

4. Let `foundSize` be 0.

5. For each `pieceIndex` of `address`'s pieces's indices:

   1. If `address`'s pieces[`pieceIndex`] is not 0:

      1. If `foundSize` is greater than `longestSize`, then set `longestIndex` to `foundIndex` and `longestSize` to `foundSize`.

      2. Set `foundIndex` to null.

      3. Set `foundSize` to 0.

   2. Otherwise:

      1. If `foundIndex` is null, then set `foundIndex` to `pieceIndex`.

      2. Increment `foundSize` by 1.

6. If `foundSize` is greater than `longestSize`, then return `foundIndex`.

7. Return `longestIndex`.

In `0:f:0:0:f:f:0:0` it would point to the second 0.


### Host equivalence

To determine whether a host `A` equals host `B`, return true if `A` is `B`, and false otherwise.

Certificate comparison requires a host equivalence check that ignores the trailing dot of a domain (if any). However, those hosts have also various other facets enforced, such as DNS length, that are not enforced here, as URLs do not enforce them. If anyone has a good suggestion for how to bring these two closer together, or what a good unified model would be, please file an issue.


## URLs

At a high level, a [URL](#concept-url), [valid URL string](#valid-url-string), [URL parser](#concept-url-parser), and [URL serializer](#concept-url-serializer) relate as follows:

- The [URL parser](#concept-url-parser) takes an arbitrary [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string) and returns either failure or a [URL](#concept-url). It might also record zero or more [validation errors](#validation-error).

- A [URL](#concept-url) can be seen as the in-memory representation.

- A [valid URL string](#valid-url-string) defines what input would not trigger a [validation error](#validation-error) or failure when given to the [URL parser](#concept-url-parser). I.e., input that would be considered conforming or valid.

- The [URL serializer](#concept-url-serializer) takes a [URL](#concept-url) and returns an [ASCII string](https://infra.spec.whatwg.org/#ascii-string). (If that string is then [parsed](#concept-url-parser), the result will [equal](#concept-url-equals) the [URL](#concept-url) that was [serialized](#concept-url-serializer).) The output of the [URL serializer](#concept-url-serializer) is not always a [valid URL string](#valid-url-string).

Input | Base | Valid | Output
---|---|---|---
`https:example.org` | | ❌ | `https://example.org/`
`https://////example.com///` | | ❌ | `https://example.com///`
`https://example.com/././foo` | | ✅ | `https://example.com/foo`
`hello:world` | `https://example.com/` | ✅ | `hello:world`
`https:example.org` | `https://example.com/` | ❌ | `https://example.com/example.org`
`\example\..\demo/.\` | `https://example.com/` | ❌ | `https://example.com/demo/`
`example` | `https://example.com/demo` | ✅ | `https://example.com/example`
`file:///C|/demo` | | ❌ | `file:///C:/demo`
`..` | `file:///C:/demo` | ✅ | `file:///C:/`
`file://loc%61lhost/` | | ✅ | `file:///`
`https://user:password@example.org/` | | ❌ | `https://user:password@example.org/`
`https://example.org/foo bar` | | ❌ | `https://example.org/foo%20bar`
`https://EXAMPLE.com/../x` | | ✅ | `https://example.com/x`
`https://ex ample.org/` | | ❌ | Failure
`example` | | ❌, due to lack of base | Failure
`https://example.com:demo` | | ❌ | Failure
`http://[www.example.com]/` | | ❌ | Failure
`https://example.org//` | | ✅ | `https://example.org//`
`https://example.com/[]?[]#[]` | | ❌ | `https://example.com/[]?[]#[]`
`https://example/%?%#%` | | ❌ | `https://example/%?%#%`
`https://example/%25?%25#%25` | | ✅ | `https://example/%25?%25#%25`

The base and output [URL](#concept-url) are represented in [serialized](#concept-url-serializer) form for brevity.


### URL representation

A [URL](#concept-url) is a [struct](https://infra.spec.whatwg.org/#struct) that represents a universal identifier. To disambiguate from a [valid URL string](#valid-url-string) it can also be referred to as a [URL record](#concept-url).

A [URL](#concept-url)'s [scheme](#concept-url-scheme) is an [ASCII string](https://infra.spec.whatwg.org/#ascii-string) that identifies the type of [URL](#concept-url) and can be used to dispatch a [URL](#concept-url) for further processing after [parsing](#concept-url-parser). It is initially the empty string.

A [URL](#concept-url)'s [username](#concept-url-username) is an [ASCII string](https://infra.spec.whatwg.org/#ascii-string) identifying a username. It is initially the empty string.

A [URL](#concept-url)'s [password](#concept-url-password) is an [ASCII string](https://infra.spec.whatwg.org/#ascii-string) identifying a password. It is initially the empty string.

A [URL](#concept-url)'s [host](#concept-url-host) is null or a [host](#concept-host). It is initially null.

The following table lists allowed [URL](#concept-url)'s [scheme](#concept-url-scheme) / [host](#concept-url-host) combinations.

[scheme](#concept-url-scheme) | [host](#concept-url-host) | [domain](#concept-domain) | [IPv4 address](#concept-ipv4) | [IPv6 address](#concept-ipv6) | [opaque host](#opaque-host) | [empty host](#empty-host) | null
---|---|---|---|---|---|---|---
[Special schemes](#special-scheme) excluding "`file`" | ✅ | ✅ | ✅ | ❌ | ❌ | ❌
"`file`" | ✅ | ✅ | ✅ | ❌ | ✅ | ❌
Others | ❌ | ❌ | ✅ | ✅ | ✅ | ✅

A [URL](#concept-url)'s [port](#concept-url-port) is either null or a [16-bit unsigned integer](https://infra.spec.whatwg.org/#16-bit-unsigned-integer) that identifies a networking port. It is initially null.

A [URL](#concept-url)'s [path](#concept-url-path) is a [URL path](#url-path), usually identifying a location. It is initially « ».

A [special](#is-special) [URL](#concept-url)'s [path](#concept-url-path) is always a [list](https://infra.spec.whatwg.org/#list), i.e., it is never [opaque](#url-opaque-path).

A [URL](#concept-url)'s [query](#concept-url-query) is either null or an [ASCII string](https://infra.spec.whatwg.org/#ascii-string). It is initially null.

A [URL](#concept-url)'s [fragment](#concept-url-fragment) is either null or an [ASCII string](https://infra.spec.whatwg.org/#ascii-string) that can be used for further processing on the resource the [URL](#concept-url)'s other components identify. It is initially null.

A [URL](#concept-url) also has an associated [blob URL entry](#concept-url-blob-entry) that is either null or a [blob URL entry](https://w3c.github.io/FileAPI/#blob-url-entry). It is initially null.

This is used to support caching the object a "`blob`" URL refers to as well as its origin. It is important that these are cached as the [URL](#concept-url) might be removed from the [blob URL store](https://w3c.github.io/FileAPI/#BlobURLStore) between parsing and fetching, while fetching will still need to succeed.

The following table lists how [valid URL strings](#valid-url-string), when [parsed](#concept-url-parser), map to a [URL](#concept-url)'s components. [Username](#concept-url-username), [password](#concept-url-password), and [blob URL entry](#concept-url-blob-entry) are omitted; in the examples below they are the empty string, the empty string, and null, respectively.

Input | [Scheme](#concept-url-scheme) | [Host](#concept-url-host) | [Port](#concept-url-port) | [Path](#concept-url-path) | [Query](#concept-url-query) | [Fragment](#concept-url-fragment)
---|---|---|---|---|---|---
`https://example.com/` | "`https`" | "`example.com`" | null | « the empty string » | null | null
`https://localhost:8000/search?q=text#hello` | "`https`" | "`localhost`" | 8000 | « "`search`" » | "`q=text`" | "`hello`"
`urn:isbn:9780307476463` | "`urn`" | null | null | "`isbn:9780307476463`" | null | null
`file:///ada/Analytical%20Engine/README.md` | "`file`" | null | null | « "`ada`", "`Analytical%20Engine`", "`README.md`" » | null | null

---

A [URL path](#url-path) is either a [URL path segment](#url-path-segment) or a [list](https://infra.spec.whatwg.org/#list) of zero or more [URL path segments](#url-path-segment).

A [URL path segment](#url-path-segment) is an [ASCII string](https://infra.spec.whatwg.org/#ascii-string). It commonly refers to a directory or a file, but has no predefined meaning.

A [single-dot URL path segment](#single-dot-path-segment) is a [URL path segment](#url-path-segment) that is "`.`" or an [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for "`%2e`".

A [double-dot URL path segment](#double-dot-path-segment) is a [URL path segment](#url-path-segment) that is "`..`" or an [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for "`.%2e`", "`%2e.`", or "`%2e%2e`".


### URL miscellaneous

A [special scheme](#special-scheme) is an [ASCII string](https://infra.spec.whatwg.org/#ascii-string) that is listed in the first column of the following table. The [default port](#default-port) for a [special scheme](#special-scheme) is listed in the second column on the same row. The [default port](#default-port) for any other [ASCII string](https://infra.spec.whatwg.org/#ascii-string) is null.

[Special scheme](#special-scheme) | [Default port](#default-port)
---|---
"`ftp`" | 21
"`file`" | null
"`http`" | 80
"`https`" | 443
"`ws`" | 80
"`wss`" | 443

A [URL](#concept-url) [is special](#is-special) if its [scheme](#concept-url-scheme) is a [special scheme](#special-scheme). A [URL](#concept-url) [is not special](#is-not-special) if its [scheme](#concept-url-scheme) is not a [special scheme](#special-scheme).

A [URL](#concept-url) [includes credentials](#include-credentials) if its [username](#concept-url-username) or [password](#concept-url-password) is not the empty string.

A [URL](#concept-url) has an [opaque path](#url-opaque-path) if its [path](#concept-url-path) is a [URL path segment](#url-path-segment).

A [URL](#concept-url) [cannot have a username/password/port](#cannot-have-a-username-password-port) if its [host](#concept-url-host) is null or the empty string, or its [scheme](#concept-url-scheme) is "`file`".

A [URL](#concept-url) can be designated as [base URL](#concept-base-url).

A [base URL](#concept-base-url) is useful for the [URL parser](#concept-url-parser) when the input might be a [relative-URL string](#relative-url-string).

---

A [Windows drive letter](#windows-drive-letter) is two code points, of which the first is an [ASCII alpha](https://infra.spec.whatwg.org/#ascii-alpha) and the second is either U+003A (:) or U+007C (|).

A [normalized Windows drive letter](#normalized-windows-drive-letter) is a [Windows drive letter](#windows-drive-letter) of which the second code point is U+003A (:).

As per the [URL writing](#url-writing) section, only a [normalized Windows drive letter](#normalized-windows-drive-letter) is conforming.

A string [starts with a Windows drive letter](#start-with-a-windows-drive-letter) if all of the following are true:

- its [length](https://infra.spec.whatwg.org/#string-length) is greater than or equal to 2
- its first two code points are a [Windows drive letter](#windows-drive-letter)
- its [length](https://infra.spec.whatwg.org/#string-length) is 2 or its third code point is U+002F (/), U+005C (\\), U+003F (?), or U+0023 (#).

String | Starts with a Windows drive letter
---|---
"`c:`" | ✅
"`c:/`" | ✅
"`c:a`" | ❌

To [shorten a `url`'s path](#shorten-a-urls-path):

1. [Assert](https://infra.spec.whatwg.org/#assert): `url` does not have an [opaque path](#url-opaque-path).

2. Let `path` be `url`'s [path](#concept-url-path).

3. If `url`'s [scheme](#concept-url-scheme) is "`file`", `path`'s [size](https://infra.spec.whatwg.org/#list-size) is 1, and `path`[0] is a [normalized Windows drive letter](#normalized-windows-drive-letter), then return.

4. [Remove](https://infra.spec.whatwg.org/#list-remove) `path`'s last item, if any.


### URL writing

A [valid URL string](#valid-url-string) must be either a [relative-URL-with-fragment string](#relative-url-with-fragment-string) or an [absolute-URL-with-fragment string](#absolute-url-with-fragment-string).

An [absolute-URL-with-fragment string](#absolute-url-with-fragment-string) must be an [absolute-URL string](#absolute-url-string), optionally followed by U+0023 (#) and a [URL-fragment string](#url-fragment-string).

An [absolute-URL string](#absolute-url-string) must be one of the following:

- a [URL-scheme string](#url-scheme-string) that is an [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for a [special scheme](#special-scheme) and not an [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for "`file`", followed by U+003A (:) and a [scheme-relative-special-URL string](#scheme-relative-special-url-string)

- a [URL-scheme string](#url-scheme-string) that is *not* an [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for a [special scheme](#special-scheme), followed by U+003A (:) and a [relative-URL string](#relative-url-string)

- a [URL-scheme string](#url-scheme-string) that is an [ASCII case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for "`file`", followed by U+003A (:) and a [scheme-relative-file-URL string](#scheme-relative-file-url-string)

any optionally followed by U+003F (?) and a [URL-query string](#url-query-string).

A [URL-scheme string](#url-scheme-string) must be one [ASCII alpha](https://infra.spec.whatwg.org/#ascii-alpha), followed by zero or more of [ASCII alphanumeric](https://infra.spec.whatwg.org/#ascii-alphanumeric), U+002B (+), U+002D (-), and U+002E (.). [Schemes](#url-scheme-string) should be registered in the IANA URI \[sic\] Schemes registry. [IANA-URI-SCHEMES] [RFC7595]

A [relative-URL-with-fragment string](#relative-url-with-fragment-string) must be a [relative-URL string](#relative-url-string), optionally followed by U+0023 (#) and a [URL-fragment string](#url-fragment-string).

A [relative-URL string](#relative-url-string) must be one of the following, switching on [base URL](#concept-base-url)'s [scheme](#concept-url-scheme):

A [special scheme](#special-scheme) that is not "`file`"
: a [scheme-relative-special-URL string](#scheme-relative-special-url-string)

: a [path-absolute-URL string](#path-absolute-url-string)

: a [path-relative-scheme-less-URL string](#path-relative-scheme-less-url-string)

"`file`"
: a [scheme-relative-file-URL string](#scheme-relative-file-url-string)

: a [path-absolute-URL string](#path-absolute-url-string) if [base URL](#concept-base-url)'s [host](#concept-url-host) is an [empty host](#empty-host)

: a [path-absolute-non-Windows-file-URL string](#path-absolute-non-windows-file-url-string) if [base URL](#concept-base-url)'s [host](#concept-url-host) is not an [empty host](#empty-host)

: a [path-relative-scheme-less-URL string](#path-relative-scheme-less-url-string)

Otherwise
: a [scheme-relative-URL string](#scheme-relative-url-string)

: a [path-absolute-URL string](#path-absolute-url-string)

: a [path-relative-scheme-less-URL string](#path-relative-scheme-less-url-string)

any optionally followed by U+003F (?) and a [URL-query string](#url-query-string).

A non-null [base URL](#concept-base-url) is necessary when [parsing](#concept-url-parser) a [relative-URL string](#relative-url-string).

A [scheme-relative-special-URL string](#scheme-relative-special-url-string) must be "`//`", followed by a [valid host string](#valid-host-string), optionally followed by U+003A (:) and a [URL-port string](#url-port-string), optionally followed by a [path-absolute-URL string](#path-absolute-url-string).

A [URL-port string](#url-port-string) must be one of the following:

- the empty string

- one or more [ASCII digits](https://infra.spec.whatwg.org/#ascii-digit) representing a decimal number that is a [16-bit unsigned integer](https://infra.spec.whatwg.org/#16-bit-unsigned-integer).

A [scheme-relative-URL string](#scheme-relative-url-string) must be "`//`", followed by an [opaque-host-and-port string](#opaque-host-and-port-string), optionally followed by a [path-absolute-URL string](#path-absolute-url-string).

An [opaque-host-and-port string](#opaque-host-and-port-string) must be either the empty string or: a [valid opaque-host string](#valid-opaque-host-string), optionally followed by U+003A (:) and a [URL-port string](#url-port-string).

A [scheme-relative-file-URL string](#scheme-relative-file-url-string) must be "`//`", followed by one of the following:

- a [valid host string](#valid-host-string), optionally followed by a [path-absolute-non-Windows-file-URL string](#path-absolute-non-windows-file-url-string)

- a [path-absolute-URL string](#path-absolute-url-string).

A [path-absolute-URL string](#path-absolute-url-string) must be U+002F (/) followed by a [path-relative-URL string](#path-relative-url-string).

A [path-absolute-non-Windows-file-URL string](#path-absolute-non-windows-file-url-string) must be a [path-absolute-URL string](#path-absolute-url-string) that does not start with: U+002F (/), followed by a [Windows drive letter](#windows-drive-letter), followed by U+002F (/).

A [path-relative-URL string](#path-relative-url-string) must be zero or more [URL-path-segment strings](#url-path-segment-string), separated from each other by U+002F (/), and not start with U+002F (/).

A [path-relative-scheme-less-URL string](#path-relative-scheme-less-url-string) must be a [path-relative-URL string](#path-relative-url-string) that does not start with: a [URL-scheme string](#url-scheme-string), followed by U+003A (:).

A [URL-path-segment string](#url-path-segment-string) must be one of the following:

- zero or more [URL units](#url-units) excluding U+002F (/) and U+003F (?), that together are not a [single-dot URL path segment](#single-dot-path-segment) or a [double-dot URL path segment](#double-dot-path-segment).

- a [single-dot URL path segment](#single-dot-path-segment)

- a [double-dot URL path segment](#double-dot-path-segment).

A [URL-query string](#url-query-string) must be zero or more [URL units](#url-units).

A [URL-fragment string](#url-fragment-string) must be zero or more [URL units](#url-units).

The [URL code points](#url-code-points) are [ASCII alphanumeric](https://infra.spec.whatwg.org/#ascii-alphanumeric), U+0021 (!), U+0024 ($), U+0026 (&), U+0027 ('), U+0028 LEFT PARENTHESIS, U+0029 RIGHT PARENTHESIS, U+002A (*), U+002B (+), U+002C (,), U+002D (-), U+002E (.), U+002F (/), U+003A (:), U+003B (;), U+003D (=), U+003F (?), U+0040 (@), U+005F (_), U+007E (~), and [code points](https://infra.spec.whatwg.org/#code-point) in the range U+00A0 to U+10FFFD, inclusive, excluding [surrogates](https://infra.spec.whatwg.org/#surrogate) and [noncharacters](https://infra.spec.whatwg.org/#noncharacter).

Code points greater than U+007F DELETE will be converted to [percent-encoded bytes](#percent-encoded-byte) by the [URL parser](#concept-url-parser).

In HTML, when the document encoding is a legacy encoding, code points in the [URL-query string](#url-query-string) that are higher than U+007F DELETE will be converted to [percent-encoded bytes](#percent-encoded-byte) *using the document's encoding*. This can cause problems if a URL that works in one document is copied to another document that uses a different document encoding. Using the [UTF-8](https://encoding.spec.whatwg.org/#utf-8) encoding everywhere solves this problem.

For example, consider this HTML document:

```html
<!doctype html>
<meta charset="windows-1252">
<a href="?sm&ouml;rg&aring;sbord">Test</a>
```

Since the document encoding is windows-1252, the link's [URL](#concept-url)'s [query](#concept-url-query) will be "`sm%F6rg%E5sbord`". If the document encoding had been UTF-8, it would instead be "`sm%C3%B6rg%C3%A5sbord`".

The [URL units](#url-units) are [URL code points](#url-code-points) and [percent-encoded bytes](#percent-encoded-byte).

[Percent-encoded bytes](#percent-encoded-byte) can be used to encode code points that are not [URL code points](#url-code-points) or are excluded from being written.

---

There is no way to express a [username](#concept-url-username) or [password](#concept-url-password) of a [URL record](#concept-url) within a [valid URL string](#valid-url-string).


### URL parsing

The [URL parser](#concept-url-parser) takes a [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string) `input`, with an optional null or [base URL](#concept-base-url) `base` (default null) and an optional [encoding](https://encoding.spec.whatwg.org/#encoding) `encoding` (default [UTF-8](https://encoding.spec.whatwg.org/#utf-8)), and then runs these steps:

Non-web-browser implementations only need to implement the [basic URL parser](#concept-basic-url-parser).

How user input in the web browser's address bar is converted to a [URL record](#concept-url) is out-of-scope of this standard. This standard does include [URL rendering requirements](#url-rendering) as they pertain trust decisions.

1. Let `url` be the result of running the [basic URL parser](#concept-basic-url-parser) on `input` with `base` and `encoding`.

2. If `url` is failure, return failure.

3. If `url`'s [scheme](#concept-url-scheme) is not "`blob`", return `url`.

4. Set `url`'s [blob URL entry](#concept-url-blob-entry) to the result of [resolving the blob URL](https://w3c.github.io/FileAPI/#blob-url-resolve) `url`, if that did not return failure, and null otherwise.

5. Return `url`.

---

The [basic URL parser](#concept-basic-url-parser) takes a [scalar value string](https://infra.spec.whatwg.org/#scalar-value-string) `input`, with an optional null or [base URL](#concept-base-url) `base` (default null), an optional [encoding](https://encoding.spec.whatwg.org/#encoding) `encoding` (default [UTF-8](https://encoding.spec.whatwg.org/#utf-8)), an optional [URL](#concept-url) [`url`](#basic-url-parser-url), and an optional state override [`state override`](#basic-url-parser-state-override), and then runs these steps:

The `encoding` argument is a legacy concept only relevant for HTML. The `url` and `state override` arguments are only for use by various APIs. [HTML]

When the `url` and `state override` arguments are not passed, the [basic URL parser](#concept-basic-url-parser) returns either a new [URL](#concept-url) or failure. If they are passed, the algorithm modifies the passed `url` and can terminate without returning anything.

1. If `url` is not given:

   1. Set `url` to a new [URL](#concept-url).

   2. If `input` contains any leading or trailing [C0 control or space](https://infra.spec.whatwg.org/#c0-control-or-space), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

   3. Remove any leading and trailing [C0 control or space](https://infra.spec.whatwg.org/#c0-control-or-space) from `input`.

2. If `input` contains any [ASCII tab or newline](https://infra.spec.whatwg.org/#ascii-tab-or-newline), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

3. Remove all [ASCII tab or newline](https://infra.spec.whatwg.org/#ascii-tab-or-newline) from `input`.

4. Let `state` be `state override` if given, or [scheme start state](#scheme-start-state) otherwise.

5. Set `encoding` to the result of [getting an output encoding](https://encoding.spec.whatwg.org/#get-an-output-encoding) from `encoding`.

6. Let `buffer` be the empty string.

7. Let `atSignSeen`, `insideBrackets`, and `passwordTokenSeen` be false.

8. Let `pointer` be a [pointer](#pointer) for `input`.

9. Keep running the following state machine by switching on `state`. If after a run `pointer` points to the [EOF code point](#eof-code-point), go to the next step. Otherwise, increase `pointer` by 1 and continue with the state machine.

   [scheme start state](#scheme-start-state)

   : 1. If [c](#c) is an [ASCII alpha](https://infra.spec.whatwg.org/#ascii-alpha), append [c](#c), [lowercased](https://infra.spec.whatwg.org/#ascii-lowercase), to `buffer`, and set `state` to [scheme state](#scheme-state).

     2. Otherwise, if `state override` is not given, set `state` to [no scheme state](#no-scheme-state) and decrease `pointer` by 1.

     3. Otherwise, return failure.

        This indication of failure is used exclusively by the [`Location`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#location) object's [`protocol`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-location-protocol) setter.

   [scheme state](#scheme-state)

   : 1. If [c](#c) is an [ASCII alphanumeric](https://infra.spec.whatwg.org/#ascii-alphanumeric), U+002B (+), U+002D (-), or U+002E (.), append [c](#c), [lowercased](https://infra.spec.whatwg.org/#ascii-lowercase), to `buffer`.

     2. Otherwise, if [c](#c) is U+003A (:), then:

        1. If `state override` is given, then:

           1. If `url`'s [scheme](#concept-url-scheme) is a [special scheme](#special-scheme) and `buffer` is not a [special scheme](#special-scheme), then return.

           2. If `url`'s [scheme](#concept-url-scheme) is not a [special scheme](#special-scheme) and `buffer` is a [special scheme](#special-scheme), then return.

           3. If `url` [includes credentials](#include-credentials) or has a non-null [port](#concept-url-port), and `buffer` is "`file`", then return.

           4. If `url`'s [scheme](#concept-url-scheme) is "`file`" and its [host](#concept-url-host) is an [empty host](#empty-host), then return.

        2. Set `url`'s [scheme](#concept-url-scheme) to `buffer`.

        3. If `state override` is given, then:

           1. If `url`'s [port](#concept-url-port) is `url`'s [scheme](#concept-url-scheme)'s [default port](#default-port), then set `url`'s [port](#concept-url-port) to null.

           2. Return.

        4. Set `buffer` to the empty string.

        5. If `url`'s [scheme](#concept-url-scheme) is "`file`", then:

           1. If [remaining](#remaining) does not start with "`//`", [special-scheme-missing-following-solidus](#special-scheme-missing-following-solidus) [validation error](#validation-error).

           2. Set `state` to [file state](#file-state).

        6. Otherwise, if `url` [is special](#is-special), `base` is non-null, and `base`'s [scheme](#concept-url-scheme) is `url`'s [scheme](#concept-url-scheme):

           1. [Assert](https://infra.spec.whatwg.org/#assert): `base` [is special](#is-special) (and therefore does not have an [opaque path](#url-opaque-path)).

           2. Set `state` to [special relative or authority state](#special-relative-or-authority-state).

        7. Otherwise, if `url` [is special](#is-special), set `state` to [special authority slashes state](#special-authority-slashes-state).

        8. Otherwise, if [remaining](#remaining) starts with an U+002F (/), set `state` to [path or authority state](#path-or-authority-state) and increase `pointer` by 1.

        9. Otherwise, set `url`'s [path](#concept-url-path) to the empty string and set `state` to [opaque path state](#cannot-be-a-base-url-path-state).

     3. Otherwise, if `state override` is not given, set `buffer` to the empty string, `state` to [no scheme state](#no-scheme-state), and start over (from the first code point in `input`).

     4. Otherwise, return failure.

        This indication of failure is used exclusively by the [`Location`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#location) object's [`protocol`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-location-protocol) setter. Furthermore, the non-failure termination earlier in this state is an intentional difference for defining that setter.

   [no scheme state](#no-scheme-state)

   : 1. If `base` is null, or `base` has an [opaque path](#url-opaque-path) and [c](#c) is not U+0023 (#), [missing-scheme-non-relative-URL](#missing-scheme-non-relative-url) [validation error](#validation-error), return failure.

     2. Otherwise, if `base` has an [opaque path](#url-opaque-path) and [c](#c) is U+0023 (#), set `url`'s [scheme](#concept-url-scheme) to `base`'s [scheme](#concept-url-scheme), `url`'s [path](#concept-url-path) to `base`'s [path](#concept-url-path), `url`'s [query](#concept-url-query) to `base`'s [query](#concept-url-query), `url`'s [fragment](#concept-url-fragment) to the empty string, and set `state` to [fragment state](#fragment-state).

     3. Otherwise, if `base`'s [scheme](#concept-url-scheme) is not "`file`", set `state` to [relative state](#relative-state) and decrease `pointer` by 1.

     4. Otherwise, set `state` to [file state](#file-state) and decrease `pointer` by 1.

   [special relative or authority state](#special-relative-or-authority-state)

   : 1. If [c](#c) is U+002F (/) and [remaining](#remaining) starts with U+002F (/), then set `state` to [special authority ignore slashes state](#special-authority-ignore-slashes-state) and increase `pointer` by 1.

     2. Otherwise, [special-scheme-missing-following-solidus](#special-scheme-missing-following-solidus) [validation error](#validation-error), set `state` to [relative state](#relative-state) and decrease `pointer` by 1.

   [path or authority state](#path-or-authority-state)

   : 1. If [c](#c) is U+002F (/), then set `state` to [authority state](#authority-state).

     2. Otherwise, set `state` to [path state](#path-state), and decrease `pointer` by 1.

   [relative state](#relative-state)

   : 1. Assert: `base`'s [scheme](#concept-url-scheme) is not "`file`".

     2. Set `url`'s [scheme](#concept-url-scheme) to `base`'s [scheme](#concept-url-scheme).

     3. If [c](#c) is U+002F (/), then set `state` to [relative slash state](#relative-slash-state).

     4. Otherwise, if `url` [is special](#is-special) and [c](#c) is U+005C (\\), [invalid-reverse-solidus](#invalid-reverse-solidus) [validation error](#validation-error), set `state` to [relative slash state](#relative-slash-state).

     5. Otherwise:

        1. Set `url`'s [username](#concept-url-username) to `base`'s [username](#concept-url-username), `url`'s [password](#concept-url-password) to `base`'s [password](#concept-url-password), `url`'s [host](#concept-url-host) to `base`'s [host](#concept-url-host), `url`'s [port](#concept-url-port) to `base`'s [port](#concept-url-port), `url`'s [path](#concept-url-path) to a [clone](https://infra.spec.whatwg.org/#list-clone) of `base`'s [path](#concept-url-path), and `url`'s [query](#concept-url-query) to `base`'s [query](#concept-url-query).

        2. If [c](#c) is U+003F (?), then set `url`'s [query](#concept-url-query) to the empty string, and `state` to [query state](#query-state).

        3. Otherwise, if [c](#c) is U+0023 (#), set `url`'s [fragment](#concept-url-fragment) to the empty string and `state` to [fragment state](#fragment-state).

        4. Otherwise, if [c](#c) is not the [EOF code point](#eof-code-point):

           1. Set `url`'s [query](#concept-url-query) to null.

           2. [Shorten](#shorten-a-urls-path) `url`'s [path](#concept-url-path).

           3. Set `state` to [path state](#path-state) and decrease `pointer` by 1.

   [relative slash state](#relative-slash-state)

   : 1. If `url` [is special](#is-special) and [c](#c) is U+002F (/) or U+005C (\\), then:

        1. If [c](#c) is U+005C (\\), [invalid-reverse-solidus](#invalid-reverse-solidus) [validation error](#validation-error).

        2. Set `state` to [special authority ignore slashes state](#special-authority-ignore-slashes-state).

     2. Otherwise, if [c](#c) is U+002F (/), then set `state` to [authority state](#authority-state).

     3. Otherwise, set `url`'s [username](#concept-url-username) to `base`'s [username](#concept-url-username), `url`'s [password](#concept-url-password) to `base`'s [password](#concept-url-password), `url`'s [host](#concept-url-host) to `base`'s [host](#concept-url-host), `url`'s [port](#concept-url-port) to `base`'s [port](#concept-url-port), `state` to [path state](#path-state), and then, decrease `pointer` by 1.

   [special authority slashes state](#special-authority-slashes-state)

   : 1. If [c](#c) is U+002F (/) and [remaining](#remaining) starts with U+002F (/), then set `state` to [special authority ignore slashes state](#special-authority-ignore-slashes-state) and increase `pointer` by 1.

     2. Otherwise, [special-scheme-missing-following-solidus](#special-scheme-missing-following-solidus) [validation error](#validation-error), set `state` to [special authority ignore slashes state](#special-authority-ignore-slashes-state) and decrease `pointer` by 1.

   [special authority ignore slashes state](#special-authority-ignore-slashes-state)

   : 1. If [c](#c) is neither U+002F (/) nor U+005C (\\), then set `state` to [authority state](#authority-state) and decrease `pointer` by 1.

     2. Otherwise, [special-scheme-missing-following-solidus](#special-scheme-missing-following-solidus) [validation error](#validation-error).

   [authority state](#authority-state)

   : 1. If [c](#c) is U+0040 (@), then:

        1. [Invalid-credentials](#invalid-credentials) [validation error](#validation-error).

        2. If `atSignSeen` is true, then prepend "`%40`" to `buffer`.

        3. Set `atSignSeen` to true.

        4. For each `codePoint` in `buffer`:

           1. If `codePoint` is U+003A (:) and `passwordTokenSeen` is false, then set `passwordTokenSeen` to true and [continue](https://infra.spec.whatwg.org/#iteration-continue).

           2. Let `encodedCodePoints` be the result of running [UTF-8 percent-encode](#utf-8-percent-encode) `codePoint` using the [userinfo percent-encode set](#userinfo-percent-encode-set).

           3. If `passwordTokenSeen` is true, then append `encodedCodePoints` to `url`'s [password](#concept-url-password).

           4. Otherwise, append `encodedCodePoints` to `url`'s [username](#concept-url-username).

        5. Set `buffer` to the empty string.

     2. Otherwise, if one of the following is true:

        - [c](#c) is the [EOF code point](#eof-code-point), U+002F (/), U+003F (?), or U+0023 (#)

        - `url` [is special](#is-special) and [c](#c) is U+005C (\\)

        then:

        1. If `atSignSeen` is true and `buffer` is the empty string, [host-missing](#host-missing) [validation error](#validation-error), return failure.

        2. Decrease `pointer` by `buffer`'s [code point length](https://infra.spec.whatwg.org/#string-code-point-length) + 1, set `buffer` to the empty string, and set `state` to [host state](#host-state).

     3. Otherwise, append [c](#c) to `buffer`.

   [host state](#host-state)  
   [hostname state](#hostname-state)

   : 1. If `state override` is given and `url`'s [scheme](#concept-url-scheme) is "`file`", then decrease `pointer` by 1 and set `state` to [file host state](#file-host-state).

     2. Otherwise, if [c](#c) is U+003A (:) and `insideBrackets` is false:

        1. If `buffer` is the empty string, [host-missing](#host-missing) [validation error](#validation-error), return failure.

        2. If `state override` is given and `state override` is [hostname state](#hostname-state), then return failure.

        3. Let `host` be the result of [host parsing](#concept-host-parser) `buffer` with `url` [is not special](#is-not-special).

        4. If `host` is failure, then return failure.

        5. Set `url`'s [host](#concept-url-host) to `host`, `buffer` to the empty string, and `state` to [port state](#port-state).

     3. Otherwise, if one of the following is true:

        - [c](#c) is the [EOF code point](#eof-code-point), U+002F (/), U+003F (?), or U+0023 (#)

        - `url` [is special](#is-special) and [c](#c) is U+005C (\\)

        then decrease `pointer` by 1, and:

        1. If `url` [is special](#is-special) and `buffer` is the empty string, [host-missing](#host-missing) [validation error](#validation-error), return failure.

        2. Otherwise, if `state override` is given, `buffer` is the empty string, and either `url` [includes credentials](#include-credentials) or `url`'s [port](#concept-url-port) is non-null, then return failure.

        3. Let `host` be the result of [host parsing](#concept-host-parser) `buffer` with `url` [is not special](#is-not-special).

        4. If `host` is failure, then return failure.

        5. Set `url`'s [host](#concept-url-host) to `host`, `buffer` to the empty string, and `state` to [path start state](#path-start-state).

        6. If `state override` is given, then return.

     4. Otherwise:

        1. If [c](#c) is U+005B ([), then set `insideBrackets` to true.

        2. If [c](#c) is U+005D (]), then set `insideBrackets` to false.

        3. Append [c](#c) to `buffer`.

   [port state](#port-state)

   : 1. If [c](#c) is an [ASCII digit](https://infra.spec.whatwg.org/#ascii-digit), append [c](#c) to `buffer`.

     2. Otherwise, if one of the following is true:

        - [c](#c) is the [EOF code point](#eof-code-point), U+002F (/), U+003F (?), or U+0023 (#);

        - `url` [is special](#is-special) and [c](#c) is U+005C (\\); or

        - `state override` is given,

        then:

        1. If `buffer` is not the empty string:

           1. Let `port` be the mathematical integer value that is represented by `buffer` in radix-10 using [ASCII digits](https://infra.spec.whatwg.org/#ascii-digit) for digits with values 0 through 9.

           2. If `port` is not a [16-bit unsigned integer](https://infra.spec.whatwg.org/#16-bit-unsigned-integer), [port-out-of-range](#port-out-of-range) [validation error](#validation-error), return failure.

           3. Set `url`'s [port](#concept-url-port) to null, if `port` is `url`'s [scheme](#concept-url-scheme)'s [default port](#default-port); otherwise to `port`.

           4. Set `buffer` to the empty string.

           5. If `state override` is given, then return.

        2. If `state override` is given, then return failure.

        3. Set `state` to [path start state](#path-start-state) and decrease `pointer` by 1.

     3. Otherwise, [port-invalid](#port-invalid) [validation error](#validation-error), return failure.

   [file state](#file-state)

   : 1. Set `url`'s [scheme](#concept-url-scheme) to "`file`".

     2. Set `url`'s [host](#concept-url-host) to the empty string.

     3. If [c](#c) is U+002F (/) or U+005C (\\), then:

        1. If [c](#c) is U+005C (\\), [invalid-reverse-solidus](#invalid-reverse-solidus) [validation error](#validation-error).

        2. Set `state` to [file slash state](#file-slash-state).

     4. Otherwise, if `base` is non-null and `base`'s [scheme](#concept-url-scheme) is "`file`":

        1. Set `url`'s [host](#concept-url-host) to `base`'s [host](#concept-url-host), `url`'s [path](#concept-url-path) to a [clone](https://infra.spec.whatwg.org/#list-clone) of `base`'s [path](#concept-url-path), and `url`'s [query](#concept-url-query) to `base`'s [query](#concept-url-query).

        2. If [c](#c) is U+003F (?), then set `url`'s [query](#concept-url-query) to the empty string and `state` to [query state](#query-state).

        3. Otherwise, if [c](#c) is U+0023 (#), set `url`'s [fragment](#concept-url-fragment) to the empty string and `state` to [fragment state](#fragment-state).

        4. Otherwise, if [c](#c) is not the [EOF code point](#eof-code-point):

           1. Set `url`'s [query](#concept-url-query) to null.

           2. If the [code point substring](https://infra.spec.whatwg.org/#code-point-substring-to-the-end-of-the-string) from `pointer` to the end of `input` does not [start with a Windows drive letter](#start-with-a-windows-drive-letter), then [shorten](#shorten-a-urls-path) `url`'s [path](#concept-url-path).

           3. Otherwise:

              1. [File-invalid-Windows-drive-letter](#file-invalid-windows-drive-letter) [validation error](#validation-error).

              2. Set `url`'s [path](#concept-url-path) to « ».

              This is a (platform-independent) Windows drive letter quirk.

           4. Set `state` to [path state](#path-state) and decrease `pointer` by 1.

     5. Otherwise, set `state` to [path state](#path-state), and decrease `pointer` by 1.

   [file slash state](#file-slash-state)

   : 1. If [c](#c) is U+002F (/) or U+005C (\\), then:

        1. If [c](#c) is U+005C (\\), [invalid-reverse-solidus](#invalid-reverse-solidus) [validation error](#validation-error).

        2. Set `state` to [file host state](#file-host-state).

     2. Otherwise:

        1. If `base` is non-null and `base`'s [scheme](#concept-url-scheme) is "`file`", then:

           1. Set `url`'s [host](#concept-url-host) to `base`'s [host](#concept-url-host).

           2. If the [code point substring](https://infra.spec.whatwg.org/#code-point-substring-to-the-end-of-the-string) from `pointer` to the end of `input` does not [start with a Windows drive letter](#start-with-a-windows-drive-letter) and `base`'s [path](#concept-url-path)[0] is a [normalized Windows drive letter](#normalized-windows-drive-letter), then [append](https://infra.spec.whatwg.org/#list-append) `base`'s [path](#concept-url-path)[0] to `url`'s [path](#concept-url-path).

              This is a (platform-independent) Windows drive letter quirk.

        2. Set `state` to [path state](#path-state), and decrease `pointer` by 1.

   [file host state](#file-host-state)

   : 1. If [c](#c) is the [EOF code point](#eof-code-point), U+002F (/), U+005C (\\), U+003F (?), or U+0023 (#), then decrease `pointer` by 1 and then:

        1. If `state override` is not given and `buffer` is a [Windows drive letter](#windows-drive-letter), [file-invalid-Windows-drive-letter-host](#file-invalid-windows-drive-letter-host) [validation error](#validation-error), set `state` to [path state](#path-state).

           This is a (platform-independent) Windows drive letter quirk. `buffer` is not reset here and instead used in the [path state](#path-state).

        2. Otherwise, if `buffer` is the empty string, then:

           1. Set `url`'s [host](#concept-url-host) to the empty string.

           2. If `state override` is given, then return.

           3. Set `state` to [path start state](#path-start-state).

        3. Otherwise, run these steps:

           1. Let `host` be the result of [host parsing](#concept-host-parser) `buffer` with `url` [is not special](#is-not-special).

           2. If `host` is failure, then return failure.

           3. If `host` is "`localhost`", then set `host` to the empty string.

           4. Set `url`'s [host](#concept-url-host) to `host`.

           5. If `state override` is given, then return.

           6. Set `buffer` to the empty string and `state` to [path start state](#path-start-state).

     2. Otherwise, append [c](#c) to `buffer`.

   [path start state](#path-start-state)

   : 1. If `url` [is special](#is-special), then:

        1. If [c](#c) is U+005C (\\), [invalid-reverse-solidus](#invalid-reverse-solidus) [validation error](#validation-error).

        2. Set `state` to [path state](#path-state).

        3. If [c](#c) is neither U+002F (/) nor U+005C (\\), then decrease `pointer` by 1.

     2. Otherwise, if `state override` is not given and [c](#c) is U+003F (?), set `url`'s [query](#concept-url-query) to the empty string and `state` to [query state](#query-state).

     3. Otherwise, if `state override` is not given and [c](#c) is U+0023 (#), set `url`'s [fragment](#concept-url-fragment) to the empty string and `state` to [fragment state](#fragment-state).

     4. Otherwise, if [c](#c) is not the [EOF code point](#eof-code-point):

        1. Set `state` to [path state](#path-state).

        2. If [c](#c) is not U+002F (/), then decrease `pointer` by 1.

     5. Otherwise, if `state override` is given and `url`'s [host](#concept-url-host) is null, [append](https://infra.spec.whatwg.org/#list-append) the empty string to `url`'s [path](#concept-url-path).

   [path state](#path-state)

   : 1. If one of the following is true:

        - [c](#c) is the [EOF code point](#eof-code-point) or U+002F (/)

        - `url` [is special](#is-special) and [c](#c) is U+005C (\\)

        - `state override` is not given and [c](#c) is U+003F (?) or U+0023 (#)

        then:

        1. If `url` [is special](#is-special) and [c](#c) is U+005C (\\), [invalid-reverse-solidus](#invalid-reverse-solidus) [validation error](#validation-error).

        2. If `buffer` is a [double-dot URL path segment](#double-dot-path-segment), then:

           1. [Shorten](#shorten-a-urls-path) `url`'s [path](#concept-url-path).

           2. If neither [c](#c) is U+002F (/), nor `url` [is special](#is-special) and [c](#c) is U+005C (\\), [append](https://infra.spec.whatwg.org/#list-append) the empty string to `url`'s [path](#concept-url-path).

              This means that for input `/usr/..` the result is `/` and not a lack of a path.

        3. Otherwise, if `buffer` is a [single-dot URL path segment](#single-dot-path-segment) and if neither [c](#c) is U+002F (/), nor `url` [is special](#is-special) and [c](#c) is U+005C (\\), [append](https://infra.spec.whatwg.org/#list-append) the empty string to `url`'s [path](#concept-url-path).

        4. Otherwise, if `buffer` is not a [single-dot URL path segment](#single-dot-path-segment), then:

           1. If `url`'s [scheme](#concept-url-scheme) is "`file`", `url`'s [path](#concept-url-path) [is empty](https://infra.spec.whatwg.org/#list-is-empty), and `buffer` is a [Windows drive letter](#windows-drive-letter), then replace the second code point in `buffer` with U+003A (:).

              This is a (platform-independent) Windows drive letter quirk.

           2. [Append](https://infra.spec.whatwg.org/#list-append) `buffer` to `url`'s [path](#concept-url-path).

        5. Set `buffer` to the empty string.

        6. If [c](#c) is U+003F (?), then set `url`'s [query](#concept-url-query) to the empty string and `state` to [query state](#query-state).

        7. If [c](#c) is U+0023 (#), then set `url`'s [fragment](#concept-url-fragment) to the empty string and `state` to [fragment state](#fragment-state).

     2. Otherwise, run these steps:

        1. If [c](#c) is not a [URL code point](#url-code-points) and not U+0025 (%), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

        2. If [c](#c) is U+0025 (%) and [remaining](#remaining) does not start with two [ASCII hex digits](https://infra.spec.whatwg.org/#ascii-hex-digit), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

        3. [UTF-8 percent-encode](#utf-8-percent-encode) [c](#c) using the [path percent-encode set](#path-percent-encode-set) and append the result to `buffer`.

   [opaque path state](#cannot-be-a-base-url-path-state)

   : 1. If [c](#c) is U+003F (?), then set `url`'s [query](#concept-url-query) to the empty string and `state` to [query state](#query-state).

     2. Otherwise, if [c](#c) is U+0023 (#), then set `url`'s [fragment](#concept-url-fragment) to the empty string and `state` to [fragment state](#fragment-state).

     3. Otherwise, if [c](#c) is U+0020 SPACE:

        1. If [remaining](#remaining) starts with U+003F (?) or U+003F (#), then append "`%20`" to `url`'s [path](#concept-url-path).

        2. Otherwise, append U+0020 SPACE to `url`'s [path](#concept-url-path).

     4. Otherwise, if [c](#c) is not the [EOF code point](#eof-code-point):

        1. If [c](#c) is not a [URL code point](#url-code-points) and not U+0025 (%), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

        2. If [c](#c) is U+0025 (%) and [remaining](#remaining) does not start with two [ASCII hex digits](https://infra.spec.whatwg.org/#ascii-hex-digit), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

        3. [UTF-8 percent-encode](#utf-8-percent-encode) [c](#c) using the [C0 control percent-encode set](#c0-control-percent-encode-set) and append the result to `url`'s [path](#concept-url-path).

   [query state](#query-state)

   : 1. If `encoding` is not [UTF-8](https://encoding.spec.whatwg.org/#utf-8) and one of the following is true:

        - `url` [is not special](#is-not-special)

        - `url`'s [scheme](#concept-url-scheme) is "`ws`" or "`wss`"

        then set `encoding` to [UTF-8](https://encoding.spec.whatwg.org/#utf-8).

     2. If one of the following is true:

        - `state override` is not given and [c](#c) is U+0023 (#)

        - [c](#c) is the [EOF code point](#eof-code-point)

        then:

        1. Let `queryPercentEncodeSet` be the [special-query percent-encode set](#special-query-percent-encode-set) if `url` [is special](#is-special); otherwise the [query percent-encode set](#query-percent-encode-set).

        2. [Percent-encode after encoding](#string-percent-encode-after-encoding), with `encoding`, `buffer`, and `queryPercentEncodeSet`, and append the result to `url`'s [query](#concept-url-query).

           This operation cannot be invoked code-point-for-code-point due to the stateful [ISO-2022-JP encoder](https://encoding.spec.whatwg.org/#iso-2022-jp-encoder).

        3. Set `buffer` to the empty string.

        4. If [c](#c) is U+0023 (#), then set `url`'s [fragment](#concept-url-fragment) to the empty string and state to [fragment state](#fragment-state).

     3. Otherwise, if [c](#c) is not the [EOF code point](#eof-code-point):

        1. If [c](#c) is not a [URL code point](#url-code-points) and not U+0025 (%), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

        2. If [c](#c) is U+0025 (%) and [remaining](#remaining) does not start with two [ASCII hex digits](https://infra.spec.whatwg.org/#ascii-hex-digit), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

        3. Append [c](#c) to `buffer`.

   [fragment state](#fragment-state)

   : 1. If [c](#c) is not the [EOF code point](#eof-code-point), then:

        1. If [c](#c) is not a [URL code point](#url-code-points) and not U+0025 (%), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

        2. If [c](#c) is U+0025 (%) and [remaining](#remaining) does not start with two [ASCII hex digits](https://infra.spec.whatwg.org/#ascii-hex-digit), [invalid-URL-unit](#invalid-url-unit) [validation error](#validation-error).

        3. [UTF-8 percent-encode](#utf-8-percent-encode) [c](#c) using the [fragment percent-encode set](#fragment-percent-encode-set) and append the result to `url`'s [fragment](#concept-url-fragment).

10. Return `url`.

---

To [set the username](#set-the-username) given a `url` and `username`, set `url`'s [username](#concept-url-username) to the result of running [UTF-8 percent-encode](#string-utf-8-percent-encode) on `username` using the [userinfo percent-encode set](#userinfo-percent-encode-set).

To [set the password](#set-the-password) given a `url` and `password`, set `url`'s [password](#concept-url-password) to the result of running [UTF-8 percent-encode](#string-utf-8-percent-encode) on `password` using the [userinfo percent-encode set](#userinfo-percent-encode-set).


### URL serializing

The [URL serializer](#concept-url-serializer) takes a [URL](#concept-url) `url`, with an optional boolean [`exclude fragment`](#url-serializer-exclude-fragment) (default false), and then runs these steps. They return an [ASCII string](https://infra.spec.whatwg.org/#ascii-string).

1. Let `output` be `url`'s [scheme](#concept-url-scheme) and U+003A (:) concatenated.

2. If `url`'s [host](#concept-url-host) is non-null:

   1. Append "`//`" to `output`.

   2. If `url` [includes credentials](#include-credentials), then:

      1. Append `url`'s [username](#concept-url-username) to `output`.

      2. If `url`'s [password](#concept-url-password) is not the empty string, then append U+003A (:), followed by `url`'s [password](#concept-url-password), to `output`.

      3. Append U+0040 (@) to `output`.

   3. Append `url`'s [host](#concept-url-host), [serialized](#concept-host-serializer), to `output`.

   4. If `url`'s [port](#concept-url-port) is non-null, append U+003A (:) followed by `url`'s [port](#concept-url-port), [serialized](#serialize-an-integer), to `output`.

3. If `url`'s [host](#concept-url-host) is null, `url` does not have an [opaque path](#url-opaque-path), `url`'s [path](#concept-url-path)'s [size](https://infra.spec.whatwg.org/#list-size) is greater than 1, and `url`'s [path](#concept-url-path)[0] is the empty string, then append U+002F (/) followed by U+002E (.) to `output`.

   This prevents `web+demo:/.//not-a-host/` or `web+demo:/path/..//not-a-host/`, when [parsed](#concept-url-parser) and then [serialized](#concept-url-serializer), from ending up as `web+demo://not-a-host/` (they end up as `web+demo:/.//not-a-host/`).

4. Append the result of [URL path serializing](#url-path-serializer) `url` to `output`.

5. If `url`'s [query](#concept-url-query) is non-null, append U+003F (?), followed by `url`'s [query](#concept-url-query), to `output`.

6. If `exclude fragment` is false and `url`'s [fragment](#concept-url-fragment) is non-null, then append U+0023 (#), followed by `url`'s [fragment](#concept-url-fragment), to `output`.

7. Return `output`.

The [URL path serializer](#url-path-serializer) takes a [URL](#concept-url) `url` and then runs these steps. They return an [ASCII string](https://infra.spec.whatwg.org/#ascii-string).

1. If `url` has an [opaque path](#url-opaque-path), then return `url`'s [path](#concept-url-path).

2. Let `output` be the empty string.

3. [For each](https://infra.spec.whatwg.org/#list-iterate) `segment` of `url`'s [path](#concept-url-path): append U+002F (/) followed by `segment` to `output`.

4. Return `output`.


### URL equivalence

To determine whether a [URL](#concept-url) `A` [equals](#concept-url-equals) [URL](#concept-url) `B`, with an optional boolean [`exclude fragments`](#url-equals-exclude-fragments) (default false), run these steps:

1. Let `serializedA` be the result of [serializing](#concept-url-serializer) `A`, with [*exclude fragment*](#url-serializer-exclude-fragment) set to `exclude fragments`.

2. Let `serializedB` be the result of [serializing](#concept-url-serializer) `B`, with [*exclude fragment*](#url-serializer-exclude-fragment) set to `exclude fragments`.

3. Return true if `serializedA` is `serializedB`; otherwise false.


### Origin

See [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)'s definition in HTML for the necessary background information. [HTML]

The [origin](#concept-url-origin) of a [URL](#concept-url) `url` is the [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) returned by running these steps, switching on `url`'s [scheme](#concept-url-scheme):

"`blob`"
: 1. If `url`'s [blob URL entry](#concept-url-blob-entry) is non-null, then return `url`'s [blob URL entry](#concept-url-blob-entry)'s [environment](https://w3c.github.io/FileAPI/#blob-url-entry-environment)'s [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin).

  2. Let `pathURL` be the result of [parsing](#concept-basic-url-parser) the result of [URL path serializing](#url-path-serializer) `url`.

  3. If `pathURL` is failure, then return a new [opaque origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque).

  4. If `pathURL`'s [scheme](#concept-url-scheme) is "`http`", "`https`", or "`file`", then return `pathURL`'s [origin](#concept-url-origin).

  5. Return a new [opaque origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque).

  The [origin](#concept-url-origin) of `blob:https://whatwg.org/d0360e2f-caee-469f-9a2f-87d5b0456f6f` is the [tuple origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-tuple) ("`https`", "`whatwg.org`", null, null).

"`ftp`"  
"`http`"  
"`https`"  
"`ws`"  
"`wss`"
: Return the [tuple origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-tuple) (`url`'s [scheme](#concept-url-scheme), `url`'s [host](#concept-url-host), `url`'s [port](#concept-url-port), null).

"`file`"
: Unfortunate as it is, this is left as an exercise to the reader. When in doubt, return a new [opaque origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque).

Otherwise
: Return a new [opaque origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque).

  This does indeed mean that these [URLs](#concept-url) cannot be [same origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with themselves.


### URL rendering

A [URL](#concept-url) should be rendered in its [serialized](#concept-url-serializer) form, with modifications described below, when the primary purpose of displaying a URL is to have the user make a security or trust decision. For example, users are expected to make trust decisions based on a URL rendered in the browser address bar.


#### Simplify non-human-readable or irrelevant components

Remove components that can provide opportunities for spoofing or distract from security-relevant information:

- Browsers may render only a URL's [host](#concept-url-host) in places where it is important for end users to distinguish between the host and other parts of the URL such as the [path](#concept-url-path). Browsers may consider simplifying the host further to draw attention to its [registrable domain](#host-registrable-domain). For example, browsers may omit a leading `www` or `m` [domain label](#domain-label) to simplify the host, or display its registrable domain only to remove spoofing opportunities posted by subdomains (e.g., `https://examplecorp.attacker.com/`).

- Browsers should not render a [URL](#concept-url)'s [username](#concept-url-username) and [password](#concept-url-password), as they can be mistaken for a [URL](#concept-url)'s [host](#concept-url-host) (e.g., `https://examplecorp.com@attacker.example/`).

- Browsers may render a URL without its [scheme](#concept-url-scheme) if the display surface only ever permits a single scheme (such as a browser feature that omits `https://` because it is only enabled for secure origins). Otherwise, the scheme may be replaced or supplemented with a human-readable string (e.g., "Not secure"), a security indicator icon, or both.


#### Elision

In a space-constrained display, URLs should be elided carefully to avoid misleading the user when making a security decision:

- Browsers should ensure that at least the [registrable domain](#host-registrable-domain) can be shown when the URL is rendered (to avoid showing, e.g., `...examplecorp.com` when loading `https://not-really-examplecorp.com/`).

- When the full [host](#concept-url-host) cannot be rendered, browsers should elide [domain labels](#domain-label) starting from the lowest-level domain label. For example, `examplecorp.com.evil.com` should be elided as `...com.evil.com`, not `examplecorp.com...`. (Note that bidirectional text means that the lowest-level domain label may not appear on the left.)


#### Internationalization and special characters

Internationalized domain names (IDNs), special characters, and bidirectional text should be handled with care to prevent spoofing:

- Browsers should render a [URL](#concept-url)'s [host](#concept-url-host) by running [domain to Unicode](#concept-domain-to-unicode) with the [URL](#concept-url)'s [host](#concept-url-host) and false.

  Various characters can be used in homograph spoofing attacks. Consider detecting confusable characters and warning when they are in use. [IDNFAQ] [UTS39]

- URLs are particularly prone to confusion between host and path when they contain bidirectional text, so in this case it is particularly advisable to only render a URL's [host](#concept-url-host). For readability, other parts of the [URL](#concept-url), if rendered, should have their sequences of [percent-encoded bytes](#percent-encoded-byte) replaced with code points resulting from running [UTF-8 decode without BOM](https://encoding.spec.whatwg.org/#utf-8-decode-without-bom) on the [percent-decoding](#string-percent-decode) of those sequences, unless that renders those sequences invisible. Browsers may choose to not decode certain sequences that present spoofing risks (e.g., U+1F512 (🔒)).

- Browsers should render bidirectional text as if it were in a left-to-right embedding. [BIDI]

  Unfortunately, as rendered [URLs](#concept-url) are strings and can appear anywhere, a specific bidirectional algorithm for rendered [URLs](#concept-url) would not see wide adoption. Bidirectional text interacts with the parts of a [URL](#concept-url) in ways that can cause the rendering to be different from the model. Users of bidirectional languages can come to expect this, particularly in plain text environments.


## `application/x-www-form-urlencoded`

The `application/x-www-form-urlencoded` format provides a way to encode a list of tuples, each consisting of a name and a value.

The `application/x-www-form-urlencoded` format is in many ways an aberrant monstrosity, the result of many years of implementation accidents and compromises leading to a set of requirements necessary for interoperability, but in no way representing good design practices. In particular, readers are cautioned to pay close attention to the twisted details involving repeated (and in some cases nested) conversions between character encodings and byte sequences. Unfortunately the format is in widespread use due to the prevalence of HTML forms. [HTML]


### `application/x-www-form-urlencoded` parsing

A legacy server-oriented implementation might have to support encodings other than UTF-8 as well as have special logic for tuples of which the name is `_charset_`. Such logic is not described here as only UTF-8 is conforming.

The `application/x-www-form-urlencoded` parser takes a byte sequence `input`, and then runs these steps:

1.  Let `sequences` be the result of splitting `input` on 0x26 (&).

2.  Let `output` be an initially empty list of name-value tuples where both name and value hold a string.

3.  For each byte sequence `bytes` in `sequences`:

    1.  If `bytes` is the empty byte sequence, then continue.

    2.  If `bytes` contains a 0x3D (=), then let `name` be the bytes from the start of `bytes` up to but excluding its first 0x3D (=), and let `value` be the bytes, if any, after the first 0x3D (=) up to the end of `bytes`. If 0x3D (=) is the first byte, then `name` will be the empty byte sequence. If it is the last, then `value` will be the empty byte sequence.

    3.  Otherwise, let `name` have the value of `bytes` and let `value` be the empty byte sequence.

    4.  Replace any 0x2B (+) in `name` and `value` with 0x20 (SP).

    5.  Let `nameString` and `valueString` be the result of running UTF-8 decode without BOM on the percent-decoding of `name` and `value`, respectively.

    6.  Append (`nameString`, `valueString`) to `output`.

4.  Return `output`.


### `application/x-www-form-urlencoded` serializing

The `application/x-www-form-urlencoded` serializer takes a list of name-value tuples `tuples`, with an optional encoding `encoding` (default UTF-8), and then runs these steps. They return an ASCII string.

1.  Set `encoding` to the result of getting an output encoding from `encoding`.

2.  Let `output` be the empty string.

3.  For each `tuple` of `tuples`:

    1.  Assert: `tuple`'s name and `tuple`'s value are scalar value strings.

    2.  Let `name` be the result of running percent-encode after encoding with `encoding`, `tuple`'s name, the `application/x-www-form-urlencoded` percent-encode set, and true.

    3.  Let `value` be the result of running percent-encode after encoding with `encoding`, `tuple`'s value, the `application/x-www-form-urlencoded` percent-encode set, and true.

    4.  If `output` is not the empty string, then append U+0026 (&) to `output`.

    5.  Append `name`, followed by U+003D (=), followed by `value`, to `output`.

4.  Return `output`.


### Hooks

The `application/x-www-form-urlencoded` string parser takes a scalar value string `input`, UTF-8 encodes it, and then returns the result of `application/x-www-form-urlencoded` parsing it.


## API

This section uses terminology from Web IDL. Browser user agents must support this API. JavaScript implementations should support this API. Other user agents or programming languages are encouraged to use an API suitable to their needs, which might not be this one.


### URL class

```idl
[Exposed=*,
 LegacyWindowAlias=webkitURL]
interface URL {
  constructor(USVString url, optional USVString base);

  static URL? parse(USVString url, optional USVString base);
  static boolean canParse(USVString url, optional USVString base);

  stringifier attribute USVString href;
  readonly attribute USVString origin;
           attribute USVString protocol;
           attribute USVString username;
           attribute USVString password;
           attribute USVString host;
           attribute USVString hostname;
           attribute USVString port;
           attribute USVString pathname;
           attribute USVString search;
  [SameObject] readonly attribute URLSearchParams searchParams;
           attribute USVString hash;

  USVString toJSON();
};
```

A `URL` object has an associated:

- URL: a URL.
- query object: a `URLSearchParams` object.

The API URL parser takes a scalar value string `url` and an optional null-or-scalar value string `base` (default null), and then runs these steps:

1. Let `parsedBase` be null.

2. If `base` is non-null:

   1. Set `parsedBase` to the result of running the basic URL parser on `base`.

   2. If `parsedBase` is failure, then return failure.

3. Return the result of running the basic URL parser on `url` with `parsedBase`.

To initialize a `URL` object `url` with a URL `urlRecord`:

1. Let `query` be `urlRecord`'s query, if that is non-null; otherwise the empty string.

2. Set `url`'s URL to `urlRecord`.

3. Set `url`'s query object to a new `URLSearchParams` object.

4. Initialize `url`'s query object with `query`.

5. Set `url`'s query object's URL object to `url`.

The `new URL(url, base)` constructor steps are:

1. Let `parsedURL` be the result of running the API URL parser on `url` with `base`, if given.

2. If `parsedURL` is failure, then throw a `TypeError`.

3. Initialize this with `parsedURL`.

To parse a string into a URL without using a base URL, invoke the `URL` constructor with a single argument:

```javascript
var input = "https://example.org/💩",
    url = new URL(input)
url.pathname // "/%F0%9F%92%A9"
```

This throws an exception if the input is a relative-URL string:

```javascript
try {
  var url = new URL("/🍣🍺")
} catch(e) {
  // that happened
}
```

For those cases a base URL is necessary:

```javascript
var input = "/🍣🍺",
    url = new URL(input, document.baseURI)
url.href // "https://url.spec.whatwg.org/%F0%9F%8D%A3%F0%9F%8D%BA"
```

A `URL` object can be used as a base URL (as the IDL requires a string as argument, a `URL` object stringifies to its `href` getter return value):

```javascript
var url = new URL("🏳️‍🌈", new URL("https://pride.example/hello-world"))
url.pathname // "/%F0%9F%8F%B3%EF%B8%8F%E2%80%8D%F0%9F%8C%88"
```

The static `parse(url, base)` method steps are:

1. Let `parsedURL` be the result of running the API URL parser on `url` with `base`, if given.

2. If `parsedURL` is failure, then return null.

3. Let `url` be a new `URL` object.

4. Initialize `url` with `parsedURL`.

5. Return `url`.

The static `canParse(url, base)` method steps are:

1. Let `parsedURL` be the result of running the API URL parser on `url` with `base`, if given.

2. If `parsedURL` is failure, then return false.

3. Return true.

The `href` getter steps and the `toJSON()` method steps are to return the serialization of this's URL.

The `href` setter steps are:

1. Let `parsedURL` be the result of running the basic URL parser on the given value.

2. If `parsedURL` is failure, then throw a `TypeError`.

3. Set this's URL to `parsedURL`.

4. Empty this's query object's list.

5. Let `query` be this's URL's query.

6. If `query` is non-null, then set this's query object's list to the result of parsing `query`.

The `origin` getter steps are to return the serialization of this's URL's origin.

The `protocol` getter steps are to return this's URL's scheme, followed by U+003A (:).

The `protocol` setter steps are to basic URL parse the given value, followed by U+003A (:), with this's URL as *url* and scheme start state as *state override*.

The `username` getter steps are to return this's URL's username.

The `username` setter steps are:

1. If this's URL cannot have a username/password/port, then return.

2. Set the username given this's URL and the given value.

The `password` getter steps are to return this's URL's password.

The `password` setter steps are:

1. If this's URL cannot have a username/password/port, then return.

2. Set the password given this's URL and the given value.

The `host` getter steps are:

1. Let `url` be this's URL.

2. If `url`'s host is null, then return the empty string.

3. If `url`'s port is null, return `url`'s host, serialized.

4. Return `url`'s host, serialized, followed by U+003A (:) and `url`'s port, serialized.

The `host` setter steps are:

1. If this's URL has an opaque path, then return.

2. Basic URL parse the given value with this's URL as *url* and host state as *state override*.

If the given value for the `host` setter lacks a port, this's URL's port will not change. This can be unexpected as `host` getter does return a URL-port string so one might have assumed the setter to always "reset" both.

The `hostname` getter steps are:

1. If this's URL's host is null, then return the empty string.

2. Return this's URL's host, serialized.

The `hostname` setter steps are:

1. If this's URL has an opaque path, then return.

2. Basic URL parse the given value with this's URL as *url* and hostname state as *state override*.

The `port` getter steps are:

1. If this's URL's port is null, then return the empty string.

2. Return this's URL's port, serialized.

The `port` setter steps are:

1. If this's URL cannot have a username/password/port, then return.

2. If the given value is the empty string, then set this's URL's port to null.

3. Otherwise, basic URL parse the given value with this's URL as *url* and port state as *state override*.

The `pathname` getter steps are to return the result of URL path serializing this's URL.

The `pathname` setter steps are:

1. If this's URL has an opaque path, then return.

2. Empty this's URL's path.

3. Basic URL parse the given value with this's URL as *url* and path start state as *state override*.

The `search` getter steps are:

1. If this's URL's query is either null or the empty string, then return the empty string.

2. Return U+003F (?), followed by this's URL's query.

The `search` setter steps are:

1. Let `url` be this's URL.

2. If the given value is the empty string, then set `url`'s query to null, empty this's query object's list, and return.

3. Let `input` be the given value with a single leading U+003F (?) removed, if any.

4. Set `url`'s query to the empty string.

5. Basic URL parse `input` with `url` as *url* and query state as *state override*.

6. Set this's query object's list to the result of parsing `input`.

The `searchParams` getter steps are to return this's query object.

The `hash` getter steps are:

1. If this's URL's fragment is either null or the empty string, then return the empty string.

2. Return U+0023 (#), followed by this's URL's fragment.

The `hash` setter steps are:

1. If the given value is the empty string, then set this's URL's fragment to null and return.

2. Let `input` be the given value with a single leading U+0023 (#) removed, if any.

3. Set this's URL's fragment to the empty string.

4. Basic URL parse `input` with this's URL as *url* and fragment state as *state override*.


### URLSearchParams class

```idl
[Exposed=*]
interface URLSearchParams {
  constructor(optional (sequence<sequence<USVString>> or record<USVString, USVString> or USVString) init = "");

  readonly attribute unsigned long size;

  undefined append(USVString name, USVString value);
  undefined delete(USVString name, optional USVString value);
  USVString? get(USVString name);
  sequence<USVString> getAll(USVString name);
  boolean has(USVString name, optional USVString value);
  undefined set(USVString name, USVString value);

  undefined sort();

  iterable<USVString, USVString>;
  stringifier;
};
```

Constructing and stringifying a `URLSearchParams` object is fairly straightforward:

```javascript
let params = new URLSearchParams({key: "730d67"})
params.toString() // "key=730d67"
```

As a `URLSearchParams` object uses the `application/x-www-form-urlencoded` format underneath there are some difference with how it encodes certain code points compared to a `URL` object (including `href` and `search`). This can be especially surprising when using `searchParams` to operate on a URL's query.

```javascript
const url = new URL('https://example.com/?a=b ~');
console.log(url.href);   // "https://example.com/?a=b%20~"
url.searchParams.sort();
console.log(url.href);   // "https://example.com/?a=b+%7E"
```

```javascript
const url = new URL('https://example.com/?a=~&b=%7E');
console.log(url.search);                // "?a=~&b=%7E"
console.log(url.searchParams.get('a')); // "~"
console.log(url.searchParams.get('b')); // "~"
```

`URLSearchParams` objects will percent-encode anything in the `application/x-www-form-urlencoded` percent-encode set, and will encode U+0020 SPACE as U+002B (+).

Ignoring encodings (use UTF-8), `search` will percent-encode anything in the query percent-encode set or the special-query percent-encode set (depending on whether or not the URL is special).

A `URLSearchParams` object has an associated:

- list: a list of tuples each consisting of a name and a value, initially empty.
- URL object: null or a `URL` object, initially null.

To initialize a `URLSearchParams` object `query` with `init`:

1. If `init` is a sequence, then for each `innerSequence` of `init`:

   1. If `innerSequence`'s size is not 2, then throw a `TypeError`.

   2. Append (`innerSequence`[0], `innerSequence`[1]) to `query`'s list.

2. Otherwise, if `init` is a record, then for each `name` → `value` of `init`, append (`name`, `value`) to `query`'s list.

3. Otherwise:

   1. Assert: `init` is a string.

   2. Set `query`'s list to the result of parsing `init`.

To update a `URLSearchParams` object `query`:

1. If `query`'s URL object is null, then return.

2. Let `serializedQuery` be the serialization of `query`'s list.

3. If `serializedQuery` is the empty string, then set `serializedQuery` to null.

4. Set `query`'s URL object's URL's query to `serializedQuery`.

The `new URLSearchParams(init)` constructor steps are:

1. If `init` is a string and starts with U+003F (?), then remove the first code point from `init`.

2. Initialize this with `init`.

The `size` getter steps are to return this's list's size.

The `append(name, value)` method steps are:

1. Append (`name`, `value`) to this's list.

2. Update this.

The `delete(name, value)` method steps are:

1. If `value` is given, then remove all tuples whose name is `name` and value is `value` from this's list.

2. Otherwise, remove all tuples whose name is `name` from this's list.

3. Update this.

The `get(name)` method steps are to return the value of the first tuple whose name is `name` in this's list, if there is such a tuple; otherwise null.

The `getAll(name)` method steps are to return the values of all tuples whose name is `name` in this's list, in list order; otherwise the empty sequence.

The `has(name, value)` method steps are:

1. If `value` is given and there is a tuple whose name is `name` and value is `value` in this's list, then return true.

2. If `value` is not given and there is a tuple whose name is `name` in this's list, then return true.

3. Return false.

The `set(name, value)` method steps are:

1. If this's list contains any tuples whose name is `name`, then set the value of the first such tuple to `value` and remove the others.

2. Otherwise, append (`name`, `value`) to this's list.

3. Update this.

It can be useful to sort the name-value tuples in a `URLSearchParams` object, in particular to increase cache hits. This can be accomplished through invoking the `sort()` method:

```javascript
const url = new URL("https://example.org/?q=🏳️‍🌈&key=e1f7bc78");
url.searchParams.sort();
url.search; // "?key=e1f7bc78&q=%F0%9F%8F%B3%EF%B8%8F%E2%80%8D%F0%9F%8C%88"
```

To avoid altering the original input, e.g., for comparison purposes, construct a new `URLSearchParams` object:

```javascript
const sorted = new URLSearchParams(url.search)
sorted.sort()
```

The `sort()` method steps are:

1. Set this's list to the result of sorting in ascending order this's list, with `a` being less than `b` if `a`'s name is code unit less than `b`'s name.

2. Update this.

The value pairs to iterate over are this's list's tuples with the key being the name and the value being the value.

The stringification behavior steps are to return the serialization of this's list.


### URL APIs elsewhere

A standard that exposes URLs, should expose the URL as a string (by serializing an internal URL). A standard should not expose a URL using a `URL` object. `URL` objects are meant for URL manipulation. In IDL the USVString type should be used.

The higher-level notion here is that values are to be exposed as immutable data structures.

If a standard decides to use a variant of the name "URL" for a feature it defines, it should name such a feature "url" (i.e., lowercase and with an "l" at the end). Names such as "URL", "URI", and "IRI" should not be used. However, if the name is a compound, "URL" (i.e., uppercase) is preferred, e.g., "newURL" and "oldURL".

The `EventSource` and `HashChangeEvent` interfaces in HTML are examples of proper naming.


# Acknowledgments

There have been a lot of people that have helped make URLs more interoperable over the years and thereby furthered the goals of this standard. Likewise many people have helped making this standard what it is today.

With that, many thanks to 100の人, Adam Barth, Addison Phillips, Adrián Chaves, Adrien Ricciardi, Albert Wiersch, Alex Christensen, Alexis Hunt, Alexandre Morgaut, Alexis Hunt, Alwin Blok, Andrew Sullivan, Arkadiusz Michalski, Behnam Esfahbod, Bobby Holley, Boris Zbarsky, Brad Hill, Brandon Ross, Cailyn Hansen, Chris Dumez, Chris Rebert, Corey Farwell, Dan Appelquist, Daniel Bratell, Daniel Stenberg, David Burns, David Håsäther, David Sheets, David Singer, David Walp, Domenic Denicola, Emily Schechter, Emily Stark, Eric Lawrence, Erik Arvidsson, Gavin Carothers, Geoff Richards, Glenn Maynard, Gordon P. Hemsley, hemanth, Henri Sivonen, Ian Hickson, Ilya Grigorik, Italo A. Casas, Jakub Gieryluk, James Graham, James Manger, James Ross, Jeff Hodges, Jeffrey Posnick, Jeffrey Yasskin, Joe Duarte, Joshua Bell, Jxck, Karl Wagner, Kemal Zebari, 田村健人 (Kent TAMURA), Kevin Grandon, Kornel Lesiński, Larry Masinter, Leif Halvard Silli, Mark Amery, Mark Davis, Marcos Cáceres, Marijn Kruisselbrink, Martin Dürst, Mathias Bynens, Matt Falkenhagen, Matt Giuca, Michael Peick, Michael™ Smith, Michal Bukovský, Michel Suignard, Mikaël Geljić, Noah Levitt, Peter Occil, Philip Jägenstedt, Philippe Ombredanne, Prayag Verma, Rimas Misevičius, Robert Kieffer, Rodney Rehm, Roy Fielding, Ryan Sleevi, Sam Ruby, Sam Sneddon, Santiago M. Mola, Sebastian Mayr, Shannon Booth, Simon Pieters, Simon Sapin, Steven Vachon, Stuart Cook, Sven Uhlig, Tab Atkins, 吉野剛史 (Takeshi Yoshino), Tantek Çelik, Tiancheng "Timothy" Gu, Tim Berners-Lee, 簡冠庭 (Tim Guan-tin Chien), Titi_Alone, Tomek Wytrębowicz, Trevor Rowbotham, Tristan Seligmann, Valentin Gosu, Vyacheslav Matva, Wei Wang, Wolf Lammen, 山岸和利 (Yamagishi Kazutoshi), Yongsheng Zhang, 成瀬ゆい (Yui Naruse), and zealousidealroll for being awesome!

This standard is written by Anne van Kesteren (Apple, <annevk@annevk.nl>).