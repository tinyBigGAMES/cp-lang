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

unit ELang.JIT;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  ELang.LLVM,
  ELang.Resources,
  ELang.Errors,
  ELang.Platform,
  ELang.Common;

type
  { TELJIT }
  TELJIT = class(TELObject)
  private
    FContext: LLVMContextRef;
    FThreadSafeContext: LLVMOrcThreadSafeContextRef;
    FLLJIT: LLVMOrcLLJITRef;
    FIsInitialized: Boolean;
    FLastError: string;

    procedure Cleanup();
    procedure CPVerifyModule(AModule: LLVMModuleRef);
    function LoadIRFromMemory(const ALLVMIR: string): Boolean;
    function LoadIRFromFile(const AFilename: string): Boolean;
    function ExecuteMain(): Integer;
    function CreateLLJIT(): Boolean;
    function AddModuleToJIT(AModule: LLVMModuleRef): Boolean;

  public
    constructor Create; override;
    destructor Destroy; override;

    function ExecIRFromString(const ALLVMIR: string): Integer;
    function ExecIRFromFile(const AFilename: string): Integer;
    function ExecIRFromModule(const AModule: LLVMModuleRef): Integer;

    property LastError: string read FLastError;
    property IsInitialized: Boolean read FIsInitialized;

    class function IRFromString(const ALLVMIR: string): Integer;
    class function IRFromFile(const AFilename: string): Integer;
    class function IRFromModule(const AModule: LLVMModuleRef): Integer;
  end;

{ Routines }
function ELJITIRFromString(const ALLVMIR: string): Integer;
function ELJITIRFromFile(const AFilename: string): Integer;
function ELJITIRFromModule(const AModule: LLVMModuleRef): Integer;

implementation

function ELJITIRFromString(const ALLVMIR: string): Integer;
begin
  Result := TELJIT.IRFromString(ALLVMIR);
end;

function ELJITIRFromFile(const AFilename: string): Integer;
begin
  Result := TELJIT.IRFromFile(AFilename);
end;

function ELJITIRFromModule(const AModule: LLVMModuleRef): Integer;
begin
  Result := TELJIT.IRFromModule(AModule);
end;

function IfThen(const ACondition: Boolean; const ATrueValue, AFalseValue: string): string;
begin
  if ACondition then
    Result := ATrueValue
  else
    Result := AFalseValue;
end;

{ TLEJIT }
constructor TELJIT.Create;
begin
  inherited;

  FContext := nil;
  FThreadSafeContext := nil;
  FLLJIT := nil;
  FIsInitialized := False;
  FLastError := '';

  // Create per-instance LLVM context
  FContext := LLVMContextCreate();
  if FContext = nil then
  begin
    FLastError := RSJITContextCreationFailed;
    Exit;
  end;

  // Create thread-safe context wrapper for ORC
  FThreadSafeContext := LLVMOrcCreateNewThreadSafeContext();
  if FThreadSafeContext = nil then
  begin
    FLastError := RSJITThreadSafeContextFailed;
    Exit;
  end;

  // Create LLJIT instance
  if not CreateLLJIT() then
    Exit;

  FIsInitialized := True;
end;

destructor TELJIT.Destroy;
begin
  Cleanup();

  inherited;
end;

procedure TELJIT.Cleanup();
begin
  if FLLJIT <> nil then
  begin
    LLVMOrcDisposeLLJIT(FLLJIT);
    FLLJIT := nil;
  end;

  if FThreadSafeContext <> nil then
  begin
    LLVMOrcDisposeThreadSafeContext(FThreadSafeContext);
    FThreadSafeContext := nil;
  end;

  if FContext <> nil then
  begin
    LLVMContextDispose(FContext);
    FContext := nil;
  end;

  FIsInitialized := False;
end;

procedure TELJIT.CPVerifyModule(AModule: LLVMModuleRef);
var
  LErrorMessage: PUTF8Char;
  LDiagnostic: string;
