const std = @import("std");

pub const MAX_STATES: usize = 128;
pub const DEAD_STATE: u16 = 0;
pub const START_STATE: u16 = 1;

pub const Span = struct {
    start: usize,
    end: usize,
};

pub const Dfa = struct {
    num_states: u16,
    table: [MAX_STATES][256]u16,
    accepting: [MAX_STATES]bool,

    pub fn init() Dfa {
        var dfa = Dfa{
            .num_states = 2, // 0 = dead, 1 = start
            .table = undefined,
            .accepting = undefined,
        };
        for (0..MAX_STATES) |s| {
            dfa.accepting[s] = false;
            for (0..256) |b| {
                dfa.table[s][b] = DEAD_STATE;
            }
        }
        return dfa;
    }

    pub fn matches(self: *const Dfa, input: []const u8) bool {
        var state: u16 = START_STATE;
        for (input) |b| {
            state = self.table[state][b];
            if (state == DEAD_STATE) return false;
        }
        return self.accepting[state];
    }

    pub fn find(self: *const Dfa, input: []const u8) ?Span {
        var start_idx: usize = 0;
        while (start_idx < input.len) : (start_idx += 1) {
            var state: u16 = START_STATE;
            var last_accept_end: ?usize = null;

            for (input[start_idx..], 0..) |b, offset| {
                state = self.table[state][b];
                if (state == DEAD_STATE) break;
                if (self.accepting[state]) {
                    last_accept_end = start_idx + offset + 1;
                }
            }

            if (last_accept_end) |end_idx| {
                return Span{ .start = start_idx, .end = end_idx };
            }
        }
        return null;
    }

    pub fn scanCount(self: *const Dfa, input: []const u8) usize {
        var count: usize = 0;
        var idx: usize = 0;
        while (idx < input.len) {
            var state: u16 = START_STATE;
            var match_end: ?usize = null;

            for (input[idx..], 0..) |b, offset| {
                state = self.table[state][b];
                if (state == DEAD_STATE) break;
                if (self.accepting[state]) {
                    match_end = idx + offset + 1;
                }
            }

            if (match_end) |end_pos| {
                count += 1;
                idx = end_pos;
            } else {
                idx += 1;
            }
        }
        return count;
    }

    pub fn compileRuntime(pattern: []const u8) Dfa {
        var dfa = Dfa.init();
        var is_alternation = false;
        for (pattern) |c| {
            if (c == '|') {
                is_alternation = true;
                break;
            }
        }
        if (is_alternation) {
            compileAlternation(&dfa, pattern);
        } else {
            compileSequence(&dfa, pattern);
        }
        return dfa;
    }

    pub fn compile(comptime pattern: []const u8) Dfa {
        @setEvalBranchQuota(500_000);
        return compileRuntime(pattern);
    }

    fn compileSequence(dfa: *Dfa, pattern: []const u8) void {
        var current_state: u16 = START_STATE;
        var p_idx: usize = 0;

        while (p_idx < pattern.len) {
            const next_state = dfa.num_states;
            dfa.num_states += 1;

            const c = pattern[p_idx];
            if (c == '\\' and p_idx + 1 < pattern.len) {
                p_idx += 1;
                const esc = pattern[p_idx];
                p_idx += 1;

                const has_plus = (p_idx < pattern.len and pattern[p_idx] == '+');
                const has_star = (p_idx < pattern.len and pattern[p_idx] == '*');
                if (has_plus or has_star) p_idx += 1;

                if (esc == 'd') {
                    // Digits '0'..'9'
                    for ('0'..'9' + 1) |b| {
                        dfa.table[current_state][b] = next_state;
                    }
                } else if (esc == 'w') {
                    // Word chars: [a-zA-Z0-9_]
                    for ('a'..'z' + 1) |b| dfa.table[current_state][b] = next_state;
                    for ('A'..'Z' + 1) |b| dfa.table[current_state][b] = next_state;
                    for ('0'..'9' + 1) |b| dfa.table[current_state][b] = next_state;
                    dfa.table[current_state]['_'] = next_state;
                } else if (esc == 's') {
                    // Whitespace: ' ', '\t', '\r', '\n'
                    dfa.table[current_state][' '] = next_state;
                    dfa.table[current_state]['\t'] = next_state;
                    dfa.table[current_state]['\r'] = next_state;
                    dfa.table[current_state]['\n'] = next_state;
                } else {
                    dfa.table[current_state][esc] = next_state;
                }

                if (has_plus) {
                    // Self-loop on next_state
                    if (esc == 'd') {
                        for ('0'..'9' + 1) |b| dfa.table[next_state][b] = next_state;
                    } else if (esc == 'w') {
                        for ('a'..'z' + 1) |b| dfa.table[next_state][b] = next_state;
                        for ('A'..'Z' + 1) |b| dfa.table[next_state][b] = next_state;
                        for ('0'..'9' + 1) |b| dfa.table[next_state][b] = next_state;
                        dfa.table[next_state]['_'] = next_state;
                    } else if (esc == 's') {
                        dfa.table[next_state][' '] = next_state;
                        dfa.table[next_state]['\t'] = next_state;
                        dfa.table[next_state]['\r'] = next_state;
                        dfa.table[next_state]['\n'] = next_state;
                    } else {
                        dfa.table[next_state][esc] = next_state;
                    }
                }
            } else if (c == '.') {
                p_idx += 1;
                const has_plus = (p_idx < pattern.len and pattern[p_idx] == '+');
                const has_star = (p_idx < pattern.len and pattern[p_idx] == '*');
                if (has_plus or has_star) p_idx += 1;

                for (0..256) |b| {
                    if (b != '\n') {
                        dfa.table[current_state][b] = next_state;
                        if (has_plus) {
                            dfa.table[next_state][b] = next_state;
                        }
                    }
                }
            } else if (c == '[') {
                p_idx += 1;
                // Parse character class
                var class_bytes: [256]bool = @splat(false);
                while (p_idx < pattern.len and pattern[p_idx] != ']') {
                    if (p_idx + 2 < pattern.len and pattern[p_idx + 1] == '-') {
                        const start_c = pattern[p_idx];
                        const end_c = pattern[p_idx + 2];
                        p_idx += 3;
                        for (start_c..end_c + 1) |b| {
                            class_bytes[b] = true;
                        }
                    } else {
                        class_bytes[pattern[p_idx]] = true;
                        p_idx += 1;
                    }
                }
                if (p_idx < pattern.len and pattern[p_idx] == ']') p_idx += 1;

                const has_plus = (p_idx < pattern.len and pattern[p_idx] == '+');
                const has_star = (p_idx < pattern.len and pattern[p_idx] == '*');
                if (has_plus or has_star) p_idx += 1;

                for (0..256) |b| {
                    if (class_bytes[b]) {
                        dfa.table[current_state][b] = next_state;
                        if (has_plus) {
                            dfa.table[next_state][b] = next_state;
                        }
                    }
                }
            } else {
                p_idx += 1;
                const has_plus = (p_idx < pattern.len and pattern[p_idx] == '+');
                const has_star = (p_idx < pattern.len and pattern[p_idx] == '*');
                if (has_plus or has_star) p_idx += 1;

                dfa.table[current_state][c] = next_state;
                if (has_plus) {
                    dfa.table[next_state][c] = next_state;
                }
            }

            current_state = next_state;
        }

        dfa.accepting[current_state] = true;
    }

    fn compileAlternation(dfa: *Dfa, pattern: []const u8) void {
        var start_idx: usize = 0;
        var p_idx: usize = 0;

        while (p_idx <= pattern.len) {
            if (p_idx == pattern.len or pattern[p_idx] == '|') {
                const sub_pattern = pattern[start_idx..p_idx];
                if (sub_pattern.len > 0) {
                    var branch_state = START_STATE;
                    for (sub_pattern, 0..) |c, i| {
                        const is_last = (i == sub_pattern.len - 1);
                        var target_state = dfa.table[branch_state][c];
                        if (target_state == DEAD_STATE) {
                            target_state = dfa.num_states;
                            dfa.num_states += 1;
                            dfa.table[branch_state][c] = target_state;
                        }
                        if (is_last) {
                            dfa.accepting[target_state] = true;
                        }
                        branch_state = target_state;
                    }
                }
                start_idx = p_idx + 1;
            }
            p_idx += 1;
        }
    }
};

