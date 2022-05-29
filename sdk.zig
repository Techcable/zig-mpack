const std = @import("std");
const assert = std.debug.assert;

fn sdk_root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

fn dep_root() []const u8 {
    return sdk_root() ++ "/deps/mpack";
}

/// A module of ludocode mpack (the underlying library).
///
/// You can declare a dependency on only part of the library,
/// without bringing in the whole thing.
///
/// However, some modules have dependencies on others.
/// Enabling a module requires you to enable its dependency..
pub const Module = enum {
    reader,
    expect,
    node,
    writer,

    /// The dependencies of this module
    pub fn dependencies(self: Module) []const Module {
        return switch (self) {
            .reader, .writer => &[0]Module{},
            .expect => &[1]Module{.reader},
            .node => &[1]Module{.reader},
        };
    }

    /// All supported modules
    pub const ALL: []const Module = std.enums.values(Module);
};

pub const Options = struct {
    /// The parts of the library to include
    included_modules: []const Module = Module.ALL,
    /// Link to the C standard library
    ///
    /// For now, this is effectively required.
    link_c_stdlib: bool = true,
    /// Activate msgpack debugging.
    ///
    /// If this option is "null", it will take on a
    /// default value of true in debug (or ReleaseSafe) modes,
    /// and false in unchecked mdoes
    mpack_debug: ?bool = null,
    /// Activate read tracking.
    ///
    /// This ensures that the correct number of elements
    /// or bytes are read from a compound type.
    ///
    /// The default value depends on mpack_debug
    read_tracking: ?bool = null,
    /// Activate write tracking
    ///
    /// This ensures that the correct number of elements
    /// or bytes are written in a compound type.
    ///
    /// The default value depends on mpack_debug
    write_tracking: ?bool = null,
    /// Enable the use of extension types
    ///
    /// For now this is not really supported.
    extensions: bool = false,
    /// Tell the mpack library to optimize for size.
    optimize_for_size: ?bool = false,
};

/// An internal msgpack flags.
////
/// These all correspons to definitions in
/// mpack-platform.h, just stripped of their MPACK_ prefix
/// and converted to lowercase
///
/// See mpack-platform.h for descrptions.
///
/// This is the subset we use (everything else is default)
const Flag = enum {
    // options for modules
    reader,
    expect,
    node,
    writer,
    // generic options
    extensions,
    stdlib,
    // This enables support for C stdio wrappers.
    //
    // We want to unconditionally disable
    // this in favor of zig wrappers
    stdio,
    // SKIP: float, double
    // debugging options
    debug,
    strings,
    custom_assert,
    custom_break,
    read_tracking,
    write_tracking,
    // misc options
    optimize_for_size,

    const DEFINE_PREFIX = "MPACK_";
    const MAX_DEFINE_LEN = determineMaxLen: {
        var len: usize = 0;
        for (std.enums.values(Flag)) |flag| {
            len = std.math.max(len, @tagName(flag).len + DEFINE_PREFIX.len);
        }
        break :determineMaxLen len;
    };
    fn raw_definition_name(self: Flag) std.BoundedArray(u8, MAX_DEFINE_LEN) {
        var res: std.BoundedArray(u8, MAX_DEFINE_LEN) = .{};
        res.appendSliceAssumeCapacity(DEFINE_PREFIX);
        const name = @tagName(self);
        _ = std.ascii.upperString(res.unusedCapacitySlice(), name);
        res.len += name.len;
        assert(res.len <= MAX_DEFINE_LEN);
        return res;
    }
};

