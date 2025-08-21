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

unit CPLang.IRContext;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  System.Math,
  CPLang.LLVM,
  CPLang.Platform,
  CPLang.Resources,
  CPLang.Errors,
  CPLang.Common;

type

  { TCPIRContext }
  TCPIRContext = class
  private
    FContext: LLVMContextRef;
    FModule: LLVMModuleRef;
    FBuilder: LLVMBuilderRef;
    FModuleName: string;
    FTargetTriple: string;
    FDataLayout: string;
    FCurrentFunction: LLVMValueRef;
    FCurrentBlock: LLVMBasicBlockRef;
    FRegisterCount: UInt32;
    FLabelCount: Integer;
    FStringLiteralCount: Integer;
    FGlobalCount: Integer;
    FOwnsContext: Boolean;
    FStringConstants: TDictionary<string, LLVMValueRef>;
    
    function GetNextRegister: string;
    function GetNextStringLiteral: string;
    function GetNextGlobal: string;
    function CreateStringConstant(const AValue: string): LLVMValueRef;
    procedure ValidateModuleState(const AOperation: string);
    procedure ValidateFunctionState(const AOperation: string);
    procedure ValidateBlockState(const AOperation: string);

  public
    constructor Create(const AModuleName: string; const AContext: LLVMContextRef = nil);
    destructor Destroy; override;
    
    // Module Configuration
    function ModuleName(const AName: string): TCPIRContext;
    function TargetTriple(const ATriple: string): TCPIRContext;
    function DataLayout(const ALayout: string): TCPIRContext;

    // Type Creation Methods
    function VoidType: LLVMTypeRef;
    function BoolType: LLVMTypeRef;
    function Int1Type: LLVMTypeRef;
    function Int8Type: LLVMTypeRef;
    function Int16Type: LLVMTypeRef;
    function Int32Type: LLVMTypeRef;
    function Int64Type: LLVMTypeRef;
    function FloatType: LLVMTypeRef;
    function DoubleType: LLVMTypeRef;
    function IntPtrType: LLVMTypeRef;
    function PointerType(const APointedType: LLVMTypeRef): LLVMTypeRef;
    function ArrayType(const AElementType: LLVMTypeRef; const ASize: Cardinal): LLVMTypeRef;
    function StructType(const AFields: array of LLVMTypeRef; const APacked: Boolean = False): LLVMTypeRef;
    function FunctionType(const AReturnType: LLVMTypeRef; const AParams: array of LLVMTypeRef; const AVarArgs: Boolean = False): LLVMTypeRef;

    // Constant Creation Methods
    function ConstNull(const AType: LLVMTypeRef): LLVMValueRef;
    function ConstUndef(const AType: LLVMTypeRef): LLVMValueRef;
    function ConstBool(const AValue: Boolean): LLVMValueRef;
    function ConstInt1(const AValue: Boolean): LLVMValueRef;
    function ConstInt8(const AValue: Byte): LLVMValueRef;
    function ConstInt16(const AValue: Word): LLVMValueRef;
    function ConstInt32(const AValue: Integer): LLVMValueRef;
    function ConstInt64(const AValue: Int64): LLVMValueRef;
    function ConstFloat(const AValue: Single): LLVMValueRef;
    function ConstDouble(const AValue: Double): LLVMValueRef;
    function ConstString(const AValue: string): LLVMValueRef;
    function ConstArray(const AType: LLVMTypeRef; const AElements: array of LLVMValueRef): LLVMValueRef;
    function ConstStruct(const AElements: array of LLVMValueRef; const APacked: Boolean = False): LLVMValueRef;

    // Global Declaration Methods
    function DeclareGlobal(const AName: string; const AType: LLVMTypeRef; const AInitializer: LLVMValueRef = nil; 
      const ALinkage: LLVMLinkage = LLVMPrivateLinkage): LLVMValueRef;
    function DeclareFunction(const AName: string; const AFunctionType: LLVMTypeRef; 
      const ACallingConv: LLVMCallConv = LLVMCCallConv; const ALinkage: LLVMLinkage = LLVMExternalLinkage): LLVMValueRef;
    function DeclareExternalFunction(const AName: string; const AReturnType: LLVMTypeRef; const ALibrary: string; 
      const AParams: array of LLVMTypeRef; const ACallingConv: LLVMCallConv = LLVMCCallConv;
      const AVarArgs: Boolean = False): LLVMValueRef;

    // Function Building Methods
    function BeginFunction(const AName: string; const AFunctionType: LLVMTypeRef;
      const ACallingConv: LLVMCallConv = LLVMCCallConv; const ALinkage: LLVMLinkage = LLVMExternalLinkage): TCPIRContext;
    function AddFunctionAttribute(const AAttribute: LLVMAttributeRef): TCPIRContext;
    function EndFunction: TCPIRContext;

    // Basic Block Methods
    function BasicBlock(const AName: string): TCPIRContext;
    function CreateLabel(const APrefix: string = 'bb'): string;

    // Memory Operations
    function Alloca(const AType: LLVMTypeRef; const AArraySize: LLVMValueRef = nil; const AAlignment: Integer = 0): LLVMValueRef;
    function Load(const APtr: LLVMValueRef; const AType: LLVMTypeRef): LLVMValueRef;
    function Store(const AValue: LLVMValueRef; const APtr: LLVMValueRef; const AAlignment: Integer = 0): TCPIRContext;
    function GEP(const APtr: LLVMValueRef; const AIndices: array of LLVMValueRef): LLVMValueRef;
    function ExtractValue(const AValue: LLVMValueRef; const AIndices: array of Integer): LLVMValueRef;
    function InsertValue(const AAggregate: LLVMValueRef; const AValue: LLVMValueRef; const AIndices: array of Integer): LLVMValueRef;

    // Arithmetic Operations
    function Add(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function Sub(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function Mul(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function UDiv(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function SDiv(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function URem(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function SRem(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function FAdd(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function FSub(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function FMul(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function FDiv(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function FRem(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;

    // Bitwise Operations
    function BitwiseAnd(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function BitwiseOr(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function BitwiseXor(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function ShiftLeft(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function LShr(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function AShr(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function ROL(const AValue: LLVMValueRef; const AAmount: LLVMValueRef): LLVMValueRef;
    function ROR(const AValue: LLVMValueRef; const AAmount: LLVMValueRef): LLVMValueRef;

    // Comparison Operations
    function ICmp(const ACondition: LLVMIntPredicate; const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
    function FCmp(const ACondition: LLVMRealPredicate; const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;

    // Type Conversion Operations
    function Trunc(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function ZExt(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function SExt(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function FPTrunc(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function FPExt(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function FPToUI(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function FPToSI(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function UIToFP(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function SIToFP(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function PtrToInt(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function IntToPtr(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
    function BitCast(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;

    // Control Flow Operations
    function Br(const ATarget: LLVMBasicBlockRef): TCPIRContext;
    function CondBr(const ACondition: LLVMValueRef; const ATrueTarget: LLVMBasicBlockRef; const AFalseTarget: LLVMBasicBlockRef): TCPIRContext;
    function Switch(const AValue: LLVMValueRef; const ADefaultTarget: LLVMBasicBlockRef): LLVMValueRef;
    function AddSwitchCase(const ASwitchInst: LLVMValueRef; const AValue: LLVMValueRef; const ATarget: LLVMBasicBlockRef): TCPIRContext;
    function Ret(const AValue: LLVMValueRef = nil): TCPIRContext;
    function RetVoid: TCPIRContext;

    // PHI Nodes
    function Phi(const AType: LLVMTypeRef): LLVMValueRef;
    function AddPhiIncoming(const APhiNode: LLVMValueRef; const AValue: LLVMValueRef; const ABlock: LLVMBasicBlockRef): TCPIRContext;

    // Function Calls
    function Call(const AFunction: LLVMValueRef; const AArgs: array of LLVMValueRef; 
      const ACallingConv: LLVMCallConv = LLVMCCallConv): LLVMValueRef;
    function CallVoid(const AFunction: LLVMValueRef; const AArgs: array of LLVMValueRef; 
      const ACallingConv: LLVMCallConv = LLVMCCallConv): TCPIRContext;
    function IndirectCall(const AFunctionPtr: LLVMValueRef; const AFunctionType: LLVMTypeRef; const AArgs: array of LLVMValueRef; 
      const ACallingConv: LLVMCallConv = LLVMCCallConv): LLVMValueRef;

    // Miscellaneous Operations
    function Select(const ACondition: LLVMValueRef; const ATrueValue: LLVMValueRef; const AFalseValue: LLVMValueRef): LLVMValueRef;
    function InlineAsm(const AFunctionType: LLVMTypeRef; const AAsmCode: string; const AConstraints: string; 
      const AHasSideEffects: Boolean = True; const AIsAlignStack: Boolean = False): LLVMValueRef;

    // Memory Intrinsics
    function MemCpy(const ADest: LLVMValueRef; const ASource: LLVMValueRef; const ASize: LLVMValueRef; const AAlign: Integer = 1): TCPIRContext;
    function MemSet(const ADest: LLVMValueRef; const AValue: LLVMValueRef; const ASize: LLVMValueRef; const AAlign: Integer = 1): TCPIRContext;
    function MemMove(const ADest: LLVMValueRef; const ASource: LLVMValueRef; const ASize: LLVMValueRef; const AAlign: Integer = 1): TCPIRContext;

    // Utility Methods
    function Comment(const AComment: string): TCPIRContext;
    function GetStringReference(const AValue: string): LLVMValueRef;
    function CreateBasicBlock(const AName: string; const AFunction: LLVMValueRef = nil): LLVMBasicBlockRef;
    function GetFunctionType(const AFunction: LLVMValueRef): LLVMTypeRef;

    // Module Access
    function GetModule: LLVMModuleRef;
    function ExtractModule: LLVMModuleRef;
    function Clear: TCPIRContext;
    function GetIR: string;

    // Properties
    property Module: LLVMModuleRef read FModule;
    property Context: LLVMContextRef read FContext;
    property Builder: LLVMBuilderRef read FBuilder;
    property CurrentFunction: LLVMValueRef read FCurrentFunction;
    property CurrentBlock: LLVMBasicBlockRef read FCurrentBlock;
  end;

implementation

{ TCPIRContext }
constructor TCPIRContext.Create(const AModuleName: string; const AContext: LLVMContextRef);
begin
  inherited Create;
  
  FModuleName := AModuleName;
  FTargetTriple := '';
  FDataLayout := '';
  FCurrentFunction := nil;
  FCurrentBlock := nil;
  FRegisterCount := 0;
  FLabelCount := 0;
  FStringLiteralCount := 0;
  FGlobalCount := 0;
  FStringConstants := TDictionary<string, LLVMValueRef>.Create;

  if AContext <> nil then
  begin
    FContext := AContext;
    FOwnsContext := False;
  end
  else
  begin
    FContext := LLVMContextCreate();
    FOwnsContext := True;
  end;

  if FContext = nil then
    raise ECPException.Create(
      RSIRContextCreationFailed,
      [],
      RSIRContextContextCreationNil,
      RSIRSuggestCheckLLVMInstallation
    );

  FModule := LLVMModuleCreateWithNameInContext(PUTF8Char(UTF8String(AModuleName)), FContext);
  if FModule = nil then
    raise ECPException.Create(
      Format(RSIRModuleCreationFailed, [AModuleName]),
      [AModuleName],
      RSIRContextModuleCreationNil,
      RSIRSuggestCheckLLVMContext
    );

  FBuilder := LLVMCreateBuilderInContext(FContext);
  if FBuilder = nil then
    raise ECPException.Create(
      RSIRBuilderCreationFailed,
      [],
      RSIRContextBuilderCreationNil,
      RSIRSuggestCheckLLVMContext
    );
end;

destructor TCPIRContext.Destroy;
begin
  FStringConstants.Free;

  if FBuilder <> nil then
    LLVMDisposeBuilder(FBuilder);

  if FModule <> nil then
    LLVMDisposeModule(FModule);

  if FOwnsContext and (FContext <> nil) then
    LLVMContextDispose(FContext);

  inherited;
end;

function TCPIRContext.GetNextRegister: string;
begin
  Inc(FRegisterCount);
  Result := IntToStr(FRegisterCount);  // LLVM adds % automatically
  Result := '';
end;

function TCPIRContext.GetNextStringLiteral: string;
begin
  Inc(FStringLiteralCount);
  if FStringLiteralCount = 1 then
    Result := '@.str'
  else
    Result := '@.str.' + IntToStr(FStringLiteralCount - 1);
end;

function TCPIRContext.GetNextGlobal: string;
begin
  Inc(FGlobalCount);
  Result := '@global' + IntToStr(FGlobalCount);
end;

function TCPIRContext.CreateStringConstant(const AValue: string): LLVMValueRef;
var
  LCleanString: string;
  LEscapedValue: UTF8String;
  LLength: Integer;
  LArrayType: LLVMTypeRef;
  LInitializer: LLVMValueRef;
  LGlobalName: string;
begin
  if FStringConstants.ContainsKey(AValue) then
  begin
    Result := FStringConstants[AValue];
    Exit;
  end;

  // Process string: remove quotes and add null terminator
  LCleanString := AValue;
  if (LCleanString.Length >= 2) and (LCleanString[1] = '"') and (LCleanString[LCleanString.Length] = '"') then
    LCleanString := LCleanString.Substring(1, LCleanString.Length - 2);
  
  LCleanString := LCleanString.Replace('\n', #10);
  LCleanString := LCleanString.Replace('\r', #13);
  LCleanString := LCleanString.Replace('\t', #9);
  LCleanString := LCleanString.Replace('\\', '\');
  LCleanString := LCleanString.Replace('\"', '"');
  LCleanString := LCleanString + #0; // Null terminate
  
  LEscapedValue := UTF8String(LCleanString);
  LLength := Length(LEscapedValue);

  // Create array type for string
  LArrayType := LLVMArrayType(LLVMInt8TypeInContext(FContext), LLength);
  
  // Create string constant
  LInitializer := LLVMConstStringInContext(FContext, PUTF8Char(LEscapedValue), LLength - 1, LLVMBool(0)); // Don't include null in count

  // Generate unique global name
  LGlobalName := GetNextStringLiteral;

  // Create global constant
  Result := LLVMAddGlobal(FModule, LArrayType, PUTF8Char(UTF8String(LGlobalName.Substring(1)))); // Remove @ prefix
  LLVMSetInitializer(Result, LInitializer);
  LLVMSetLinkage(Result, LLVMPrivateLinkage);
  LLVMSetGlobalConstant(Result, LLVMBool(1));
  LLVMSetUnnamedAddr(Result, LLVMGlobalUnnamedAddr);

  // Cache for reuse
  FStringConstants.Add(AValue, Result);
end;

procedure TCPIRContext.ValidateModuleState(const AOperation: string);
begin
  if FModule = nil then
    raise ECPException.Create(
      Format(RSIRCannotPerformNoModule, [AOperation]),
      [AOperation],
      RSIRContextModuleIsNil,
      RSIRSuggestEnsureBuilderConstructed
    );
end;

procedure TCPIRContext.ValidateFunctionState(const AOperation: string);
begin
  ValidateModuleState(AOperation);
  
  if FCurrentFunction = nil then
    raise ECPException.Create(
      Format(RSIRCannotPerformNoFunction, [AOperation]),
      [AOperation],
      RSIRContextNoFunctionBuilding,
      RSIRSuggestCallBeginFunction
    );
end;

procedure TCPIRContext.ValidateBlockState(const AOperation: string);
begin
  ValidateFunctionState(AOperation);
  
  if FCurrentBlock = nil then
    raise ECPException.Create(
      Format(RSIRCannotPerformNoBlock, [AOperation]),
      [AOperation],
      RSIRContextNoBlockActive,
      RSIRSuggestCallBasicBlock
    );
end;

function TCPIRContext.ModuleName(const AName: string): TCPIRContext;
begin
  ValidateModuleState('ModuleName');
  
  if Trim(AName) = '' then
    raise ECPException.Create(RSIRModuleNameEmpty, []);
    
  FModuleName := AName;
  LLVMSetModuleIdentifier(FModule, PUTF8Char(UTF8String(AName)), Length(UTF8String(AName)));
  
  Result := Self;
end;

function TCPIRContext.TargetTriple(const ATriple: string): TCPIRContext;
begin
  ValidateModuleState('TargetTriple');
  
  FTargetTriple := ATriple;
  if ATriple <> '' then
    LLVMSetTarget(FModule, PUTF8Char(UTF8String(ATriple)));
    
  Result := Self;
end;

function TCPIRContext.DataLayout(const ALayout: string): TCPIRContext;
begin
  ValidateModuleState('DataLayout');
  
  FDataLayout := ALayout;
  if ALayout <> '' then
    LLVMSetDataLayout(FModule, PUTF8Char(UTF8String(ALayout)));
    
  Result := Self;
end;

function TCPIRContext.VoidType: LLVMTypeRef;
begin
  Result := LLVMVoidTypeInContext(FContext);
end;

function TCPIRContext.BoolType: LLVMTypeRef;
begin
  Result := LLVMInt1TypeInContext(FContext);
end;

function TCPIRContext.Int1Type: LLVMTypeRef;
begin
  Result := LLVMInt1TypeInContext(FContext);
end;

function TCPIRContext.Int8Type: LLVMTypeRef;
begin
  Result := LLVMInt8TypeInContext(FContext);
end;

function TCPIRContext.Int16Type: LLVMTypeRef;
begin
  Result := LLVMInt16TypeInContext(FContext);
end;

function TCPIRContext.Int32Type: LLVMTypeRef;
begin
  Result := LLVMInt32TypeInContext(FContext);
end;

function TCPIRContext.Int64Type: LLVMTypeRef;
begin
  Result := LLVMInt64TypeInContext(FContext);
end;

function TCPIRContext.FloatType: LLVMTypeRef;
begin
  Result := LLVMFloatTypeInContext(FContext);
end;

function TCPIRContext.DoubleType: LLVMTypeRef;
begin
  Result := LLVMDoubleTypeInContext(FContext);
end;

function TCPIRContext.IntPtrType: LLVMTypeRef;
var
  LTargetTriple: string;
  LArch: string;
  LDashPos: Integer;
begin
  LTargetTriple := FTargetTriple;
  if LTargetTriple = '' then
    CPGetLLVMPlatformTargetTriple();

  LDashPos := LTargetTriple.IndexOf('-');
  if LDashPos > 0 then
    LArch := LTargetTriple.Substring(0, LDashPos).ToLower
  else
    LArch := LTargetTriple.ToLower;
    
  if (LArch = 'x86_64') or (LArch = 'aarch64') or (LArch = 'x64') or LArch.Contains('64') then
    Result := LLVMInt64TypeInContext(FContext)
  else if (LArch = 'i386') or (LArch = 'i586') or (LArch = 'i686') or (LArch = 'arm') or LArch.Contains('32') then
    Result := LLVMInt32TypeInContext(FContext)
  else
    Result := LLVMInt64TypeInContext(FContext);
end;

function TCPIRContext.PointerType(const APointedType: LLVMTypeRef): LLVMTypeRef;
begin
  Result := LLVMPointerType(APointedType, 0);
end;

function TCPIRContext.ArrayType(const AElementType: LLVMTypeRef; const ASize: Cardinal): LLVMTypeRef;
begin
  Result := LLVMArrayType(AElementType, ASize);
end;

function TCPIRContext.StructType(const AFields: array of LLVMTypeRef; const APacked: Boolean): LLVMTypeRef;
var
  LFieldsArray: array of LLVMTypeRef;
  I: Integer;
begin
  SetLength(LFieldsArray, Length(AFields));
  for I := 0 to Length(AFields) - 1 do
    LFieldsArray[I] := AFields[I];
    
  if Length(LFieldsArray) > 0 then
    Result := LLVMStructTypeInContext(FContext, @LFieldsArray[0], Length(LFieldsArray), LLVMBool(IfThen(APacked, 1, 0)))
  else
    Result := LLVMStructTypeInContext(FContext, nil, 0, LLVMBool(IfThen(APacked, 1, 0)));
end;

function TCPIRContext.FunctionType(const AReturnType: LLVMTypeRef; const AParams: array of LLVMTypeRef; const AVarArgs: Boolean): LLVMTypeRef;
var
  LParamsArray: array of LLVMTypeRef;
  I: Integer;
begin
  SetLength(LParamsArray, Length(AParams));
  for I := 0 to Length(AParams) - 1 do
    LParamsArray[I] := AParams[I];
    
  if Length(LParamsArray) > 0 then
    Result := LLVMFunctionType(AReturnType, @LParamsArray[0], Length(LParamsArray), LLVMBool(IfThen(AVarArgs, 1, 0)))
  else
    Result := LLVMFunctionType(AReturnType, nil, 0, LLVMBool(IfThen(AVarArgs, 1, 0)));
end;

function TCPIRContext.ConstNull(const AType: LLVMTypeRef): LLVMValueRef;
begin
  Result := LLVMConstNull(AType);
end;

function TCPIRContext.ConstUndef(const AType: LLVMTypeRef): LLVMValueRef;
begin
  Result := LLVMGetUndef(AType);
end;

function TCPIRContext.ConstBool(const AValue: Boolean): LLVMValueRef;
begin
  Result := LLVMConstInt(LLVMInt1TypeInContext(FContext), UInt64(IfThen(AValue, 1, 0)), LLVMBool(0));
end;

function TCPIRContext.ConstInt1(const AValue: Boolean): LLVMValueRef;
begin
  Result := LLVMConstInt(LLVMInt1TypeInContext(FContext), UInt64(IfThen(AValue, 1, 0)), LLVMBool(0));
end;

function TCPIRContext.ConstInt8(const AValue: Byte): LLVMValueRef;
begin
  Result := LLVMConstInt(LLVMInt8TypeInContext(FContext), UInt64(AValue), LLVMBool(0));
end;

function TCPIRContext.ConstInt16(const AValue: Word): LLVMValueRef;
begin
  Result := LLVMConstInt(LLVMInt16TypeInContext(FContext), UInt64(AValue), LLVMBool(0));
end;

function TCPIRContext.ConstInt32(const AValue: Integer): LLVMValueRef;
begin
  Result := LLVMConstInt(LLVMInt32TypeInContext(FContext), UInt64(Cardinal(AValue)), LLVMBool(0));
end;

function TCPIRContext.ConstInt64(const AValue: Int64): LLVMValueRef;
begin
  Result := LLVMConstInt(LLVMInt64TypeInContext(FContext), UInt64(AValue), LLVMBool(0));
end;

function TCPIRContext.ConstFloat(const AValue: Single): LLVMValueRef;
begin
  Result := LLVMConstReal(LLVMFloatTypeInContext(FContext), AValue);
end;

function TCPIRContext.ConstDouble(const AValue: Double): LLVMValueRef;
begin
  Result := LLVMConstReal(LLVMDoubleTypeInContext(FContext), AValue);
end;

function TCPIRContext.ConstString(const AValue: string): LLVMValueRef;
begin
  Result := CreateStringConstant(AValue);
end;

function TCPIRContext.ConstArray(const AType: LLVMTypeRef; const AElements: array of LLVMValueRef): LLVMValueRef;
var
  LElementsArray: array of LLVMValueRef;
  I: Integer;
begin
  SetLength(LElementsArray, Length(AElements));
  for I := 0 to Length(AElements) - 1 do
    LElementsArray[I] := AElements[I];
    
  if Length(LElementsArray) > 0 then
    Result := LLVMConstArray(AType, @LElementsArray[0], Length(LElementsArray))
  else
    Result := LLVMConstArray(AType, nil, 0);
end;

function TCPIRContext.ConstStruct(const AElements: array of LLVMValueRef; const APacked: Boolean): LLVMValueRef;
var
  LElementsArray: array of LLVMValueRef;
  I: Integer;
begin
  SetLength(LElementsArray, Length(AElements));
  for I := 0 to Length(AElements) - 1 do
    LElementsArray[I] := AElements[I];
    
  if Length(LElementsArray) > 0 then
    Result := LLVMConstStructInContext(FContext, @LElementsArray[0], Length(LElementsArray), LLVMBool(IfThen(APacked, 1, 0)))
  else
    Result := LLVMConstStructInContext(FContext, nil, 0, LLVMBool(IfThen(APacked, 1, 0)));
end;

function TCPIRContext.DeclareGlobal(const AName: string; const AType: LLVMTypeRef; const AInitializer: LLVMValueRef;
  const ALinkage: LLVMLinkage): LLVMValueRef;
var
  LGlobalName: string;
begin
  ValidateModuleState('DeclareGlobal');
  
  if AName <> '' then
    LGlobalName := AName
  else
    LGlobalName := GetNextGlobal.Substring(1); // Remove @ prefix
    
  Result := LLVMAddGlobal(FModule, AType, PUTF8Char(UTF8String(LGlobalName)));
  
  if AInitializer <> nil then
    LLVMSetInitializer(Result, AInitializer)
  else
    LLVMSetInitializer(Result, LLVMGetUndef(AType));
    
  LLVMSetLinkage(Result, ALinkage);
end;

function TCPIRContext.DeclareFunction(const AName: string; const AFunctionType: LLVMTypeRef;
  const ACallingConv: LLVMCallConv; const ALinkage: LLVMLinkage): LLVMValueRef;
begin
  ValidateModuleState('DeclareFunction');
  
  Result := LLVMAddFunction(FModule, PUTF8Char(UTF8String(AName)), AFunctionType);
  LLVMSetLinkage(Result, ALinkage);
  LLVMSetFunctionCallConv(Result, ACallingConv);
end;

function TCPIRContext.DeclareExternalFunction(const AName: string; const AReturnType: LLVMTypeRef; const ALibrary: string;
  const AParams: array of LLVMTypeRef; const ACallingConv: LLVMCallConv; const AVarArgs: Boolean): LLVMValueRef;
var
  LFunctionType: LLVMTypeRef;
begin
  LFunctionType := FunctionType(AReturnType, AParams, AVarArgs);
  Result := DeclareFunction(AName, LFunctionType, ACallingConv, LLVMExternalLinkage);
end;

function TCPIRContext.BeginFunction(const AName: string; const AFunctionType: LLVMTypeRef;
  const ACallingConv: LLVMCallConv; const ALinkage: LLVMLinkage): TCPIRContext;
begin
  ValidateModuleState('BeginFunction');
  
  if Trim(AName) = '' then
    raise ECPException.Create(RSIRFunctionNameEmpty, []);
    
  FCurrentFunction := LLVMAddFunction(FModule, PUTF8Char(UTF8String(AName)), AFunctionType);
  LLVMSetLinkage(FCurrentFunction, ALinkage);
  LLVMSetFunctionCallConv(FCurrentFunction, ACallingConv);
  
  FCurrentBlock := nil;
  
  Result := Self;
end;

function TCPIRContext.AddFunctionAttribute(const AAttribute: LLVMAttributeRef): TCPIRContext;
begin
  ValidateFunctionState('AddFunctionAttribute');

  LLVMAddAttributeAtIndex(FCurrentFunction, LLVMAttributeFunctionIndex, AAttribute);

  Result := Self;
end;

function TCPIRContext.EndFunction: TCPIRContext;
begin
  ValidateFunctionState('EndFunction');
  
  FCurrentFunction := nil;
  FCurrentBlock := nil;
  
  Result := Self;
end;

function TCPIRContext.BasicBlock(const AName: string): TCPIRContext;
var
  LBlock: LLVMBasicBlockRef;
begin
  ValidateFunctionState('BasicBlock');
  
  if Trim(AName) = '' then
    raise ECPException.Create(RSIRBasicBlockNameEmpty, []);
    
  LBlock := LLVMAppendBasicBlockInContext(FContext, FCurrentFunction, PUTF8Char(UTF8String(AName)));
  FCurrentBlock := LBlock;
  LLVMPositionBuilderAtEnd(FBuilder, LBlock);
  
  Result := Self;
end;

function TCPIRContext.CreateLabel(const APrefix: string): string;
begin
  Inc(FLabelCount);
  Result := APrefix + IntToStr(FLabelCount);
end;

function TCPIRContext.CreateBasicBlock(const AName: string; const AFunction: LLVMValueRef): LLVMBasicBlockRef;
var
  LFunction: LLVMValueRef;
begin
  ValidateModuleState('CreateBasicBlock');
  
  if AFunction <> nil then
    LFunction := AFunction
  else
  begin
    ValidateFunctionState('CreateBasicBlock');
    LFunction := FCurrentFunction;
  end;
    
  Result := LLVMAppendBasicBlockInContext(FContext, LFunction, PUTF8Char(UTF8String(AName)));
end;

function TCPIRContext.Alloca(const AType: LLVMTypeRef; const AArraySize: LLVMValueRef; const AAlignment: Integer): LLVMValueRef;
begin
  ValidateBlockState('Alloca');
  
  if AArraySize <> nil then
    Result := LLVMBuildArrayAlloca(FBuilder, AType, AArraySize, CPAsUTF8(GetNextRegister()))
  else
    Result := LLVMBuildAlloca(FBuilder, AType, CPAsUTF8(GetNextRegister()));
    
  if AAlignment > 0 then
    LLVMSetAlignment(Result, Cardinal(AAlignment));
end;

function TCPIRContext.Load(const APtr: LLVMValueRef; const AType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('Load');
  
  Result := LLVMBuildLoad2(FBuilder, AType, APtr, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.Store(const AValue: LLVMValueRef; const APtr: LLVMValueRef; const AAlignment: Integer): TCPIRContext;
var
  LStoreInst: LLVMValueRef;
begin
  ValidateBlockState('Store');
  
  LStoreInst := LLVMBuildStore(FBuilder, AValue, APtr);
  
  if AAlignment > 0 then
    LLVMSetAlignment(LStoreInst, Cardinal(AAlignment));
    
  Result := Self;
end;

function TCPIRContext.GEP(const APtr: LLVMValueRef; const AIndices: array of LLVMValueRef): LLVMValueRef;
var
  LIndicesArray: array of LLVMValueRef;
  LElementType: LLVMTypeRef;
  I: Integer;
begin
  ValidateBlockState('GEP');
  
  SetLength(LIndicesArray, Length(AIndices));
  for I := 0 to Length(AIndices) - 1 do
    LIndicesArray[I] := AIndices[I];
  
  // Use i8 as default element type for opaque pointers
  LElementType := LLVMInt8TypeInContext(FContext);
    
  if Length(LIndicesArray) > 0 then
    Result := LLVMBuildGEP2(FBuilder, LElementType, APtr, @LIndicesArray[0], Length(LIndicesArray), CPAsUTF8(GetNextRegister()))
  else
    Result := LLVMBuildGEP2(FBuilder, LElementType, APtr, nil, 0, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.ExtractValue(const AValue: LLVMValueRef; const AIndices: array of Integer): LLVMValueRef;
var
  V: LLVMValueRef;
  I: Integer;
  LIdx: Cardinal;
  LName: string;
begin
  ValidateBlockState('ExtractValue');

  if Length(AIndices) = 0 then
    Exit(AValue);

  V := AValue;
  for I := 0 to High(AIndices) do
  begin
    LIdx := Cardinal(AIndices[I]);
    if I = High(AIndices) then
      LName := GetNextRegister()
    else
      LName := '';
    V := LLVMBuildExtractValue(FBuilder, V, LIdx, CPAsUTF8(LName));
  end;

  Result := V;
end;

function TCPIRContext.InsertValue(const AAggregate: LLVMValueRef; const AValue: LLVMValueRef; const AIndices: array of Integer): LLVMValueRef;
var
  LDepth, I: Integer;
  LIdx: Cardinal;
  LCurAgg: LLVMValueRef;
  LAggStack: array of LLVMValueRef;
  LName: string;
begin
  ValidateBlockState('InsertValue');

  LDepth := Length(AIndices);
  if LDepth = 0 then
    Exit(AAggregate);

  if LDepth = 1 then
  begin
    LIdx := Cardinal(AIndices[0]);
    Result := LLVMBuildInsertValue(FBuilder, AAggregate, AValue, LIdx, CPAsUTF8(GetNextRegister()));
    Exit;
  end;

  // descend: keep aggregates on the path
  SetLength(LAggStack, LDepth - 1);
  LCurAgg := AAggregate;
  for I := 0 to LDepth - 2 do
  begin
    LAggStack[I] := LCurAgg;
    LIdx := Cardinal(AIndices[I]);
    LCurAgg := LLVMBuildExtractValue(FBuilder, LCurAgg, LIdx, nil);
  end;

  // insert into the innermost aggregate
  LIdx := Cardinal(AIndices[LDepth - 1]);
  LCurAgg := LLVMBuildInsertValue(FBuilder, LCurAgg, AValue, LIdx, nil);

  // ascend: rebuild aggregates back to the root
  for I := LDepth - 2 downto 0 do
  begin
    LIdx := Cardinal(AIndices[I]);
    if I = 0 then
      LName := GetNextRegister()
    else
      LName := '';
    LCurAgg := LLVMBuildInsertValue(FBuilder, LAggStack[I], LCurAgg, LIdx, CPAsUTF8(LName));
  end;

  Result := LCurAgg;
end;

function TCPIRContext.Add(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('Add');
  
  Result := LLVMBuildAdd(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.Sub(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('Sub');

  Result := LLVMBuildSub(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.Mul(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('Mul');
  
  Result := LLVMBuildMul(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.UDiv(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('UDiv');
  
  Result := LLVMBuildUDiv(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.SDiv(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('SDiv');
  
  Result := LLVMBuildSDiv(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.URem(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('URem');
  
  Result := LLVMBuildURem(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.SRem(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('SRem');
  
  Result := LLVMBuildSRem(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FAdd(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('FAdd');
  
  Result := LLVMBuildFAdd(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FSub(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('FSub');
  
  Result := LLVMBuildFSub(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FMul(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('FMul');
  
  Result := LLVMBuildFMul(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FDiv(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('FDiv');
  
  Result := LLVMBuildFDiv(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FRem(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('FRem');
  
  Result := LLVMBuildFRem(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.BitwiseAnd(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('BitwiseAnd');
  
  Result := LLVMBuildAnd(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.BitwiseOr(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('BitwiseOr');
  
  Result := LLVMBuildOr(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.BitwiseXor(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('BitwiseXor');
  
  Result := LLVMBuildXor(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.ShiftLeft(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('ShiftLeft');
  
  Result := LLVMBuildShl(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.LShr(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('LShr');
  
  Result := LLVMBuildLShr(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.AShr(const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('AShr');
  
  Result := LLVMBuildAShr(FBuilder, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.ROL(const AValue: LLVMValueRef; const AAmount: LLVMValueRef): LLVMValueRef;
var
  LModule: LLVMModuleRef;
  LIntrinsic: LLVMValueRef;
  LArgs: array[0..2] of LLVMValueRef;
  LValueType: LLVMTypeRef;
  LIntrinsicID: Cardinal;
begin
  ValidateBlockState('ROL');
  
  LValueType := LLVMTypeOf(AValue);
  LModule := FModule;
  
  // Get the fshl intrinsic ID
  LIntrinsicID := LLVMLookupIntrinsicID('llvm.fshl', 9);
  
  // Get the intrinsic declaration
  LIntrinsic := LLVMGetIntrinsicDeclaration(LModule, LIntrinsicID, @LValueType, 1);
  
  // Arguments: (value, value, amount) - same value twice for rotate
  LArgs[0] := AValue;
  LArgs[1] := AValue; 
  LArgs[2] := AAmount;
  
  Result := LLVMBuildCall2(FBuilder, LLVMGlobalGetValueType(LIntrinsic), 
    LIntrinsic, @LArgs[0], 3, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.ROR(const AValue: LLVMValueRef; const AAmount: LLVMValueRef): LLVMValueRef;
var
  LModule: LLVMModuleRef;
  LIntrinsic: LLVMValueRef;
  LArgs: array[0..2] of LLVMValueRef;
  LValueType: LLVMTypeRef;
  LIntrinsicID: Cardinal;
begin
  ValidateBlockState('ROR');
  
  LValueType := LLVMTypeOf(AValue);
  LModule := FModule;
  
  // Get the fshr intrinsic ID
  LIntrinsicID := LLVMLookupIntrinsicID('llvm.fshr', 9);
  
  // Get the intrinsic declaration
  LIntrinsic := LLVMGetIntrinsicDeclaration(LModule, LIntrinsicID, @LValueType, 1);
  
  // Arguments: (value, value, amount) - same value twice for rotate
  LArgs[0] := AValue;
  LArgs[1] := AValue;
  LArgs[2] := AAmount;
  
  Result := LLVMBuildCall2(FBuilder, LLVMGlobalGetValueType(LIntrinsic),
    LIntrinsic, @LArgs[0], 3, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.ICmp(const ACondition: LLVMIntPredicate; const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('ICmp');
  
  Result := LLVMBuildICmp(FBuilder, ACondition, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FCmp(const ACondition: LLVMRealPredicate; const ALeft: LLVMValueRef; const ARight: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('FCmp');
  
  Result := LLVMBuildFCmp(FBuilder, ACondition, ALeft, ARight, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.Trunc(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('Trunc');
  
  Result := LLVMBuildTrunc(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.ZExt(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('ZExt');
  
  Result := LLVMBuildZExt(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.SExt(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('SExt');
  
  Result := LLVMBuildSExt(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FPTrunc(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('FPTrunc');
  
  Result := LLVMBuildFPTrunc(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FPExt(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('FPExt');
  
  Result := LLVMBuildFPExt(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FPToUI(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('FPToUI');
  
  Result := LLVMBuildFPToUI(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.FPToSI(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('FPToSI');
  
  Result := LLVMBuildFPToSI(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.UIToFP(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('UIToFP');
  
  Result := LLVMBuildUIToFP(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.SIToFP(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('SIToFP');

  Result := LLVMBuildSIToFP(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.PtrToInt(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('PtrToInt');
  
  Result := LLVMBuildPtrToInt(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.IntToPtr(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('IntToPtr');
  
  Result := LLVMBuildIntToPtr(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.BitCast(const AValue: LLVMValueRef; const ATargetType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('BitCast');
  
  Result := LLVMBuildBitCast(FBuilder, AValue, ATargetType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.Br(const ATarget: LLVMBasicBlockRef): TCPIRContext;
begin
  ValidateBlockState('Br');
  
  LLVMBuildBr(FBuilder, ATarget);
  
  Result := Self;
end;

function TCPIRContext.CondBr(const ACondition: LLVMValueRef; const ATrueTarget: LLVMBasicBlockRef; const AFalseTarget: LLVMBasicBlockRef): TCPIRContext;
begin
  ValidateBlockState('CondBr');
  
  LLVMBuildCondBr(FBuilder, ACondition, ATrueTarget, AFalseTarget);
  
  Result := Self;
end;

function TCPIRContext.Switch(const AValue: LLVMValueRef; const ADefaultTarget: LLVMBasicBlockRef): LLVMValueRef;
begin
  ValidateBlockState('Switch');
  
  Result := LLVMBuildSwitch(FBuilder, AValue, ADefaultTarget, 0);
end;

function TCPIRContext.AddSwitchCase(const ASwitchInst: LLVMValueRef; const AValue: LLVMValueRef; const ATarget: LLVMBasicBlockRef): TCPIRContext;
begin
  ValidateBlockState('AddSwitchCase');
  
  LLVMAddCase(ASwitchInst, AValue, ATarget);
  
  Result := Self;
end;

function TCPIRContext.Ret(const AValue: LLVMValueRef): TCPIRContext;
begin
  ValidateBlockState('Ret');
  
  if AValue <> nil then
    LLVMBuildRet(FBuilder, AValue)
  else
    LLVMBuildRetVoid(FBuilder);
    
  Result := Self;
end;

function TCPIRContext.RetVoid: TCPIRContext;
begin
  ValidateBlockState('RetVoid');
  
  LLVMBuildRetVoid(FBuilder);
  
  Result := Self;
end;

function TCPIRContext.Phi(const AType: LLVMTypeRef): LLVMValueRef;
begin
  ValidateBlockState('Phi');
  
  Result := LLVMBuildPhi(FBuilder, AType, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.AddPhiIncoming(const APhiNode: LLVMValueRef; const AValue: LLVMValueRef; const ABlock: LLVMBasicBlockRef): TCPIRContext;
var
  LValues: array[0..0] of LLVMValueRef;
  LBlocks: array[0..0] of LLVMBasicBlockRef;
begin
  ValidateBlockState('AddPhiIncoming');
  
  LValues[0] := AValue;
  LBlocks[0] := ABlock;
  
  LLVMAddIncoming(APhiNode, @LValues[0], @LBlocks[0], 1);
  
  Result := Self;
end;

function TCPIRContext.Call(const AFunction: LLVMValueRef; const AArgs: array of LLVMValueRef;
  const ACallingConv: LLVMCallConv): LLVMValueRef;
var
  LArgsArray: array of LLVMValueRef;
  LFunctionType: LLVMTypeRef;
  I: Integer;
begin
  ValidateBlockState('Call');
  
  SetLength(LArgsArray, Length(AArgs));
  for I := 0 to Length(AArgs) - 1 do
    LArgsArray[I] := AArgs[I];
  
  LFunctionType := GetFunctionType(AFunction);
    
  if Length(LArgsArray) > 0 then
    Result := LLVMBuildCall2(FBuilder, LFunctionType, AFunction, @LArgsArray[0], Length(LArgsArray), CPAsUTF8(GetNextRegister()))
  else
    Result := LLVMBuildCall2(FBuilder, LFunctionType, AFunction, nil, 0, CPAsUTF8(GetNextRegister()));
    
  LLVMSetInstructionCallConv(Result, ACallingConv);
end;

function TCPIRContext.CallVoid(const AFunction: LLVMValueRef; const AArgs: array of LLVMValueRef;
  const ACallingConv: LLVMCallConv): TCPIRContext;
var
  LArgsArray: array of LLVMValueRef;
  LCallInst: LLVMValueRef;
  LFunctionType: LLVMTypeRef;
  I: Integer;
begin
  ValidateBlockState('CallVoid');
  
  SetLength(LArgsArray, Length(AArgs));
  for I := 0 to Length(AArgs) - 1 do
    LArgsArray[I] := AArgs[I];
  
  LFunctionType := GetFunctionType(AFunction);
    
  if Length(LArgsArray) > 0 then
    LCallInst := LLVMBuildCall2(FBuilder, LFunctionType, AFunction, @LArgsArray[0], Length(LArgsArray), '')
  else
    LCallInst := LLVMBuildCall2(FBuilder, LFunctionType, AFunction, nil, 0, '');
    
  LLVMSetInstructionCallConv(LCallInst, ACallingConv);
  
  Result := Self;
end;

function TCPIRContext.IndirectCall(const AFunctionPtr: LLVMValueRef; const AFunctionType: LLVMTypeRef; const AArgs: array of LLVMValueRef;
  const ACallingConv: LLVMCallConv): LLVMValueRef;
var
  LArgsArray: array of LLVMValueRef;
  I: Integer;
begin
  ValidateBlockState('IndirectCall');
  
  SetLength(LArgsArray, Length(AArgs));
  for I := 0 to Length(AArgs) - 1 do
    LArgsArray[I] := AArgs[I];
    
  if Length(LArgsArray) > 0 then
    Result := LLVMBuildCall2(FBuilder, AFunctionType, AFunctionPtr, @LArgsArray[0], Length(LArgsArray), CPAsUTF8(GetNextRegister()))
  else
    Result := LLVMBuildCall2(FBuilder, AFunctionType, AFunctionPtr, nil, 0, CPAsUTF8(GetNextRegister()));
    
  LLVMSetInstructionCallConv(Result, ACallingConv);
end;

function TCPIRContext.Select(const ACondition: LLVMValueRef; const ATrueValue: LLVMValueRef; const AFalseValue: LLVMValueRef): LLVMValueRef;
begin
  ValidateBlockState('Select');

  Result := LLVMBuildSelect(FBuilder, ACondition, ATrueValue, AFalseValue, CPAsUTF8(GetNextRegister()));
end;

function TCPIRContext.InlineAsm(const AFunctionType: LLVMTypeRef; const AAsmCode: string; const AConstraints: string;
  const AHasSideEffects: Boolean; const AIsAlignStack: Boolean): LLVMValueRef;
begin
  ValidateBlockState('InlineAsm');
  
  Result := LLVMGetInlineAsm(AFunctionType, PUTF8Char(UTF8String(AAsmCode)), Length(UTF8String(AAsmCode)),
    PUTF8Char(UTF8String(AConstraints)), Length(UTF8String(AConstraints)), 
    LLVMBool(IfThen(AHasSideEffects, 1, 0)), LLVMBool(IfThen(AIsAlignStack, 1, 0)), LLVMInlineAsmDialectATT, LLVMBool(0));
end;

function TCPIRContext.MemCpy(const ADest: LLVMValueRef; const ASource: LLVMValueRef; const ASize: LLVMValueRef; const AAlign: Integer): TCPIRContext;
begin
  ValidateBlockState('MemCpy');
  
  LLVMBuildMemCpy(FBuilder, ADest, Cardinal(AAlign), ASource, Cardinal(AAlign), ASize);
  
  Result := Self;
end;

function TCPIRContext.MemSet(const ADest: LLVMValueRef; const AValue: LLVMValueRef; const ASize: LLVMValueRef; const AAlign: Integer): TCPIRContext;
begin
  ValidateBlockState('MemSet');
  
  LLVMBuildMemSet(FBuilder, ADest, AValue, ASize, Cardinal(AAlign));
  
  Result := Self;
end;

function TCPIRContext.MemMove(const ADest: LLVMValueRef; const ASource: LLVMValueRef; const ASize: LLVMValueRef; const AAlign: Integer): TCPIRContext;
begin
  ValidateBlockState('MemMove');
  
  LLVMBuildMemMove(FBuilder, ADest, Cardinal(AAlign), ASource, Cardinal(AAlign), ASize);
  
  Result := Self;
end;

function TCPIRContext.Comment(const AComment: string): TCPIRContext;
begin
  // LLVM API doesn't directly support comments in IR
  // Comments are typically added during text generation
  // For API-based building, we can optionally add metadata
  
  Result := Self;
end;

function TCPIRContext.GetStringReference(const AValue: string): LLVMValueRef;
var
  LStringGlobal: LLVMValueRef;
  LStringType: LLVMTypeRef;
  LIndices: array[0..1] of LLVMValueRef;
begin
  LStringGlobal := CreateStringConstant(AValue);
  LStringType := LLVMTypeOf(LStringGlobal);
  
  // Create GEP to get pointer to first character
  LIndices[0] := ConstInt32(0);
  LIndices[1] := ConstInt32(0);
  
  Result := LLVMConstGEP2(LStringType, LStringGlobal, @LIndices[0], 2);
end;

function TCPIRContext.GetModule: LLVMModuleRef;
begin
  Result := FModule;
end;

function TCPIRContext.ExtractModule: LLVMModuleRef;
begin
  Result := FModule;
  FModule := nil; // Transfer ownership to caller
end;

function TCPIRContext.Clear: TCPIRContext;
begin
  FStringConstants.Clear;
  FCurrentFunction := nil;
  FCurrentBlock := nil;
  FRegisterCount := 0;
  FLabelCount := 0;
  FStringLiteralCount := 0;
  FGlobalCount := 0;
  
  if FModule <> nil then
    LLVMDisposeModule(FModule);
    
  FModule := LLVMModuleCreateWithNameInContext(PUTF8Char(UTF8String(FModuleName)), FContext);
  
  Result := Self;
end;

function TCPIRContext.GetFunctionType(const AFunction: LLVMValueRef): LLVMTypeRef;
begin
  Result := LLVMGlobalGetValueType(AFunction);
end;

function TCPIRContext.GetIR: string;
var
  LIRString: PUTF8Char;
begin
  ValidateModuleState('GetIR');

  LIRString := LLVMPrintModuleToString(FModule);
  try
    Result := string(LIRString);
  finally
    LLVMDisposeMessage(LIRString);
  end;
end;

end.
