const std = @import("std");

pub const CompletionTokensDetails = struct {
    reasoning_tokens: u64,
    audio_tokens: u64,
    accepted_prediction_tokens: u64,
    rejected_prediction_tokens: u64,
};

pub const PromptTokensDetails = struct {
    cached_tokens: u64,
    audio_tokens: u64,
};

pub const Usage = struct {
    prompt_tokens: u64,
    completion_tokens: u64,
    total_tokens: u64,
    prompt_tokens_details: PromptTokensDetails,
    completion_tokens_details: CompletionTokensDetails,
};

pub const Message = struct {
    role: []const u8,
    content: []const u8,
    refusal: ?[]const u8,
};

pub const Choice = struct {
    index: u64,
    message: Message,
    logprobs: ?[]const u8,
    finish_reason: []const u8,
};

pub const ChatCompletion = struct {
    id: []const u8,
    object: []const u8,
    created: i64,
    model: []const u8,
    choices: []Choice,
    usage: Usage,
    service_tier: []const u8,
    system_fingerprint: []const u8,
};
