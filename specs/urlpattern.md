## URL patterns


### Introduction

A URL pattern consists of several components, each of which represents a pattern which could be matched against the corresponding component of a URL.

It can be constructed using a string for each component, or from a shorthand string. It can optionally be resolved relative to a base URL.

The shorthand "`https://example.com/:category/*`" corresponds to the following components:

protocol
:   "`https`"

username
:   "`*`"

password
:   "`*`"

hostname
:   "`example.com`"

port
:   ""

pathname
:   "`/:category/*`"

search
:   "`*`"

hash
:   "`*`"

It matches the following URLs:

- `https://example.com/products/`

- `https://example.com/blog/our-greatest-product-ever`

It does not match the following URLs:

- `https://example.com/`

- `http://example.com/products/`

- `https://example.com:8443/blog/our-greatest-product-ever`

This is a fairly simple pattern which requires most components to either match an exact string, or allows any string ("`*`"). The pathname component matches any path with at least two `/`-separated path components, the first of which is captured as "`category`".

The shorthand "`http{s}?://{:subdomain.}?shop.example/products/:id([0-9]+)#reviews`" corresponds to the following components:

protocol
:   "`http{s}?`"

username
:   "`*`"

password
:   "`*`"

hostname
:   "`{:subdomain.}?shop.example`"

port
:   ""

pathname
:   "`/products/:id([0-9]+)`"

search
:   ""

hash
:   "`reviews`"

It matches the following URLs:

- `https://shop.example/products/74205#reviews`

- `https://kathryn@voyager.shop.example/products/74656#reviews`

- `http://insecure.shop.example/products/1701#reviews`

It does not match the following URLs:

- `https://shop.example/products/2000`

- `http://shop.example:8080/products/0#reviews`

- `https://nx.shop.example/products/01?speed=5#reviews`

- `https://shop.example/products/chair#reviews`

This is a more complicated pattern which includes:

- optional parts marked with `?` (braces are needed to make it unambiguous exactly what is optional), and

- a regexp part named "`id`" which uses a regular expression to define what sorts of substrings match (the parentheses are necessary to mark it as a regular expression, and are not part of the regexp itself).

The shorthand "`../admin/*`" with the base URL "`https://discussion.example/forum/?page=2`" corresponds to the following components:

protocol
:   "`https`"

username
:   "`*`"

password
:   "`*`"

hostname
:   "`discussion.example`"

port
:   ""

pathname
:   "`/admin/*`"

search
:   "`*`"

hash
:   "`*`"

It matches the following URLs:

- `https://discussion.example/admin/`

- `https://edd:librarian@discussion.example/admin/update?id=1`

It does not match the following URLs:

- `https://discussion.example/forum/admin/`

- `http://discussion.example:8080/admin/update?id=1`

This pattern demonstrates how pathnames are resolved relative to a base URL, in a similar way to relative URLs.


### The `URLPattern` class

```idl
typedef (USVString or URLPatternInit) URLPatternInput;

[Exposed=(Window,Worker)]
interface URLPattern {
  constructor(URLPatternInput input, USVString baseURL, optional URLPatternOptions options = {});
  constructor(optional URLPatternInput input = {}, optional URLPatternOptions options = {});

  boolean test(optional URLPatternInput input = {}, optional USVString baseURL);

  URLPatternResult? exec(optional URLPatternInput input = {}, optional USVString baseURL);

  readonly attribute USVString protocol;
  readonly attribute USVString username;
  readonly attribute USVString password;
  readonly attribute USVString hostname;
  readonly attribute USVString port;
  readonly attribute USVString pathname;
  readonly attribute USVString search;
  readonly attribute USVString hash;

  readonly attribute boolean hasRegExpGroups;
};

dictionary URLPatternInit {
  USVString protocol;
  USVString username;
  USVString password;
  USVString hostname;
  USVString port;
  USVString pathname;
  USVString search;
  USVString hash;
  USVString baseURL;
};

dictionary URLPatternOptions {
  boolean ignoreCase = false;
};

dictionary URLPatternResult {
  sequence<URLPatternInput> inputs;

  URLPatternComponentResult protocol;
  URLPatternComponentResult username;
  URLPatternComponentResult password;
  URLPatternComponentResult hostname;
  URLPatternComponentResult port;
  URLPatternComponentResult pathname;
  URLPatternComponentResult search;
  URLPatternComponentResult hash;
};

dictionary URLPatternComponentResult {
  USVString input;
  record<USVString, (USVString or undefined)> groups;
};
```

Each `URLPattern` has an associated URL pattern, a URL pattern.

`urlPattern = new URLPattern(input)`
:   Constructs a new `URLPattern` object. The `input` is an object containing separate patterns for each URL component; e.g. hostname, pathname, etc. Missing components will default to a wildcard pattern. In addition, `input` can contain a `baseURL` property that provides static text patterns for any missing components.

`urlPattern = new URLPattern(patternString, baseURL)`
:   Constructs a new `URLPattern` object. `patternString` is a URL string containing pattern syntax for one or more components. If `baseURL` is provided, then `patternString` can be relative. This constructor will always set at least an empty string value and does not default any components to wildcard patterns.

`urlPattern = new URLPattern(input, options)`

:   Constructs a new `URLPattern` object. The `options` is an object containing the additional configuration options that can affect how the components are matched. Currently it has only one property `ignoreCase` which can be set to true to enable case-insensitive matching.

    Note that by default, that is in the absence of the `options` argument, matching is always case-sensitive.

`urlPattern = new URLPattern(patternString, baseURL, options)`
:   Constructs a new `URLPattern` object. This overrides supports a `URLPatternOptions` object when constructing a pattern from a `patternString` object, describing the patterns for individual components, and base URL.

`matches = urlPattern.test(input)`
:   Tests if `urlPattern` matches the given arguments. The `input` is an object containing strings representing each URL component; e.g. hostname, pathname, etc. Missing components are treated as empty strings. In addition, `input` can contain a `baseURL` property that provides values for any missing components. If `urlPattern` matches the `input` on a component-by-component basis then true is returned. Otherwise, false is returned.

`matches = urlPattern.test(url, baseURL)`

:   Tests if `urlPattern` matches the given arguments. `url` is a URL string. If `baseURL` is provided, then `url` can be relative.

    If `urlPattern` matches the `input` on a component-by-component basis then true is returned. Otherwise, false is returned.

`result = urlPattern.exec(input)`

:   Executes the `urlPattern` against the given arguments. The `input` is an object containing strings representing each URL component; e.g. hostname, pathname, etc. Missing components are treated as empty strings. In addition, `input` can contain a baseURL property that provides values for any missing components.

    If `urlPattern` matches the `input` on a component-by-component basis then an object is returned containing the results. Matched group values are contained in per-component group objects within the `result` object; e.g. `matches.pathname.groups.id`. If `urlPattern` does not match the `input`, then `result` is null.

`result = urlPattern.exec(url, baseURL)`

:   Executes the `urlPattern` against the given arguments. `url` is a URL string. If `baseURL` is provided, then `input` can be relative.

    If `urlPattern` matches the `input` on a component-by-component basis then an object is returned containing the results. Matched group values are contained in per-component group objects within the `result` object; e.g. `matches.pathname.groups.id`. If `urlPattern` does not match the `input`, then `result` is null.

`urlPattern.protocol`

:   Returns `urlPattern`'s normalized protocol pattern string.

`urlPattern.username`

:   Returns `urlPattern`'s normalized username pattern string.

`urlPattern.password`

:   Returns `urlPattern`'s normalized password pattern string.

`urlPattern.hostname`

:   Returns `urlPattern`'s normalized hostname pattern string.

`urlPattern.port`

:   Returns `urlPattern`'s normalized port pattern string.

`urlPattern.pathname`

:   Returns `urlPattern`'s normalized pathname pattern string.

`urlPattern.search`

:   Returns `urlPattern`'s normalized search pattern string.

`urlPattern.hash`

:   Returns `urlPattern`'s normalized hash pattern string.

`urlPattern.hasRegExpGroups`

:   Returns whether `urlPattern` contains one or more groups which uses regular expression matching.

The `new URLPattern(input, baseURL, options)` constructor steps are:

1.  Run initialize given this, `input`, `baseURL`, and `options`.

The `new URLPattern(input, options)` constructor steps are:

1.  Run initialize given this, `input`, null, and `options`.

To initialize a `URLPattern` given a `URLPattern` `this`, `URLPatternInput` `input`, string or null `baseURL`, and `URLPatternOptions` `options`:

1.  Set `this`'s associated URL pattern to the result of create given `input`, `baseURL`, and `options`.

The `protocol` getter steps are:

1.  Return this's associated URL pattern's protocol component's pattern string.

The `username` getter steps are:

1.  Return this's associated URL pattern's username component's pattern string.

The `password` getter steps are:

1.  Return this's associated URL pattern's password component's pattern string.

The `hostname` getter steps are:

1.  Return this's associated URL pattern's hostname component's pattern string.

The `port` getter steps are:

1.  Return this's associated URL pattern's port component's pattern string.

The `pathname` getter steps are:

1.  Return this's associated URL pattern's pathname component's pattern string.

The `search` getter steps are:

1.  Return this's associated URL pattern's search component's pattern string.

The `hash` getter steps are:

1.  Return this's associated URL pattern's hash component's pattern string.

The `hasRegExpGroups` getter steps are:

1.  If this's associated URL pattern's has regexp groups, then return true.

2.  Return false.

The `test(input, baseURL)` method steps are:

1.  Let `result` be the result of match given this's associated URL pattern, `input`, and `baseURL` if given.

2.  If `result` is null, return false.

3.  Return true.

The `exec(input, baseURL)` method steps are:

1.  Return the result of match given this's associated URL pattern, `input`, and `baseURL` if given.


### The URL pattern struct

A URL pattern is a struct with the following items:

- protocol component, a component

- username component, a component

- password component, a component

- hostname component, a component

- port component, a component

- pathname component, a component

- search component, a component

- hash component, a component

A component is a struct with the following items:

- pattern string, a well formed pattern string

- regular expression, a `RegExp`

- group name list, a list of strings

- has regexp groups, a boolean


### High-level operations

To create a URL pattern given a `URLPatternInput` `input`, string or null `baseURL`, and `URLPatternOptions` `options`:

1.  Let `init` be null.

2.  If `input` is a scalar value string then:

    1.  Set `init` to the result of running parse a constructor string given `input`.

    2.  If `baseURL` is null and `init`["`protocol`"] does not exist, then throw a `TypeError`.

    3.  If `baseURL` is not null, set `init`["`baseURL`"] to `baseURL`.

3.  Otherwise:

    1.  Assert: `input` is a `URLPatternInit`.

    2.  If `baseURL` is not null, then throw a `TypeError`.

    3.  Set `init` to `input`.

4.  Let `processedInit` be the result of process a URLPatternInit given `init`, "`pattern`", null, null, null, null, null, null, null, and null.

5.  For each `componentName` of « "`protocol`", "`username`", "`password`", "`hostname`", "`port`", "`pathname`", "`search`", "`hash`" »:

    1.  If `processedInit`[`componentName`] does not exist, then set `processedInit`[`componentName`] to "`*`".

6.  If `processedInit`["`protocol`"] is a special scheme and `processedInit`["`port`"] is a string which represents its corresponding default port in radix-10 using ASCII digits then set `processedInit`["`port`"] to the empty string.

7.  Let `urlPattern` be a new URL pattern.

8.  Set `urlPattern`'s protocol component to the result of compiling a component given `processedInit`["`protocol`"], canonicalize a protocol, and default options.

9.  Set `urlPattern`'s username component to the result of compiling a component given `processedInit`["`username`"], canonicalize a username, and default options.

10. Set `urlPattern`'s password component to the result of compiling a component given `processedInit`["`password`"], canonicalize a password, and default options.

11. If the result running hostname pattern is an IPv6 address given `processedInit`["`hostname`"] is true, then set `urlPattern`'s hostname component to the result of compiling a component given `processedInit`["`hostname`"], canonicalize an IPv6 hostname, and hostname options.

12. Otherwise, set `urlPattern`'s hostname component to the result of compiling a component given `processedInit`["`hostname`"], canonicalize a hostname, and hostname options.

