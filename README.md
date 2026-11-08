# Alexandrite

Alexandrite is a compile-time and runtime Deterministic Finite Automaton (DFA) regular expression compiler and lexical analyzer engine written in pure Zig.

## Overview

Unlike backtracking regular expression engines that suffer from exponential worst-case time complexity (Regular Expression Denial of Service / ReDoS), Alexandrite compiles regular expression patterns into minimal DFA transition tables. Runtime matching executes in strict O(n) time with zero dynamic memory allocation.

When evaluated at compile time via Zig `comptime`, the entire transition matrix is embedded directly into the binary's read-only data section (`.rodata`).

## Architecture

- **Comptime Lowering**: Ingests pattern specifications, computes transitions, and lowers the state graph into a static `[MAX_STATES][256]u16` matrix.
- **Zero Heap Matching**: Runtime search requires no stack recursion, no dynamic buffers, and no backtracking. State progression is a single array index lookup (`state = table[state][byte]`).
- **Freestanding WebAssembly**: Compiles out-of-the-box to `wasm32-freestanding` (< 70 KB) with exported memory buffers for interactive browser execution.
- **Lexer Pipeline**: Built-in multi-rule tokenization engine supporting line and column position tracking.

## Building

```bash
# Run unit test suite
zig build test

# Build native CLI executable and freestanding WASM binary
zig build -Doptimize=ReleaseFast
```

Artifacts are placed in `zig-out/bin/`:
- `alexandrite`: Native command-line utility.
- `alexandrite.wasm`: Freestanding WebAssembly module.

## Usage

### Native CLI

```bash
# Test full string match
./zig-out/bin/alexandrite match "\\d\\d\\d-\\d\\d-\\d\\d\\d\\d" "123-45-6789"

# Find first matching span in text
./zig-out/bin/alexandrite find "\\d\\d\\d-\\d\\d-\\d\\d\\d\\d" "audit record ssn=987-65-4321 logged"

# Dump compiled DFA state transitions
./zig-out/bin/alexandrite dump "GET|POST|DELETE"

# Run internal scanner benchmark
./zig-out/bin/alexandrite bench
```

### Zig Library Integration

```zig
const std = @import("std");
const dfa_mod = @import("alexandrite").dfa;

// Compiled at compile time directly into read-only data section
const ssn_scanner = comptime dfa_mod.Dfa.compile("\\d\\d\\d-\\d\\d-\\d\\d\\d\\d");

pub fn scanAuditLog(line: []const u8) bool {
    return ssn_scanner.find(line) != null;
}
```

## Security & Verification

- Fully verified with `repo_guard.py` for supply-chain and memory safety.
- Complete bounded execution guarantees: zero catastrophic backtracking possible by construction.

## License

MIT License. Copyright (c) 2026 Jeong Hoon Kim.
