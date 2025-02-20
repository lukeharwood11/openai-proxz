const std = @import("std");
const json = std.json;

pub fn Response(comptime T: type) type {
    return struct {
        value: T,
        parsed: ?json.Parsed(T) = null,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn parse(allocator: std.mem.Allocator, source: []const u8) !Self {
            const parsed = try json.parseFromSlice(T, allocator, source, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
            return Self{
                .value = parsed.value,
                .parsed = parsed,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *const Self) void {
            if (self.parsed) |parsed| {
                parsed.deinit();
            }
        }
    };
}

pub const APIError = struct {
    message: []const u8,
    type: []const u8,
    param: ?[]const u8 = null,
    code: ?[]const u8 = null,
};

pub const APIErrorResponse = struct {
    @"error": APIError,
};
