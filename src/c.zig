//! C interop
const mpack_options = @import("msgpack_options");

fn cflag(b: bool) []const u8 {
    return if (b) "1" else "0";
}

pub usingnamespace @cImport({
    @cDefine("MPACK_EXTENSIONS", cflag(mpack_options.enable_extensions));
    @cDefine("MPACK_DEBUG", cflag(mpack_options.mpack_debug));
    @cDefine("MPACK_STDLIB", cflag(mpack_options.use_c_stdlib));
    @cDefine("MPACK_STDIO", cflag(mpack_options.use_c_stdio));
    @cDefine("MPACK_READ_TRACKING", cflag(mpack_options.read_tracking));
    @cDefine("MPACK_WRITE_TRACKING", cflag(mpack_options.write_tracking));
    @cInclude("mpack.h");
});
