const std = @import("std");

fn sdk_root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

fn dep_root() []const u8 {
    return sdk_root() ++ "/deps/mpack";
}

pub const MpackOptions = struct {};

pub fn setup_msgpack(step: *std.build.LibExeObjStep, _: MpackOptions) void {
    step.addPackage(.{ .name = "zig-msgpack", .path = std.build.FileSource{ .path = sdk_root() ++ "/src/mpack.zig" } });
    step.addIncludePath(dep_root() ++ "/src/mpack");
    // Compile mpack library
    const mpack_parts = [_][]const u8{ "common", "expect", "node", "platform", "reader", "writer" };
    inline for (mpack_parts) |part| {
        step.addCSourceFile(dep_root() ++ "/src/mpack/mpack-" ++ part ++ ".c", &[_][]const u8{});
    }
}
