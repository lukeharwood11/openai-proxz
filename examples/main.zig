const std = @import("std");
const proxz = @import("proxz");

const ChatMessage = proxz.ChatMessage;
const OpenAI = proxz.OpenAI;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // make sure you have an OPENAI_API_KEY environment variable set!
    var openai = try OpenAI.init(allocator, .{ .api_key = "test" });
    defer openai.deinit();

    var response = try openai.chat.completions.create(.{
        .model = "gpt-4o",
        .messages = &[_]ChatMessage{
            .{
                .role = "user",
                .content = "Hello, world!",
            },
        },
    });
    // This will free all the memory allocated for the response
    defer response.deinit();
    const completion = response.data;
    std.log.debug("{s}", .{completion.choices[0].message.content});
}
