/// We want to build this out so others can call
/// ```zig
/// const zai = @import("zai");
/// const openai = zai.openai
///
/// ...
/// client = openai.OpenAI.init(allocator);
/// ```
const std = @import("std");
const http = std.http;

pub const OpenAIConfig = struct {
    api_key: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
    organization_id: ?[]const u8 = null,
    project_id: ?[]const u8 = null,
};

pub const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatRequest = struct {
    model: []const u8,
    messages: []const ChatMessage,
};

pub const ChatChoice = struct {
    message: ChatMessage,
    finish_reason: []const u8,
    index: u64,
};

pub const ChatResponse = struct {
    id: []const u8,
    object: []const u8,
    created: u64,
    choices: []const ChatChoice,
};

pub const Chat = struct {
    client: *const OpenAI,
    pub fn init(client: *const OpenAI) Chat {
        return Chat{
            .client = client,
        };
    }

    pub fn create(_: *Chat, _: ChatRequest) void {
        std.debug.print("Chat.create", .{});
    }

    pub fn createStream(_: *Chat, _: ChatRequest) void {
        std.debug.print("Chat.createStream", .{});
    }

    pub fn deinit(_: *Chat) void {}
};

pub const Embeddings = struct {
    client: *const OpenAI,

    pub fn init(client: *const OpenAI) Embeddings {
        return Embeddings{
            .client = client,
        };
    }

    pub fn deinit(_: *Embeddings) void {}
};

pub const OpenAI = struct {
    allocator: *const std.mem.Allocator,
    config: OpenAIConfig,
    client: http.Client,
    chat: Chat,
    embeddings: Embeddings,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, openai_config: OpenAIConfig) OpenAI {
        const client = http.Client{ .allocator = allocator };
        var self = OpenAI{
            .allocator = &allocator,
            .config = openai_config,
            .client = client,
            .chat = undefined,
            .embeddings = undefined,
        };
        self.chat = Chat.init(&self);
        self.embeddings = Embeddings.init(&self);
        return self;
    }

    pub fn deinit(self: *OpenAI) void {
        self.client.deinit();
        self.chat.deinit();
        self.embeddings.deinit();
    }
};
