const std = @import("std");
const dfa_mod = @import("dfa.zig");
const Dfa = dfa_mod.Dfa;

var global_dfa: Dfa = undefined;
var is_initialized: bool = false;
var memory_buffer: [65536]u8 = @splat(0);

export fn alexandrite_get_buffer() [*]u8 {
    return &memory_buffer;
}

export fn alexandrite_compile(len: usize) u32 {
    if (len > memory_buffer.len) return 0;
    const pattern = memory_buffer[0..len];
    global_dfa = Dfa.compileRuntime(pattern);
    is_initialized = true;
    return global_dfa.num_states;
}

export fn alexandrite_matches(len: usize) u32 {
    if (!is_initialized or len > memory_buffer.len) return 0;
    const input = memory_buffer[0..len];
    return if (global_dfa.matches(input)) 1 else 0;
}

export fn alexandrite_find_start(len: usize) i32 {
    if (!is_initialized or len > memory_buffer.len) return -1;
    const input = memory_buffer[0..len];
    if (global_dfa.find(input)) |span| {
        return @intCast(span.start);
    }
    return -1;
}

export fn alexandrite_find_end(len: usize) i32 {
    if (!is_initialized or len > memory_buffer.len) return -1;
    const input = memory_buffer[0..len];
    if (global_dfa.find(input)) |span| {
        return @intCast(span.end);
    }
    return -1;
}

export fn alexandrite_get_states() u32 {
    if (!is_initialized) return 0;
    return global_dfa.num_states;
}

export fn alexandrite_is_accepting(state: u32) u32 {
    if (!is_initialized or state >= dfa_mod.MAX_STATES) return 0;
    return if (global_dfa.accepting[state]) 1 else 0;
}

export fn alexandrite_get_transition(state: u32, byte_val: u32) u32 {
    if (!is_initialized or state >= dfa_mod.MAX_STATES or byte_val >= 256) return dfa_mod.DEAD_STATE;
    return global_dfa.table[state][byte_val];
}
