{===============================================================================
   ___    _
  | __|__| |   __ _ _ _  __ _ ™
  | _|___| |__/ _` | ' \/ _` |
  |___|  |____\__,_|_||_\__, |
                        |___/
    C Power | Pascal Clarity

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/e-lang

 See LICENSE file for license agreement
===============================================================================}

unit ELang.Resources;

{$I ELang.Defines.inc}

interface

resourcestring
  // Exception Display Messages
  RSCompilationError = '❌ COMPILATION ERROR:';
  RSErrorDetails = '📍 ERROR DETAILS:';
  RSSymbolTableAnalysis = '🔍 SYMBOL TABLE ANALYSIS:';
  RSSuggestions = '💡 SUGGESTIONS:';
  RSErrorObjectNil = '   (Error object is nil)';
  RSCategoryEmpty = '   Category: (empty)';
  RSErrorCode = '   Code: %d';
  RSLocation = '   Location: %s';
  RSRelatedSymbol = '   Related Symbol: %s';
  RSTypeMismatch = '   Type Mismatch: Expected "%s", got "%s"';
  RSNoContextInfo = '   (No context info)';
  RSNoSuggestionsAvailable = '   (No suggestions available)';
  RSContextSuggestionsEmpty = '   (Context and suggestions are empty)';
  RSContext = '   Context: %s';
  RSSuggestion = '💡 SUGGESTION:';
  RSLLVMDiagnostics = '🔧 LLVM DIAGNOSTICS:';
  RSAPICall = '   API Call: %s';
  RSFunction = '   Function: %s';
  RSValueInfo = '   Value Info: %s';
  RSLLVMModuleIR = '   LLVM Module IR:';
  RSBeginLLVMIR = '   --- BEGIN LLVM IR ---';
  RSEndLLVMIR = '   --- END LLVM IR ---';
  RSUnknownSystemError = '❌ UNKNOWN SYSTEM ERROR:';
  RSExceptionObjectNil = '   (Exception object is nil)';
  RSUnexpectedSystemError = '❌ UNEXPECTED SYSTEM ERROR:';
  RSSystemErrorDetails = '🔧 SYSTEM ERROR DETAILS:';
  RSExceptionType = '   Exception Type: %s';
  RSMessage = '   Message: %s';
  RSHelpContext = '   Help Context: %d';
  RSDiagnosticInformation = '📋 DIAGNOSTIC INFORMATION:';
  RSInternalCompilerError = '   This may indicate an internal compiler error or system issue.';
  RSReportError = '   Please report this error with reproduction steps.';

