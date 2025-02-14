const std = @import("std");
const zai = @import("zai");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    var openai = zai.OpenAI.init(allocator, .{
        .api_key = "sk-proj-1234567890",
    });
    defer openai.deinit();

    // std.log.debug("{any}", .{openai.chat.client});
    openai.chat.create(.{
        .model = "gpt-4o",
        .messages = &.{
            .{
                .role = "user",
                .content = "Hello, world!",
            },
        },
    });
}
