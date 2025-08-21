# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Repo Update** (2025-08-21 – jarroddavis68)
  - Forgot to add math.e

- **Repo Update** (2025-08-21 – jarroddavis68)
  Complete E-Lang to CP-Lang refactor and compiler implementation
  - Rebranded entire project from E-Lang to CP-Lang
  - Changed all unit names from ELang to CPLang prefix
  - Updated copyright to tinyBigGAMES LLC 2025-present
  - New project identity C Power Pascal Clarity
  - Website changed to https://cp-lang.org/
  - Implemented complete lexical analyzer in CPLang.Lexer.pas
  - Added comprehensive parser in CPLang.Parser.pas
  - Built full semantic analysis system in CPLang.Semantic.pas
  - Created complete type system in CPLang.Types.pas
  - Added LLVM integration and code generation
  - Implemented include system with preprocessor directives
  - Built comprehensive error handling and reporting
  - Added symbol table management
  - Created platform abstraction layer
  - Implemented compiler orchestration with progress reporting
  - Language supports C99 syntax with Pascal keywords
  - Mandatory main function requirement
  - Variable declarations with initialization
  - Functions and procedures with external linking
  - Record types and arrays
  - Full control flow statements
  - Expression evaluation with operator precedence
  - Preprocessor directives support
  - 18 Pascal units plus 1 include file
  - Targets 64-bit platforms Windows Linux macOS
  - Requires Delphi 12 or higher
  - Professional compiler architecture with multi-phase compilation

- **Repo Update** (2025-08-20 – jarroddavis68)
  E-Lang is the experimental baby cousin to CPascal - a testing ground for features,
  ideas, and concepts before they mature into the main language.
  What's Implemented:
  - Complete 5-phase compilation pipeline (Include -> Lexical -> Syntax -> Semantic -> CodeGen)
  - Full LLVM IR code generation with TELCodeGen, TELTypeMapper, TELValueContext
  - All language constructs: variables, functions, control flow, expressions, types
  - External library binding support (DLL integration)
  - Cross-platform LLVM backend with target configuration
  - Advanced error reporting with source position mapping
  - Progress monitoring and real-time compilation feedback
  Architecture:
  - 18+ core compiler units with clean separation of concerns
  - Comprehensive type system with pointer, array, record, function types
  - Scoped symbol resolution and nested context management
  - String constant pooling and memory optimization
  - 100+ LLVM operations exposed through IRContext wrapper

- **Create FUNDING.yml** (2025-08-17 – Jarrod Davis)


### Changed
- **Update LICENSE** (2025-08-17 – Jarrod Davis)

- **Initial commit** (2025-08-17 – Jarrod Davis)

