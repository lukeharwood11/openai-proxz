const std = @import("std");
const proxz = @import("proxz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    var openai = try proxz.OpenAI.init(allocator, .{
        .api_key = "sk-proj-1234567890",
    });
    defer openai.deinit();

    // std.log.debug("{any}", .{openai.chat.client});
    const response = try openai.chat.completions.create(.{
        .model = "gpt-4o",
        .messages = &.{
            .{
                .role = "user",
                .content = "Hello, world!",
            },
        },
    });
    std.log.debug("I got a response: {s}", .{response});
}
