const std = @import("std");
const openai = @import("client.zig");
const OpenAI = openai.OpenAI;

pub const ListModelResponse = struct {
    object: []const u8,
    data: []const Object,
    arena: *std.heap.ArenaAllocator,

    pub fn deinit(self: *const ListModelResponse) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
pub const Object = struct { id: []const u8, object: []const u8, created: u64, owned_by: []const u8 };

/// Response payload. The user is responsible for calling deinit() to free all memory for this request.
pub const ObjectResponse = struct {
    id: []const u8,
    object: []const u8,
    created: u64,
    owned_by: []const u8,
    arena: *std.heap.ArenaAllocator,

    pub fn deinit(self: *const ObjectResponse) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};

/// Struct containing all API calls for the /models routes.
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
    /// Caller is responsible for calling `deinit` on the returned `ListModelResponse` object to clean up all memeory
    pub fn list(self: *const Models) !ListModelResponse {
        const response: ListModelResponse = try self.client.request(.{ .method = .GET, .path = "/models" }, ListModelResponse);
        return response;
    }

    /// Retrieves model information for provided model ID (e.g. "gpt-4o").
    /// Caller is responsible for calling `deinit` on the returned `ObjectResponse` object to clean up all memeory
    pub fn retrieve(self: *const Models, id: []const u8) !ObjectResponse {
        const path = try std.fmt.allocPrint(self.client.allocator, "/models/{s}", .{id});
        defer self.client.allocator.free(path);
        const response: ObjectResponse = try self.client.request(.{ .method = .GET, .path = path }, ObjectResponse);
        return response;
    }
};