13. Set `urlPattern`'s port component to the result of compiling a component given `processedInit`["`port`"], canonicalize a port, and default options.

14. Let `compileOptions` be a copy of the default options with the ignore case property set to `options`["`ignoreCase`"].

15. If the result of running protocol component matches a special scheme given `urlPattern`'s protocol component is true, then:

    1.  Let `pathCompileOptions` be copy of the pathname options with the ignore case property set to `options`["`ignoreCase`"].

    2.  Set `urlPattern`'s pathname component to the result of compiling a component given `processedInit`["`pathname`"], canonicalize a pathname, and `pathCompileOptions`.

16. Otherwise set `urlPattern`'s pathname component to the result of compiling a component given `processedInit`["`pathname`"], canonicalize an opaque pathname, and `compileOptions`.

17. Set `urlPattern`'s search component to the result of compiling a component given `processedInit`["`search`"], canonicalize a search, and `compileOptions`.

18. Set `urlPattern`'s hash component to the result of compiling a component given `processedInit`["`hash`"], canonicalize a hash, and `compileOptions`.

19. Return `urlPattern`.

To perform a match given a URL pattern `urlPattern`, a `URLPatternInput` or URL `input`, and an optional string `baseURLString`:

1.  Let `protocol` be the empty string.

2.  Let `username` be the empty string.

3.  Let `password` be the empty string.

4.  Let `hostname` be the empty string.

5.  Let `port` be the empty string.

6.  Let `pathname` be the empty string.

7.  Let `search` be the empty string.

8.  Let `hash` be the empty string.

9.  Let `inputs` be an empty list.

10. If `input` is a URL, then append the serialization of `input` to `inputs`.

11. Otherwise, append `input` to `inputs`.

12. If `input` is a `URLPatternInit` then:

    1.  If `baseURLString` was given, throw a `TypeError`.

    2.  Let `applyResult` be the result of process a URLPatternInit given `input`, "url", `protocol`, `username`, `password`, `hostname`, `port`, `pathname`, `search`, and `hash`. If this throws an exception, catch it, and return null.

    3.  Set `protocol` to `applyResult`["`protocol`"].

    4.  Set `username` to `applyResult`["`username`"].

    5.  Set `password` to `applyResult`["`password`"].

    6.  Set `hostname` to `applyResult`["`hostname`"].

    7.  Set `port` to `applyResult`["`port`"].

    8.  Set `pathname` to `applyResult`["`pathname`"].

    9.  Set `search` to `applyResult`["`search`"].

    10. Set `hash` to `applyResult`["`hash`"].

13. Otherwise:

    1.  Let `url` be `input`.

    2.  If `input` is a `USVString`:

        1.  Let `baseURL` be null.

        2.  If `baseURLString` was given, then:

            1.  Set `baseURL` to the result of running the basic URL parser on `baseURLString`.

            2.  If `baseURL` is failure, return null.

            3.  Append `baseURLString` to `inputs`.

        3.  Set `url` to the result of running the basic URL parser on `input` with `baseURL`.

        4.  If `url` is failure, return null.

    3.  Assert: `url` is a URL.

    4.  Set `protocol` to `url`'s scheme.

    5.  Set `username` to `url`'s username.

    6.  Set `password` to `url`'s password.

    7.  Set `hostname` to `url`'s host, serialized, or the empty string if the value is null.

    8.  Set `port` to `url`'s port, serialized, or the empty string if the value is null.

    9.  Set `pathname` to the result of URL path serializing `url`.

    10. Set `search` to `url`'s query or the empty string if the value is null.

    11. Set `hash` to `url`'s fragment or the empty string if the value is null.

14. Let `protocolExecResult` be RegExpBuiltinExec(`urlPattern`'s protocol component's regular expression, `protocol`).

15. Let `usernameExecResult` be RegExpBuiltinExec(`urlPattern`'s username component's regular expression, `username`).

16. Let `passwordExecResult` be RegExpBuiltinExec(`urlPattern`'s password component's regular expression, `password`).

17. Let `hostnameExecResult` be RegExpBuiltinExec(`urlPattern`'s hostname component's regular expression, `hostname`).

18. Let `portExecResult` be RegExpBuiltinExec(`urlPattern`'s port component's regular expression, `port`).

19. Let `pathnameExecResult` be RegExpBuiltinExec(`urlPattern`'s pathname component's regular expression, `pathname`).

20. Let `searchExecResult` be RegExpBuiltinExec(`urlPattern`'s search component's regular expression, `search`).

21. Let `hashExecResult` be RegExpBuiltinExec(`urlPattern`'s hash component's regular expression, `hash`).

22. If `protocolExecResult`, `usernameExecResult`, `passwordExecResult`, `hostnameExecResult`, `portExecResult`, `pathnameExecResult`, `searchExecResult`, or `hashExecResult` are null then return null.

23. Let `result` be a new `URLPatternResult`.

24. Set `result`["`inputs`"] to `inputs`.

25. Set `result`["`protocol`"] to the result of creating a component match result given `urlPattern`'s protocol component, `protocol`, and `protocolExecResult`.

26. Set `result`["`username`"] to the result of creating a component match result given `urlPattern`'s username component, `username`, and `usernameExecResult`.

27. Set `result`["`password`"] to the result of creating a component match result given `urlPattern`'s password component, `password`, and `passwordExecResult`.

28. Set `result`["`hostname`"] to the result of creating a component match result given `urlPattern`'s hostname component, `hostname`, and `hostnameExecResult`.

29. Set `result`["`port`"] to the result of creating a component match result given `urlPattern`'s port component, `port`, and `portExecResult`.

30. Set `result`["`pathname`"] to the result of creating a component match result given `urlPattern`'s pathname component, `pathname`, and `pathnameExecResult`.

31. Set `result`["`search`"] to the result of creating a component match result given `urlPattern`'s search component, `search`, and `searchExecResult`.

32. Set `result`["`hash`"] to the result of creating a component match result given `urlPattern`'s hash component, `hash`, and `hashExecResult`.

33. Return `result`.

A URL pattern `urlPattern` has regexp groups if the following steps return true:

1.  If `urlPattern`'s protocol component has regexp groups is true, then return true.

2.  If `urlPattern`'s username component has regexp groups is true, then return true.

3.  If `urlPattern`'s password component has regexp groups is true, then return true.

4.  If `urlPattern`'s hostname component has regexp groups is true, then return true.

5.  If `urlPattern`'s port component has regexp groups is true, then return true.

6.  If `urlPattern`'s pathname component has regexp groups is true, then return true.

7.  If `urlPattern`'s search component has regexp groups is true, then return true.

8.  If `urlPattern`'s hash component has regexp groups is true, then return true.

9.  Return false.


### Internals

To compile a component given a string `input`, encoding callback `encoding callback`, and options `options`:

1.  Let `part list` be the result of running parse a pattern string given `input`, `options`, and `encoding callback`.

2.  Let (`regular expression string`, `name list`) be the result of running generate a regular expression and name list given `part list` and `options`.

3.  Let `flags` be an empty string.

4.  If `options`'s ignore case is true then set `flags` to "`vi`".

5.  Otherwise set `flags` to "`v`"

6.  Let `regular expression` be RegExpCreate(`regular expression string`, `flags`). If this throws an exception, catch it, and throw a `TypeError`.

    The specification uses regular expressions to perform all matching, but this is not mandated. Implementations are free to perform matching directly against the part list when possible; e.g. when there are no custom regexp matching groups. If there are custom regular expressions, however, its important that they be immediately evaluated in the compile a component algorithm so an error can be thrown if they are invalid.

7.  Let `pattern string` be the result of running generate a pattern string given `part list` and `options`.

8.  Let `has regexp groups` be false.

9.  For each `part` of `part list`:

    1.  If `part`'s type is "`regexp`", then set `has regexp groups` to true.

10. Return a new component whose pattern string is `pattern string`, regular expression is `regular expression`, group name list is `name list`, and has regexp groups is `has regexp groups`.

To create a component match result given a component `component`, a string `input`, and an array representing the output of RegExpBuiltinExec `execResult`:

1.  Let `result` be a new `URLPatternComponentResult`.

2.  Set `result`["`input`"] to `input`.

3.  Let `groups` be a `record<USVString, (USVString or undefined)>`.

4.  Let `index` be 1.

5.  While `index` is less than Get(`execResult`, "`length`"):

    1.  Let `name` be `component`'s group name list[`index` − 1].

    2.  Let `value` be Get(`execResult`, ToString(`index`)).

    3.  Set `groups`[`name`] to `value`.

    4.  Increment `index` by 1.

6.  Set `result`["`groups`"] to `groups`.

7.  Return `result`.

To create a dummy URL:

1.  Let `dummyInput` be "`https://dummy.invalid/`".

2.  Return the result of running the basic URL parser on `dummyInput`.

The default options is an options struct with delimiter code point set to the empty string and prefix code point set to the empty string.

The hostname options is an options struct with delimiter code point set "`.`" and prefix code point set to the empty string.

The pathname options is an options struct with delimiter code point set "`/`" and prefix code point set to "`/`".

To determine if a protocol component matches a special scheme given a component `protocol component`:

1.  Let `special scheme list` be a list populated with all of the special schemes.

