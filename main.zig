const std = @import("std");

// zson — dead-simple JSON pretty/minify with ANSI colors.
// - input: file / stdin / --eval "<json>"
// - indent: --indent 2|4, minify: --compact
// - color: auto (TTY), force with --color / --no-color
// - trailing commas: --allow-trailing-commas (preprocess, never touches strings)
// Zig 0.13 compatible.

// ===== Trailing comma stripper (only outside of strings) =====
fn stripTrailingCommas(alloc: std.mem.Allocator, src: []const u8) ![]u8 {
    // Output buffer
    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();

    // State trackers
    var i: usize = 0;
    var in_string = false;
    var escape = false;

    // Scan byte by byte
    while (i < src.len) : (i += 1) {
        const c = src[i];

        // Inside a JSON string: copy bytes verbatim, track escapes and closing quote
        if (in_string) {
            try out.append(c);
            if (escape) {
                escape = false;
            } else if (c == '\\') {
                escape = true;
            } else if (c == '"') {
                in_string = false;
            }
            continue;
        }

        // String begins
        if (c == '"') {
            in_string = true;
            try out.append(c);
            continue;
        }

        // Potential trailing comma: skip if followed by only whitespace then '}' or ']'
        if (c == ',') {
            var j = i + 1;
            while (j < src.len) : (j += 1) {
                const d = src[j];
                if (d == ' ' or d == '\t' or d == '\n' or d == '\r') continue;
                if (d == '}' or d == ']') {
                    // drop this comma
                    break;
                } else {
                    // normal comma; keep it
                    try out.append(c);
                    break;
                }
            }
            // Comma at EOF: keep it to let parser error naturally
            if (j >= src.len) try out.append(c);
            continue;
        }

        // Default: copy
        try out.append(c);
    }

    return out.toOwnedSlice();
}

// ===== ANSI color palette =====
const C = struct {
    pub const reset = "\x1b[0m";
    pub const gray  = "\x1b[90m";
    pub const green = "\x1b[32m";
    pub const yellow= "\x1b[33m";
    pub const blue  = "\x1b[34m";
    pub const red   = "\x1b[31m";
};

fn isSpace(b: u8) bool {
    return b == ' ' or b == '\t' or b == '\n' or b == '\r';
}

fn writeSlice(dst: *std.ArrayList(u8), s: []const u8) !void {
    try dst.appendSlice(s);
}

// Parse a JSON string token starting at the opening quote.
// Returns the index of the closing quote and whether the token is a "key" (immediately followed by ':').
fn parseStringToken(bytes: []const u8, start: usize) struct { end: usize, is_key: bool } {
    var i = start + 1; // skip the first quote
    var escape = false;
    while (i < bytes.len) : (i += 1) {
        const c = bytes[i];
        if (escape) { escape = false; continue; }
        if (c == '\\') { escape = true; continue; }
        if (c == '"') break;
    }
    // Look ahead for ':' (ignoring spaces) to decide if this string is a key
    var j = i + 1;
    while (j < bytes.len and isSpace(bytes[j])) : (j += 1) {}
    const is_key = (j < bytes.len and bytes[j] == ':');
    return .{ .end = i, .is_key = is_key };
}

// Colorize a plain JSON string (already pretty/minified as desired).
// If use_color == false, returns a dup of the input unchanged.
fn colorizeJson(alloc: std.mem.Allocator, plain: []const u8, use_color: bool) ![]u8 {
    if (!use_color) return try alloc.dupe(u8, plain);

    var out = std.ArrayList(u8).init(alloc);
    errdefer out.deinit();

    var i: usize = 0;
    while (i < plain.len) {
        const c = plain[i];

        // JSON strings (keys vs values)
        if (c == '"') {
            const tok = parseStringToken(plain, i);
            const endq = if (tok.end < plain.len) tok.end else plain.len - 1;
            const color = if (tok.is_key) C.yellow else C.green;
            try writeSlice(&out, color);
            try out.appendSlice(plain[i .. endq + 1]); // include closing quote
            try writeSlice(&out, C.reset);
            i = endq + 1;
            continue;
        }

        // JSON numbers (int/float/exponent)
        if (c == '-' or (c >= '0' and c <= '9')) {
            var j = i;
            if (plain[j] == '-') j += 1;
            while (j < plain.len and (plain[j] >= '0' and plain[j] <= '9')) : (j += 1) {}
            if (j < plain.len and plain[j] == '.') {
                j += 1;
                while (j < plain.len and (plain[j] >= '0' and plain[j] <= '9')) : (j += 1) {}
            }
            if (j < plain.len and (plain[j] == 'e' or plain[j] == 'E')) {
                j += 1;
                if (j < plain.len and (plain[j] == '+' or plain[j] == '-')) j += 1;
                while (j < plain.len and (plain[j] >= '0' and plain[j] <= '9')) : (j += 1) {}
            }
            try writeSlice(&out, C.blue);
            try out.appendSlice(plain[i..j]);
            try writeSlice(&out, C.reset);
            i = j;
            continue;
        }

        // true / false / null (quick literal check)
        if (c == 't' or c == 'f' or c == 'n') {
            const rem = plain[i .. @min(i + 5, plain.len)];
            if (std.mem.startsWith(u8, rem, "true")) {
                try writeSlice(&out, C.red); try out.appendSlice("true"); try writeSlice(&out, C.reset);
                i += 4; continue;
            } else if (std.mem.startsWith(u8, rem, "false")) {
                try writeSlice(&out, C.red); try out.appendSlice("false"); try writeSlice(&out, C.reset);
                i += 5; continue;
            } else if (std.mem.startsWith(u8, rem, "null")) {
                try writeSlice(&out, C.red); try out.appendSlice("null"); try writeSlice(&out, C.reset);
                i += 4; continue;
            }
        }

        // Punctuation / braces
        if (c == '{' or c == '}' or c == '[' or c == ']' or c == ':' or c == ',') {
            try writeSlice(&out, C.gray);
            try out.append(c);
            try writeSlice(&out, C.reset);
            i += 1;
            continue;
        }

        // Whitespace / others
        try out.append(c);
        i += 1;
    }

    return out.toOwnedSlice();
}

