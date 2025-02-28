//! ***An OpenAI API library for the Zig programming language!***
//!
//! ## Installation
// To install `proxz`, run
//!
//!```bash
//! zig fetch --save "git+https://github.com/lukeharwood11/openai-proxz"
//!```
//!
//!And add the following to your `build.zig`
//!
//!```zig
//!const proxz = b.dependency("proxz", .{
//!    .target = target,
//!    .optimize = optimize,
//!});
//!
//!exe.root_module.addImport("proxz", proxz.module("proxz"));
//!```
//!
//!Reference `OpenAI` to create a new client and `OpenAIConfig` to view what configuration options can be used.
const std = @import("std");
pub const client = @import("client.zig");
pub const models = @import("models.zig");
pub const completions = @import("completions.zig");
pub const embeddings = @import("embeddings.zig");
/// Contains helper functions for creating your own deserializable types.
pub const json = @import("json.zig");

pub const OpenAI = client.OpenAI;
pub const OpenAIConfig = client.OpenAIConfig;
pub const ChatMessage = completions.ChatMessage;

test {
    std.testing.refAllDecls(@This());
}
