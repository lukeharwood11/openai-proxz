const std = @import("std");
const log = std.log;
const models = @import("models.zig");
const client = @import("client.zig");

pub const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatRequest = struct {
    model: []const u8,
    messages: []const ChatMessage,
};

pub const CompletionTokensDetails = struct {
    reasoning_tokens: ?u64 = null,
    audio_tokens: ?u64 = null,
    accepted_prediction_tokens: ?u64 = null,
    rejected_prediction_tokens: ?u64 = null,
};

pub const PromptTokensDetails = struct {
    cached_tokens: ?u64 = null,
    audio_tokens: ?u64 = null,
};

pub const Usage = struct {
    prompt_tokens: u64,
    completion_tokens: u64,
    total_tokens: u64,
    prompt_tokens_details: ?PromptTokensDetails = null,
    completion_tokens_details: ?CompletionTokensDetails = null,
};

pub const Message = struct {
    role: []const u8,
    content: []const u8,
    refusal: ?[]const u8 = null,
    function_call: ?[]const u8 = null,
};

pub const Choice = struct {
    index: u64,
    message: Message,
    logprobs: ?[]const u8 = null,
    finish_reason: []const u8,
};

pub const ChatCompletion = struct {
    id: []const u8,
    object: []const u8,
    created: i64,
    model: []const u8,
    choices: []Choice,
    usage: Usage,
    system_fingerprint: ?[]const u8 = null,
};

pub const Completions = struct {
    openai: *const client.OpenAI,

    pub fn init(openai: *const client.OpenAI) Completions {
        return Completions{
            .openai = openai,
        };
    }

    pub fn deinit(_: *Completions) void {}

    pub fn create(self: *Completions, request: ChatRequest) !models.Response(ChatCompletion) {
        const allocator = self.openai.arena.allocator();
        const body = try std.json.stringifyAlloc(allocator, request, .{});
        defer allocator.free(body);

        const response = try self.openai.request(.POST, "/chat/completions", .{
            .body = body,
        }, ChatCompletion);
        switch (response) {
            .err => |err| {
                log.err("{s} ({s}): {s}", .{ err.value.@"error".type, err.value.@"error".code orelse "None", err.value.@"error".message });
                return client.OpenAIError.BadRequest;
            },
            .ok => |ok| {
                return ok;
            },
        }
    }
};