2.  For each `scheme` of `special scheme list`:

    1.  Let `test result` be RegExpBuiltinExec(`protocol component`'s regular expression, `scheme`).

    2.  If `test result` is not null, then return true.

3.  Return false.

To determine if a hostname pattern is an IPv6 address given a pattern string `input`:

1.  If `input`'s code point length is less than 2, then return false.

2.  Let `input code points` be `input` interpreted as a list of code points.

3.  If `input code points`[0] is U+005B (`[`), then return true.

4.  If `input code points`[0] is U+007B (`{`) and `input code points`[1] is U+005B (`[`), then return true.

5.  If `input code points`[0] is U+005C (`\`) and `input code points`[1] is U+005B (`[`), then return true.

6.  Return false.


### Constructor string parsing

A constructor string parser is a struct.

A constructor string parser has an associated input, a string, which must be set upon creation.

A constructor string parser has an associated token list, a token list, which must be set upon creation.

A constructor string parser has an associated result, a `URLPatternInit`, initially set to a new `URLPatternInit`.

A constructor string parser has an associated component start, a number, initially set to 0.

A constructor string parser has an associated token index, a number, initially set to 0.

A constructor string parser has an associated token increment, a number, initially set to 1.

A constructor string parser has an associated group depth, a number, initially set to 0.

A constructor string parser has an associated hostname IPv6 bracket depth, a number, initially set to 0.

A constructor string parser has an associated protocol matches a special scheme flag, a boolean, initially set to false.

A constructor string parser has an associated state, a string, initially set to "`init`". It must be one of the following:

- "`init`"
- "`protocol`"
- "`authority`"
- "`username`"
- "`password`"
- "`hostname`"
- "`port`"
- "`pathname`"
- "`search`"
- "`hash`"
- "`done`"

The URLPattern constructor string algorithm is very similar to the basic URL parser algorithm, but some differences prevent us from using that algorithm directly.

First, the URLPattern constructor string parser operates on tokens generated using the "`lenient`" tokenize policy. In constrast, basic URL parser operates on code points. Operating on tokens allows the URLPattern constructor string parser to more easily distinguish between code points that are significant pattern syntax and code points that might be a URL component separator. For example, it makes it trivial to handle named groups like "`:hmm`" in "`https://a.c:hmm.example.com:8080`" without getting confused with the port number.

Second, the URLPattern constructor string parser needs to avoid applying URL canonicalization to all code points like basic URL parser does. Instead we perform canonicalization on only parts of the pattern string we know are safe later when compiling each component pattern string.

Finally, the URLPattern constructor string parser does not handle some parts of the basic URL parser state machine. For example, it does not treat backslashes specially as they would all be treated as pattern characters and would require excessive escaping. In addition, this parser might not handle some more esoteric parts of the URL parsing algorithm like file URLs with a hostname. The goal with this parser was to handle the most common URLs while allowing any niche case to be handled instead via the `URLPatternInit` constructor.

In the constructor string algorithm, the pathname, search, and hash are wildcarded if earlier components are specified but later ones are not. For example, "`https://example.com/foo`" matches any search and any hash. Similarly, "`https://example.com`" matches any URL on that origin. This is analogous to the notion of a more specific component in the notes about process a URLPatternInit (e.g., a search is more specific than a pathname), but the constructor syntax only has a few cases where it is possible to specify a more specific component without also specifying the less specific components.

The username and password components are always wildcard unless they are explicitly specified.

If a hostname is specified and the port is not, the port is assumed to be the default port. If authors want to match any port, they have to write `:*` explicitly. For example, "`https://*`" is any HTTPS origin on port 443, and "`https://*:*`" is any HTTPS origin on any port.

To parse a constructor string given a string `input`:

1.  Let `parser` be a new constructor string parser whose input is `input` and token list is the result of running tokenize given `input` and "`lenient`".

2.  While `parser`'s token index is less than `parser`'s token list size:

    1.  Set `parser`'s token increment to 1.

        On every iteration of the parse loop the `parser`'s token index will be incremented by its token increment value. Typically this means incrementing by 1, but at certain times it is set to zero. The token increment is then always reset back to 1 at the top of the loop.

    2.  If `parser`'s token list[`parser`'s token index]'s type is "`end`" then:

        1.  If `parser`'s state is "`init`":

            If we reached the end of the string in the "`init`" state, then we failed to find a protocol terminator and this has to be a relative URLPattern constructor string.

            1.  Run rewind given `parser`.

                We next determine at which component the relative pattern begins. Relative pathnames are most common, but URLs and URLPattern constructor strings can begin with the search or hash components as well.

            2.  If the result of running is a hash prefix given `parser` is true, then run change state given `parser`, "`hash`" and 1.

            3.  Otherwise if the result of running is a search prefix given `parser` is true:

                1.  Run change state given `parser`, "`search`" and 1.

            4.  Otherwise:

                1.  Run change state given `parser`, "`pathname`" and 0.

            5.  Increment `parser`'s token index by `parser`'s token increment.

            6.  Continue.

        2.  If `parser`'s state is "`authority`":

            If we reached the end of the string in the "`authority`" state, then we failed to find an "`@`". Therefore there is no username or password.

            1.  Run rewind and set state given `parser`, and "`hostname`".

            2.  Increment `parser`'s token index by `parser`'s token increment.

            3.  Continue.

        3.  Run change state given `parser`, "`done`" and 0.

        4.  Break.

    3.  If the result of running is a group open given `parser` is true:

        We ignore all code points within "`{ ... }`" pattern groupings. It would not make sense to allow a URL component boundary to lie within a grouping; e.g. "`https://example.c{om/fo}o`". While not supported within well formed pattern strings, we handle nested groupings here to avoid parser confusion.

        It is not necessary to perform this logic for regexp or named groups since those values are collapsed into individual tokens by the tokenize algorithm.

        1.  Increment `parser`'s group depth by 1.

        2.  Increment `parser`'s token index by `parser`'s token increment.

        3.  Continue.

    4.  If `parser`'s group depth is greater than 0:

        1.  If the result of running is a group close given `parser` is true, then decrement `parser`'s group depth by 1.

        2.  Otherwise:

            1.  Increment `parser`'s token index by `parser`'s token increment.

            2.  Continue.

    5.  Switch on `parser`'s state and run the associated steps:

        "`init`"

        :   1.  If the result of running is a protocol suffix given `parser` is true:

                1.  Run rewind and set state given `parser` and "`protocol`".

        "`protocol`"

        :   1.  If the result of running is a protocol suffix given `parser` is true:

                1.  Run compute protocol matches a special scheme flag given `parser`.

                    We need to eagerly compile the protocol component to determine if it matches any special schemes. If it does then certain special rules apply. It determines if the pathname defaults to a "`/`" and also whether we will look for the username, password, hostname, and port components. Authority slashes can also cause us to look for these components as well. Otherwise we treat this as an "opaque path URL" and go straight to the pathname component.

                2.  Let `next state` be "`pathname`".

                3.  Let `skip` be 1.

                4.  If the result of running next is authority slashes given `parser` is true:

                    1.  Set `next state` to "`authority`".

                    2.  Set `skip` to 3.

                5.  Otherwise if `parser`'s protocol matches a special scheme flag is true, then set `next state` to "`authority`".

                6.  Run change state given `parser`, `next state`, and `skip`.

        "`authority`"

        :   1.  If the result of running is an identity terminator given `parser` is true, then run rewind and set state given `parser` and "`username`".

            2.  Otherwise if any of the following are true:

                - the result of running is a pathname start given `parser`;
                - the result of running is a search prefix given `parser`; or
                - the result of running is a hash prefix given `parser`,

                then run rewind and set state given `parser` and "`hostname`".

        "`username`"

        :   1.  If the result of running is a password prefix given `parser` is true, then run change state given `parser`, "`password`", and 1.

            2.  Otherwise if the result of running is an identity terminator given `parser` is true, then run change state given `parser`, "`hostname`", and 1.

        "`password`"

        :   1.  If the result of running is an identity terminator given `parser` is true, then run change state given `parser`, "`hostname`", and 1.

        "`hostname`"

        :   1.  If the result of running is an IPv6 open given `parser` is true, then increment `parser`'s hostname IPv6 bracket depth by 1.

            2.  Otherwise if the result of running is an IPv6 close given `parser` is true, then decrement `parser`'s hostname IPv6 bracket depth by 1.

            3.  Otherwise if the result of running is a port prefix given `parser` is true and `parser`'s hostname IPv6 bracket depth is zero, then run change state given `parser`, "`port`", and 1.

            4.  Otherwise if the result of running is a pathname start given `parser` is true, then run change state given `parser`, "`pathname`", and 0.

            5.  Otherwise if the result of running is a search prefix given `parser` is true, then run change state given `parser`, "`search`", and 1.

            6.  Otherwise if the result of running is a hash prefix given `parser` is true, then run change state given `parser`, "`hash`", and 1.

        "`port`"

        :   1.  If the result of running is a pathname start given `parser` is true, then run change state given `parser`, "`pathname`", and 0.

            2.  Otherwise if the result of running is a search prefix given `parser` is true, then run change state given `parser`, "`search`", and 1.

            3.  Otherwise if the result of running is a hash prefix given `parser` is true, then run change state given `parser`, "`hash`", and 1.

        "`pathname`"

        :   1.  If the result of running is a search prefix given `parser` is true, then run change state given `parser`, "`search`", and 1.

            2.  Otherwise if the result of running is a hash prefix given `parser` is true, then run change state given `parser`, "`hash`", and 1.

        "`search`"

        :   1.  If the result of running is a hash prefix given `parser` is true, then run change state given `parser`, "`hash`", and 1.

        "`hash`"

        :   1.  Do nothing.

        "`done`"

        :   1.  Assert: This step is never reached.

    6.  Increment `parser`'s token index by `parser`'s token increment.

3.  If `parser`'s result contains "`hostname`" and not "`port`", then set `parser`'s result["`port`"] to the empty string.

    This is special-cased because when an author does not specify a port, they usually intend the default port. If any port is acceptable, the author can specify it as a wildcard explicitly. For example, "`https://example.com/*`" does not match URLs beginning with "`https://example.com:8443/`", which is a different origin.

4.  Return `parser`'s result.

To change state given a constructor string parser `parser`, a state `new state`, and a number `skip`:

1.  If `parser`'s state is not "`init`", not "`authority`", and not "`done`", then set `parser`'s result[`parser`'s state] to the result of running make a component string given `parser`.

2.  If `parser`'s state is not "`init`" and `new state` is not "`done`", then:

    1.  If `parser`'s state is "`protocol`", "`authority`", "`username`", or "`password`"; `new state` is "`port`", "`pathname`", "`search`", or "`hash`"; and `parser`'s result["`hostname`"] does not exist, then set `parser`'s result["`hostname`"] to the empty string.

    2.  If `parser`'s state is "`protocol`", "`authority`", "`username`", "`password`", "`hostname`", or "`port`"; `new state` is "`search`" or "`hash`"; and `parser`'s result["`pathname`"] does not exist, then:

        1.  If `parser`'s protocol matches a special scheme flag is true, then set `parser`'s result["`pathname`"] to "`/`".

        2.  Otherwise, set `parser`'s result["`pathname`"] to the empty string.

    3.  If `parser`'s state is "`protocol`", "`authority`", "`username`", "`password`", "`hostname`", "`port`", or "`pathname`"; `new state` is "`hash`"; and `parser`'s result["`search`"] does not exist, then set `parser`'s result["`search`"] to the empty string.

3.  Set `parser`'s state to `new state`.

4.  Increment `parser`'s token index by `skip`.

5.  Set `parser`'s component start to `parser`'s token index.

6.  Set `parser`'s token increment to 0.

To rewind given a constructor string parser `parser`:

1.  Set `parser`'s token index to `parser`'s component start.

2.  Set `parser`'s token increment to 0.

To rewind and set state given a constructor string parser `parser` and a state `state`:

1.  Run rewind given `parser`.

2.  Set `parser`'s state to `state`.

To get a safe token given a constructor string parser `parser` and a number `index`:

1.  If `index` is less than `parser`'s token list's size, then return `parser`'s token list[`index`].

2.  Assert: `parser`'s token list's size is greater than or equal to 1.

3.  Let `last index` be `parser`'s token list's size − 1.

4.  Let `token` be `parser`'s token list[`last index`].

5.  Assert: `token`'s type is "`end`".

6.  Return `token`.

To run is a non-special pattern char given a constructor string parser `parser`, a number `index`, and a string `value`:

1.  Let `token` be the result of running get a safe token given `parser` and `index`.

2.  If `token`'s value is not `value`, then return false.

3.  If any of the following are true:

    - `token`'s type is "`char`";
    - `token`'s type is "`escaped-char`"; or
    - `token`'s type is "`invalid-char`",

    then return true.

4.  Return false.

To run is a protocol suffix given a constructor string parser `parser`:

1.  Return the result of running is a non-special pattern char given `parser`, `parser`'s token index, and "`:`".

To run next is authority slashes given a constructor string parser `parser`:

1.  If the result of running is a non-special pattern char given `parser`, `parser`'s token index + 1, and "`/`" is false, then return false.

2.  If the result of running is a non-special pattern char given `parser`, `parser`'s token index + 2, and "`/`" is false, then return false.

3.  Return true.

To run is an identity terminator given a constructor string parser `parser`:

1.  Return the result of running is a non-special pattern char given `parser`, `parser`'s token index, and "`@`".

To run is a password prefix given a constructor string parser `parser`:

1.  Return the result of running is a non-special pattern char given `parser`, `parser`'s token index, and "`:`".

To run is a port prefix given a constructor string parser `parser`:

1.  Return the result of running is a non-special pattern char given `parser`, `parser`'s token index, and "`:`".

To run is a pathname start given a constructor string parser `parser`:

1.  Return the result of running is a non-special pattern char given `parser`, `parser`'s token index, and "`/`".

To run is a search prefix given a constructor string parser `parser`:

1.  If result of running is a non-special pattern char given `parser`, `parser`'s token index and "`?`" is true, then return true.

2.  If `parser`'s token list[`parser`'s token index]'s value is not "`?`", then return false.

3.  Let `previous index` be `parser`'s token index − 1.

4.  If `previous index` is less than 0, then return true.

5.  Let `previous token` be the result of running get a safe token given `parser` and `previous index`.

6.  If any of the following are true, then return false:

    - `previous token`'s type is "`name`".
    - `previous token`'s type is "`regexp`".
    - `previous token`'s type is "`close`".
    - `previous token`'s type is "`asterisk`".

7.  Return true.

To run is a hash prefix given a constructor string parser `parser`:

1.  Return the result of running is a non-special pattern char given `parser`, `parser`'s token index and "`#`".

To run is a group open given a constructor string parser `parser`:

1.  If `parser`'s token list[`parser`'s token index]'s type is "`open`", then return true.

2.  Otherwise return false.

To run is a group close given a constructor string parser `parser`:

1.  If `parser`'s token list[`parser`'s token index]'s type is "`close`", then return true.

2.  Otherwise return false.

To run is an IPv6 open given a constructor string parser `parser`:

1.  Return the result of running is a non-special pattern char given `parser`, `parser`'s token index, and "`[`".

To run is an IPv6 close given a constructor string parser `parser`:

