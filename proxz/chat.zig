const client = @import("client.zig");
const completions = @import("completions.zig");
const Completions = completions.Completions;

/// Container for the completions module. Chat endpoints have been deprecated by OpenAI.
pub const Chat = struct {
    openai: *const client.OpenAI,
    completions: completions.Completions,

    pub fn init(openai: *const client.OpenAI) Chat {
        return Chat{
            .openai = openai,
            .completions = Completions.init(openai),
        };
    }

    pub fn deinit(self: *Chat) void {
        self.completions.deinit();
    }
};