begin
  if AModule = nil then
    raise EELException.Create(
      RSJITCannotVerifyNilModule,
      [],
      RSJITContextModuleParameterNil,
      RSJITSuggestEnsureModuleLoaded
    );

  LErrorMessage := nil;
  if LLVMVerifyModule(AModule, LLVMReturnStatusAction, @LErrorMessage) <> 0 then
  begin
    if LErrorMessage <> nil then
    begin
      LDiagnostic := string(UTF8String(LErrorMessage));
      LLVMDisposeMessage(LErrorMessage);
    end
    else
      LDiagnostic := RSJITModuleVerificationUnknownError;
      
    raise EELException.Create(
      RSJITModuleVerificationFailed,
      [],
      Format(RSJITContextModuleContainsInvalidIR, [LDiagnostic]),
      RSJITSuggestCheckIRSyntax
    );
  end;
end;

function TELJIT.CreateLLJIT(): Boolean;
var
  LError: LLVMErrorRef;
  LBuilder: LLVMOrcLLJITBuilderRef;
  LTargetMachineBuilder: LLVMOrcJITTargetMachineBuilderRef;
begin
  Result := False;
  FLastError := '';

  try
    // Create LLJIT builder for configuration
    LBuilder := LLVMOrcCreateLLJITBuilder();
    if LBuilder = nil then
    begin
      FLastError := RSJITBuilderCreationFailed;
      Exit;
    end;

    // Create target machine builder for native target
    LTargetMachineBuilder := LLVMOrcJITTargetMachineBuilderCreateFromTargetMachine(
      LLVMCreateTargetMachine(
        LLVMGetFirstTarget(), // Use first available target for simplicity
        LLVMGetDefaultTargetTriple(),
        LLVMGetHostCPUName(),
        LLVMGetHostCPUFeatures(),
        LLVMCodeGenLevelDefault,
        LLVMRelocDefault,
        LLVMCodeModelDefault
      )
    );

    if LTargetMachineBuilder = nil then
    begin
      FLastError := RSJITTargetMachineBuilderFailed;
      LLVMOrcDisposeLLJITBuilder(LBuilder);
      Exit;
    end;

    // Set target machine builder in LLJIT builder
    LLVMOrcLLJITBuilderSetJITTargetMachineBuilder(LBuilder, LTargetMachineBuilder);

    // Create LLJIT instance
    LError := LLVMOrcCreateLLJIT(@FLLJIT, LBuilder);
    if LError <> nil then
    begin
      FLastError := Format(RSJITCreationFailed, [string(UTF8String(LLVMGetErrorMessage(LError)))]);
      LLVMConsumeError(LError);
      Exit;
    end;

    Result := True;

  except
    on E: Exception do
    begin
      FLastError := Format(RSJITExceptionCreatingLLJIT, [E.Message]);
      Result := False;
    end;
  end;
end;

function TELJIT.AddModuleToJIT(AModule: LLVMModuleRef): Boolean;
var
  LError: LLVMErrorRef;
  LThreadSafeModule: LLVMOrcThreadSafeModuleRef;
  LMainJITDylib: LLVMOrcJITDylibRef;
begin
  Result := False;
  FLastError := '';

  if FLLJIT = nil then
  begin
    FLastError := RSJITLLJITNotInitialized;
    Exit;
  end;

  if AModule = nil then
  begin
    FLastError := RSJITModuleIsNil;
    Exit;
  end;

  try
    // Wrap module in thread-safe wrapper
    LThreadSafeModule := LLVMOrcCreateNewThreadSafeModule(AModule, FThreadSafeContext);
    if LThreadSafeModule = nil then
    begin
      FLastError := RSJITThreadSafeModuleFailed;
      Exit;
    end;

    // Get main JITDylib (the default dylib for symbol resolution)
    LMainJITDylib := LLVMOrcLLJITGetMainJITDylib(FLLJIT);
    if LMainJITDylib = nil then
    begin
      FLastError := RSJITMainJITDylibFailed;
      LLVMOrcDisposeThreadSafeModule(LThreadSafeModule);
      Exit;
    end;

    // Add module to LLJIT (this triggers compilation)
    LError := LLVMOrcLLJITAddLLVMIRModule(FLLJIT, LMainJITDylib, LThreadSafeModule);
    if LError <> nil then
    begin
      FLastError := Format(RSJITAddModuleFailed, [string(UTF8String(LLVMGetErrorMessage(LError)))]);
      LLVMConsumeError(LError);
      Exit;
    end;

    // ThreadSafeModule is now owned by LLJIT
    Result := True;

  except
    on E: Exception do
    begin
      FLastError := Format(RSJITExceptionAddingModule, [E.Message]);
      Result := False;
    end;
  end;
