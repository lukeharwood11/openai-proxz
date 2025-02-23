const std = @import("std");
const proxz = @import("proxz");

const ChatMessage = proxz.ChatMessage;
const OpenAI = proxz.OpenAI;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // make sure you have an OPENAI_API_KEY environment variable set!
    // or pass it in explicitly...
    // const alternate_config: proxz.OpenAIConfig = .{
    //     .api_key = "my-groq-api-key",
    //     .base_url = "https://api.groq.com/openai/v1",
    //     .max_retries = 5,
    // };
    var openai = try OpenAI.init(allocator, .{});
    defer openai.deinit();

    var response = try openai.models.retrieve("gpt-4o");

    // var response = try openai.chat.completions.create(.{
    //     .model = "gpt-4o",
    //     .messages = &[_]ChatMessage{
    //         .{
    //             .role = "user",
    //             .content = "Hello, world!",
    //         },
    //     },
    // });
    // This will free all the memory allocated for the response
    defer response.deinit();
    const completion = response.data;
    // std.log.debug("{s}", .{completion.choices[0].message.content});
    std.log.debug("{s}", .{completion.owned_by});
}
