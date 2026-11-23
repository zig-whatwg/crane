'use strict';

// Node's url in the browser page: the browser's own URL and URLSearchParams, and Node's file-URL
// conversions (POSIX paths only, as on the hosts this runs on).

const {native} = __reactJestPage;
const {URL, URLSearchParams} = native;

function fileURLToPath(u) {
  const url = typeof u === 'string' ? new URL(u) : u;
  if (url.protocol !== 'file:') {
    throw Object.assign(new TypeError('The URL must be of scheme file'), {code: 'ERR_INVALID_URL_SCHEME'});
  }
  if (url.hostname !== '') {
    throw Object.assign(new TypeError(`File URL host must be "localhost" or empty on ${'darwin'}`), {code: 'ERR_INVALID_FILE_URL_HOST'});
  }
  return decodeURIComponent(url.pathname);
}

function pathToFileURL(p) {
  const url = new URL('file://');
  url.pathname = String(p).replace(/%/g, '%25').replace(/\\/g, '%5C').replace(/\n/g, '%0A').replace(/\r/g, '%0D').replace(/\t/g, '%09');
  return url;
}

// The legacy API, as far as Jest's dependencies read it.
function parse(input) {
  let u;
  try {
    u = new URL(input);
  } catch {
    return {href: input, path: input, pathname: input, protocol: null, host: null, hostname: null, search: null, query: null, hash: null};
  }
  return {
    href: u.href,
    protocol: u.protocol,
    slashes: true,
    auth: u.username ? u.username + (u.password ? ':' + u.password : '') : null,
    host: u.host,
    port: u.port || null,
    hostname: u.hostname,
    hash: u.hash || null,
    search: u.search || null,
    query: u.search ? u.search.slice(1) : null,
    pathname: u.pathname,
    path: u.pathname + u.search,
  };
}

module.exports = {
  URL,
  URLSearchParams,
  fileURLToPath,
  pathToFileURL,
  parse,
  format: u => (typeof u === 'string' ? u : u.href || String(u)),
  resolve: (from, to) => new URL(to, new URL(from, 'resolve://')).href.replace(/^resolve:\/\//, ''),
  domainToASCII: d => new URL('http://' + d).hostname,
  domainToUnicode: d => d,
};
