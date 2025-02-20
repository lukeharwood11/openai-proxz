const client = @import("client.zig");
const completions = @import("completions.zig");
const Completions = completions.Completions;
const ChatRequest = completions.ChatRequest;

pub const Chat = struct {
    openai: *const client.OpenAI,
    completions: completions.Completions,

    pub fn init(openai: *const client.OpenAI) Chat {
        return Chat{
            .openai = openai,
            .completions = Completions.init(openai),
        };
    }

    pub fn create(self: *Chat, request: ChatRequest) !void {
        _ = self;
        _ = request;
        return error.NotImplemented;
    }

    pub fn createStream(self: *Chat, request: ChatRequest) !void {
        _ = self;
        _ = request;
        return error.NotImplemented;
    }

    pub fn deinit(_: *Chat) void {}
};
