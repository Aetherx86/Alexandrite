# Alexandrite

컴파일 타임 DFA 정규식 컴파일러 및 어휘 분석기 (Comptime DFA Regex Compiler & Lexer)

순수 Zig로 작성된 컴파일 타임 및 런타임 결정론적 유한 오토마톤(Deterministic Finite Automaton, DFA) 정규 표현식 컴파일러이자 어휘 분석기(Lexer) 엔진입니다.

[English Documentation](README.md)

## 개요

지수 함수적 최악 시간 복잡도(정규식 서비스 거부 공격 / ReDoS)를 유발하는 기존 백트래킹 정규식 엔진과 달리, Alexandrite는 정규식 패턴을 최소화된 DFA 상태 전이 테이블로 컴파일합니다. 런타임 매칭은 동적 메모리 할당 없이 엄격한 O(n) 시간에 수행됩니다.

Zig의 `comptime`을 통해 컴파일 타임에 평가될 경우, 전체 상태 전이 행렬이 바이너리의 읽기 전용 데이터 섹션(`.rodata`)에 직접 임베딩됩니다.

## 아키텍처

- **컴파일 타임 로우어링 (Comptime Lowering)**: 패턴 정의를 해석하고 상태 전이를 계산하여 정적 `[MAX_STATES][256]u16` 행렬로 상태 그래프를 로우어링합니다.
- **제로 힙 매칭 (Zero Heap Matching)**: 런타임 검색 시 스택 재귀, 동적 버퍼, 백트래킹이 전혀 발생하지 않습니다. 상태 전이는 단순 단일 배열 인덱스 조회(`state = table[state][byte]`)로 완결됩니다.
- **자립형 WebAssembly**: 브라우저 인터랙티브 실행을 위한 메모리 버퍼 인터페이스와 함께 `wasm32-freestanding` (< 70 KB)으로 즉시 컴파일됩니다.
- **어휘 분석 파이프라인 (Lexer Pipeline)**: 라인 및 컬럼 위치 추적을 기본 지원하는 멀티 룰 토큰화 엔진을 내장하고 있습니다.

## 빌드 및 테스트

```bash
# 단위 테스트 스위트 실행
zig build test

# 네이티브 CLI 실행 파일 및 독립형 WASM 바이너리 빌드
zig build -Doptimize=ReleaseFast
```

## 코드 예제

```zig
const dfa_mod = @import("alexandrite");
const ssn_scanner = comptime dfa_mod.Dfa.compile("\\d\\d\\d-\\d\\d-\\d\\d\\d\\d");

pub fn scanAuditLog(line: []const u8) bool {
    return ssn_scanner.find(line) != null;
}
```

## 보안 및 검증

- 공급망 및 메모리 안전성을 보장하기 위해 `repo_guard.py` 검증을 완벽하게 통과했습니다.
- 유계 실행(bounded execution) 보장: 구조적으로 파국적 백트래킹이 원천 불가능합니다.

## 라이선스

MIT License. Copyright (c) 2026 Jeong Hoon Kim.
