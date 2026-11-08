const std = @import("std");
const dfa_mod = @import("dfa.zig");
const Dfa = dfa_mod.Dfa;

pub const TokenType = enum(u16) {
    identifier = 1,
    number = 2,
    string_literal = 3,
    operator = 4,
    whitespace = 5,
    comment = 6,
    keyword = 7,
    unknown = 8,
};

pub const Token = struct {
    token_type: TokenType,
    start: usize,
    end: usize,
    line: usize,
    column: usize,
};

pub const LexerRule = struct {
    token_type: TokenType,
    dfa: Dfa,
};

pub const Lexer = struct {
    rules: [8]?LexerRule,
    rule_count: usize,

    pub fn init() Lexer {
        return .{
            .rules = @splat(null),
            .rule_count = 0,
        };
    }

    pub fn addRule(self: *Lexer, token_type: TokenType, pattern: []const u8) void {
        if (self.rule_count >= 8) return;
        self.rules[self.rule_count] = LexerRule{
            .token_type = token_type,
            .dfa = Dfa.compileRuntime(pattern),
        };
        self.rule_count += 1;
    }

    pub fn tokenize(self: *const Lexer, input: []const u8, out_tokens: []Token) usize {
        var token_idx: usize = 0;
        var cursor: usize = 0;
        var line: usize = 1;
        var col: usize = 1;

        while (cursor < input.len and token_idx < out_tokens.len) {
            // Check whitespace first
            if (input[cursor] == ' ' or input[cursor] == '\t' or input[cursor] == '\r' or input[cursor] == '\n') {
                if (input[cursor] == '\n') {
                    line += 1;
                    col = 1;
                } else {
                    col += 1;
                }
                cursor += 1;
                continue;
            }

            var best_len: usize = 0;
            var best_type: TokenType = .unknown;

            for (0..self.rule_count) |r| {
                if (self.rules[r]) |rule| {
                    var state: u16 = dfa_mod.START_STATE;
                    var match_len: usize = 0;

                    for (input[cursor..], 0..) |b, offset| {
                        state = rule.dfa.table[state][b];
                        if (state == dfa_mod.DEAD_STATE) break;
                        if (rule.dfa.accepting[state]) {
                            match_len = offset + 1;
                        }
                    }

                    if (match_len > best_len) {
                        best_len = match_len;
                        best_type = rule.token_type;
                    }
                }
            }

            if (best_len > 0) {
                out_tokens[token_idx] = Token{
                    .token_type = best_type,
                    .start = cursor,
                    .end = cursor + best_len,
                    .line = line,
                    .column = col,
                };
                token_idx += 1;
                cursor += best_len;
                col += best_len;
            } else {
                // Unknown single byte fallback
                out_tokens[token_idx] = Token{
                    .token_type = .unknown,
                    .start = cursor,
                    .end = cursor + 1,
                    .line = line,
                    .column = col,
                };
                token_idx += 1;
                cursor += 1;
                col += 1;
            }
        }

        return token_idx;
    }
};

test "Lexer Tokenization" {
    var lexer = Lexer.init();
    lexer.addRule(.number, "\\d+");
    lexer.addRule(.identifier, "[a-z]+");
    lexer.addRule(.operator, "+|-|*|/");

    const source = "val 42 + count 99";
    var tokens: [16]Token = undefined;
    const count = lexer.tokenize(source, &tokens);

    try std.testing.expect(count >= 5);
    try std.testing.expectEqual(TokenType.identifier, tokens[0].token_type);
    try std.testing.expectEqualStrings("val", source[tokens[0].start..tokens[0].end]);

    try std.testing.expectEqual(TokenType.number, tokens[1].token_type);
    try std.testing.expectEqualStrings("42", source[tokens[1].start..tokens[1].end]);

    try std.testing.expectEqual(TokenType.operator, tokens[2].token_type);
    try std.testing.expectEqualStrings("+", source[tokens[2].start..tokens[2].end]);
}
