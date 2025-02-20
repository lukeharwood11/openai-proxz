pub const client = @import("client.zig");
pub const models = @import("models.zig");
pub const completions = @import("completions.zig");
pub const embeddings = @import("embeddings.zig");

pub const OpenAI = client.OpenAI;
pub const OpenAIConfig = client.OpenAIConfig;
pub const ChatMessage = completions.ChatMessage;
