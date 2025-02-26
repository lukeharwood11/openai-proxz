const std = @import("std");
const openai = @import("client.zig");
const OpenAI = openai.OpenAI;

pub const ListModelResponse = struct { object: []const u8, data: []const Object };
pub const Object = struct { id: []const u8, object: []const u8, created: u64, owned_by: []const u8 };

pub const Models = struct {
    client: *const OpenAI,

    pub fn init(client: *const OpenAI) Models {
        return Models{
            .client = client,
        };
    }

    pub fn deinit(self: *Models) void {
        _ = self;
    }

    /// Lists available models.
    /// Caller is responsible for calling `deinit` on the returned `client.Response` object to clean up all memeory
    pub fn list(self: *const Models) !openai.Response(ListModelResponse) {
        const response = try self.client.request(.{ .method = .GET, .path = "/models" }, ListModelResponse);
        return response;
    }

    /// Retrieves model information for provided model ID (e.g. "gpt-4o").
    /// Caller is responsible for calling `deinit` on the returned `client.Response` object to clean up all memeory
    pub fn retrieve(self: *const Models, id: []const u8) !openai.Response(Object) {
        const path = try std.fmt.allocPrint(self.client.allocator, "/models/{s}", .{id});
        defer self.client.allocator.free(path);
        const response = try self.client.request(.{ .method = .GET, .path = path }, Object);
        return response;
    }
};