pub fn main() !void {
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Args
    const argv = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, argv);

    // CLI options
    var path: ?[]const u8 = null;
    var eval_json: ?[]const u8 = null;
    var indent: u8 = 2;
    var compact = false;
    var allow_trailing = false;
    var force_color: ?bool = null;

    // Parse CLI
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            return printUsage();
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--indent")) {
            if (i + 1 >= argv.len) return printUsage();
            i += 1;
            const n = try std.fmt.parseInt(u8, argv[i], 10);
            indent = if (n >= 4) 4 else 2;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--compact")) {
            compact = true;
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--allow-trailing-commas")) {
            allow_trailing = true;
        } else if (std.mem.eql(u8, arg, "-e") or std.mem.eql(u8, arg, "--eval")) {
            if (i + 1 >= argv.len) return printUsage();
            i += 1;
            eval_json = argv[i];
        } else if (std.mem.eql(u8, arg, "--color")) {
            force_color = true;
        } else if (std.mem.eql(u8, arg, "--no-color")) {
            force_color = false;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return printUsage();
        } else {
            path = arg;
        }
    }

    // Disallow both file and --eval simultaneously
    if (path != null and eval_json != null) {
        std.debug.print("error: use either a file path or --eval, not both\n", .{});
        return error.InvalidArgument;
    }

    // Read input bytes
    const max = 128 * 1024 * 1024;
    const raw_input: []u8 = blk: {
        if (eval_json) |s| {
            break :blk try alloc.dupe(u8, s);
        } else if (path) |p| {
            break :blk try std.fs.cwd().readFileAlloc(alloc, p, max);
        } else {
            var stdin = std.io.getStdIn();
            break :blk try stdin.readToEndAlloc(alloc, max);
        }
    };
    defer alloc.free(raw_input);

    // Optional trailing comma cleanup
    const input: []u8 = if (allow_trailing)
        try stripTrailingCommas(alloc, raw_input)
    else
        try alloc.dupe(u8, raw_input);
    defer alloc.free(input);

    // Parse JSON into a dynamic Value
    var parsed = try std.json.parseFromSlice(std.json.Value, alloc, input, .{
        .ignore_unknown_fields = false,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    // Stringify with chosen whitespace (pretty/minified)
    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();

    const ws: std.json.StringifyOptions = if (compact)
        .{ .whitespace = .minified }
    else if (indent == 4)
        .{ .whitespace = .indent_4 }
    else
        .{ .whitespace = .indent_2 };

    try std.json.stringify(parsed.value, ws, buf.writer());

    // Color decision: auto if TTY, override via flags
    const stdout_file = std.io.getStdOut();
    const use_color = (force_color orelse stdout_file.isTty());

    // Apply colors (or pass-through)
    const colored = try colorizeJson(alloc, buf.items, use_color);
    defer alloc.free(colored);

    // Emit
    const stdout = stdout_file.writer();
    try stdout.writeAll(colored);
    try stdout.writeByte('\n');
}

// Print help text (use writeAll to avoid {} formatting issues)
fn printUsage() !void {
    const w = std.io.getStdErr().writer();
    try w.writeAll(
        \\Usage: zson [options] [file]
        \\
        \\  Reads JSON from a file or stdin and pretty-prints to stdout.
        \\
        \\Options:
        \\  -i, --indent <2|4>      Indentation size (default: 2)
        \\  -c, --compact           Minify output (ignore indent)
        \\  -t, --allow-trailing-commas
        \\                          Strip trailing commas before parsing
        \\  -e, --eval <json>       Read JSON directly from the argument
        \\      --color             Force ANSI colors (default: auto if TTY)
        \\      --no-color          Disable ANSI colors
        \\  -h, --help              Show this help
        \\
        \\Examples:
        \\  cat data.json | zson
        \\  zson -i 4 data.json
        \\  zson --compact data.json
        \\  zson -t broken.json
        \\  zson --color ok.json
        \\  zson -e '{"a":1,"b":[2,3]}'
        \\
    );
}
