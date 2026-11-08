# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-08

### Added
- Initial release of Alexandrite: Compile-Time & Runtime DFA Regular Expression and Lexer Engine in Zig.
- Compile-time minimal DFA transition matrix construction embedding tables into .rodata.
- Runtime DFA construction for dynamic patterns without heap allocations during matching.
- Lexer engine supporting token rule registration and stream tokenization.
- Freestanding WebAssembly compilation target (wasm32-freestanding) with direct buffer exports.
- Benchmark and validation test suite with sub-100 MB/s scanning throughput.
