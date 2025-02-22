const std = @import("std");
const json = std.json;

/// An OpenAI API response wrapper, returns a struct with the following fields:
/// ```
/// data: T,
/// parsed: ?json.Parsed(T) = null,
/// allocator: std.mem.Allocator,
/// ```
/// The caller is responsible of calling `deinit` on this object to clean up resources
pub fn Response(comptime T: type) type {
    return struct {
        /// The response payload
        data: T,
        /// The backing json Parsed object, that contains all memory created for this object
        parsed: ?json.Parsed(T) = null,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Parses the response from the API into a struct of type T, which is accessible via the .data field
        /// The caller is also responsible for calling deinit() on the response to free all allocated memory
        pub fn parse(allocator: std.mem.Allocator, source: []const u8) !Self {
            const parsed = try json.parseFromSlice(T, allocator, source, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
            return Self{
                .data = parsed.value,
                .parsed = parsed,
                .allocator = allocator,
            };
        }

        /// Deinitializes all memory allocated for the response
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
