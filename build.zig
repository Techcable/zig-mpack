const std = @import("std");

const sdk = @import("./sdk.zig");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const main_tests = b.addTest("src/mpack.zig");
    sdk.setup_msgpack(main_tests, .{});
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