pub fn setup_msgpack(step: *std.build.LibExeObjStep, opts: Options) void {
    step.addIncludePath(dep_root() ++ "/src/mpack");
    // handle options
    var specified_modules = std.enums.EnumSet(Module).init(.{});
    for (opts.included_modules) |mod| {
        // check for duplicates
        assert(!specified_modules.contains(mod));
        specified_modules.insert(mod);
    }
    // determine the paths to the c module sources
    const module_source_paths: std.BoundedArray([]const u8, 6) = initModSources: {
        var module_names: std.BoundedArray([]const u8, 6) = .{};
        // always include "platform" and "common" are present
        module_names.appendSliceAssumeCapacity(&[2][]const u8{ "platform", "common" });
        // use whatever they specify as options in an enum map
        var iter = specified_modules.iterator();
        while (iter.next()) |specified_mod| {
            // check for dependencies
            for (specified_mod.dependencies()) |dep| {
                if (!specified_modules.contains(dep)) {
                    std.debug.panic("Requiring module {} also requires dependency {}", .{ specified_mod, dep });
                }
            }
            module_names.appendAssumeCapacity(@tagName(specified_mod));
        }
        // now convert names to actual paths (requires allocation)
        var module_source_paths: std.BoundedArray([]const u8, 6) = .{};
        for (module_names.slice()) |name| {
            module_source_paths.appendAssumeCapacity(step.builder.fmt(
                "{s}/src/mpack/mpack-{s}.c",
                .{ dep_root(), name },
            ));
        }
        break :initModSources module_source_paths;
    };
    const mpack_debug = opts.mpack_debug orelse switch (step.build_mode) {
        .ReleaseFast, .ReleaseSmall => false,
        .Debug, .ReleaseSafe => true,
    };
    const read_tracking = opts.read_tracking orelse mpack_debug;
    const write_tracking = opts.write_tracking orelse mpack_debug;
    if (!mpack_debug) {
        assert(!read_tracking);
        assert(!write_tracking);
    }
    var flags = std.enums.EnumMap(Flag, bool).init(.{
        .stdlib = opts.link_c_stdlib,
        // In theory, we never want to use C stdio (we always want to use Zig)
        //
        // However, the library's internal formatting for error messages requires sprintf
        // Since we want formatted error messages, we enable "C stdio" in debug mode
        .stdio = mpack_debug,
        .extensions = opts.extensions,
        .optimize_for_size = opts.optimize_for_size orelse (step.build_mode == .ReleaseSmall),
        //
        // override debug options
        //
        .debug = mpack_debug,
        .read_tracking = read_tracking,
        .write_tracking = write_tracking,
        // We disable including C strings (descriptions of errors & types)
        // because our Zig bindings include their own (also @tagName() and @errorName())
        .strings = false,
        // always use our own assert (zig panic)
        .custom_assert = mpack_debug,
        .custom_break = mpack_debug,
    });
    for (std.enums.values(Module)) |mod| {
        const flag = std.meta.stringToEnum(Flag, @tagName(mod)).?;
        flags.put(flag, specified_modules.contains(mod));
    }
    var msgpack_cc_options = std.ArrayList([]const u8).init(step.builder.allocator);
    // add all flags
    {
        var iter = flags.iterator();
        while (iter.next()) |entry| {
            const flag_name = entry.key.raw_definition_name();
            const flag_value = if (entry.value.*) "1" else "0";
            msgpack_cc_options.append(step.builder.fmt(
                "-D{s}={s}",
                .{ flag_name.slice(), flag_value },
            )) catch unreachable;
        }
    }
    // some of these options also need to be given to the Zig library (for c.h)
    //
    // It appears zig already "hashes contents to file names", so we don't need
    // to worry about generating duplicates here (wow)
    var optionsPkg = initOptions: {
        var options = step.builder.addOptions();
        options.addOption(bool, "mpack_debug", mpack_debug);
        options.addOption(bool, "use_c_stdlib", opts.link_c_stdlib);
        options.addOption(bool, "use_c_stdio", flags.get(Flag.stdio).?);
        options.addOption(bool, "enable_extensions", opts.extensions);
        options.addOption(bool, "read_tracking", read_tracking);
        options.addOption(bool, "write_tracking", write_tracking);
        break :initOptions options.getPackage("msgpack_options");
    };
    step.addPackage(optionsPkg);
    step.addCSourceFiles(
        module_source_paths.slice(),
        msgpack_cc_options.items,
    );
    var deps = step.builder.allocator.alloc(std.build.Pkg, 1) catch unreachable;
    deps[0] = optionsPkg;
    step.addPackage(.{
        .name = "mpack",
        .path = std.build.FileSource{ .path = sdk_root() ++ "/src/mpack.zig" },
        .dependencies = deps,
    });
}
