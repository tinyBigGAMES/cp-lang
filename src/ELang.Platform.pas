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

unit ELang.Platform;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  ELang.Resources,
  {$IF DEFINED(MSWINDOWS) AND DEFINED(CPUX64)}
  WinApi.Windows,
  {$ENDIF}
  ELang.LLVM;

type
  { TELLLVMPlatformTarget }
  TELLLVMPlatformTarget = (
    ptX86_64,      // x86-64 (AMD64/Intel 64)
    ptAArch64,     // ARM 64-bit
    ptWebAssembly, // WebAssembly target
    ptRISCV        // RISC-V 64-bit
  );

  { TELLLVMPlatformInitResult }
  TELLLVMPlatformInitResult = record
    Success: Boolean;
    ErrorMessage: string;
    PlatformTarget: TELLLVMPlatformTarget;
    TargetTriple: string;
    DataLayout: string;
  end;

// LLVM
function  ELIsLLVMPlatformInitialized(): Boolean;
function  ELGetLLVMPlatformTargetTriple(): string;
function  ELGetLLVMPlatformDataLayout(): string;
function  ELGetLLVMPlatformTarget(): TELLLVMPlatformTarget;
function  ELGetLLVMPlatformInitResult(): TELLLVMPlatformInitResult;

// Console
procedure ELInitConsole();
function  ELHasConsole(): Boolean;
function  ELPrint(const AText: string): string; overload;
function  ELPrint(const AText: string; const AArgs: array of const): string; overload;
function  ELPrintLn(const AText: string): string; overload;
function  ELPrintLn(const AText: string; const AArgs: array of const): string; overload;
procedure ELPause();

// String
function  ELAsUTF8(const AText: string): Pointer;

implementation

var
  // Global initialization state
  GPlatformInitialized: Boolean = False;
  GPlatformInitResult: TELLLVMPlatformInitResult;
  GMarshaller: TMarshaller;

function CPInitLLVMPlatform(): TELLLVMPlatformInitResult;
var
  LContext: LLVMContextRef;
  LModule: LLVMModuleRef;
  LEngine: LLVMExecutionEngineRef;
  LTargetMachine: LLVMTargetMachineRef;
  LTargetTriple: PAnsiChar;
  LTargetData: LLVMTargetDataRef;
  LLayoutStr: PAnsiChar;
  LError: PAnsiChar;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  Result.TargetTriple := '';
  Result.DataLayout := '';

  {$IF DEFINED(MSWINDOWS) AND DEFINED(CPUX64)}
    Result.PlatformTarget := ptX86_64;
    LLVMInitializeX86TargetInfo();
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetMC();
    LLVMInitializeX86AsmPrinter();
    LLVMInitializeX86AsmParser();
    LLVMInitializeX86Disassembler();

  {$ELSEIF DEFINED(MSWINDOWS) AND DEFINED(CPUX86)}
    Result.PlatformTarget := ptX86_64;
    LLVMInitializeX86TargetInfo();
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetMC();
    LLVMInitializeX86AsmPrinter();
    LLVMInitializeX86AsmParser();
    LLVMInitializeX86Disassembler();

  {$ELSEIF DEFINED(LINUX) AND DEFINED(CPUX64)}
    Result.PlatformTarget := ptX86_64;
    LLVMInitializeX86TargetInfo();
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetMC();
    LLVMInitializeX86AsmPrinter();

  {$ELSEIF DEFINED(LINUX) AND DEFINED(CPUAARCH64)}
    Result.PlatformTarget := ptAArch64;
    LLVMInitializeAArch64TargetInfo();
    LLVMInitializeAArch64Target();
    LLVMInitializeAArch64TargetMC();
    LLVMInitializeAArch64AsmPrinter();
    LLVMInitializeAArch64AsmParser();
    LLVMInitializeAArch64Disassembler();

  {$ELSEIF DEFINED(MACOS) AND DEFINED(CPUX64)}
    Result.PlatformTarget := ptX86_64;
    LLVMInitializeX86TargetInfo();
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetMC();
    LLVMInitializeX86AsmPrinter();
    LLVMInitializeX86AsmParser();
    LLVMInitializeX86Disassembler();

  {$ELSEIF DEFINED(MACOS) AND DEFINED(CPUAARCH64)}
    Result.PlatformTarget := ptAArch64;
    LLVMInitializeAArch64TargetInfo();
    LLVMInitializeAArch64Target();
    LLVMInitializeAArch64TargetMC();
    LLVMInitializeAArch64AsmPrinter();
    LLVMInitializeAArch64AsmParser();
    LLVMInitializeAArch64Disassembler();

  {$ELSE}
    Result.PlatformTarget := ptX86_64;
    Result.ErrorMessage := RSUnsupportedPlatform;
    LLVMInitializeX86TargetInfo();
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetMC();
    LLVMInitializeX86AsmPrinter();
    LLVMInitializeX86AsmParser();
    LLVMInitializeX86Disassembler();
  {$ENDIF}

  try
    LContext := LLVMContextCreate();
    LModule := LLVMModuleCreateWithNameInContext('Dummy', LContext);

    if LLVMCreateExecutionEngineForModule(@LEngine, LModule, @LError) <> 0 then
      raise Exception.Create(Format(RSLLVMJitInitFailed, [string(AnsiString(LError))]));

    LTargetMachine := LLVMGetExecutionEngineTargetMachine(LEngine);
    if LTargetMachine = nil then
      raise Exception.Create(RSLLVMTargetMachineNil);

    LTargetTriple := LLVMGetTargetMachineTriple(LTargetMachine);
    Result.TargetTriple := string(UTF8String(LTargetTriple));
    LLVMDisposeMessage(LTargetTriple);

    LTargetData := LLVMCreateTargetDataLayout(LTargetMachine);
    LLayoutStr := LLVMCopyStringRepOfTargetData(LTargetData);
    Result.DataLayout := string(UTF8String(LLayoutStr));
    LLVMDisposeMessage(LLayoutStr);

    LLVMDisposeTargetData(LTargetData);
    LLVMDisposeExecutionEngine(LEngine);
    LLVMContextDispose(LContext);

    Result.Success := True;
  except
    on E: Exception do
      Result.ErrorMessage := Format(RSRuntimeLLVMInspectionFailed, [E.Message]);
  end;
