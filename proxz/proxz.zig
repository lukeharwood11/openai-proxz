//! ***An OpenAI API library for the Zig programming language!***
//!
//! ## Installation
// To install `proxz`, run
//!
//!```bash
//! zig fetch --save "git+https://github.com/lukeharwood11/openai-proxz#3fd51f2247929c4d161e5a1ed53f2b8aef104261"
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
pub const client = @import("client.zig");
pub const models = @import("models.zig");
pub const completions = @import("completions.zig");
pub const embeddings = @import("embeddings.zig");

pub const OpenAI = client.OpenAI;
pub const OpenAIConfig = client.OpenAIConfig;
pub const ChatMessage = completions.ChatMessage;
