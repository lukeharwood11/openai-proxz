const std = @import("std");
const proxz = @import("proxz");

const ChatMessage = proxz.ChatMessage;
const OpenAI = proxz.OpenAI;

pub const std_options = std.Options{
    .log_level = .debug, // this sets your app level log config
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{
            .scope = .proxz,
            .level = .info, // set to .debug, .warn, .info, or .err
        },
    },
};

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

    var stream = try openai.chat.completions.createStream(.{
        .model = "gpt-4o-mini",
        .messages = &[_]ChatMessage{
            .{
                .role = "user",
                .content = "Write me a poem about lizards. Make it a paragraph or two.",
            },
        },
    });
    defer stream.deinit();
    std.debug.print("\n", .{});
    while (try stream.next()) |val| {
        std.debug.print("{s}", .{val.choices[0].delta.content});
    }
    std.debug.print("\n", .{});

    var models_response = try openai.models.retrieve("gpt-4o");
    defer models_response.deinit();

    std.log.debug("Model is owned by '{s}'", .{models_response.owned_by});

    var models_list = try openai.models.list();
    defer models_list.deinit();

    std.log.debug("The first model you have available is '{s}'", .{models_list.data[0].id});

    var chat_response = try openai.chat.completions.create(.{
        .model = "gpt-4o-mini",
        .messages = &[_]ChatMessage{
            .{
                .role = "user",
                .content = "Hello, world!",
            },
        },
    });
    // This will free all the memory allocated for the response
    defer chat_response.deinit();
    std.log.debug("{s}", .{chat_response.choices[0].message.content});

    const inputs = [_][]const u8{ "Hello", "Foo", "Bar" };
    const embeddings_response = try openai.embeddings.create(.{
        .model = "text-embedding-3-small",
        .input = &inputs,
    });
    defer embeddings_response.deinit();
    std.log.debug("Model: {s}\nNumber of Embeddings: {d}\nDimensions of Embeddings: {d}", .{
        embeddings_response.model,
        embeddings_response.data.len,
        embeddings_response.data[0].embedding.len,
    });
}