end;

function TELJIT.LoadIRFromMemory(const ALLVMIR: string): Boolean;
var
  LMemoryBuffer: LLVMMemoryBufferRef;
  LErrorMessage: PUTF8Char;
  LIRBytes: UTF8String;
  LModule: LLVMModuleRef;
  LDiagnostic: string;
begin

  FLastError := '';

  if not FIsInitialized then
    raise EELException.Create(
      RSJITCannotLoadNotInitialized,
      [],
      RSJITContextLLVMNotInitialized,
      RSJITSuggestCheckLLVMInstallation
    );

  if Trim(ALLVMIR) = '' then
    raise EELException.Create(
      RSJITCannotLoadEmptyIR,
      [],
      RSJITContextIRStringEmpty,
      RSJITSuggestProvideValidIR
    );

  try
    // Convert string to UTF8 for LLVM
    LIRBytes := UTF8String(ALLVMIR);

    // Create memory buffer from string
    LMemoryBuffer := LLVMCreateMemoryBufferWithMemoryRange(
      PUTF8Char(LIRBytes),
      Length(LIRBytes),
      'cpascal_ir',
      0  // Don't copy - we manage the memory
    );

    if LMemoryBuffer = nil then
      raise EELException.Create(
        RSJITMemoryBufferCreationFailed,
        [],
        RSJITContextLLVMCreationFailed,
        RSJITSuggestCheckUTF8Valid
      );

    // Parse IR into module
    LErrorMessage := nil;
    if LLVMParseIRInContext(FContext, LMemoryBuffer, @LModule, @LErrorMessage) <> 0 then
    begin
      if LErrorMessage <> nil then
      begin
        LDiagnostic := string(UTF8String(LErrorMessage));
        LLVMDisposeMessage(LErrorMessage);
      end
      else
        LDiagnostic := RSJITUnknownLLVMParsingError;
        
      raise EELException.Create(
        RSJITParseIRFailed,
        [],
        Format(RSJITContextIRParsingFailed, [LDiagnostic]),
        RSJITSuggestCheckIRStructure
      );
    end;

    // Verify module before adding to JIT
    CPVerifyModule(LModule);

    // Add module to JIT
    if not AddModuleToJIT(LModule) then
    begin
      LLVMDisposeModule(LModule);
      // AddModuleToJIT already sets FLastError, convert to exception
      raise EELException.Create(
        RSJITAddModuleToJIT,
        [],
        Format(RSJITContextModuleCompilationFailed, [FLastError]),
        RSJITSuggestCheckModuleDependencies
      );
    end;

    // Module is now owned by LLJIT
    Result := True;

  except
    on EELException do
      raise; // Re-raise ECPExceptions as-is
    on E: Exception do
      raise EELException.Create(
        RSJITUnexpectedErrorLoadingMemory,
        [],
        Format(RSJITExceptionDuringIRLoading, [E.Message, E.ClassName]),
        RSJITSuggestUnexpectedError
      );
  end;
end;

function TELJIT.LoadIRFromFile(const AFilename: string): Boolean;
var
  LMemoryBuffer: LLVMMemoryBufferRef;
  LErrorMessage: PUTF8Char;
  LFilenameUTF8: UTF8String;
  LModule: LLVMModuleRef;
  LDiagnostic: string;
