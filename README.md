![Static Badge](https://img.shields.io/badge/zig-0.13.0-%23F7A41D?logo=zig&logoColor=%23F7A41D)
![Static Badge](https://img.shields.io/badge/License-MIT-blue)

# ProxZ 🦎

An OpenAI API library for the Zig programming language!

|✨ Documentation ✨||
|--|--|
|📙 ProxZ Docs |<https://proxz.mle.academy> |
|📗 OpenAI API Docs|<https://platform.openai.com/docs/api-reference>|

## Features

- An easy to use interface, similar to that of `openai-python`
- Built-in retry logic
- Environment variable config support for API keys, org. IDs, project IDs, and base urls
- Integration with the most popular OpenAI endpoints with a generic `request` method for missing endpoints

## Installation

> [!NOTE]  
> This is only compatible with zig version 0.13.0 at this time.

To install `proxz`, run

```bash
 zig fetch --save "git+https://github.com/lukeharwood11/openai-proxz"
```

And add the following to your `build.zig`

```zig
const proxz = b.dependency("proxz", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("proxz", proxz.module("proxz"));
```

## Usage

### Client Configuration

```zig
const proxz = @import("proxz");
const OpenAI = proxz.OpenAI;
```

```zig
// make sure you have an OPENAI_API_KEY environment variable set,
// or pass in a .api_key field to explicitly set!
var openai = try OpenAI.init(allocator, .{});
defer openai.deinit();
```

### Chat Completions

```zig
const ChatMessage = proxz.ChatMessage;

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
const completions = response.data;
std.log.debug("{s}", .{completions.choices[0].message.content});
```

### Embeddings

```zig
const inputs = [_][]const u8{ "Hello", "Foo", "Bar" };
const embeddings_response = try openai.embeddings.create(.{
    .model = "text-embedding-3-small",
    .input = &inputs,
});
// Don't forget to free resources!
defer embeddings_response.deinit();
const embeddings = embeddings_response.data;
std.log.debug("Model: {s}\nNumber of Embeddings: {d}\nDimensions of Embeddings: {d}", .{
    embeddings.model,
    embeddings.data.len,
    embeddings.data[0].embedding.len,
});
```

## Contributions

Contributions are welcome and encouraged! Submit an issue for any bugs/feature requests and open a PR if you tackled one of them!

## Building Docs

```bash
zig build-lib -femit-docs proxz/proxz.zig
```