test "Comptime DFA Literal Matching" {
    const dfa = comptime Dfa.compile("admin");
    try std.testing.expect(dfa.matches("admin"));
    try std.testing.expect(!dfa.matches("root"));
    try std.testing.expect(!dfa.matches("admi"));
}

test "Comptime DFA Alternation" {
    const dfa = comptime Dfa.compile("GET|POST|DELETE|PATCH");
    try std.testing.expect(dfa.matches("GET"));
    try std.testing.expect(dfa.matches("POST"));
    try std.testing.expect(dfa.matches("DELETE"));
    try std.testing.expect(dfa.matches("PATCH"));
    try std.testing.expect(!dfa.matches("PUT"));
}

test "Comptime DFA SSN PII Scanner" {
    const ssn_dfa = comptime Dfa.compile("\\d\\d\\d-\\d\\d-\\d\\d\\d\\d");
    try std.testing.expect(ssn_dfa.matches("123-45-6789"));
    try std.testing.expect(!ssn_dfa.matches("123-45-678a"));

    const log_sample = "User login audit: SSN 987-65-4321 logged from 10.0.0.1";
    const span = ssn_dfa.find(log_sample);
    try std.testing.expect(span != null);
    try std.testing.expectEqualStrings("987-65-4321", log_sample[span.?.start..span.?.end]);
}

test "Comptime DFA Repetition Plus" {
    const dfa = comptime Dfa.compile("a+b");
    try std.testing.expect(dfa.matches("ab"));
    try std.testing.expect(dfa.matches("aaaab"));
    try std.testing.expect(!dfa.matches("b"));
}