begin

  FLastError := '';

  if not FIsInitialized then
    raise EELException.Create(
      RSJITCannotLoadNotInitialized,
      [],
      RSJITContextLLVMNotInitialized,
      RSJITSuggestCheckLLVMInstallation
    );

  if Trim(AFilename) = '' then
    raise EELException.Create(
      RSJITCannotLoadEmptyFilename,
      [],
      RSJITContextFilenameEmpty,
      RSJITSuggestProvideValidFilePath
    );

  if not TFile.Exists(AFilename) then
    raise EELException.Create(
      Format(RSJITFileNotFound, [AFilename]),
      [AFilename],
      Format(RSJITContextFileNotExist, [AFilename]),
      RSJITSuggestCheckFilePermissions
    );

  try
    LFilenameUTF8 := UTF8String(AFilename);

    // Create memory buffer from file
    LErrorMessage := nil;
    if LLVMCreateMemoryBufferWithContentsOfFile(
      PUTF8Char(LFilenameUTF8),
      @LMemoryBuffer,
      @LErrorMessage) <> 0 then
    begin
      if LErrorMessage <> nil then
      begin
        LDiagnostic := string(UTF8String(LErrorMessage));
        LLVMDisposeMessage(LErrorMessage);
      end
      else
        LDiagnostic := RSJITUnknownFileReadingError;
        
      raise EELException.Create(
        Format(RSJITFileReadFailed, [AFilename]),
        [AFilename],
        Format(RSJITContextFileReadingFailed, [LDiagnostic]),
        RSJITSuggestCheckFileNotCorrupted
      );
    end;

    // Parse IR into module
    LErrorMessage := nil;
    if LLVMParseIRInContext(FContext, LMemoryBuffer, @LModule, @LErrorMessage) <> 0 then
    begin
      if LErrorMessage <> nil then
      begin
        LDiagnostic := string(UTF8String(LErrorMessage));
        LLVMDisposeMessage(LErrorMessage);
      end
      else
        LDiagnostic := RSJITUnknownLLVMParsingError;
        
      raise EELException.Create(
        Format(RSJITParseFileIRFailed, [AFilename]),
        [AFilename],
        Format(RSJITContextFileIRParsingFailed, [LDiagnostic]),
        RSJITSuggestCheckFileIRSyntax
      );
    end;

    // Verify module before adding to JIT
    CPVerifyModule(LModule);

    // Add module to JIT
    if not AddModuleToJIT(LModule) then
    begin
      LLVMDisposeModule(LModule);
      // AddModuleToJIT already sets FLastError, convert to exception
      raise EELException.Create(
        Format(RSJITAddFileModuleToJIT, [AFilename]),
        [AFilename],
        Format(RSJITContextModuleCompilationFailed, [FLastError]),
        RSJITSuggestCheckModuleDependencies
      );
    end;

    // Module is now owned by LLJIT
    Result := True;

  except
    on EELException do
      raise; // Re-raise ECPExceptions as-is
    on E: Exception do
      raise EELException.Create(
        Format(RSJITUnexpectedErrorLoadingFile, [AFilename]),
        [AFilename],
        Format(RSJITExceptionDuringFileLoading, [E.Message, E.ClassName]),
        RSJITSuggestUnexpectedError
      );
  end;
end;

function TELJIT.ExecuteMain(): Integer;
var
  LError: LLVMErrorRef;
  LMainSymbol: LLVMOrcExecutorAddress;
  LMainFunction: function(): Integer; cdecl;
  LDiagnostic: string;