end;

function ELGetLLVMPlatformTargetTriple(): string;
begin
  Result := GPlatformInitResult.TargetTriple;
end;

function ELGetLLVMPlatformDataLayout(): string;
begin
  Result := GPlatformInitResult.DataLayout;
end;

function ELGetLLVMPlatformTarget(): TELLLVMPlatformTarget;
begin
  {$IF DEFINED(MSWINDOWS) AND (DEFINED(CPUX64) OR DEFINED(CPUX86))}
    Result := ptX86_64;
  {$ELSEIF DEFINED(LINUX) AND DEFINED(CPUX64)}
    Result := ptX86_64;
  {$ELSEIF DEFINED(LINUX) AND DEFINED(CPUAARCH64)}
    Result := ptAArch64;
  {$ELSEIF DEFINED(MACOS) AND DEFINED(CPUX64)}
    Result := ptX86_64;
  {$ELSEIF DEFINED(MACOS) AND DEFINED(CPUAARCH64)}
    Result := ptAArch64;
  {$ELSE}
    Result := ptX86_64; // Default fallback
  {$ENDIF}
end;

{$IF DEFINED(MSWINDOWS) AND DEFINED(CPUX64)}
  function EnableVirtualTerminalProcessing(): Boolean;
  var
    HOut: THandle;
    LMode: DWORD;
  begin
    Result := False;

    HOut := GetStdHandle(STD_OUTPUT_HANDLE);
    if HOut = INVALID_HANDLE_VALUE then Exit;
    if not GetConsoleMode(HOut, LMode) then Exit;

    LMode := LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if not SetConsoleMode(HOut, LMode) then Exit;

    Result := True;
  end;
{$ENDIF}

procedure ELInitConsole();
begin
  {$IF DEFINED(MSWINDOWS) AND DEFINED(CPUX64)}
    EnableVirtualTerminalProcessing();
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
  {$ENDIF}
end;

function ELHasConsole(): Boolean;
begin
  {$IF DEFINED(MSWINDOWS) AND DEFINED(CPUX64)}
  Result := Boolean(GetConsoleWindow() <> 0);
  {$ENDIF}
end;

function ELPrint(const AText: string): string;
begin
  if not ELHasConsole() then Exit;
  Result := AText;
  Write(Result);
end;

function ELPrint(const AText: string; const AArgs: array of const): string;
begin
  if not ELHasConsole() then Exit;
  Result := Format(AText, AArgs);
  Write(Result);
end;

function ELPrintLn(const AText: string): string;
begin
  if not ELHasConsole() then Exit;
  Result := AText;
  WriteLn(Result);
end;

function  ELPrintLn(const AText: string; const AArgs: array of const): string;
begin
  if not ELHasConsole() then Exit;
  Result := Format(AText, AArgs);
  WriteLn(Result);
end;

procedure ELPause();
begin
  ELPrintLn('');
  ELPrint('Press ENTER to continue...');
  ReadLn;
  ELPrintLn('');
end;

function ELIsLLVMPlatformInitialized(): Boolean;
begin
  Result := GPlatformInitialized;
end;

function ELGetLLVMPlatformInitResult(): TELLLVMPlatformInitResult;
begin
  Result := GPlatformInitResult;
end;

function  ELAsUTF8(const AText: string): Pointer;
begin
  Result := GMarshaller.AsUtf8(AText).ToPointer;
end;

initialization
  ReportMemoryLeaksOnShutdown := True;
  // Automatically initialize LLVM platform at unit load
  GPlatformInitResult := CPInitLLVMPlatform();
  GPlatformInitialized := GPlatformInitResult.Success;

  // Initialize console only for console applications
  {$IF DEFINED(CONSOLE)}
  ELInitConsole();
  {$ENDIF}

end.
