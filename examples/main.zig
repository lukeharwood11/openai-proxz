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

    // var response = try openai.models.retrieve("gpt-4o");
    var chat_response = try openai.chat.completions.create(.{
        .model = "gpt-4o",
        .messages = &[_]ChatMessage{
            .{
                .role = "user",
                .content = "Hello, world!",
            },
        },
    });
    // This will free all the memory allocated for the response
    defer chat_response.deinit();
    const completion = chat_response.data;
    std.log.debug("{s}\n", .{completion.choices[0].message.content});

    const inputs = [_][]const u8{ "Hello", "Foo", "Bar" };
    const embeddings_response = try openai.embeddings.create(.{
        .model = "text-embedding-3-small",
        .input = &inputs,
    });
    defer embeddings_response.deinit();
    const embeddings = embeddings_response.data;
    std.log.debug("Model: {s}\nNumber of Embeddings: {d}\nDimensions of Embeddings: {d}", .{
        embeddings.model,
        embeddings.data.len,
        embeddings.data[0].embedding.len,
    });
}
