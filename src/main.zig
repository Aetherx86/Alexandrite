const std = @import("std");
pub const dfa = @import("dfa.zig");
pub const lexer = @import("lexer.zig");
pub const wasm = @import("wasm.zig");

pub fn main(init: std.process.Init) !void {
    _ = init.arena.allocator();
    var args = init.minimal.args.iterate();
    _ = args.next(); // skip prog name

    const cmd = args.next() orelse {
        printUsage();
        return;
    };

    if (std.mem.eql(u8, cmd, "match")) {
        const pattern = args.next() orelse {
            std.debug.print("Error: missing pattern argument\n", .{});
            return;
        };
        const text = args.next() orelse {
            std.debug.print("Error: missing text argument\n", .{});
            return;
        };
        const d = dfa.Dfa.compileRuntime(pattern);
        if (d.matches(text)) {
            std.debug.print("MATCH: text matches pattern '{s}' (states: {d})\n", .{ pattern, d.num_states });
        } else {
            std.debug.print("NO MATCH: text does not match pattern '{s}' (states: {d})\n", .{ pattern, d.num_states });
        }
    } else if (std.mem.eql(u8, cmd, "find")) {
        const pattern = args.next() orelse return;
        const text = args.next() orelse return;
        const d = dfa.Dfa.compileRuntime(pattern);
        if (d.find(text)) |span| {
            std.debug.print("FOUND at [{d}..{d}]: '{s}'\n", .{ span.start, span.end, text[span.start..span.end] });
        } else {
            std.debug.print("NOT FOUND\n", .{});
        }
    } else if (std.mem.eql(u8, cmd, "dump")) {
        const pattern = args.next() orelse return;
        const d = dfa.Dfa.compileRuntime(pattern);
        std.debug.print("DFA for pattern: '{s}'\n", .{pattern});
        std.debug.print("Total States: {d}\n", .{d.num_states});
        std.debug.print("Accepting States: ", .{});
        for (0..d.num_states) |s| {
            if (d.accepting[s]) {
                std.debug.print("{d} ", .{s});
            }
        }
        std.debug.print("\n", .{});
    } else if (std.mem.eql(u8, cmd, "bench")) {
        std.debug.print("Benchmarking zero-allocation DFA scanner over 100,000 log records...\n", .{});
        const pattern = "\\d\\d\\d-\\d\\d-\\d\\d\\d\\d";
        const d = dfa.Dfa.compileRuntime(pattern);

        const sample = "2026-11-08 12:00:00 [AUDIT] user_id=9876 ssn=123-45-6789 event=login_success\n";
        const iterations = 100_000;
        var matches: usize = 0;

        const ts_start = std.Io.Clock.Timestamp.now(init.io, .awake);
        for (0..iterations) |_| {
            if (d.find(sample)) |_| {
                matches += 1;
            }
        }
        const ts_end = std.Io.Clock.Timestamp.now(init.io, .awake);
        const elapsed_ns = ts_start.durationTo(ts_end).raw.nanoseconds;

        const total_bytes = sample.len * iterations;
        const mb_per_sec = (@as(f64, @floatFromInt(total_bytes)) / (1024.0 * 1024.0)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);

        std.debug.print("Scanned {d} matches in {d:.2} ms ({d:.2} MB/s throughput)\n", .{
            matches,
            @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0,
            mb_per_sec,
        });
    } else {
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\Alexandrite: Compile-Time & Runtime DFA Regular Expression Engine
        \\
        \\Usage:
        \\  alexandrite match <pattern> <text>
        \\  alexandrite find <pattern> <text>
        \\  alexandrite dump <pattern>
        \\  alexandrite bench
        \\  alexandrite --help
        \\
    , .{});
}

test {
    _ = @import("dfa.zig");
    _ = @import("lexer.zig");
    _ = @import("wasm.zig");
}