// JIT Execution Errors
  RSJITContextCreationFailed = 'Failed to create LLVM context';
  RSJITThreadSafeContextFailed = 'Failed to create thread-safe context';
  RSJITBuilderCreationFailed = 'Failed to create LLJIT builder';
  RSJITTargetMachineBuilderFailed = 'Failed to create target machine builder';
  RSJITCreationFailed = 'Failed to create LLJIT: %s';
  RSJITNotInitialized = 'LLVM JIT not initialized';
  RSJITLLJITNotInitialized = 'LLJIT not initialized';
  RSJITModuleIsNil = 'Module is nil';
  RSJITThreadSafeModuleFailed = 'Failed to create thread-safe module';
  RSJITMainJITDylibFailed = 'Failed to get main JITDylib';
  RSJITAddModuleFailed = 'Failed to add module to LLJIT: %s';
  RSJITCannotVerifyNilModule = 'Cannot verify nil module';
  RSJITModuleVerificationFailed = 'LLVM module verification failed';
  RSJITCannotLoadEmptyIR = 'Cannot load empty LLVM IR';
  RSJITMemoryBufferCreationFailed = 'Failed to create LLVM memory buffer';
  RSJITParseIRFailed = 'Failed to parse LLVM IR';
  RSJITAddModuleToJIT = 'Failed to add module to JIT';
  RSJITCannotLoadEmptyFilename = 'Cannot load IR from empty filename';
  RSJITFileNotFound = 'LLVM IR file not found: %s';
  RSJITFileReadFailed = 'Failed to read LLVM IR file: %s';
  RSJITParseFileIRFailed = 'Failed to parse LLVM IR from file: %s';
  RSJITAddFileModuleToJIT = 'Failed to add module to JIT from file: %s';
  RSJITCannotExecuteNotInitialized = 'Cannot execute: LLJIT not initialized';
  RSJITMainSymbolLookupFailed = 'Failed to lookup main function symbol';
  RSJITMainSymbolNullAddress = 'main function symbol has null address';
  RSJITCannotLoadNotInitialized = 'Cannot load IR: LLVM JIT not initialized';
  RSJITCannotExecuteNotInitialized2 = 'Cannot execute: LLVM JIT not initialized';
  RSJITCannotExecuteModuleNil = 'Cannot execute: Module is nil';
  RSJITInitializationFailed = 'LLVM JIT initialization failed';

  // JIT Error Context Messages
  RSJITContextModuleParameterNil = 'Module parameter is nil';
  RSJITContextLLVMNotInitialized = 'LLVM context or LLJIT instance failed to initialize properly';
  RSJITContextIRStringEmpty = 'LLVM IR string is empty or contains only whitespace';
  RSJITContextFilenameEmpty = 'Filename parameter is empty or contains only whitespace';
  RSJITContextFileNotExist = 'File does not exist or is not accessible: %s';
  RSJITContextJITNotInitialized = 'JIT compilation engine was not properly initialized';
  RSJITContextSymbolLookupFailed = 'Symbol lookup failed: %s';
  RSJITContextSymbolNullAddress = 'Symbol lookup succeeded but returned null address for main function';
  RSJITContextModuleCompilationFailed = 'Module compilation failed: %s';
  RSJITContextFileReadingFailed = 'File reading failed: %s';
  RSJITContextIRParsingFailed = 'LLVM IR parsing failed: %s';
  RSJITContextFileIRParsingFailed = 'LLVM IR parsing failed: %s';
  RSJITContextLLVMCreationFailed = 'LLVM could not create memory buffer from IR string';
  RSJITContextModuleContainsInvalidIR = 'Module contains invalid LLVM IR: %s';

  // JIT Error Suggestions
  RSJITSuggestCheckLLVMInstallation = 'Check LLVM installation and ensure proper initialization in constructor';
  RSJITSuggestProvideValidIR = 'Provide valid LLVM IR code for compilation and execution';
  RSJITSuggestEnsureModuleLoaded = 'Ensure module is properly loaded before verification';
  RSJITSuggestCheckIRSyntax = 'Check LLVM IR syntax, ensure all references are valid, and verify function signatures match their calls';
  RSJITSuggestCheckUTF8Valid = 'Check that LLVM IR string is valid UTF-8 and not corrupted';
  RSJITSuggestCheckIRStructure = 'Check LLVM IR syntax, ensure proper module structure, and verify all instructions are valid';
  RSJITSuggestCheckModuleDependencies = 'Check module dependencies and ensure all symbols are available';
  RSJITSuggestProvideValidFilePath = 'Provide a valid file path to an LLVM IR file';
  RSJITSuggestCheckFilePermissions = 'Check that the file path is correct and the file exists with proper read permissions';
  RSJITSuggestCheckFileNotCorrupted = 'Check file permissions, ensure file is not corrupted, and verify it contains valid text';
  RSJITSuggestCheckFileIRSyntax = 'Check LLVM IR syntax in file, ensure proper module structure, and verify all instructions are valid';
  RSJITSuggestEnsureModuleCompiled = 'Ensure module was successfully loaded and compiled before attempting execution';
  RSJITSuggestEnsureMainFunction = 'Ensure the module contains a main function and was successfully compiled';
  RSJITSuggestCheckJITCompilation = 'This indicates a JIT compilation issue - check that main function was properly compiled';
  RSJITSuggestCheckLLVMLibraries = 'Check LLVM installation and library dependencies';
  RSJITSuggestEnsureModuleGenerated = 'Ensure module was properly generated before execution';
  RSJITSuggestSystemLevelIssue = 'This may indicate a system-level issue or LLVM library problem';
  RSJITSuggestRuntimeError = 'This may indicate a runtime error in the compiled code or system-level issue';
  RSJITSuggestUnexpectedError = 'This may indicate a system-level issue or LLVM library problem';

  // JIT Internal Error Messages
  RSJITModuleVerificationUnknownError = 'Module verification failed with unknown error';
  RSJITExceptionCreatingLLJIT = 'Exception creating LLJIT: %s';
  RSJITExceptionAddingModule = 'Exception adding module to JIT: %s';
  RSJITUnknownLLVMParsingError = 'Unknown LLVM parsing error';
  RSJITUnknownFileReadingError = 'Unknown file reading error';
  RSJITUnexpectedErrorLoadingMemory = 'Unexpected error loading IR from memory';
  RSJITExceptionDuringIRLoading = 'Exception during IR loading: %s (%s)';
  RSJITUnexpectedErrorLoadingFile = 'Unexpected error loading IR from file: %s';
  RSJITExceptionDuringFileLoading = 'Exception during file loading: %s (%s)';
  RSJITUnexpectedErrorDuringExecution = 'Unexpected error during execution';
  RSJITExceptionDuringMainExecution = 'Exception during main function execution: %s (%s)';

  // IR Context Errors
  RSIRContextCreationFailed = 'Failed to create LLVM context';
  RSIRModuleCreationFailed = 'Failed to create LLVM module: %s';
  RSIRBuilderCreationFailed = 'Failed to create LLVM builder';
  RSIRCannotPerformNoModule = 'Cannot perform %s: No module available';
  RSIRCannotPerformNoFunction = 'Cannot perform %s: No current function';
  RSIRCannotPerformNoBlock = 'Cannot perform %s: No current basic block';
  RSIRModuleNameEmpty = 'Module name cannot be empty';
  RSIRFunctionNameEmpty = 'Function name cannot be empty';
  RSIRBasicBlockNameEmpty = 'Basic block name cannot be empty';

  // IR Context Error Context Messages
  RSIRContextContextCreationNil = 'LLVM context creation returned nil';
  RSIRContextModuleCreationNil = 'LLVM module creation returned nil';
  RSIRContextBuilderCreationNil = 'LLVM instruction builder creation returned nil';
  RSIRContextModuleIsNil = 'LLVM module is nil';
  RSIRContextNoFunctionBuilding = 'No function is currently being built';
  RSIRContextNoBlockActive = 'No basic block is currently active';

  // IR Context Error Suggestions
  RSIRSuggestCheckLLVMInstallation = 'Check LLVM installation and ensure proper library loading';
  RSIRSuggestCheckLLVMContext = 'Check LLVM installation and context validity';
  RSIRSuggestEnsureBuilderConstructed = 'Ensure TLGIRBuilder was properly constructed and module was created';
  RSIRSuggestCallBeginFunction = 'Call BeginFunction() first to create a function';
  RSIRSuggestCallBasicBlock = 'Call BasicBlock() first to create a basic block';

  // Platform Errors
  RSUnsupportedPlatform = 'Warning: Unsupported platform detected, defaulting to Windows X86-64 target';
  RSLLVMJitInitFailed = 'LLVM JIT init failed: %s';
  RSLLVMTargetMachineNil = 'LLVM target machine is nil';
  RSRuntimeLLVMInspectionFailed = 'Runtime LLVM inspection failed: %s';

  // TCPParser Error Messages
  RSParserFileNotFound = 'Source file not found: "%s"';
  RSParserFileEmpty = 'Source file is empty: "%s"';
  RSParserInvalidCharacter = 'Invalid character "%s" at line %d, column %d';
  RSParserUnexpectedEndOfFile = 'Unexpected end of file while tokenizing';
  RSParserTokenDefinitionEmpty = 'Token definition cannot be empty';
  RSParserPatternInvalid = 'Invalid pattern "%s" for token type "%s"';
  RSParserDuplicateTokenType = 'Token type "%s" is already defined';
  RSParserUnterminatedString = 'Unterminated string literal starting at line %d, column %d';
  RSParserUnterminatedComment = 'Unterminated comment starting at line %d, column %d';
  RSParserInvalidEscapeSequence = 'Invalid escape sequence "\%s" at line %d, column %d';
  RSParserNoTokenDefinitions = 'No token definitions have been configured';
  RSParserEngineNotInitialized = 'Parser engine has not been properly initialized';
  RSParserRuleNotFound = 'Parse rule "%s" not found';
  RSParserInfiniteLoop = 'Infinite loop detected in rule "%s"';
  RSParserCompilationUnitActive = 'Compilation unit "%s" is already active';
  RSParserModuleNameEmpty = 'Module name cannot be empty';
  RSParserNoCompilationUnit = 'No compilation unit is active';
  RSParserNoRulesDefined = 'No parsing rules have been defined';
  RSParserNoStartRule = 'No start rule has been defined';
  RSParserCompilationUnitRequired = 'compilation_unit rule is required but not found';
  RSParserCompilationUnitMustBeFirst = 'compilation_unit must be the first rule defined';
  RSParserModuleNameNotExtracted = 'Module name could not be extracted from source';
  RSIRContextNotInitialized = 'IRContext not initialized. Module name not set from compilation_unit.';
  RSParserTokenIndexOutOfBounds = 'Token index %d is out of bounds (valid range: 0-%d)';
  RSParserNoTokensCaptured = 'No tokens were captured for this rule';
  RSParserTokenAccessFailed = 'Failed to access token at index %d';
  RSParserTokenSystemNotInitialized = 'Token capture system not initialized for this context';
  
  // TCPParser Configuration Messages
  RSParserConfigSaveSuccess = 'Parser configuration saved successfully to "%s"';
  RSParserConfigLoadSuccess = 'Parser configuration loaded successfully from "%s"';
  RSParserConfigSaveFailed = 'Failed to save parser configuration to "%s"';
  RSParserConfigLoadFailed = 'Failed to load parser configuration from "%s"';
  RSParserConfigInvalidJSON = 'Invalid JSON format in configuration file "%s"';
  RSParserConfigMissingSection = 'Missing "tokenDefinitions" section in configuration';
  RSParserConfigInvalidDefinition = 'Invalid token definition at index %d in configuration';
  
  // TCPParser Error Recovery Messages
  RSParserMultipleErrors = 'Multiple parsing errors found (%d total)';
  RSParserErrorRecoveryEnabled = 'Error recovery is enabled - continuing after errors';
  RSParserMaxErrorsReached = 'Maximum error limit reached (%d errors) - stopping tokenization';
  
  // TCPParser Context Messages
  RSParserContextFileReadError = 'Failed to read file contents';
  RSParserContextTokenizationFailed = 'Tokenization process failed';
  RSParserContextInvalidConfiguration = 'Parser configuration is invalid';
  RSParserContextInvalidState = 'Parser is in an invalid state';
  RSParserContextModuleNameAutoExtract = 'Module name will be extracted automatically from source';
  RSParserContextTokenAccessError = 'Error accessing tokens in parse context';
  RSParserContextTokenSystemFailure = 'Token capture system failed during parsing';
  
  // TCPParser Suggestions
  RSParserSuggestCheckFilePath = 'Check that the file path is correct and the file exists';
  RSParserSuggestCheckFilePermissions = 'Verify file permissions and ensure the file is readable';
  RSParserSuggestDefineTokens = 'Use fluent methods to define token types before tokenizing';
  RSParserSuggestCheckPattern = 'Verify the regular expression pattern syntax';
  RSParserSuggestCheckStringDelimiters = 'Ensure string literals are properly closed';
  RSParserSuggestCheckCommentDelimiters = 'Ensure comments are properly closed';
  RSParserSuggestValidateEscapeSequence = 'Use valid escape sequences like \n, \t, \r, \\, \", etc.';
  RSParserSuggestCallReset = 'Call Reset() to end the current compilation unit first';
  RSParserSuggestProvideModuleName = 'Provide a valid module name for the compilation unit';
  RSParserSuggestSetModuleName = 'Call SetModuleName() to create a compilation unit first';
  RSParserSuggestDefineRules = 'Define parsing rules using the fluent interface before parsing';
  RSParserSuggestSetStartRule = 'Call SetStartRule() to specify which rule should be used as the entry point';
  RSParserSuggestCheckTokenIndex = 'Check that the token index is within valid bounds (0 to GetTokenCount()-1)';
  RSParserSuggestUseTokenCount = 'Call GetTokenCount() first to determine the number of available tokens';
  RSParserSuggestInitializeTokenSystem = 'Ensure the token capture system is properly initialized in the parsing context';

  // Symbol Table Errors
  RSSymbolAlreadyDeclared = 'Symbol "%s" already declared';
  RSSymbolNotFound = 'Symbol "%s" not found in symbol table';
  RSInvalidSymbolTableJSON = 'Invalid JSON configuration for symbol table';
  RSInvalidSymbolConfig = 'Invalid symbol configuration at index %d';

  // Symbol Table Debug/Display Messages
  RSSymbolTableDumpHeader = '=== SYMBOL TABLE DUMP ===';
  RSTotalSymbolsCount = 'Total symbols: %d';
  RSCaseSensitiveStatus = 'Case sensitive: %s';
  RSSymbolDeclaredAt = '%s (declared at line %d, column %d)';

implementation

end.
