const std = @import("std");
const c = @import("c.zig");
const assert = std.debug.assert;

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

    /// Parses the next MessagePack object header
    /// (an MPack tag) without advancing the reader.
    pub fn peek_tag(self: *MpackReader) Error!MTag {
        const tag = c.mpack_peek_tag(&self.reader);
        if (tag.is_nil()) {
            try self.error_info().check_okay();
        } else {
            // should have returned nil if error
            assert(self.error_info().is_okay());
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
        const tag = c.mpack_read_tag(&self.reader);
        if (tag.is_nil()) {
            try self.error_info().check_okay();
        } else {
            // should have returned nil if error
            assert(self.error_info().is_okay());
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
};

pub const MType = enum(c.mpack_type_t) {
    missing = c.mpack_type_missing,
    nil = c.mpack_type_nil,
    int = c.mpack_type_int,
    uint = c.mpack_type_uint,
    float = c.mpack_type_float,
    double = c.mpack_type_double,
    str = c.mpack_type_str,
    bin = c.mpack_type_bin,
    array = c.mpack_type_array,
    map = c.mpack_type_map,
    ext = c.mpack_type_ext,

    pub fn to_string(self: MType) [*:0]const u8 {
        return c.mpack_type_to_string(@as(c.mpack_type_t, self));
    }
};

pub const MTag = extern struct {
    tag: c.mpack_tag_t,

    pub inline fn tag_type(self: MTag) MType {
        return c.mpack_tag_type(&self.taga);
    }

    pub inline fn is_nil(self: MTag) bool {
        return self.tag_type() == MType.nil;
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
    MsgpackErrorMemory,
} || TypeError;

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

    pub fn to_string(self: ErrorInfo) [*:0]const u8 {
        return c.mpack_error_to_string(self.err);
    }
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
};
const TestValue = struct {
    bytes: []const u8,
    value: PrimitiveValue,
};
fn expect_primitive(reader: *MpackReader, expected: PrimitiveValue) !void {
    const expectEqual = std.testing.expectEqual;
    switch (expected) {
        .U8 => |val| {
            try expectEqual(val, try reader.*.expect_u8());
        },
        .U32 => |val| {
            try expectEqual(val, try reader.*.expect_u32());
        },
        .U64 => |val| {
            try expectEqual(val, try reader.*.expect_u64());
        },
        .I32 => |val| {
            try expectEqual(val, try reader.*.expect_i32());
        },
        .I64 => |val| {
            try expectEqual(val, try reader.*.expect_i64());
        },
        .Bool => |val| {
            try expectEqual(val, try reader.*.expect_bool());
        },
        .Nil => {
            try reader.*.expect_nil();
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
    };
    for (expected_values) |value| {
        var reader = MpackReader.init_data(value.bytes);
        defer reader.destroy() catch unreachable;
        try expect_primitive(&reader, value.value);
    }
}