1.  Return the result of running is a non-special pattern char given `parser`, `parser`'s token index, and "`]`".

To run make a component string given a constructor string parser `parser`:

1.  Assert: `parser`'s token index is less than `parser`'s token list's size.

2.  Let `token` be `parser`'s token list[`parser`'s token index].

3.  Let `component start token` be the result of running get a safe token given `parser` and `parser`'s component start.

4.  Let `component start input index` be `component start token`'s index.

5.  Let `end index` be `token`'s index.

6.  Return the code point substring from `component start input index` to `end index` within `parser`'s input.

To compute protocol matches a special scheme flag given a constructor string parser `parser`:

1.  Let `protocol string` be the result of running make a component string given `parser`.

2.  Let `protocol component` be the result of compiling a component given `protocol string`, canonicalize a protocol, and default options.

3.  If the result of running protocol component matches a special scheme given `protocol component` is true, then set `parser`'s protocol matches a special scheme flag to true.


## Pattern strings

A **pattern string** is a string that is written to match a set of target strings. A **well formed** pattern string conforms to a particular pattern syntax. This pattern syntax is directly based on the syntax used by the popular [path-to-regexp](https://github.com/pillarjs/path-to-regexp) JavaScript library.

It can be parsed to produce a **part list** which describes, in order, what must appear in a component string for the pattern string to match.

Pattern strings can contain capture groups, which by default match the shortest possible string, up to a component-specific separator (`/` in the pathname, `.` in the hostname). For example, the pathname pattern "`/blog/:title`" will match "`/blog/hello-world`" but not "`/blog/2012/02`".

A regular expression enclosed in parentheses can also be used instead, so the pathname pattern "`/blog/:year(\d+)/:month(\d+)`" will match "`/blog/2012/02`".

A group can also be made optional, or repeated, by using a modifier. For example, the pathname pattern "`/products/:id?`" will match both "`/products`" and "`/products/2`" (but not "`/products/`"). In the pathname specifically, groups automatically require a leading `/`; to avoid this, the group can be explicitly deliminated, as in the pathname pattern "`/products/{:id}?`".

A full wildcard `*` can also be used to match as much as possible, as in the pathname pattern "`/products/*`".


### Parsing pattern strings


#### Tokens

A **token list** is a list containing zero or more token structs.

A **token** is a struct representing a single lexical token within a pattern string.

A token has an associated **type**, a string, initially "**`invalid-char`**". It must be one of the following:

"**`open`**"
:   The token represents a U+007B (`{`) code point.

"**`close`**"
:   The token represents a U+007D (`}`) code point.

"**`regexp`**"
:   The token represents a string of the form "`(<regular expression>)`". The regular expression is required to consist of only ASCII code points.

"**`name`**"
:   The token represents a string of the form "`:<name>`". The name value is restricted to code points that are consistent with JavaScript identifiers.

"**`char`**"
:   The token represents a valid pattern code point without any special syntactical meaning.

"**`escaped-char`**"
:   The token represents a code point escaped using a backslash like "`\<char>`".

"**`other-modifier`**"
:   The token represents a matching group modifier that is either the U+003F (`?`) or U+002B (`+`) code points.

"**`asterisk`**"
:   The token represents a U+002A (`*`) code point that can be either a wildcard matching group or a matching group modifier.

"**`end`**"
:   The token represents the end of the pattern string.

"**`invalid-char`**"
:   The token represents a code point that is invalid in the pattern. This could be because of the code point value itself or due to its location within the pattern relative to other syntactic elements.

A token has an associated **index**, a number, initially 0. It is the position of the first code point in the pattern string represented by the token.

A token has an associated **value**, a string, initially the empty string. It contains the code points from the pattern string represented by the token.


#### Tokenizing

A **tokenize policy** is a string that must be either "**`strict`**" or "**`lenient`**".

A **tokenizer** is a struct.

A tokenizer has an associated **input**, a pattern string, initially the empty string.

A tokenizer has an associated **policy**, a tokenize policy, initially "`strict`".

A tokenizer has an associated **token list**, a token list, initially an empty list.

A tokenizer has an associated **index**, a number, initially 0.

A tokenizer has an associated **next index**, a number, initially 0.

A tokenizer has an associated **code point**, a Unicode code point, initially null.

To **tokenize** a given string `input` and tokenize policy `policy`:

1.  Let `tokenizer` be a new tokenizer.

2.  Set `tokenizer`'s input to `input`.

3.  Set `tokenizer`'s policy to `policy`.

4.  While `tokenizer`'s index is less than `tokenizer`'s input's code point length:

    1.  Run seek and get the next code point given `tokenizer` and `tokenizer`'s index.

    2.  If `tokenizer`'s code point is U+002A (`*`):

        1.  Run add a token with default position and length given `tokenizer` and "`asterisk`".

        2.  Continue.

    3.  If `tokenizer`'s code point is U+002B (`+`) or U+003F (`?`):

        1.  Run add a token with default position and length given `tokenizer` and "`other-modifier`".

        2.  Continue.

    4.  If `tokenizer`'s code point is U+005C (`\`):

        1.  If `tokenizer`'s index is equal to `tokenizer`'s input's code point length − 1:

            1.  Run process a tokenizing error given `tokenizer`, `tokenizer`'s next index, and `tokenizer`'s index.

            2.  Continue.

        2.  Let `escaped index` be `tokenizer`'s next index.

        3.  Run get the next code point given `tokenizer`.

        4.  Run add a token with default length given `tokenizer`, "`escaped-char`", `tokenizer`'s next index, and `escaped index`.

        5.  Continue.

    5.  If `tokenizer`'s code point is U+007B (`{`):

        1.  Run add a token with default position and length given `tokenizer` and "`open`".

        2.  Continue.

    6.  If `tokenizer`'s code point is U+007D (`}`):

        1.  Run add a token with default position and length given `tokenizer` and "`close`".

        2.  Continue.

    7.  If `tokenizer`'s code point is U+003A (`:`):

        1.  Let `name position` be `tokenizer`'s next index.

        2.  Let `name start` be `name position`.

        3.  While `name position` is less than `tokenizer`'s input's code point length:

            1.  Run seek and get the next code point given `tokenizer` and `name position`.

            2.  Let `first code point` be true if `name position` equals `name start` and false otherwise.

            3.  Let `valid code point` be the result of running is a valid name code point given `tokenizer`'s code point and `first code point`.

            4.  If `valid code point` is false break.

            5.  Set `name position` to `tokenizer`'s next index.

        4.  If `name position` is less than or equal to `name start`:

            1.  Run process a tokenizing error given `tokenizer`, `name start`, and `tokenizer`'s index.

            2.  Continue.

        5.  Run add a token with default length given `tokenizer`, "`name`", `name position`, and `name start`.

        6.  Continue.

    8.  If `tokenizer`'s code point is U+0028 (`(`):

        1.  Let `depth` be 1.

        2.  Let `regexp position` be `tokenizer`'s next index.

        3.  Let `regexp start` be `regexp position`.

        4.  Let `error` be false.

        5.  While `regexp position` is less than `tokenizer`'s input's code point length:

            1.  Run seek and get the next code point given `tokenizer` and `regexp position`.

            2.  If `tokenizer`'s code point is not an ASCII code point:

                1.  Run process a tokenizing error given `tokenizer`, `regexp start`, and `tokenizer`'s index.

                2.  Set `error` to true.

                3.  Break.

            3.  If `regexp position` equals `regexp start` and `tokenizer`'s code point is U+003F (`?`):

                1.  Run process a tokenizing error given `tokenizer`, `regexp start`, and `tokenizer`'s index.

                2.  Set `error` to true.

                3.  Break.

            4.  If `tokenizer`'s code point is U+005C (`\`):

                1.  If `regexp position` equals `tokenizer`'s input's code point length − 1:

                    1.  Run process a tokenizing error given `tokenizer`, `regexp start`, and `tokenizer`'s index.

                    2.  Set `error` to true.

                    3.  Break

                2.  Run get the next code point given `tokenizer`.

                3.  If `tokenizer`'s code point is not an ASCII code point:

                    1.  Run process a tokenizing error given `tokenizer`, `regexp start`, and `tokenizer`'s index.

                    2.  Set `error` to true.

                    3.  Break.

                4.  Set `regexp position` to `tokenizer`'s next index.

                5.  Continue.

            5.  If `tokenizer`'s code point is U+0029 (`)`):

                1.  Decrement `depth` by 1.

                2.  If `depth` is 0:

                    1.  Set `regexp position` to `tokenizer`'s next index.

                    2.  Break.

            6.  Otherwise if `tokenizer`'s code point is U+0028 (`(`):

                1.  Increment `depth` by 1.

                2.  If `regexp position` equals `tokenizer`'s input's code point length − 1:

                    1.  Run process a tokenizing error given `tokenizer`, `regexp start`, and `tokenizer`'s index.

                    2.  Set `error` to true.

                    3.  Break

                3.  Let `temporary position` be `tokenizer`'s next index.

                4.  Run get the next code point given `tokenizer`.

                5.  If `tokenizer`'s code point is not U+003F (`?`):

                    1.  Run process a tokenizing error given `tokenizer`, `regexp start`, and `tokenizer`'s index.

                    2.  Set `error` to true.

                    3.  Break.

                6.  Set `tokenizer`'s next index to `temporary position`.

            7.  Set `regexp position` to `tokenizer`'s next index.

        6.  If `error` is true continue.

        7.  If `depth` is not zero:

            1.  Run process a tokenizing error given `tokenizer`, `regexp start`, and `tokenizer`'s index.

            2.  Continue.

        8.  Let `regexp length` be `regexp position` − `regexp start` − 1.

        9.  If `regexp length` is zero:

            1.  Run process a tokenizing error given `tokenizer`, `regexp start`, and `tokenizer`'s index.

            2.  Continue.

        10. Run add a token given `tokenizer`, "`regexp`", `regexp position`, `regexp start`, and `regexp length`.

        11. Continue.

    9.  Run add a token with default position and length given `tokenizer` and "`char`".

5.  Run add a token with default length given `tokenizer`, "`end`", `tokenizer`'s index, and `tokenizer`'s index.

6.  Return `tokenizer`'s token list.

To **get the next code point** for a given tokenizer `tokenizer`:

1.  Set `tokenizer`'s code point to the Unicode code point in `tokenizer`'s input at the position indicated by `tokenizer`'s next index.

2.  Increment `tokenizer`'s next index by 1.

To **seek and get the next code point** for a given tokenizer `tokenizer` and number `index`:

1.  Set `tokenizer`'s next index to `index`.

2.  Run get the next code point given `tokenizer`.

To **add a token** for a given tokenizer `tokenizer`, type `type`, number `next position`, number `value position`, and number `value length`:

1.  Let `token` be a new token.

2.  Set `token`'s type to `type`.

3.  Set `token`'s index to `tokenizer`'s index.

4.  Set `token`'s value to the code point substring from `value position` with length `value length` within `tokenizer`'s input.

5.  Append `token` to the back of `tokenizer`'s token list.

6.  Set `tokenizer`'s index to `next position`.

To **add a token with default length** for a given tokenizer `tokenizer`, type `type`, number `next position`, and number `value position`:

1.  Let `computed length` be `next position` − `value position`.

2.  Run add a token given `tokenizer`, `type`, `next position`, `value position`, and `computed length`.

To **add a token with default position and length** for a given tokenizer `tokenizer` and type `type`:

1.  Run add a token with default length given `tokenizer`, `type`, `tokenizer`'s next index, and `tokenizer`'s index.

To **process a tokenizing error** for a given tokenizer `tokenizer`, a number `next position`, and a number `value position`:

1.  If `tokenizer`'s policy is "`strict`", then throw a `TypeError`.

2.  Assert: `tokenizer`'s policy is "`lenient`".

3.  Run add a token with default length given `tokenizer`, "`invalid-char`", `next position`, and `value position`.

To perform **is a valid name code point** given a Unicode `code point` and a boolean `first`:

1.  If `first` is true return the result of checking if `code point` is contained in the IdentifierStart set of code points.

2.  Otherwise return the result of checking if `code point` is contained in the IdentifierPart set of code points.


#### Parts

A **part list** is a list of zero or more parts.

A **part** is a struct representing one piece of a parser pattern string. It can contain at most one matching group, a fixed text prefix, a fixed text suffix, and a modifier. It can contain as little as a single fixed text string or a single matching group.

A part has an associated **type**, a string, which must be set upon creation. It must be one of the following:

"**`fixed-text`**"
:   The part represents a simple fixed text string.

"**`regexp`**"
:   The part represents a matching group with a custom regular expression.

"**`segment-wildcard`**"
:   The part represents a matching group that matches code points up to the next separator code point. This is typically used for a named group like "`:foo`" that does not have a custom regular expression.

"**`full-wildcard`**"
:   The part represents a matching group that greedily matches all code points. This is typically used for the "`*`" wildcard matching group.

A part has an associated **value**, a string, which must be set upon creation.

A part has an associated **modifier** a string, which must be set upon creation. It must be one of the following:

"**`none`**"
:   The part does not have a modifier.

"**`optional`**"
:   The part has an optional modifier indicated by the U+003F (`?`) code point.

"**`zero-or-more`**"
:   The part has a "zero or more" modifier indicated by the U+002A (`*`) code point.

"**`one-or-more`**"
:   The part has a "one or more" modifier indicated by the U+002B (`+`) code point.

A part has an associated **name**, a string, initially the empty string.

A part has an associated **prefix**, a string, initially the empty string.

A part has an associated **suffix**, a string, initially the empty string.


#### Options

An **options** struct contains different settings that control how pattern string behaves. These options originally come from [path-to-regexp](https://github.com/pillarjs/path-to-regexp). We only include the options that are modified within the URLPattern specification and exclude the other options. For the purposes of comparison, this specification acts like [path-to-regexp](https://github.com/pillarjs/path-to-regexp) where `strict`, `start`, and `end` are always set to false.

An options has an associated **delimiter code point**, a string, which must be set upon creation. It must contain one ASCII code point or the empty string. This code point is treated as a segment separator and is used for determining how far a `:foo` named group should match by default. For example, if the delimiter code point is "`/`" then "`/:foo`" will match "`/bar`", but not "`/bar/baz`". If the delimiter code point is the empty string then the example pattern would match both strings.

An options has an associated **prefix code point**, a string, which must be set upon creation. It must contain one ASCII code point or the empty string. The code point is treated as an automatic prefix if found immediately preceding a match group. This matters when a match group is modified to be optional or repeating. For example, if prefix code point is "`/`" then "`/foo/:bar?/baz`" will treat the "`/`" before "`:bar`" as a prefix that becomes optional along with the named group. So in this example the pattern would match "`/foo/baz`".

An options has an associated **ignore case**, a boolean, which must be set up upon creation. It defaults to false. Depending on the set value, true or false, this flag enables case-sensitive or case-insensitive matches, respectively. For the purpose of comparison, this case be thought of as the negated `sensitive` option in [path-to-regexp](https://github.com/pillarjs/path-to-regexp).


#### Parsing

An **encoding callback** is an abstract algorithm that takes a given string `input`. The `input` will be a simple text piece of a pattern string. An implementing algorithm will validate and encode the `input`. It must return the encoded string or throw an exception.

A **pattern parser** is a struct.

A pattern parser has an associated **token list**, a token list, initially an empty list.

A pattern parser has an associated **encoding callback**, a encoding callback, that must be set upon creation.

A pattern parser has an associated **segment wildcard regexp**, a string, that must be set upon creation.

A pattern parser has an associated **part list**, a part list, initially an empty list.

A pattern parser has an associated **pending fixed value**, a string, initially the empty string.

A pattern parser has an associated **index**, a number, initially 0.

A pattern parser has an associated **next numeric name**, a number, initially 0.

To **parse a pattern string** given a pattern string `input`, options `options`, and encoding callback `encoding callback`:

1.  Let `parser` be a new pattern parser whose encoding callback is `encoding callback` and segment wildcard regexp is the result of running generate a segment wildcard regexp given `options`.

2.  Set `parser`'s token list to the result of running tokenize given `input` and "`strict`".

3.  While `parser`'s index is less than `parser`'s token list's size:

    1.  Let `char token` be the result of running try to consume a token given `parser` and "`char`".

    2.  Let `name token` be the result of running try to consume a token given `parser` and "`name`".

    3.  Let `regexp or wildcard token` be the result of running try to consume a regexp or wildcard token given `parser` and `name token`.

    4.  If `name token` is not null or `regexp or wildcard token` is not null:

        1.  Let `prefix` be the empty string.

        2.  If `char token` is not null then set `prefix` to `char token`'s value.

        3.  If `prefix` is not the empty string and not `options`'s prefix code point:

            1.  Append `prefix` to the end of `parser`'s pending fixed value.

            2.  Set `prefix` to the empty string.

        4.  Run maybe add a part from the pending fixed value given `parser`.

        5.  Let `modifier token` be the result of running try to consume a modifier token given `parser`.

        6.  Run add a part given `parser`, `prefix`, `name token`, `regexp or wildcard token`, the empty string, and `modifier token`.

        7.  Continue.

    5.  Let `fixed token` be `char token`.

    6.  If `fixed token` is null, then set `fixed token` to the result of running try to consume a token given `parser` and "`escaped-char`".

    7.  If `fixed token` is not null:

        1.  Append `fixed token`'s value to `parser`'s pending fixed value.

        2.  Continue.

    8.  Let `open token` be the result of running try to consume a token given `parser` and "`open`".

    9.  If `open token` is not null:

        1.  Let `prefix` be the result of running consume text given `parser`.

        2.  Set `name token` to the result of running try to consume a token given `parser` and "`name`".

        3.  Set `regexp or wildcard token` to the result of running try to consume a regexp or wildcard token given `parser` and `name token`.

        4.  Let `suffix` be the result of running consume text given `parser`.

        5.  Run consume a required token given `parser` and "`close`".

        6.  Let `modifier token` be the result of running try to consume a modifier token given `parser`.

        7.  Run add a part given `parser`, `prefix`, `name token`, `regexp or wildcard token`, `suffix`, and `modifier token`.

        8.  Continue.

    10. Run maybe add a part from the pending fixed value given `parser`.

    11. Run consume a required token given `parser` and "`end`".

4.  Return `parser`'s part list.

The **full wildcard regexp value** is the string "`.*`".

To **generate a segment wildcard regexp** given an options `options`:

1.  Let `result` be "`[^`".

2.  Append the result of running escape a regexp string given `options`'s delimiter code point to the end of `result`.

3.  Append "`]+?`" to the end of `result`.

4.  Return `result`.

To **try to consume a token** given a pattern parser `parser` and type `type`:

1.  Assert: `parser`'s index is less than `parser`'s token list size.

2.  Let `next token` be `parser`'s token list[`parser`'s index].

3.  If `next token`'s type is not `type` return null.

4.  Increment `parser`'s index by 1.

5.  Return `next token`.

To **try to consume a modifier token** given a pattern parser `parser`:

1.  Let `token` be the result of running try to consume a token given `parser` and "`other-modifier`".

2.  If `token` is not null, then return `token`.

3.  Set `token` to the result of running try to consume a token given `parser` and "`asterisk`".

4.  Return `token`.

To **try to consume a regexp or wildcard token** given a pattern parser `parser` and token `name token`:

1.  Let `token` be the result of running try to consume a token given `parser` and "`regexp`".

2.  If `name token` is null and `token` is null, then set `token` to the result of running try to consume a token given `parser` and "`asterisk`".

3.  Return `token`.

To **consume a required token** given a pattern parser `parser` and type `type`:

1.  Let `result` be the result of running try to consume a token given `parser` and `type`.

2.  If `result` is null, then throw a `TypeError`.

3.  Return `result`.

To **consume text** given a pattern parser `parser`:

1.  Let `result` be the empty string.

2.  While true:

    1.  Let `token` be the result of running try to consume a token given `parser` and "`char`".

    2.  If `token` is null, then set `token` to the result of running try to consume a token given `parser` and "`escaped-char`".

    3.  If `token` is null, then break.

    4.  Append `token`'s value to the end of `result`.

3.  Return `result`.

To **maybe add a part from the pending fixed value** given a pattern parser `parser`:

1.  If `parser`'s pending fixed value is the empty string, then return.

2.  Let `encoded value` be the result of running `parser`'s encoding callback given `parser`'s pending fixed value.

3.  Set `parser`'s pending fixed value to the empty string.

4.  Let `part` be a new part whose type is "`fixed-text`", value is `encoded value`, and modifier is "`none`".

5.  Append `part` to `parser`'s part list.

To **add a part** given a pattern parser `parser`, a string `prefix`, a token `name token`, a token `regexp or wildcard token`, a string `suffix`, and a token `modifier token`:

1.  Let `modifier` be "`none`".

2.  If `modifier token` is not null:

    1.  If `modifier token`'s value is "`?`" then set `modifier` to "`optional`".

    2.  Otherwise if `modifier token`'s value is "`*`" then set `modifier` to "`zero-or-more`".

    3.  Otherwise if `modifier token`'s value is "`+`" then set `modifier` to "`one-or-more`".

3.  If `name token` is null and `regexp or wildcard token` is null and `modifier` is "`none`":

    1.  Append `prefix` to the end of `parser`'s pending fixed value.

    2.  Return.

4.  Run maybe add a part from the pending fixed value given `parser`.

5.  If `name token` is null and `regexp or wildcard token` is null:

    1.  Assert: `suffix` is the empty string.

    2.  If `prefix` is the empty string, then return.

    3.  Let `encoded value` be the result of running `parser`'s encoding callback given `prefix`.

    4.  Let `part` be a new part whose type is "`fixed-text`", value is `encoded value`, and modifier is `modifier`.

    5.  Append `part` to `parser`'s part list.

    6.  Return.

6.  Let `regexp value` be the empty string.

7.  If `regexp or wildcard token` is null, then set `regexp value` to `parser`'s segment wildcard regexp.

8.  Otherwise if `regexp or wildcard token`'s type is "`asterisk`", then set `regexp value` to the full wildcard regexp value.

9.  Otherwise set `regexp value` to `regexp or wildcard token`'s value.

10. Let `type` be "`regexp`".

11. If `regexp value` is `parser`'s segment wildcard regexp:

    1.  Set `type` to "`segment-wildcard`".

    2.  Set `regexp value` to the empty string.

12. Otherwise if `regexp value` is the full wildcard regexp value:

    1.  Set `type` to "`full-wildcard`".

    2.  Set `regexp value` to the empty string.

13. Let `name` be the empty string.

14. If `name token` is not null, then set `name` to `name token`'s value.

15. Otherwise if `regexp or wildcard token` is not null:

    1.  Set `name` to `parser`'s next numeric name, serialized.

    2.  Increment `parser`'s next numeric name by 1.

16. If the result of running is a duplicate name given `parser` and `name` is true, then throw a `TypeError`.

17. Let `encoded prefix` be the result of running `parser`'s encoding callback given `prefix`.

18. Let `encoded suffix` be the result of running `parser`'s encoding callback given `suffix`.

19. Let `part` be a new part whose type is `type`, value is `regexp value`, modifier is `modifier`, name is `name`, prefix is `encoded prefix`, and suffix is `encoded suffix`.

20. Append `part` to `parser`'s part list.

To determine if a value **is a duplicate name** given a pattern parser `parser` and a string `name`:

1.  For each `part` of `parser`'s part list:

    1.  If `part`'s name is `name`, then return true.

2.  Return false.


### Converting part lists to regular expressions

To **generate a regular expression and name list** from a given part list `part list` and options `options`:

1.  Let `result` be "`^`".

2.  Let `name list` be a new list.

3.  For each `part` of `part list`:

    1.  If `part`'s type is "`fixed-text`":

        1.  If `part`'s modifier is "`none`", then append the result of running escape a regexp string given `part`'s value to the end of `result`.

        2.  Otherwise:

            1.  Append "`(?:`" to the end of `result`.

            2.  Append the result of running escape a regexp string given `part`'s value to the end of `result`.

            3.  Append "`)`" to the end of `result`.

            4.  Append the result of running convert a modifier to a string given `part`'s modifier to the end of `result`.

        3.  Continue.

    2.  Assert: `part`'s name is not the empty string.

    3.  Append `part`'s name to `name list`.

    4.  Let `regexp value` be `part`'s value.

    5.  If `part`'s type is "`segment-wildcard`", then set `regexp value` to the result of running generate a segment wildcard regexp given `options`.

    6.  Otherwise if `part`'s type is "`full-wildcard`", then set `regexp value` to full wildcard regexp value.

    7.  If `part`'s prefix is the empty string and `part`'s suffix is the empty string:

        1.  If `part`'s modifier is "`none`" or "`optional`", then:

            1.  Append "`(`" to the end of `result`.

            2.  Append `regexp value` to the end of `result`.

            3.  Append "`)`" to the end of `result`.

            4.  Append the result of running convert a modifier to a string given `part`'s modifier to the end of `result`.

        2.  Otherwise:

            1.  Append "`((?:`" to the end of `result`.

            2.  Append `regexp value` to the end of `result`.

            3.  Append "`)`" to the end of `result`.

            4.  Append the result of running convert a modifier to a string given `part`'s modifier to the end of `result`.

            5.  Append "`)`" to the end of `result`.

        3.  Continue.

    8.  If `part`'s modifier is "`none`" or "`optional`":

        1.  Append "`(?:`" to the end of `result`.

        2.  Append the result of running escape a regexp string given `part`'s prefix to the end of `result`.

        3.  Append "`(`" to the end of `result`.

        4.  Append `regexp value` to the end of `result`.

        5.  Append "`)`" to the end of `result`.

        6.  Append the result of running escape a regexp string given `part`'s suffix to the end of `result`.

        7.  Append "`)`" to the end of `result`.

        8.  Append the result of running convert a modifier to a string given `part`'s modifier to the end of `result`.

        9.  Continue.

    9.  Assert: `part`'s modifier is "`zero-or-more`" or "`one-or-more`".

    10. Assert: `part`'s prefix is not the empty string or `part`'s suffix is not the empty string.

    11. Append "`(?:`" to the end of `result`.

    12. Append the result of running escape a regexp string given `part`'s prefix to the end of `result`.

    13. Append "`((?:`" to the end of `result`.

    14. Append `regexp value` to the end of `result`.

    15. Append "`)(?:`" to the end of `result`.

    16. Append the result of running escape a regexp string given `part`'s suffix to the end of `result`.

    17. Append the result of running escape a regexp string given `part`'s prefix to the end of `result`.

    18. Append "`(?:`" to the end of `result`.

    19. Append `regexp value` to the end of `result`.

    20. Append "`))*)`" to the end of `result`.

    21. Append the result of running escape a regexp string given `part`'s suffix to the end of `result`.

    22. Append "`)`" to the end of `result`.

    23. If `part`'s modifier is "`zero-or-more`" then append "`?`" to the end of `result`.

4.  Append "`$`" to the end of `result`.

5.  Return (`result`, `name list`).

To **escape a regexp string** given a string `input`:

1.  Assert: `input` is an ASCII string.

2.  Let `result` be the empty string.

3.  Let `index` be 0.

4.  While `index` is less than `input`'s length:

    1.  Let `c` be `input`[`index`].

    2.  Increment `index` by 1.

    3.  If `c` is one of:

        - U+002E (`.`);
        - U+002B (`+`);
        - U+002A (`*`);
        - U+003F (`?`);
        - U+005E (`^`);
        - U+0024 (`$`);
        - U+007B (`{`);
        - U+007D (`}`);
        - U+0028 (`(`);
        - U+0029 (`)`);
        - U+005B (`[`);
        - U+005D (`]`);
        - U+007C (`|`);
        - U+002F (`/`); or
        - U+005C (`\`),

        then append "`\`" to the end of `result`.

    4.  Append `c` to the end of `result`.

5.  Return `result`.


### Converting part lists to pattern strings

To **generate a pattern string** from a given part list `part list` and options `options`:

1.  Let `result` be the empty string.

2.  Let `index list` be the result of getting the indices for `part list`.

3.  For each `index` of `index list`:

    1.  Let `part` be `part list`[`index`].

    2.  Let `previous part` be `part list`[`index` - 1] if `index` is greater than 0, otherwise let it be null.

    3.  Let `next part` be `part list`[`index` + 1] if `index` is less than `index list`'s size - 1, otherwise let it be null.

    4.  If `part`'s type is "`fixed-text`" then:

        1.  If `part`'s modifier is "`none`" then:

            1.  Append the result of running escape a pattern string given `part`'s value to the end of `result`.

            2.  Continue.

        2.  Append "`{`" to the end of `result`.

        3.  Append the result of running escape a pattern string given `part`'s value to the end of `result`.

        4.  Append "`}`" to the end of `result`.

        5.  Append the result of running convert a modifier to a string given `part`'s modifier to the end of `result`.

        6.  Continue.

    5.  Let `custom name` be true if `part`'s name[0] is not an ASCII digit; otherwise false.

    6.  Let `needs grouping` be true if at least one of the following are true, otherwise let it be false:

        - `part`'s suffix is not the empty string.
        - `part`'s prefix is not the empty string and is not `options`'s prefix code point.

    7.  If all of the following are true:

        - `needs grouping` is false; and
        - `custom name` is true; and
        - `part`'s type is "`segment-wildcard`"; and
        - `part`'s modifier is "`none`"; and
        - `next part` is not null; and
        - `next part`'s prefix is the empty string; and
        - `next part`'s suffix is the empty string

        then:

        1.  If `next part`'s type is "`fixed-text`":

            1.  Set `needs grouping` to true if the result of running is a valid name code point given `next part`'s value's first code point and the boolean false is true.

        2.  Otherwise:

            1.  Set `needs grouping` to true if `next part`'s name[0] is an ASCII digit.

    8.  If all of the following are true:

        - `needs grouping` is false; and
        - `part`'s prefix is the empty string; and
        - `previous part` is not null; and
        - `previous part`'s type is "`fixed-text`"; and
        - `previous part`'s value's last code point is `options`'s prefix code point.

        then set `needs grouping` to true.

    9.  Assert: `part`'s name is not the empty string or null.

    10. If `needs grouping` is true, then append "`{`" to the end of `result`.

    11. Append the result of running escape a pattern string given `part`'s prefix to the end of `result`.

    12. If `custom name` is true:

        1.  Append "`:`" to the end of `result`.

        2.  Append `part`'s name to the end of `result`.

    13. If `part`'s type is "`regexp`" then:

        1.  Append "`(`" to the end of `result`.

        2.  Append `part`'s value to the end of `result`.

        3.  Append "`)`" to the end of `result`.

    14. Otherwise if `part`'s type is "`segment-wildcard`" and `custom name` is false:

        1.  Append "`(`" to the end of `result`.

        2.  Append the result of running generate a segment wildcard regexp given `options` to the end of `result`.

        3.  Append "`)`" to the end of `result`.

    15. Otherwise if `part`'s type is "`full-wildcard`":

        1.  If `custom name` is false and one of the following is true:

            - `previous part` is null; or
            - `previous part`'s type is "`fixed-text`"; or
            - `previous part`'s modifier is not "`none`"; or
            - `needs grouping` is true; or
            - `part`'s prefix is not the empty string

            then append "`*`" to the end of `result`.

        2.  Otherwise:

            1.  Append "`(`" to the end of `result`.

            2.  Append full wildcard regexp value to the end of `result`.

            3.  Append "`)`" to the end of `result`.

    16. If all of the following are true:

        - `part`'s type is "`segment-wildcard`"; and
        - `custom name` is true; and
        - `part`'s suffix is not the empty string; and
        - The result of running is a valid name code point given `part`'s suffix's first code point and the boolean false is true

        then append U+005C (`\`) to the end of `result`.

    17. Append the result of running escape a pattern string given `part`'s suffix to the end of `result`.

    18. If `needs grouping` is true, then append "`}`" to the end of `result`.

    19. Append the result of running convert a modifier to a string given `part`'s modifier to the end of `result`.

4.  Return `result`.

To **escape a pattern string** given a string `input`:

1.  Assert: `input` is an ASCII string.

2.  Let `result` be the empty string.

3.  Let `index` be 0.

4.  While `index` is less than `input`'s length:

    1.  Let `c` be `input`[`index`].

    2.  Increment `index` by 1.

    3.  If `c` is one of:

        - U+002B (`+`);
        - U+002A (`*`);
        - U+003F (`?`);
        - U+003A (`:`);
        - U+007B (`{`);
        - U+007D (`}`);
        - U+0028 (`(`);
        - U+0029 (`)`); or
        - U+005C (`\`),

        then append U+005C (`\`) to the end of `result`.

    4.  Append `c` to the end of `result`.

5.  Return `result`.

To **convert a modifier to a string** given a modifier `modifier`:

1.  If `modifier` is "`zero-or-more`", then return "`*`".

2.  If `modifier` is "`optional`", then return "`?`".

3.  If `modifier` is "`one-or-more`", then return "`+`".

4.  Return the empty string.


## Canonicalization


### Encoding callbacks

To **canonicalize a protocol** given a string `value`:

1.  If `value` is the empty string, return `value`.

2.  Let `parseResult` be the result of running the [basic URL parser](https://url.spec.whatwg.org/#concept-basic-url-parser) given `value` followed by "`://dummy.invalid/`".

    Note, [state override](https://url.spec.whatwg.org/#basic-url-parser-state-override) is not used here because it enforces restrictions that are only appropriate for the [`protocol`](https://url.spec.whatwg.org/#dom-url-protocol) setter. Instead we use the protocol to parse a dummy URL using the normal parsing entry point.

3.  If `parseResult` is failure, then throw a [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4.  Return `parseResult`'s [scheme](https://url.spec.whatwg.org/#concept-url-scheme).

To **canonicalize a username** given a string `value`:

1.  If `value` is the empty string, return `value`.

2.  Let `dummyURL` be the result of [creating a dummy URL](#url-pattern-create-a-dummy-url).

3.  [Set the username](https://url.spec.whatwg.org/#set-the-username) given `dummyURL` and `value`.

4.  Return `dummyURL`'s [username](https://url.spec.whatwg.org/#concept-url-username).

To **canonicalize a password** given a string `value`:

1.  If `value` is the empty string, return `value`.

2.  Let `dummyURL` be the result of [creating a dummy URL](#url-pattern-create-a-dummy-url).

3.  [Set the password](https://url.spec.whatwg.org/#set-the-password) given `dummyURL` and `value`.

4.  Return `dummyURL`'s [password](https://url.spec.whatwg.org/#concept-url-password).

To **canonicalize a hostname** given a string `value`:

1.  If `value` is the empty string, return `value`.

2.  Let `dummyURL` be the result of [creating a dummy URL](#url-pattern-create-a-dummy-url).

3.  Let `parseResult` be the result of running the [basic URL parser](https://url.spec.whatwg.org/#concept-basic-url-parser) given `value` with `dummyURL` as *[url](https://url.spec.whatwg.org/#basic-url-parser-url)* and [hostname state](https://url.spec.whatwg.org/#hostname-state) as *[state override](https://url.spec.whatwg.org/#basic-url-parser-state-override)*.

4.  If `parseResult` is failure, then throw a [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

5.  Return `dummyURL`'s [host](https://url.spec.whatwg.org/#concept-url-host), [serialized](https://url.spec.whatwg.org/#concept-host-serializer), or empty string if it is null.

To **canonicalize an IPv6 hostname** given a string `value`:

1.  Let `result` be the empty string.

2.  [For each](https://infra.spec.whatwg.org/#list-iterate) `code point` in `value` interpreted as a [list](https://infra.spec.whatwg.org/#list) of [code points](https://infra.spec.whatwg.org/#code-point):

    1.  If all of the following are true:

        - `code point` is not an [ASCII hex digit](https://infra.spec.whatwg.org/#ascii-hex-digit);
        - `code point` is not U+005B (`[`);
        - `code point` is not U+005D (`]`); and
        - `code point` is not U+003A (`:`),

        then throw a [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

    2.  Append the result of running [ASCII lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) given `code point` to the end of `result`.

3.  Return `result`.

To **canonicalize a port** given a string `portValue` and optionally a string `protocolValue`:

1.  If `portValue` is the empty string, return `portValue`.

2.  Let `dummyURL` be the result of [creating a dummy URL](#url-pattern-create-a-dummy-url).

3.  If `protocolValue` was given, then set `dummyURL`'s [scheme](https://url.spec.whatwg.org/#concept-url-scheme) to `protocolValue`.

    Note, we set the [URL record](https://url.spec.whatwg.org/#concept-url)'s [scheme](https://url.spec.whatwg.org/#concept-url-scheme) in order for the [basic URL parser](https://url.spec.whatwg.org/#concept-basic-url-parser) to recognize and normalize default port values.

4.  Let `parseResult` be the result of running [basic URL parser](https://url.spec.whatwg.org/#concept-basic-url-parser) given `portValue` with `dummyURL` as *[url](https://url.spec.whatwg.org/#basic-url-parser-url)* and [port state](https://url.spec.whatwg.org/#port-state) as *[state override](https://url.spec.whatwg.org/#basic-url-parser-state-override)*.

5.  If `parseResult` is failure, then throw a [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

6.  Return `dummyURL`'s [port](https://url.spec.whatwg.org/#concept-url-port), [serialized](https://url.spec.whatwg.org/#serialize-an-integer), or empty string if it is null.

To **canonicalize a pathname** given a string `value`:

1.  If `value` is the empty string, then return `value`.

2.  Let `leading slash` be true if the first [code point](https://infra.spec.whatwg.org/#code-point) in `value` is U+002F (`/`) and otherwise false.

3.  Let `modified value` be "`/-`" if `leading slash` is false and otherwise the empty string.

    Note: The URL parser will automatically prepend a leading slash to the canonicalized pathname. This does not work here unfortunately. This algorithm is called for pieces of the pathname, instead of the entire pathname, when used as an encoding callback. Therefore we disable the prepending of the slash by inserting our own. An additional character is also inserted here in order to avoid inadvertantly collapsing a leading dot due to the fake leading slash being interpreted as a "`/.`" sequence. These inserted characters are then removed from the result below.

    Note, implementations are free to simply disable slash prepending in their URL parsing code instead of paying the performance penalty of inserting and removing characters in this algorithm.

4.  Append `value` to the end of `modified value`.

5.  Let `dummyURL` be the result of [creating a dummy URL](#url-pattern-create-a-dummy-url).

6.  [Empty](https://infra.spec.whatwg.org/#list-empty) `dummyURL`'s [path](https://url.spec.whatwg.org/#concept-url-path).

7.  Run [basic URL parser](https://url.spec.whatwg.org/#concept-basic-url-parser) given `modified value` with `dummyURL` as *[url](https://url.spec.whatwg.org/#basic-url-parser-url)* and [path start state](https://url.spec.whatwg.org/#path-start-state) as *[state override](https://url.spec.whatwg.org/#basic-url-parser-state-override)*.

8.  Let `result` be the result of [URL path serializing](https://url.spec.whatwg.org/#url-path-serializer) `dummyURL`.

9.  If `leading slash` is false, then set `result` to the [code point substring](https://infra.spec.whatwg.org/#code-point-substring-to-the-end-of-the-string) from 2 to the end of the string within `result`.

10. Return `result`.

To **canonicalize an opaque pathname** given a string `value`:

1.  If `value` is the empty string, return `value`.

2.  Let `dummyURL` be the result of [creating a dummy URL](#url-pattern-create-a-dummy-url).

3.  Set `dummyURL`'s [path](https://url.spec.whatwg.org/#concept-url-path) to the empty string.

4.  Let `parseResult` be the result of running [URL parsing](https://url.spec.whatwg.org/#concept-basic-url-parser) given `value` with `dummyURL` as *[url](https://url.spec.whatwg.org/#basic-url-parser-url)* and [opaque path state](https://url.spec.whatwg.org/#cannot-be-a-base-url-path-state) as *[state override](https://url.spec.whatwg.org/#basic-url-parser-state-override)*.

5.  If `parseResult` is failure, then throw a [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

6.  Return the result of [URL path serializing](https://url.spec.whatwg.org/#url-path-serializer) `dummyURL`.

To **canonicalize a search** given a string `value`:

1.  If `value` is the empty string, return `value`.

2.  Let `dummyURL` be the result of [creating a dummy URL](#url-pattern-create-a-dummy-url).

3.  Set `dummyURL`'s [query](https://url.spec.whatwg.org/#concept-url-query) to the empty string.

4.  Run [basic URL parser](https://url.spec.whatwg.org/#concept-basic-url-parser) given `value` with `dummyURL` as *[url](https://url.spec.whatwg.org/#basic-url-parser-url)* and [query state](https://url.spec.whatwg.org/#query-state) as *[state override](https://url.spec.whatwg.org/#basic-url-parser-state-override)*.

5.  Return `dummyURL`'s [query](https://url.spec.whatwg.org/#concept-url-query).

To **canonicalize a hash** given a string `value`:

1.  If `value` is the empty string, return `value`.

2.  Let `dummyURL` be the result of [creating a dummy URL](#url-pattern-create-a-dummy-url).

3.  Set `dummyURL`'s [fragment](https://url.spec.whatwg.org/#concept-url-fragment) to the empty string.

4.  Run [basic URL parser](https://url.spec.whatwg.org/#concept-basic-url-parser) given `value` with `dummyURL` as *[url](https://url.spec.whatwg.org/#basic-url-parser-url)* and [fragment state](https://url.spec.whatwg.org/#fragment-state) as *[state override](https://url.spec.whatwg.org/#basic-url-parser-state-override)*.

5.  Return `dummyURL`'s [fragment](https://url.spec.whatwg.org/#concept-url-fragment).



### `URLPatternInit` processing

To **process a URLPatternInit** given a [`URLPatternInit`](#dictdef-urlpatterninit) `init`, a string `type`, a string or null `protocol`, a string or null `username`, a string or null `password`, a string or null `hostname`, a string or null `port`, a string or null `pathname`, a string or null `search`, and a string or null `hash`:

1.  Let `result` be the result of creating a new [`URLPatternInit`](#dictdef-urlpatterninit).

2.  If `protocol` is not null, [set](https://infra.spec.whatwg.org/#map-set) `result`\["`protocol`"\] to `protocol`.

3.  If `username` is not null, [set](https://infra.spec.whatwg.org/#map-set) `result`\["`username`"\] to `username`.

4.  If `password` is not null, [set](https://infra.spec.whatwg.org/#map-set) `result`\["`password`"\] to `password`.

5.  If `hostname` is not null, [set](https://infra.spec.whatwg.org/#map-set) `result`\["`hostname`"\] to `hostname`.

6.  If `port` is not null, [set](https://infra.spec.whatwg.org/#map-set) `result`\["`port`"\] to `port`.

7.  If `pathname` is not null, [set](https://infra.spec.whatwg.org/#map-set) `result`\["`pathname`"\] to `pathname`.

8.  If `search` is not null, [set](https://infra.spec.whatwg.org/#map-set) `result`\["`search`"\] to `search`.

9.  If `hash` is not null, [set](https://infra.spec.whatwg.org/#map-set) `result`\["`hash`"\] to `hash`.

10. Let `baseURL` be null.

11. If `init`\["`baseURL`"\] [exists](https://infra.spec.whatwg.org/#map-exists):

    Note: The base URL can be used to supply additional context, but for each component, if `init` includes a component which is at least as specific as one in the base URL, none is inherited.
    A component is more specific if it appears later in one of the following two lists (which are very similar to the order they appear in the URL syntax):

    - protocol, hostname, port, pathname, search, hash

    - protocol, hostname, port, username, password

    Username and password are also never inherited from a base URL when constructing a [`URLPattern`](#urlpattern). (They are, however, inherited from the base URL when parsing a URL supplied as an argument to [`test()`](#dom-urlpattern-test) or [`exec()`](#dom-urlpattern-exec).)

    1.  Set `baseURL` to the result of running the [basic URL parser](https://url.spec.whatwg.org/#concept-basic-url-parser) on `init`\["`baseURL`"\].

    2.  If `baseURL` is failure, then throw a [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

    3.  If `init`\["`protocol`"\] does not [exist](https://infra.spec.whatwg.org/#map-exists), then set `result`\["`protocol`"\] to the result of [processing a base URL string](#process-a-base-url-string) given `baseURL`'s [scheme](https://url.spec.whatwg.org/#concept-url-scheme) and `type`.

    4.  If `type` is not "`pattern`" and `init` [contains](https://infra.spec.whatwg.org/#map-exists) none of "`protocol`", "`hostname`", "`port`" and "`username`", then set `result`\["`username`"\] to the result of [processing a base URL string](#process-a-base-url-string) given `baseURL`'s [username](https://url.spec.whatwg.org/#concept-url-username) and `type`.

    5.  If `type` is not "`pattern`" and `init` [contains](https://infra.spec.whatwg.org/#map-exists) none of "`protocol`", "`hostname`", "`port`", "`username`" and "`password`", then set `result`\["`password`"\] to the result of [processing a base URL string](#process-a-base-url-string) given `baseURL`'s [password](https://url.spec.whatwg.org/#concept-url-password) and `type`.

    6.  If `init` [contains](https://infra.spec.whatwg.org/#map-exists) neither "`protocol`" nor "`hostname`", then:

        1.  Let `baseHost` be the empty string.

        2.  If `baseURL`'s [host](https://url.spec.whatwg.org/#concept-url-host) is not null, then set `baseHost` to its [serialization](https://url.spec.whatwg.org/#concept-host-serializer).

        3.  Set `result`\["`hostname`"\] to the result of [processing a base URL string](#process-a-base-url-string) given `baseHost` and `type`.

    7.  If `init` [contains](https://infra.spec.whatwg.org/#map-exists) none of "`protocol`", "`hostname`", and "`port`", then:

        1.  If `baseURL`'s [port](https://url.spec.whatwg.org/#concept-url-port) is null, then set `result`\["`port`"\] to the empty string.

        2.  Otherwise, set `result`\["`port`"\] to `baseURL`'s [port](https://url.spec.whatwg.org/#concept-url-port), [serialized](https://url.spec.whatwg.org/#serialize-an-integer).

    8.  If `init` [contains](https://infra.spec.whatwg.org/#map-exists) none of "`protocol`", "`hostname`", "`port`", and "`pathname`", then set `result`\["`pathname`"\] to the result of [processing a base URL string](#process-a-base-url-string) given the result of [URL path serializing](https://url.spec.whatwg.org/#url-path-serializer) `baseURL` and `type`.

    9.  If `init` [contains](https://infra.spec.whatwg.org/#map-exists) none of "`protocol`", "`hostname`", "`port`", "`pathname`", and "`search`", then:

        1.  Let `baseQuery` be `baseURL`'s [query](https://url.spec.whatwg.org/#concept-url-query).

        2.  If `baseQuery` is null, then set `baseQuery` to the empty string.

        3.  Set `result`\["`search`"\] to the result of [processing a base URL string](#process-a-base-url-string) given `baseQuery` and `type`.

    10. If `init` [contains](https://infra.spec.whatwg.org/#map-exists) none of "`protocol`", "`hostname`", "`port`", "`pathname`", "`search`", and "`hash`", then:

        1.  Let `baseFragment` be `baseURL`'s [fragment](https://url.spec.whatwg.org/#concept-url-fragment).

        2.  If `baseFragment` is null, then set `baseFragment` to the empty string.

        3.  Set `result`\["`hash`"\] to the result of [processing a base URL string](#process-a-base-url-string) given `baseFragment` and `type`.

12. If `init`\["`protocol`"\] [exists](https://infra.spec.whatwg.org/#map-exists), then set `result`\["`protocol`"\] to the result of [process protocol for init](#process-protocol-for-init) given `init`\["`protocol`"\] and `type`.

13. If `init`\["`username`"\] [exists](https://infra.spec.whatwg.org/#map-exists), then set `result`\["`username`"\] to the result of [process username for init](#process-username-for-init) given `init`\["`username`"\] and `type`.

14. If `init`\["`password`"\] [exists](https://infra.spec.whatwg.org/#map-exists), then set `result`\["`password`"\] to the result of [process password for init](#process-password-for-init) given `init`\["`password`"\] and `type`.

15. If `init`\["`hostname`"\] [exists](https://infra.spec.whatwg.org/#map-exists), then set `result`\["`hostname`"\] to the result of [process hostname for init](#process-hostname-for-init) given `init`\["`hostname`"\] and `type`.

16. Let `resultProtocolString` be `result`\["`protocol`"\] if it [exists](https://infra.spec.whatwg.org/#map-exists); otherwise the empty string.

17. If `init`\["`port`"\] [exists](https://infra.spec.whatwg.org/#map-exists), then set `result`\["`port`"\] to the result of [process port for init](#process-port-for-init) given `init`\["`port`"\], `resultProtocolString`, and `type`.

18. If `init`\["`pathname`"\] [exists](https://infra.spec.whatwg.org/#map-exists):

    1.  Set `result`\["`pathname`"\] to `init`\["`pathname`"\].

    2.  If the following are all true:

        - `baseURL` is not null;
        - `baseURL` does not have an [opaque path](https://url.spec.whatwg.org/#url-opaque-path); and
        - the result of running [is an absolute pathname](#is-an-absolute-pathname) given `result`\["`pathname`"\] and `type` is false,

        then:

        1.  Let `baseURLPath` be the result of running [process a base URL string](#process-a-base-url-string) given the result of [URL path serializing](https://url.spec.whatwg.org/#url-path-serializer) `baseURL` and `type`.

        2.  Let `slash index` be the index of the last U+002F (`/`) code point found in `baseURLPath`, interpreted as a sequence of [code points](https://infra.spec.whatwg.org/#code-point), or null if there are no instances of the code point.

        3.  If `slash index` is not null:

            1.  Let `new pathname` be the [code point substring](https://infra.spec.whatwg.org/#code-point-substring-by-positions) from 0 to `slash index` + 1 within `baseURLPath`.

            2.  Append `result`\["`pathname`"\] to the end of `new pathname`.

            3.  Set `result`\["`pathname`"\] to `new pathname`.

    3.  Set `result`\["`pathname`"\] to the result of [process pathname for init](#process-pathname-for-init) given `result`\["`pathname`"\], `resultProtocolString`, and `type`.

19. If `init`\["`search`"\] [exists](https://infra.spec.whatwg.org/#map-exists) then set `result`\["`search`"\] to the result of [process search for init](#process-search-for-init) given `init`\["`search`"\] and `type`.

20. If `init`\["`hash`"\] [exists](https://infra.spec.whatwg.org/#map-exists) then set `result`\["`hash`"\] to the result of [process hash for init](#process-hash-for-init) given `init`\["`hash`"\] and `type`.

21. Return `result`.


To **process a base URL string** given a string `input` and a string `type`:

1.  [Assert](https://infra.spec.whatwg.org/#assert): `input` is not null.

2.  If `type` is not "`pattern`" return `input`.

3.  Return the result of [escaping a pattern string](#escape-a-pattern-string) given `input`.


To run **is an absolute pathname** given a [pattern string](#pattern-string) `input` and a string `type`:

1.  If `input` is the empty string, then return false.

2.  If `input`\[0\] is U+002F (`/`), then return true.

3.  If `type` is "`url`", then return false.

4.  If `input`'s [code point length](https://infra.spec.whatwg.org/#string-code-point-length) is less than 2, then return false.

5.  If `input`\[0\] is U+005C (`\`) and `input`\[1\] is U+002F (`/`), then return true.

6.  If `input`\[0\] is U+007B (`{`) and `input`\[1\] is U+002F (`/`), then return true.

7.  Return false.


To **process protocol for init** given a string `value` and a string `type`:

1.  Let `strippedValue` be the given `value` with a single trailing U+003A (`:`) removed, if any.

2.  If `type` is "`pattern`" then return `strippedValue`.

3.  Return the result of running [canonicalize a protocol](#canonicalize-a-protocol) given `strippedValue`.


To **process username for init** given a string `value` and a string `type`:

1.  If `type` is "`pattern`" then return `value`.

2.  Return the result of running [canonicalize a username](#canonicalize-a-username) given `value`.


To **process password for init** given a string `value` and a string `type`:

1.  If `type` is "`pattern`" then return `value`.

2.  Return the result of running [canonicalize a password](#canonicalize-a-password) given `value`.


To **process hostname for init** given a string `value` and a string `type`:

1.  If `type` is "`pattern`" then return `value`.

2.  Return the result of running [canonicalize a hostname](#canonicalize-a-hostname) given `value`.


To **process port for init** given a string `portValue`, a string `protocolValue`, and a string `type`:

1.  If `type` is "`pattern`" then return `portValue`.

2.  Return the result of running [canonicalize a port](#canonicalize-a-port) given `portValue` and `protocolValue`.


To **process pathname for init** given a string `pathnameValue`, a string `protocolValue`, and a string `type`:

1.  If `type` is "`pattern`" then return `pathnameValue`.

2.  If `protocolValue` is a [special scheme](https://url.spec.whatwg.org/#special-scheme) or the empty string, then return the result of running [canonicalize a pathname](#canonicalize-a-pathname) given `pathnameValue`.

    If the `protocolValue` is the empty string then no value was provided for `protocol` in the constructor dictionary. Normally we do not special case empty string dictionary values, but in this case we treat it as a [special scheme](https://url.spec.whatwg.org/#special-scheme) in order to default to the most common pathname canonicalization.

3.  Return the result of running [canonicalize an opaque pathname](#canonicalize-an-opaque-pathname) given `pathnameValue`.


To **process search for init** given a string `value` and a string `type`:

1.  Let `strippedValue` be the given `value` with a single leading U+003F (`?`) removed, if any.

2.  If `type` is "`pattern`" then return `strippedValue`.

3.  Return the result of running [canonicalize a search](#canonicalize-a-search) given `strippedValue`.


To **process hash for init** given a string `value` and a string `type`:

1.  Let `strippedValue` be the given `value` with a single leading U+0023 (`#`) removed, if any.

2.  If `type` is "`pattern`" then return `strippedValue`.

3.  Return the result of running [canonicalize a hash](#canonicalize-a-hash) given `strippedValue`.


## Using URL patterns in other specifications

To promote consistency on the web platform, other documents integrating with this specification should adhere to the following guidelines, unless there is good reason to diverge.

1.  **Accept shorthands**. Most author patterns will be simple and straightforward. Accordingly, APIs should accept shorthands for those common cases and avoid the need for authors to take additional steps to transform these into complete `URLPattern` objects.

2.  **Respect the base URL**. Just as URLs are generally parsed relative to a base URL for their environment (most commonly, a [document base URL](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url)), URL patterns should respect this as well. The `URLPattern` constructor itself is an exception because it directly exposes the concept itself, similar to how the URL constructor does not respect the base URL even though the rest of the platform does.

3.  **Be clear about regexp groups**. Some APIs may benefit from only allowing URL patterns which do not have regexp groups, for example, because user agents are likely to implement them in a different thread or process from those executing author script, and because of security or performance concerns, a JavaScript engine would not ordinarily run there. If so, this should be clearly documented (with reference to has regexp groups) and the operation should report an error as soon as possible (e.g., by throwing a JavaScript exception). If possible, this should be feature-detectable to allow for the possibility of this constraint being lifted in the future. Avoid creating different subsets of URL patterns without consulting the editors of this specification.

4.  **Be clear about what URLs will be matched**. For instance, algorithms during fetching are likely to operate on URLs with no fragment. If so, the specification should be clear that this is the case, and may advise showing a developer warning if a pattern which cannot match (e.g., because it requires a non-empty fragment) is used.



### Integrating with JavaScript APIs

```idl
typedef (USVString or URLPatternInit or URLPattern) URLPatternCompatible;
```

JavaScript APIs should accept all of:

- a `URLPattern` object

- a dictionary-like object which specifies the components required to construct a pattern

- a string (in the constructor string syntax)

To accomplish this, specifications should accept `URLPatternCompatible` as an argument to an operation or dictionary member, and process it using the following algorithm, using the appropriate environment settings object's API base URL or equivalent.

To **build a `URLPattern` object from a Web IDL value** `URLPatternCompatible` `input` given URL `baseURL` and realm `realm`, perform the following steps:

1.  If the specific type of `input` is `URLPattern`:

    1.  Return `input`.

2.  Otherwise:

    1.  Let `pattern` be a new `URLPattern` with `realm`.

    2.  Set `pattern`'s associated URL pattern to the result of building a URL pattern from a Web IDL value given `input` and `baseURL`.

    3.  Return `pattern`.


To **build a URL pattern from a Web IDL value** `URLPatternCompatible` `input` given URL `baseURL`, perform the following steps:

1.  If the specific type of `input` is `URLPattern`:

    1.  Return `input`'s associated URL pattern.

2.  Otherwise, if the specific type of `input` is `URLPatternInit`:

    1.  Let `init` be a clone of `input`.

    2.  If `init`["`baseURL`"] does not exist, set it to the serialization of `baseURL`.

    3.  Return the result of creating a URL pattern given `init`, null, and an empty map.

3.  Otherwise:

    1.  Assert: The specific type of `input` is `USVString`.

    2.  Return the result of creating a URL pattern given `input`, the serialization of `baseURL`, and an empty map.


This allows authors to concisely specify most patterns, and use the constructor to access uncommon options if necessary. The implicit use of the base URL is similar to, and consistent with, HTML's parse a URL algorithm. [HTML]



### Integrating with JSON data formats

JSON data formats which include URL patterns should mirror the behavior of JavaScript APIs and accept both:

- an object which specifies the components required to construct a pattern

- a string (in the constructor string syntax)

If a specification has an Infra value (e.g., after using parse a JSON string to an Infra value), use the following algorithm, using the appropriate base URL (by default, the URL of the JSON resource). [INFRA]

To **build a URL pattern from an Infra value** `rawPattern` given URL `baseURL`, perform the following steps.

1.  Let `serializedBaseURL` be the serialization of `baseURL`.

2.  If `rawPattern` is a string, then:

    1.  Return the result of creating a URL pattern given `rawPattern`, `serializedBaseURL`, and an empty map.

        Note: It might become necessary in the future to plumb non-empty options here.

3.  Otherwise, if `rawPattern` is a map, then:

    1.  Let `init` be «[ "`baseURL`" → `serializedBaseURL` ]», representing a dictionary of type `URLPatternInit`.

    2.  For each `key` → `value` of `rawPattern`:

        1.  If `key` is not the identifier of a dictionary member of `URLPatternInit` or one of its inherited dictionaries, `value` is not a string, or the member's type is not declared to be `USVString`, then return null.

            Note: This will need to be updated if `URLPatternInit` gains members of other types.

            Note: A future version of this specification might also have a less strict mode, if that proves useful to other specifications.

        2.  Set `init`[`key`] to `value`.

    3.  Return the result of creating a URL pattern given `init`, null, and an empty map.

        Note: It might become necessary in the future to plumb non-empty options here.

4.  Otherwise, return null.


Specifications may wish to leave room in their formats to accept options for `URLPatternOptions`, override the base URL, or similar, since it is not possible to construct a `URLPattern` object directly in this case, unlike in a JavaScript API. For example, [HTML § 7.6.1 Speculation rules](https://html.spec.whatwg.org/multipage/speculative-loading.html#speculation-rules) accepts a "`relative_to`" key which can be used to switch to using the document base URL instead of the JSON resource's URL. [HTML]



### Integrating with HTTP header fields

HTTP headers which include URL patterns should accept a string in the constructor string syntax, likely as part of a structured field [RFC9651].

Note: No known header accepts the dictionary syntax for URL patterns. If that changes, this specification will be updated to define it, likely by processing [RFC9651] inner lists.

Specifications for HTTP headers should operate on URL patterns (e.g., using the match algorithm) rather than `URLPattern` objects (which imply the existence of a JavaScript realm).

To **build a URL pattern from an HTTP structured field value** `rawPattern` given URL `baseURL`:

1.  Let `serializedBaseURL` be the serialization of `baseURL`.

2.  Assert: `rawPattern` is a string.

3.  Return the result of creating a URL pattern given `rawPattern`, `serializedBaseURL`, and an empty map.


Note: Specifications might consider accepting only patterns which do not have regexp groups if evaluating the pattern, since the performance of such patterns might be more reliable, and might not require a [ECMA-262] regular expression implementation, which might have security, code size, or other implications for implementations. On the other hand, JavaScript APIs run in environments where such an implementation is readily available.