begin

  FLastError := '';

  if FLLJIT = nil then
    raise EELException.Create(
      RSJITCannotExecuteNotInitialized,
      [],
      RSJITContextJITNotInitialized,
      RSJITSuggestEnsureModuleCompiled
    );

  try
    // Look up the main function symbol
    LError := LLVMOrcLLJITLookup(FLLJIT, @LMainSymbol, 'main');
    if LError <> nil then
    begin
      LDiagnostic := string(UTF8String(LLVMGetErrorMessage(LError)));
      LLVMConsumeError(LError);
      
      raise EELException.Create(
        RSJITMainSymbolLookupFailed,
        [],
        Format(RSJITContextSymbolLookupFailed, [LDiagnostic]),
        RSJITSuggestEnsureMainFunction
      );
    end;

    if LMainSymbol = 0 then
      raise EELException.Create(
        RSJITMainSymbolNullAddress,
        [],
        RSJITContextSymbolNullAddress,
        RSJITSuggestCheckJITCompilation
      );

    // Cast symbol address to function pointer and call it
    // Note: This assumes main() takes no arguments and returns int
    LMainFunction := Pointer(LMainSymbol);
    Result := LMainFunction();

  except
    on EELException do
      raise; // Re-raise ECPExceptions as-is
    on E: Exception do
      raise EELException.Create(
        RSJITUnexpectedErrorDuringExecution,
        [],
        Format(RSJITExceptionDuringMainExecution, [E.Message, E.ClassName]),
        RSJITSuggestRuntimeError
      );
  end;
end;

function TELJIT.ExecIRFromString(const ALLVMIR: string): Integer;
begin
  Result := -1;

  if not LoadIRFromMemory(ALLVMIR) then
    Exit;

  Result := ExecuteMain();
end;

function TELJIT.ExecIRFromFile(const AFilename: string): Integer;
begin
  Result := -1;

  if not LoadIRFromFile(AFilename) then
    Exit;

  Result := ExecuteMain();
end;

// Convenience class methods with enhanced error handling
class function TELJIT.IRFromString(const ALLVMIR: string): Integer;
var
  LJit: TELJIT;
begin
  LJit := TELJIT.Create;
  try
    // Check initialization before proceeding
    if not LJit.IsInitialized then
      raise EELException.Create(
        RSJITInitializationFailed,
        [],
        RSJITContextLLVMNotInitialized,
        RSJITSuggestCheckLLVMLibraries
      );

    Result := LJit.ExecIRFromString(ALLVMIR);

  finally
    LJit.Free;
  end;
end;

class function TELJIT.IRFromFile(const AFilename: string): Integer;
var
  LJit: TELJIT;
begin
  LJit := TELJIT.Create;
  try
    // Check initialization before proceeding
    if not LJit.IsInitialized then
      raise EELException.Create(
        RSJITInitializationFailed,
        [],
        RSJITContextLLVMNotInitialized,
        RSJITSuggestCheckLLVMLibraries
      );

    Result := LJit.ExecIRFromFile(AFilename);

  finally
    LJit.Free;
  end;
end;

function TELJIT.ExecIRFromModule(const AModule: LLVMModuleRef): Integer;
begin
  FLastError := '';

  if not FIsInitialized then
    raise EELException.Create(
      RSJITCannotExecuteNotInitialized2,
      [],
      RSJITContextLLVMNotInitialized,
      RSJITSuggestCheckLLVMInstallation
    );

  if AModule = nil then
    raise EELException.Create(
      RSJITCannotExecuteModuleNil,
      [],
      RSJITContextModuleParameterNil,
      RSJITSuggestEnsureModuleGenerated
    );

  // Verify the module before adding to JIT
  CPVerifyModule(AModule);

  // Add module to JIT
  if not AddModuleToJIT(AModule) then
    raise EELException.Create(
      RSJITAddModuleToJIT,
      [],
      Format(RSJITContextModuleCompilationFailed, [FLastError]),
      RSJITSuggestCheckModuleDependencies
    );

  // Execute main function
  Result := ExecuteMain();
end;

class function TELJIT.IRFromModule(const AModule: LLVMModuleRef): Integer;
var
  LJit: TELJIT;
begin
  LJit := TELJIT.Create;
  try
    // Check initialization before proceeding
    if not LJit.IsInitialized then
      raise EELException.Create(
        RSJITInitializationFailed,
        [],
        RSJITContextLLVMNotInitialized,
        RSJITSuggestCheckLLVMLibraries
      );

    Result := LJit.ExecIRFromModule(AModule);

  finally
    LJit.Free;
  end;
end;

end.
