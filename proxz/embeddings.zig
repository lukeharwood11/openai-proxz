const std = @import("std");
const client = @import("client.zig");

/// Request payload for `embeddings.create`
pub const EmbeddingsRequest = struct {
    model: []const u8,
    input: []const []const u8,
    encoding_format: ?[]const u8 = null,
    dimensions: ?usize = null,
    user: ?[]const u8 = null,
};

/// Content from `EmbeddingsResponse.data`
const EmbeddingObject = struct {
    object: []const u8,
    embedding: []f64,
    index: usize,
};

/// Usage object for `EmbeddingsResponse.usage`
const EmbeddingsUsage = struct {
    prompt_tokens: usize,
    total_tokens: usize,
};

/// The embeddings response object
const EmbeddingsResponse = struct {
    object: []const u8,
    data: []const EmbeddingObject,
    model: []const u8,
    usage: EmbeddingsUsage,
};

/// Module for `/embeddings` endpoints
pub const Embeddings = struct {
    openai: *const client.OpenAI,

    pub fn init(openai: *const client.OpenAI) Embeddings {
        return Embeddings{
            .openai = openai,
        };
    }

    /// Sends `POST` request to `/embeddings` with the given `EmbeddingsRequest`.
    /// The caller is also responsible for calling deinit() on the response to free all allocated memory.
    /// Returns a `client.Resource` wrapper containing an `EmbeddingsResponse`.
    pub fn create(self: *Embeddings, request: EmbeddingsRequest) !client.Response(EmbeddingsResponse) {
        const body = try std.json.stringifyAlloc(self.openai.allocator, request, .{});
        defer self.openai.allocator.free(body);
        const response = try self.openai.request(.{
            .method = .POST,
            .path = "/embeddings",
            .json = body,
        }, EmbeddingsResponse);
        return response;
    }

    pub fn deinit(_: *Embeddings) void {}
};
