const std = @import("std");
const c = @import("c.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const AllocError = Allocator.Error;

pub const MpackReader = extern struct {
    reader: c.mpack_reader_t,

    /// Initializes an MPack reader to parse a pre-loaded
    /// contiguous chunk of data. The reader does not assume
    /// ownership of the data.
    pub fn init_data(data: []const u8) MpackReader {
        var self: MpackReader = undefined;
        c.mpack_reader_init_data(&self.reader, data.ptr, data.len);
        return self;
    }

    /// Queries the error state of the MPack reader
    pub inline fn error_info(self: *MpackReader) ErrorInfo {
        return .{ .err = c.mpack_reader_error(&self.reader) };
    }

    /// Flags the specified reader to have the specified error info.
    ///
    /// This is useful in debug mode, where `destroy` would otherwise panic
    /// if there is unfinished data.
    ///
    /// If the reader is already in an error state, this call is ignored.
    ///
    /// Do something like `errdefer { reader.flag_error(mpack.ErrorInfo.INVALID) }`
    /// to avoid panics for unfinished data
    pub fn flag_error(self: *MpackReader, info: ErrorInfo) void {
        @setCold(true);
        c.mpack_reader_flag_error(&self.reader, info.err);
    }

    /// Parses the next MessagePack object header
    /// (an MPack tag) without advancing the reader.
    pub fn peek_tag(self: *MpackReader) Error!MTag {
        const tag = MTag{ .tag = c.mpack_peek_tag(&self.reader) };
        if (tag.is_nil()) {
            try self.error_info().check_okay();
        } else {
            // should have returned nil if error
            assert(self.error_info().is_ok());
        }
        return tag;
    }

    /// Reads a MessagePack object header (an MPack tag.)
    ///
    /// If the type is compound (i.e. is a map, array, string,
    /// binary or extension type), additional reads are required
    /// to get the contained data, and the corresponding done
    /// function must be called when done.
    pub fn read_tag(self: *MpackReader) Error!MTag {
        const tag = MTag{ .tag = c.mpack_read_tag(&self.reader) };
        if (tag.is_nil()) {
            try self.error_info().check_okay();
        } else {
            // should have returned nil if error
            self.error_info().check_okay() catch unreachable;
        }
        return tag;
    }

    /// Reads and discards the next object.
    ///
    /// This will read and discard all
    /// contained data as well if it is a compound type.
    pub fn discard(self: *MpackReader) Error!void {
        c.mpack_discard(&self.reader);
        try self.error_info().check_okay();
    }

    /// Finishes reading an array.
    pub fn done_array(self: *MpackReader) Error!void {
        c.mpack_done_array(&self.reader);
        try self.error_info().check_okay();
    }

    /// Finishes reading a map.
    pub fn done_map(self: *MpackReader) Error!void {
        c.mpack_done_map(&self.reader);
        try self.error_info().check_okay();
    }

    /// Finishes reading a binary data blob.
    pub fn done_bin(self: *MpackReader) Error!void {
        c.mpack_done_bin(&self.reader);
        try self.error_info().check_okay();
    }

    /// Finishes reading a string.
    pub fn done_str(self: *MpackReader) Error!void {
        c.mpack_done_str(&self.reader);
        try self.error_info().check_okay();
    }

    /// Cleans up the MPack reader,
    /// ensuring that all compound elements
    /// have been completely read
    ///
    /// Returns the final error state of the
    /// reader.
    pub inline fn destroy(self: *MpackReader) Error!void {
        var err = c.mpack_reader_destroy(&self.reader);
        try (ErrorInfo{ .err = err }).check_okay();
    }

    /// Reads bytes from a string, binary blob or extension object,
    /// copying them into the given buffer.
    ///
    /// A str, bin or ext must have been opened by a call to read_tag()
    /// which gave one of these types.
    ///
    /// This can be called multiple times for a single str, bin or ext
    /// to read the data in chunks.
    /// The total data read must add up to the size of the object.
    ///
    /// If an error occurs, the buffer contents are undefined.
    pub fn read_bytes_into(self: *MpackReader, dest: []u8) Error!void {
        if (dest.len != 0) {
            c.mpack_read_bytes(&self.reader, dest.ptr, dest.len);
            try self.error_info().check_okay();
        }
    }

    /// Skips bytes from the underlying stream.
    ///
    /// This function does not check for erorrs.
    pub fn skip_bytes(self: *MpackReader, count: usize) void {
        c.mpack_skip_bytes(&self.reader, count);
    }

    /// Reads bytes from a string, binary blob or extension object,
    /// allocating storage for them and returning the allocated pointer.
    pub fn read_bytes_alloc(self: *MpackReader, alloc: Allocator, size: u32) Error![]u8 {
        var dest = try alloc.alloc(u8, @intCast(usize, size));
        try self.read_bytes_into(dest);
        return dest;
    }

    //
    // expect API
    //

    /// Reads an 8-bit unsigned integer.
    pub inline fn expect_u8(self: *MpackReader) Error!u8 {
        const val = c.mpack_expect_u8(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a 32-bit unsigned integer.
    pub inline fn expect_u32(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_u32(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads an 64-bit unsigned integer.
    pub inline fn expect_u64(self: *MpackReader) Error!u64 {
        const val = c.mpack_expect_u64(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads an 32-bit signed integer.
    pub inline fn expect_i32(self: *MpackReader) Error!i32 {
        const val = c.mpack_expect_i32(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads an 64-bit signed integer.
    pub inline fn expect_i64(self: *MpackReader) Error!i64 {
        const val = c.mpack_expect_i64(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a 64-bit unsigned integer, ensuring that it falls within the given range.
    ///
    /// The underlying type may be an integer
    /// type of any size and signedness, as long as the value
    /// can be represented in a 64-bit unsigned int.
    ///
    /// Both values are inclusive
    pub inline fn expect_u64_range(self: *MpackReader, min: u64, max: u64) Error!u64 {
        const val = c.mpack_expect_u64_range(&self.reader, min, max);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a 64-bit signed integer, ensuring that it falls within the given range.
    ///
    /// The underlying type may be an integer
    /// type of any size and signedness, as long as the value
    /// can be represented in a 64-bit signed int.
    ///
    /// Both values are inclusive
    pub inline fn expect_i64_range(self: *MpackReader, min: i64, max: i64) Error!i64 {
        const val = c.mpack_expect_i64_range(&self.reader, min, max);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a number, returning the value as a double.
    ///
    /// The underlying value can be an integer, float or double;
    /// the value is converted to a double.
    ///
    /// Reading a very large integer with this function
    /// can incur a loss of precision.
    pub inline fn expect_double(self: *MpackReader) Error!f64 {
        const val = c.mpack_expect_double(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a double.
    ///
    /// The underlying value must be a float or double, not an integer.
    /// This ensures no loss of precision can occur.
    pub inline fn expect_double_strict(self: *MpackReader) Error!f64 {
        const val = c.mpack_expect_double_strict(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a float.
    ///
    /// The underlying value can be an integer, float or double;
    /// the value is converted to a float.
    ///
    /// Loss of precision can occur.
    pub inline fn expect_float(self: *MpackReader) Error!f32 {
        const val = c.mpack_expect_float(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a float.
    ///
    /// The underlying value must be a float, not a double or an integer.
    /// This ensures no loss of precision can occur.
    pub inline fn expect_float_strict(self: *MpackReader) Error!f32 {
        const val = c.mpack_expect_float_strict(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads a nil.
    pub inline fn expect_nil(self: *MpackReader) Error!void {
        c.mpack_expect_nil(&self.reader);
        try self.error_info().check_okay();
    }

    /// Reads a boolean.
    ///
    /// Integers will raise an error,
    /// the value must be strictly a boolean.
    pub inline fn expect_bool(self: *MpackReader) Error!bool {
        const val = c.mpack_expect_bool(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads the start of a map, returning its element count.
    ///
    /// A number of values follow equal to twice the
    /// element count of the map, alternating between keys and values.
    ///
    /// NOTE: Maps in JSON are unordered, so it is recommended
    /// not to expecta specific ordering for your map values
    /// in case your data is converted to/from JSON.
    ///
    /// WARNING(from C): This call is dangerous! It does not have
    /// a size limit, and it does not have any way of checking
    /// whether there is enough data in the message.
    ///
    /// NOTE: This is almost entirely mitigated by careful error handling
    /// of the Zig bindings, which check for errors after every call :)
    pub fn expect_map(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_map(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads the start of an array, returning its element count.
    ///
    /// A number of values follow equal to
    /// the element count of the array.
    pub fn expect_array(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_array(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads the start of an array, expecting the exact size given.
    pub fn expect_array_match(self: *MpackReader, count: u32) Error!void {
        c.mpack_expect_array_match(&self.reader, count);
        try self.error_info().check_okay();
    }

    /// Reads the start of a string, returning its size in bytes.
    ///
    /// The bytes follow and must be read separately.
    /// done_str() must be called once all bytes have been read.
    ///
    /// NUL bytes are allowed in the string, and no encoding checks are done.
    pub fn expect_str_start(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_str(&self.reader);
        try self.error_info().check_okay();
        return val;
    }

    /// Reads the start of a binary blob, returning its size in bytes.
    ///
    /// The bytes follow and must be read separately.
    /// done_bin() must be called once all bytes have been read.
    ///
    /// NUL bytes are allowed in the string, and no encoding checks are done.
    pub fn expect_bin_start(self: *MpackReader) Error!u32 {
        const val = c.mpack_expect_bin(&self.reader);
        try self.error_info().check_okay();
        return val;
    }
    /// Reads a string, allocating it in the specified allocator.
    ///
    /// NULL bytes are allowed in the string,
    /// and no encoding checks are done (it may not be valid UTF8).
    ///
    /// See also `expect_utf8_alloc`, which requires the data is UTF8 encoded
    pub fn expect_str_relaxed_alloc(self: *MpackReader, alloc: Allocator) Error![]const u8 {
        const size = try self.expect_str_start();
        const res = try self.read_bytes_alloc(alloc, size);
        try self.done_str();
        return res;
    }

    /// Reads a UTF8 encoded string,
    ///
    /// Null bytes are allowed in the string.
    /// However, it must be valid UTF8
    pub fn expect_utf8_alloc(self: *MpackReader, alloc: Allocator) Error![]const u8 {
        const bytes = try self.expect_str_relaxed_alloc(alloc);
        if (!std.unicode.utf8ValidateSlice(bytes)) {
            return Error.MsgpackErrorInvalid;
        }
        return bytes;
    }

    /// Parse the specified primitive type using compile time reflection
    ///
    /// Types that can be parsed:
    /// 1. Primitives (Integers, Floats, Booleans)
    /// 2. Optional types
    pub fn expect_reflect_primitive(
        self: *MpackReader,
        comptime T: type,
        comptime ctx: ReflectParseContext,
    ) Error!T {
        const info = @typeInfo(T);
        switch (info) {
            .Void => {
                try self.expect_nil();
                return;
            },
            .Bool => {
                return @as(T, try self.expect_bool());
            },
            .Int => |i| {
                assert(i.bits <= 64);
                const effective_bits = switch (i.signedness) {
                    .signed => i.bits - 1,
                    .unsigned => i.bits,
                };
                const max: comptime_int = (1 << effective_bits) - 1;
                return switch (i.signedness) {
                    .signed => {
                        const min: comptime_int = -(1 << effective_bits);
                        return @intCast(T, try self.expect_i64_range(@intCast(i64, min), @intCast(i64, max)));
                    },
                    .unsigned => {
                        return @intCast(T, try self.expect_u64_range(@intCast(u64, 0), @intCast(u64, max)));
                    },
                };
            },
            .Float => |i| {
                switch (i.bits) {
                    32 => {
                        if (ctx.strict_floating) {
                            return try self.*.expect_float_strict();
                        } else {
                            return try self.*.expect_float();
                        }
                    },
                    64 => {
                        if (ctx.strict_floating) {
                            return try self.*.expect_double_strict();
                        } else {
                            return try self.*.expect_double();
                        }
                    },
                    else => unreachable,
                }
            },
            // invalid type
            else => unreachable,
        }
    }

    /// Expects a string matching one of the enum names.
    ///
    /// Returns the corresponding enum value.
    ///
    /// If the value does not match any of the given strings,
    /// `Error.MpackUnexpectedEnumName` is returned.
    ///
    /// The maximum string length is implied by the maximum length
    /// of the enum name (strings are read without allocation).
    ///
    /// This zig function is the (nicer) counterpart to `mpack_expect_enum`.
    /// The advantage here is we get to use compile-time reflection ;)
    pub fn expect_enum(
        self: *MpackReader,
        comptime T: type,
    ) EnumParseError!T {
        const info = switch (@typeInfo(T)) {
            .Enum => |e| e,
            else => unreachable, // Must be enum
        };
        // should actually have some fields (or else we will always error)
        assert(info.fields.len > 0);
        comptime var max_field_len = 0;
        inline for (info.fields) |field| {
            max_field_len = @maximum(field.name.len, max_field_len);
        }
        // actually read the thing
        const tag = try self.read_tag();
        const len = try tag.str_length();
        var raw_buffer: [max_field_len]u8 = undefined;
        const buffer = readBuffer: {
            var read_all_bytes = false;
            errdefer {
                if (!read_all_bytes) self.skip_bytes(len);
                self.done_str() catch {};
            }
            if (len > max_field_len) {
                // logically impossible for a match
                return EnumParseError.MsgpackUnexpectedEnumName;
            }
            // we build an array on the stack with the maximum length of the enum.
            //
            // This is a compile time constant, but is only
            // reasonable if the enum length isn't horribly long
            assert(max_field_len <= 1024);
            var buffer: []u8 = raw_buffer[0..len];
            try self.read_bytes_into(buffer);
            read_all_bytes = true;
            break :readBuffer buffer;
        };
        try self.done_str();
        return std.meta.stringToEnum(T, buffer) orelse EnumParseError.MsgpackUnexpectedEnumName;
    }
};
pub const ReflectParseContext = struct {
    /// Require floating point types to be exact.
    ///
    /// This avoids loss of precision.
    strict_floating: bool = true,
};

pub const MType = enum(c.mpack_type_t) {
    missing = c.mpack_type_missing,
    nil = c.mpack_type_nil,
    bool = c.mpack_type_bool,
    int = c.mpack_type_int,
    uint = c.mpack_type_uint,
    float = c.mpack_type_float,
    double = c.mpack_type_double,
    str = c.mpack_type_str,
    bin = c.mpack_type_bin,
    array = c.mpack_type_array,
    map = c.mpack_type_map,
    // TODO: Compile with this enabled???
    // ext = c.mpack_type_ext,

    pub fn to_string(self: MType) [*:0]const u8 {
        return c.mpack_type_to_string(@as(c.mpack_type_t, self));
    }
};

pub const MTag = extern struct {
    tag: c.mpack_tag_t,

    pub inline fn tag_type(self: MTag) MType {
        return @intToEnum(MType, c.mpack_tag_type(self.c_ptr()));
    }

    pub inline fn is_nil(self: MTag) bool {
        return self.tag_type() == MType.nil;
    }

    pub inline fn require_type(self: MTag, expected_type: MType) TypeError!void {
        if (self.tag_type() != expected_type) {
            return TypeError.MsgpackErrorType;
        }
    }

    inline fn c_ptr(self: *const MTag) *c.mpack_tag_t {
        // casts aren't allowed to discard qualifiers.
        // I see now way to do this directly, so we do this work-around
        return @intToPtr(*c.mpack_tag_t, @ptrToInt(&self.tag));
    }

    //
    // construct
    //

    /// Generates a nil tag.
    pub inline fn make_nil() MTag {
        return .{ .tag = c.mpack_tag_make_nil() };
    }

    /// Generates a bool tag.
    pub inline fn make_bool(val: bool) MTag {
        return .{ .tag = c.mpack_tag_make_bool(val) };
    }

    /// Generates a signed int tag.
    pub inline fn make_int(val: i64) MTag {
        return .{ .tag = c.mpack_tag_make_int(val) };
    }

    /// Generates an unsigned int tag.
    pub inline fn make_uint(val: u64) MTag {
        return .{ .tag = c.mpack_tag_make_uint(val) };
    }

    /// Generates a float tag.
    pub inline fn make_float(val: f32) MTag {
        return .{ .tag = c.mpack_tag_make_float(val) };
    }

    /// Generates a float tag.
    pub inline fn make_double(val: f64) MTag {
        return .{ .tag = c.mpack_tag_make_double(val) };
    }

    /// Generates an array tag.
    ///
    /// This includes only the length, not the values.
    pub inline fn make_array(count: u32) MTag {
        return .{ .tag = c.mpack_tag_make_array(count) };
    }

    /// Generates a map tag.
    ///
    /// This includes only the length, not the values.
    pub inline fn make_map(count: u32) MTag {
        return .{ .tag = c.mpack_tag_make_map(count) };
    }

    /// Generates a string tag.
    ///
    /// This includes only the length, not the values.
    pub inline fn make_str(count: u32) MTag {
        return .{ .tag = c.mpack_tag_make_str(count) };
    }

    /// Generates a bin tag.
    ///
    /// This includes only the length, not the values.
    pub inline fn make_bin(count: u32) MTag {
        return .{ .tag = c.mpack_tag_make_bin(count) };
    }

    //
    // extract
    //

    pub inline fn bool_value(self: MTag) TypeError!bool {
        try self.require_type(.bool);
        return c.mpack_tag_bool_value(self.c_ptr());
    }

    pub inline fn int_value(self: MTag) TypeError!i64 {
        try self.require_type(.int);
        return c.mpack_tag_int_value(self.c_ptr());
    }

    pub inline fn uint_value(self: MTag) TypeError!u64 {
        try self.require_type(.uint);
        return c.mpack_tag_uint_value(self.c_ptr());
    }

    pub inline fn float_value(self: MTag) TypeError!f32 {
        try self.require_type(.float);
        return c.mpack_tag_float_value(self.c_ptr());
    }

    pub inline fn double_value(self: MTag) TypeError!f64 {
        try self.require_type(.double);
        return c.mpack_tag_double_value(self.c_ptr());
    }

    pub inline fn array_count(self: MTag) TypeError!u32 {
        try self.require_type(.array);
        return c.mpack_tag_array_count(self.c_ptr());
    }

    pub inline fn map_count(self: MTag) TypeError!u32 {
        try self.require_type(.map);
        return c.mpack_tag_map_count(self.c_ptr());
    }

    pub inline fn str_length(self: MTag) TypeError!u32 {
        try self.require_type(.str);
        return c.mpack_tag_str_length(self.c_ptr());
    }

    pub inline fn bin_length(self: MTag) TypeError!u32 {
        try self.require_type(.bin);
        return c.mpack_tag_bin_length(self.c_ptr());
    }
};

pub const TypeError = error{
    /// The type or value range did not match what was expected by the caller.
    ///
    /// This can include not only unexpected type tag,
    /// but also an unexpected value.
    /// In particular it can indicate invalid UTF8.
    ///
    /// In some contexts this is the only error that is possible
    /// (which is why it is a seperate type)
    MsgpackErrorType,
};
pub const Error = error{
    /// Some other error occured related to msgpack
    MsgpackError,
    /// The data read is not valid MessagePack
    MsgpackErrorInvalid,
    /// Indicates an underlying error occurred with IO.
    ///
    /// The reader or writer failed to fill or flush,
    /// or some other file or socket error occurred.
    MsgpackErrorIO,
    /// While reading msgpack, an allocation failure occurred
    ///
    /// This indicates failure of the underlying library,
    /// not zig allocation failrue (that is AllocError)
    MsgpackErrorMemory,
} || TypeError || AllocError;

/// An error that occurs parsing a msgpack type into a Zig enum.
///
/// TODO: Better name for this error?
pub const EnumParseError = Error || error{MsgpackUnexpectedEnumName};

pub const ErrorInfo = extern struct {
    err: c.mpack_error_t,

    pub inline fn is_ok(self: ErrorInfo) bool {
        return self.err == c.mpack_ok;
    }
    pub inline fn check_okay(self: ErrorInfo) Error!void {
        return switch (self.err) {
            c.mpack_ok => return,
            c.mpack_error_io => Error.MsgpackErrorIO,
            c.mpack_error_type => Error.MsgpackErrorType,
            c.mpack_error_invalid => Error.MsgpackErrorInvalid,
            c.mpack_error_memory => Error.MsgpackErrorMemory,
            else => Error.MsgpackError,
        };
    }

    /// Convert a zig error code to the C-level error info
    pub fn from_zig(err: Error) ErrorInfo {
        const c_err: c.mpack_error_t = switch (err) {
            Error.MsgpackErrorType => c.mpack_error_type,
            // Convert 'other' errors to "invalid" error status
            Error.MsgpackErrorInvalid, Error.MsgpackError => c.mpack_error_invalid,
            // Convert zig alloc failure to mpack alloc error failure
            Error.MsgpackErrorMemory, Error.OutOfMemory => c.mpack_error_memory,
            Error.MsgpackErrorIO => c.mpack_error_io,
        };
        return ErrorInfo{ .err = c_err };
    }

    pub fn to_string(self: ErrorInfo) [*:0]const u8 {
        return c.mpack_error_to_string(self.err);
    }

    /// Indicates error info that is actually ok (no error at all)
    pub const OK = ErrorInfo{ .err = c.mpack_ok };
    /// An `ErrorInfo` corresponding to `Error.MsgpackERrorInvalid`
    pub const INVALID = ErrorInfo{ .err = c.mpack_error_invalid };
    /// An `ErrorInfo` corresponding to `Error.MsgpackErrorType`
    pub const TYPE = ErrorInfo{ .err = c.mpack_error_type };
};

pub fn free(ptr: anytype) void {
    c.MPACK_FREE(ptr);
}

//
// code used for testing
//

const PrimitiveValue = union(enum) {
    U8: u8,
    U32: u32,
    U64: u64,
    I32: i32,
    I64: i64,
    Bool: bool,
    Nil: void,
    Double: f64,
};
const TestValue = struct {
    bytes: []const u8,
    value: PrimitiveValue,
};
const PrimitiveReadMode = enum {
    reflect,
    expect,
    tag,
};
fn expect_primitive(reader: *MpackReader, expected: PrimitiveValue, mode: PrimitiveReadMode) !void {
    const expectEqual = std.testing.expectEqual;
    const tag = if (mode == .tag) (try reader.*.read_tag()) else null;
    switch (expected) {
        .U8 => |val| {
            switch (mode) {
                .reflect => try expectEqual(val, try reader.*.expect_reflect_primitive(u8, .{})),
                .expect => try expectEqual(val, try reader.*.expect_u8()),
                .tag => try expectEqual(val, @intCast(u8, try tag.?.uint_value())),
            }
        },
        .U32 => |val| {
            switch (mode) {
                .reflect => try expectEqual(val, try reader.*.expect_reflect_primitive(u32, .{})),
                .expect => try expectEqual(val, try reader.*.expect_u32()),
                .tag => try expectEqual(val, @intCast(u32, try tag.?.uint_value())),
            }
        },
        .U64 => |val| {
            switch (mode) {
                .reflect => try expectEqual(val, try reader.*.expect_reflect_primitive(u64, .{})),
                .expect => try expectEqual(val, try reader.*.expect_u64()),
                .tag => try expectEqual(val, @intCast(u64, try tag.?.uint_value())),
            }
        },
        .I32 => |val| {
            switch (mode) {
                .reflect => try expectEqual(val, try reader.*.expect_reflect_primitive(i32, .{})),
                .expect => try expectEqual(val, try reader.*.expect_i32()),
                .tag => try expectEqual(val, @intCast(i32, try tag.?.int_value())),
            }
        },
        .I64 => |val| {
            switch (mode) {
                .reflect => try expectEqual(val, try reader.*.expect_reflect_primitive(i64, .{})),
                .expect => try expectEqual(val, try reader.*.expect_i64()),
                .tag => try expectEqual(val, @intCast(i64, try tag.?.int_value())),
            }
        },
        .Bool => |val| {
            switch (mode) {
                .reflect => try expectEqual(val, try reader.*.expect_reflect_primitive(bool, .{})),
                .expect => try expectEqual(val, try reader.*.expect_bool()),
                .tag => try expectEqual(val, try tag.?.bool_value()),
            }
        },
        .Nil => {
            switch (mode) {
                .reflect => try reader.*.expect_reflect_primitive(void, .{}),
                .expect => try reader.*.expect_nil(),
                .tag => try std.testing.expect(tag.?.is_nil()),
            }
        },
        .Double => |val| {
            switch (mode) {
                .reflect => try expectEqual(val, try reader.*.expect_reflect_primitive(f64, .{})),
                .expect => try expectEqual(val, try reader.*.expect_double_strict()),
                .tag => try expectEqual(val, try tag.?.double_value()),
            }
        },
    }
}

test "mpack primitives" {
    const expected_values = [_]TestValue{
        .{ .bytes = "\x07", .value = PrimitiveValue{ .U8 = 7 } },
        .{ .bytes = "\xcc\xf0", .value = PrimitiveValue{ .U8 = 240 } },
        .{ .bytes = "\x01", .value = PrimitiveValue{ .U8 = 1 } },
        .{ .bytes = "\x01", .value = PrimitiveValue{ .U32 = 1 } },
        .{ .bytes = "\xFF", .value = PrimitiveValue{ .I32 = -1 } },
        .{ .bytes = "\xE7", .value = PrimitiveValue{ .I32 = -25 } },
        .{ .bytes = "\xd1\xf2\x06", .value = PrimitiveValue{ .I32 = -3578 } },
        .{ .bytes = "\xcd\r\xfa", .value = PrimitiveValue{ .I32 = 3578 } },
        .{ .bytes = "\xce\x01\x00\x00\x00", .value = PrimitiveValue{ .U32 = 1 << 24 } },
        .{ .bytes = "\xd2\xff\x00\x00\x00", .value = PrimitiveValue{ .I32 = -(1 << 24) } },
        .{
            .bytes = "\xcf\x00\x00 \x00\x00\x00\x00\x1f",
            .value = PrimitiveValue{ .U64 = (1 << 45) + 31 },
        },
        .{
            .bytes = "\xd3\xff\xff\xdf\xff\xff\xff\xff\xe1",
            .value = PrimitiveValue{ .I64 = -(1 << 45) - 31 },
        },
        .{ .bytes = "\xc0", .value = PrimitiveValue{ .Nil = {} } },
        .{ .bytes = "\xc3", .value = PrimitiveValue{ .Bool = true } },
        .{ .bytes = "\xc2", .value = PrimitiveValue{ .Bool = false } },
        // doubles
        .{
            .bytes = "\xcb@\x0c\x00\x00\x00\x00\x00\x00",
            .value = PrimitiveValue{ .Double = 3.5 },
        },
        .{
            .bytes = "\xcb@\t!\xfbTD-\x18",
            .value = PrimitiveValue{ .Double = std.math.pi },
        },
    };
    for (expected_values) |value| {
        const modes = [2]PrimitiveReadMode{ .reflect, .expect };
        for (modes) |mode| {
            var reader = MpackReader.init_data(value.bytes);
            defer reader.destroy() catch unreachable;
            try expect_primitive(&reader, value.value, mode);
        }
    }
}

test "mpack strings" {
    const TestString = struct {
        encoded: []const u8,
        text: []const u8,
        utf8: bool = true,
    };
    const long_phrases = [_][]const u8{
        "For Faith is the Substance of the Things I have hoped for, the evidence for the things not seen.",
        "Let it go! Let it go! Can't hold it back anymore.",
    };
    const test_strings = [_]TestString{
        .{ .encoded = "\xa0", .text = "" },
        .{ .encoded = "\xa3foo", .text = "foo" },
        .{ .encoded = "\xd9`" ++ long_phrases[0], .text = long_phrases[0] },
        .{ .encoded = "\xd91" ++ long_phrases[1], .text = long_phrases[1] },
    };
    const alloc = std.testing.allocator;
    for (test_strings) |value| {
        var reader = MpackReader.init_data(value.encoded);
        defer reader.destroy() catch unreachable;
        var actual_text = blk: {
            if (value.utf8) {
                break :blk try reader.expect_str_relaxed_alloc(alloc);
            } else {
                break :blk try reader.expect_utf8_alloc(alloc);
            }
        };
        try std.testing.expectEqualStrings(actual_text, value.text);
        defer alloc.free(actual_text);
    }
}

test "mpack reflect enum" {
    const TestEnum = enum {
        foo,
        bar,
        poopy,
        poopy_pants,
    };
    const TestEnumValue = struct {
        encoded: []const u8,
        expected: TestEnum,
    };
    const TestEnumFail = struct { encoded: []const u8, expected: EnumParseError };
    const test_values = [_]TestEnumValue{
        .{ .encoded = "\xa3foo", .expected = .foo },
        .{ .encoded = "\xa3bar", .expected = .bar },
        .{ .encoded = "\xa5poopy", .expected = .poopy },
        .{ .encoded = "\xabpoopy_pants", .expected = .poopy_pants },
    };
    for (test_values) |value| {
        var reader = MpackReader.init_data(value.encoded);
        defer reader.destroy() catch unreachable;
        try std.testing.expectEqual(
            try reader.expect_enum(TestEnum),
            value.expected,
        );
    }
    const test_error_valeus = [_]TestEnumFail{
        // Too long
        .{ .encoded = "\xbfDo you want to build a snowman?", .expected = EnumParseError.MsgpackUnexpectedEnumName },
        // Insufficent length
        .{ .encoded = "\xa2ab", .expected = EnumParseError.MsgpackUnexpectedEnumName },
        // Zero length
        .{ .encoded = "\xa0", .expected = EnumParseError.MsgpackUnexpectedEnumName },
        // Correct length, no match
        .{ .encoded = "\xa3baz", .expected = EnumParseError.MsgpackUnexpectedEnumName },
        // wrong type
        .{ .encoded = "\x11", .expected = EnumParseError.MsgpackErrorType },
    };
    for (test_error_valeus) |error_value| {
        var reader = MpackReader.init_data(error_value.encoded);
        defer reader.destroy() catch unreachable;
        try std.testing.expectError(
            error_value.expected,
            reader.expect_enum(TestEnum),
        );
    }
}

test "error info" {
    try std.testing.expect(ErrorInfo.OK.is_ok());
    try std.testing.expectError(Error.MsgpackErrorInvalid, ErrorInfo.INVALID.check_okay());
    try std.testing.expectError(Error.MsgpackErrorMemory, ErrorInfo.from_zig(std.mem.Allocator.Error.OutOfMemory).check_okay());
}
