const client = @import("client.zig");

pub const EmbeddingsRequest = struct {
    model: []const u8,
    input: [][]const u8,
};

pub const Embeddings = struct {
    openai: *const client.OpenAI,

    pub fn init(openai: *const client.OpenAI) Embeddings {
        return Embeddings{
            .openai = openai,
        };
    }

    pub fn create(self: *Embeddings, request: EmbeddingsRequest) !void {
        _ = self;
        _ = request;
        return error.NotImplemented;
    }

    pub fn deinit(_: *Embeddings) void {}
};
