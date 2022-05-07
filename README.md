zig-msgpack
============
Zig bindings to [ludocode/mpack](https://github.com/ludocode/mpack).

The underlying library is excellent (and ~60K), we just add a nice Zig wrapper.

The bindings pretty closely match the underlying C API, with a handful exceptions:

1. We convert to zig-style errors for use with `try`/`catch`

## TODO?
These bindings are incomplete, please open a PR (or an issue) if there is something you need and we don't have.

In particular, we don't include bindings to the Node API (yet). See issue #4

Type reflection doesn't work with structs. This is fairly difficult to do when input is a map
and the fields can be in any order :(
