zig-msgpack
============
Zig bindings to [ludocode/mpack](https://github.com/ludocode/mpack).

The underlying library is excellent (and ~60K), we just add a nice Zig wrapper.

The bindings pretty closely match the underlying C API, with a handful exceptions:

1. We convert to zig-style errors for use with `try`/`catch`
2. We support type-reflection to serialize from msgpack maps -> zig struct (WIP)
   - Field names must match *exactly*

## TODO?
These bindings are incomplete, please open a PR (or an issue) if there is something you need and we don't have.

In particular, we don't include bindings to the Node API.

I'm under the impression that the Node API is mostly used for deserializing maps/arrays into C structures.
It also makes error handling much simpler (for C).

With zig, the nice type-reflection makes deserializing maps easy enough without needing to read into memory.
