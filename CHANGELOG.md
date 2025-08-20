# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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

