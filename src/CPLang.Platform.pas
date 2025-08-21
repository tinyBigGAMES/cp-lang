{===============================================================================
              _
  __ _ __ ___| |__ _ _ _  __ _ ™
 / _| '_ \___| / _` | ' \/ _` |
 \__| .__/   |_\__,_|_||_\__, |
    |_|                  |___/
    C Power | Pascal Clarity

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://cp-lang.org/

 See LICENSE file for license agreement
===============================================================================}

unit CPLang.Platform;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  CPLang.Resources,
  {$IF DEFINED(MSWINDOWS) AND DEFINED(CPUX64)}
  WinApi.Windows,
  {$ENDIF}
  CPLang.LLVM;

type
  { TCPLLVMPlatformTarget }
  TCPLLVMPlatformTarget = (
    ptX86_64,      // x86-64 (AMD64/Intel 64)
    ptAArch64,     // ARM 64-bit
    ptWebAssembly, // WebAssembly target
    ptRISCV        // RISC-V 64-bit
  );

  { TCPLLVMPlatformInitResult }
  TCPLLVMPlatformInitResult = record
    Success: Boolean;
    ErrorMessage: string;
    PlatformTarget: TCPLLVMPlatformTarget;
    TargetTriple: string;
    DataLayout: string;
  end;

{ LLVM }
function  CPIsLLVMPlatformInitialized(): Boolean;
function  CPGetLLVMPlatformTargetTriple(): string;
function  CPGetLLVMPlatformDataLayout(): string;
function  CPGetLLVMPlatformTarget(): TCPLLVMPlatformTarget;
function  CPGetLLVMPlatformInitResult(): TCPLLVMPlatformInitResult;

{ Console }
function CPHasConsole(): Boolean;

{/ Strings }
function  CPAsUTF8(const AText: string): Pointer;

implementation

var
  // Global initialization state
  GPlatformInitialized: Boolean = False;
  GPlatformInitResult: TCPLLVMPlatformInitResult;
  GMarshaller: TMarshaller;

function CPInitLLVMPlatform(): TCPLLVMPlatformInitResult;
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

function CPGetLLVMPlatformTargetTriple(): string;
begin
  Result := GPlatformInitResult.TargetTriple;
end;

function CPGetLLVMPlatformDataLayout(): string;
begin
  Result := GPlatformInitResult.DataLayout;
end;

function CPGetLLVMPlatformTarget(): TCPLLVMPlatformTarget;
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

{ Console }
procedure CPInitConsole();
begin
  {$IF DEFINED(MSWINDOWS) AND DEFINED(CPUX64)}
    EnableVirtualTerminalProcessing();
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
  {$ENDIF}
end;

function CPHasConsole(): Boolean;
begin
  {$IF DEFINED(MSWINDOWS) AND DEFINED(CPUX64)}
  Result := Boolean(GetConsoleWindow() <> 0);
  {$ENDIF}
end;

function CPIsLLVMPlatformInitialized(): Boolean;
begin
  Result := GPlatformInitialized;
end;

function CPGetLLVMPlatformInitResult(): TCPLLVMPlatformInitResult;
begin
  Result := GPlatformInitResult;
end;

{ Strings }
function  CPAsUTF8(const AText: string): Pointer;
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
  CPInitConsole();
  {$ENDIF}

end.
