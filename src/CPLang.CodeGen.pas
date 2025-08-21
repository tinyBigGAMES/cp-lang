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

unit CPLang.CodeGen;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Platform,
  CPLang.Common,
  CPLang.Parser,
  CPLang.IRContext,
  CPLang.Errors,
  CPLang.LLVM;

type
  { TCPCodeGen }
  TCPCodeGen = class
  private
    FIRContext: TCPIRContext;
    FErrorCollector: TCPErrorCollector;
    FVariables: TDictionary<string, LLVMValueRef>;
    FFunctions: TDictionary<string, LLVMValueRef>;
    FCurrentFunction: LLVMValueRef;
    
    function GenerateNode(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateProgram(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateMainFunction(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateFunctionDecl(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateVariableDecl(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateStatementBlock(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateAssignment(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateIfStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateWhileStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateForStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateRepeatStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateCaseStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateReturnStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateCallStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateBreakStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateContinueStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateGotoStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateLabelStatement(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateExpression(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateIdentifier(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateLiteral(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateFunctionCall(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateBinaryOp(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateUnaryOp(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateArrayAccess(const ANode: TCPASTNode): LLVMValueRef;
    function GenerateMemberAccess(const ANode: TCPASTNode): LLVMValueRef;
    
    function MapType(const ATypeName: string): LLVMTypeRef;
    function ExtractTypeFromNode(const ANode: TCPASTNode): LLVMTypeRef;
    function IsOrdinalType(const AType: LLVMTypeRef): Boolean;
    function GetTypeName(const AType: LLVMTypeRef): string;
    procedure ReportError(const AMessage: string; const ANode: TCPASTNode);
    
  public
    constructor Create(const AErrorCollector: TCPErrorCollector; const AModuleName: string = 'cp_lang_module');
    destructor Destroy(); override;
    
    function Generate(const AAST: TCPASTNode): string;
    
    property IRContext: TCPIRContext read FIRContext;
  end;

implementation

{ TCPCodeGen }

constructor TCPCodeGen.Create(const AErrorCollector: TCPErrorCollector; const AModuleName: string);
begin
  inherited Create();
  FErrorCollector := AErrorCollector;

  FIRContext := TCPIRContext.Create(AModuleName);
  FIRContext.TargetTriple(CPGetLLVMPlatformTargetTriple());
  FIRContext.DataLayout(CPGetLLVMPlatformDataLayout());
  
  FVariables := TDictionary<string, LLVMValueRef>.Create();
  FFunctions := TDictionary<string, LLVMValueRef>.Create();
  FCurrentFunction := nil;
end;

destructor TCPCodeGen.Destroy();
begin
  FFunctions.Free();
  FVariables.Free();
  FIRContext.Free();

  inherited;
end;

function TCPCodeGen.Generate(const AAST: TCPASTNode): string;
begin
  GenerateNode(AAST);
  Result := FIRContext.GetIR();
end;

function TCPCodeGen.GenerateNode(const ANode: TCPASTNode): LLVMValueRef;
begin
  case ANode.NodeType of
    astProgram: Result := GenerateProgram(ANode);
    astMainFunction: Result := GenerateMainFunction(ANode);
    astFunctionDecl: Result := GenerateFunctionDecl(ANode);
    astVariableDecl: Result := GenerateVariableDecl(ANode);
    astStatementBlock: Result := GenerateStatementBlock(ANode);
    astAssignment: Result := GenerateAssignment(ANode);
    astIfStatement: Result := GenerateIfStatement(ANode);
    astWhileStatement: Result := GenerateWhileStatement(ANode);
    astForStatement: Result := GenerateForStatement(ANode);
    astRepeatStatement: Result := GenerateRepeatStatement(ANode);
    astCaseStatement: Result := GenerateCaseStatement(ANode);
    astReturnStatement: Result := GenerateReturnStatement(ANode);
    astCallStatement: Result := GenerateCallStatement(ANode);
    astBreakStatement: Result := GenerateBreakStatement(ANode);
    astContinueStatement: Result := GenerateContinueStatement(ANode);
    astGotoStatement: Result := GenerateGotoStatement(ANode);
    astLabelStatement: Result := GenerateLabelStatement(ANode);
    astExpression: Result := GenerateExpression(ANode);
    astBinaryOp: Result := GenerateBinaryOp(ANode);
    astUnaryOp: Result := GenerateUnaryOp(ANode);
    astIdentifier: Result := GenerateIdentifier(ANode);
    astLiteral: Result := GenerateLiteral(ANode);
    astFunctionCall: Result := GenerateFunctionCall(ANode);
    astArrayAccess: Result := GenerateArrayAccess(ANode);
    astMemberAccess: Result := GenerateMemberAccess(ANode);
  else
    Result := nil;
  end;
end;

function TCPCodeGen.GenerateProgram(const ANode: TCPASTNode): LLVMValueRef;
var
  I: Integer;
begin
  for I := 0 to ANode.ChildCount() - 1 do
    GenerateNode(ANode.GetChild(I));
  Result := nil;
end;

function TCPCodeGen.GenerateMainFunction(const ANode: TCPASTNode): LLVMValueRef;
var
  LMainType: LLVMTypeRef;
begin
  // main(): int32
  LMainType := FIRContext.FunctionType(FIRContext.Int32Type(), []);
  FIRContext.BeginFunction('main', LMainType);
  FCurrentFunction := FIRContext.CurrentFunction;
  FFunctions.AddOrSetValue('main', FCurrentFunction);
  
  FIRContext.BasicBlock('entry');
  
  // Generate body (child 1 is statement block)
  GenerateNode(ANode.GetChild(1));
  
  FIRContext.EndFunction();
  Result := FCurrentFunction;
end;

function TCPCodeGen.GenerateFunctionDecl(const ANode: TCPASTNode): LLVMValueRef;
var
  LHeader: TCPASTNode;
  LFunctionName: string;
  LIsExternal: Boolean;
  LIsVariadic: Boolean;
  LParameterList: TCPASTNode;
  LParameterTypes: TArray<LLVMTypeRef>;
  LParameterNames: TArray<string>;
  LReturnType: LLVMTypeRef;
  LFunctionType: LLVMTypeRef;
  I, J, K: Integer;
  LParamNode: TCPASTNode;
  LParamType: LLVMTypeRef;
  LParamName: string;
  LParam: LLVMValueRef;
  LAlloca: LLVMValueRef;
begin
  // Structure: function header + (body | external lib)
  LHeader := ANode.GetChild(0);
  LFunctionName := LHeader.GetChild(0).Value;
  LIsExternal := (ANode.ChildCount() = 2) and (ANode.GetChild(1).NodeType = astLiteral);
  
  // Extract parameters
  LParameterList := LHeader.GetChild(1);
  LIsVariadic := False;
  
  // Count non-variadic parameters
  J := 0;
  for I := 0 to LParameterList.ChildCount() - 1 do
  begin
    if (LParameterList.GetChild(I).NodeType = astParameterList) and 
       (LParameterList.GetChild(I).Value = '...') then
    begin
      LIsVariadic := True;
    end
    else
      Inc(J);
  end;
  
  SetLength(LParameterTypes, J);
  SetLength(LParameterNames, 0);
  
  // Extract parameter info
  J := 0;
  for I := 0 to LParameterList.ChildCount() - 1 do
  begin
    LParamNode := LParameterList.GetChild(I);
    
    if (LParamNode.NodeType = astParameterList) and (LParamNode.Value = '...') then
      Continue;
    
    // Last child is type, others are parameter names
    LParamType := ExtractTypeFromNode(LParamNode.GetChild(LParamNode.ChildCount() - 1));
    LParameterTypes[J] := LParamType;
    
    // Extract parameter names
    for K := 0 to LParamNode.ChildCount() - 2 do
    begin
      if LParamNode.GetChild(K).NodeType = astIdentifier then
      begin
        LParamName := LParamNode.GetChild(K).Value;
        SetLength(LParameterNames, Length(LParameterNames) + 1);
        LParameterNames[High(LParameterNames)] := LParamName;
      end;
    end;
    
    Inc(J);
  end;
  
  // Return type
  if (LHeader.Value = 'function') and (LHeader.ChildCount() = 3) then
    LReturnType := ExtractTypeFromNode(LHeader.GetChild(2))
  else
    LReturnType := FIRContext.VoidType();
  
  // Create function
  LFunctionType := FIRContext.FunctionType(LReturnType, LParameterTypes, LIsVariadic);
  
  if LIsExternal then
  begin
    Result := FIRContext.DeclareFunction(LFunctionName, LFunctionType);
  end
  else
  begin
    FIRContext.BeginFunction(LFunctionName, LFunctionType);
    Result := FIRContext.CurrentFunction;
    FCurrentFunction := Result;
    
    FIRContext.BasicBlock('entry');
    
    // Create parameter allocas
    for I := 0 to High(LParameterNames) do
    begin
      LParam := LLVMGetParam(Result, Cardinal(I));
      LAlloca := FIRContext.Alloca(LParameterTypes[I]);
      FIRContext.Store(LParam, LAlloca);
      FVariables.AddOrSetValue(LParameterNames[I], LAlloca);
    end;
    
    // Generate body
    GenerateNode(ANode.GetChild(1));
    
    FIRContext.EndFunction();
  end;
  
  FFunctions.AddOrSetValue(LFunctionName, Result);
end;

function TCPCodeGen.GenerateVariableDecl(const ANode: TCPASTNode): LLVMValueRef;
var
  I: Integer;
  LIdentifierCount: Integer;
  LVarName: string;
  LVarType: LLVMTypeRef;
  LAlloca: LLVMValueRef;
  LInitValue: LLVMValueRef;
begin
  // Structure: identifier+ type [init_expression]
  
  // Count identifiers
  LIdentifierCount := 0;
  for I := 0 to ANode.ChildCount() - 1 do
  begin
    if ANode.GetChild(I).NodeType = astIdentifier then
      Inc(LIdentifierCount);
  end;
  
  // Type is at index LIdentifierCount
  LVarType := ExtractTypeFromNode(ANode.GetChild(LIdentifierCount));
  
  // Process each identifier
  for I := 0 to LIdentifierCount - 1 do
  begin
    LVarName := ANode.GetChild(I).Value;
    LAlloca := FIRContext.Alloca(LVarType);
    FVariables.AddOrSetValue(LVarName, LAlloca);
    
    // Handle initialization (at index LIdentifierCount + 1)
    if ANode.ChildCount() > LIdentifierCount + 1 then
    begin
      LInitValue := GenerateNode(ANode.GetChild(LIdentifierCount + 1));
      FIRContext.Store(LInitValue, LAlloca);
    end;
  end;
  
  Result := nil;
end;

function TCPCodeGen.GenerateStatementBlock(const ANode: TCPASTNode): LLVMValueRef;
var
  I: Integer;
begin
  for I := 0 to ANode.ChildCount() - 1 do
    GenerateNode(ANode.GetChild(I));
  Result := nil;
end;

function TCPCodeGen.GenerateAssignment(const ANode: TCPASTNode): LLVMValueRef;
var
  LTarget: LLVMValueRef;
  LValue: LLVMValueRef;
  LVarName: string;
  LAlloca: LLVMValueRef;
begin
  // Structure: lvalue := expression
  
  // Simple identifier assignment
  if ANode.GetChild(0).NodeType = astIdentifier then
  begin
    LVarName := ANode.GetChild(0).Value;
    LAlloca := FVariables[LVarName];
    LValue := GenerateNode(ANode.GetChild(1));
    FIRContext.Store(LValue, LAlloca);
  end
  else
  begin
    // Complex lvalue - generate address
    LTarget := GenerateNode(ANode.GetChild(0));
    LValue := GenerateNode(ANode.GetChild(1));
    FIRContext.Store(LValue, LTarget);
  end;
  
  Result := nil;
end;

function TCPCodeGen.GenerateIfStatement(const ANode: TCPASTNode): LLVMValueRef;
var
  LCondition: LLVMValueRef;
  LThenBlock, LElseBlock, LMergeBlock: LLVMBasicBlockRef;
begin
  // Structure: condition then_stmt [else_stmt]
  
  LCondition := GenerateNode(ANode.GetChild(0));
  
  LThenBlock := FIRContext.CreateBasicBlock('if.then');
  LElseBlock := FIRContext.CreateBasicBlock('if.else');
  LMergeBlock := FIRContext.CreateBasicBlock('if.merge');
  
  FIRContext.CondBr(LCondition, LThenBlock, LElseBlock);
  
  // Then block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LThenBlock);
  GenerateNode(ANode.GetChild(1));
  FIRContext.Br(LMergeBlock);
  
  // Else block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LElseBlock);
  if ANode.ChildCount() = 3 then
    GenerateNode(ANode.GetChild(2));
  FIRContext.Br(LMergeBlock);
  
  // Merge
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LMergeBlock);
  Result := nil;
end;

function TCPCodeGen.GenerateWhileStatement(const ANode: TCPASTNode): LLVMValueRef;
var
  LCondition: LLVMValueRef;
  LHeaderBlock, LBodyBlock, LExitBlock: LLVMBasicBlockRef;
begin
  // Structure: condition do statement
  
  LHeaderBlock := FIRContext.CreateBasicBlock('while.header');
  LBodyBlock := FIRContext.CreateBasicBlock('while.body');
  LExitBlock := FIRContext.CreateBasicBlock('while.exit');
  
  FIRContext.Br(LHeaderBlock);
  
  // Header
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LHeaderBlock);
  LCondition := GenerateNode(ANode.GetChild(0));
  FIRContext.CondBr(LCondition, LBodyBlock, LExitBlock);
  
  // Body
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LBodyBlock);
  GenerateNode(ANode.GetChild(1));
  FIRContext.Br(LHeaderBlock);
  
  // Exit
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LExitBlock);
  Result := nil;
end;

function TCPCodeGen.GenerateForStatement(const ANode: TCPASTNode): LLVMValueRef;
var
  LLoopVar: string;
  LStartValue, LEndValue: LLVMValueRef;
  LLoopVarAlloca: LLVMValueRef;
  LCurrentValue, LNextValue: LLVMValueRef;
  LCondition: LLVMValueRef;
  LCondBlock, LBodyBlock, LIncrBlock, LExitBlock: LLVMBasicBlockRef;
  LIsUpward: Boolean;
  LVarType: LLVMTypeRef;
begin
  // Structure: variable start_expr end_expr body_stmt
  // Value contains "to" or "downto"
  
  LLoopVar := ANode.GetChild(0).Value;
  LIsUpward := (ANode.Value = 'to');
  
  // Get existing loop variable (must be declared before loop)
  if not FVariables.TryGetValue(LLoopVar, LLoopVarAlloca) then
  begin
    ReportError('Loop variable not declared: ' + LLoopVar, ANode);
    Exit(nil);
  end;
  
  // Validate loop variable type is ordinal
  LVarType := LLVMGetAllocatedType(LLoopVarAlloca);
  if not IsOrdinalType(LVarType) then
  begin
    ReportError('For-loop variable must be an ordinal type (integer or char), got: ' + GetTypeName(LVarType), ANode);
    Exit(nil);
  end;
  
  // Generate start and end values
  LStartValue := GenerateNode(ANode.GetChild(1));
  LEndValue := GenerateNode(ANode.GetChild(2));
  
  // Initialize loop variable
  FIRContext.Store(LStartValue, LLoopVarAlloca);
  
  // Create basic blocks
  LCondBlock := FIRContext.CreateBasicBlock('for.cond');
  LBodyBlock := FIRContext.CreateBasicBlock('for.body');
  LIncrBlock := FIRContext.CreateBasicBlock('for.incr');
  LExitBlock := FIRContext.CreateBasicBlock('for.exit');
  
  // Jump to condition
  FIRContext.Br(LCondBlock);
  
  // Condition block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LCondBlock);
  LCurrentValue := FIRContext.Load(LLoopVarAlloca, LVarType);
  
  if LIsUpward then
    LCondition := FIRContext.ICmp(LLVMIntSLE, LCurrentValue, LEndValue)
  else
    LCondition := FIRContext.ICmp(LLVMIntSGE, LCurrentValue, LEndValue);
    
  FIRContext.CondBr(LCondition, LBodyBlock, LExitBlock);
  
  // Body block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LBodyBlock);
  GenerateNode(ANode.GetChild(3));
  FIRContext.Br(LIncrBlock);
  
  // Increment block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LIncrBlock);
  LCurrentValue := FIRContext.Load(LLoopVarAlloca, LVarType);
  
  if LIsUpward then
    LNextValue := FIRContext.Add(LCurrentValue, LLVMConstInt(LVarType, 1, 0))
  else
    LNextValue := FIRContext.Sub(LCurrentValue, LLVMConstInt(LVarType, 1, 0));
    
  FIRContext.Store(LNextValue, LLoopVarAlloca);
  FIRContext.Br(LCondBlock);
  
  // Exit block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LExitBlock);
  
  Result := nil;
end;

function TCPCodeGen.GenerateRepeatStatement(const ANode: TCPASTNode): LLVMValueRef;
begin
  // TODO: Implement repeat loops
  Result := nil;
end;

function TCPCodeGen.GenerateCaseStatement(const ANode: TCPASTNode): LLVMValueRef;
begin
  // TODO: Implement case statements
  Result := nil;
end;

function TCPCodeGen.GenerateReturnStatement(const ANode: TCPASTNode): LLVMValueRef;
var
  LReturnValue: LLVMValueRef;
begin
  // Structure: [expression]
  
  if ANode.ChildCount() = 1 then
  begin
    LReturnValue := GenerateNode(ANode.GetChild(0));
    FIRContext.Ret(LReturnValue);
  end
  else
  begin
    FIRContext.RetVoid();
  end;
  
  Result := nil;
end;

function TCPCodeGen.GenerateCallStatement(const ANode: TCPASTNode): LLVMValueRef;
begin
  // Structure: expression
  Result := GenerateNode(ANode.GetChild(0));
end;

function TCPCodeGen.GenerateBreakStatement(const ANode: TCPASTNode): LLVMValueRef;
begin
  // TODO: Implement break
  Result := nil;
end;

function TCPCodeGen.GenerateContinueStatement(const ANode: TCPASTNode): LLVMValueRef;
begin
  // TODO: Implement continue
  Result := nil;
end;

function TCPCodeGen.GenerateGotoStatement(const ANode: TCPASTNode): LLVMValueRef;
begin
  // TODO: Implement goto
  Result := nil;
end;

function TCPCodeGen.GenerateLabelStatement(const ANode: TCPASTNode): LLVMValueRef;
begin
  // TODO: Implement labels
  Result := nil;
end;

function TCPCodeGen.GenerateExpression(const ANode: TCPASTNode): LLVMValueRef;
begin
  // Expression nodes wrap other expressions
  Result := GenerateNode(ANode.GetChild(0));
end;

function TCPCodeGen.GenerateIdentifier(const ANode: TCPASTNode): LLVMValueRef;
var
  LName: string;
  LAlloca: LLVMValueRef;
  LFunction: LLVMValueRef;
begin
  LName := ANode.Value;
  
  // Try variables
  if FVariables.TryGetValue(LName, LAlloca) then
  begin
    Result := FIRContext.Load(LAlloca, FIRContext.Int32Type());
    Exit;
  end;
  
  // Try functions
  if FFunctions.TryGetValue(LName, LFunction) then
  begin
    Result := LFunction;
    Exit;
  end;
  
  ReportError('Undefined identifier: ' + LName, ANode);
  Result := nil;
end;

function TCPCodeGen.GenerateLiteral(const ANode: TCPASTNode): LLVMValueRef;
var
  LValue: string;
  LIntValue: Integer;
  LFloatValue: Double;
begin
  LValue := ANode.Value;
  
  if LValue = 'true' then
    Result := FIRContext.ConstBool(True)
  else if LValue = 'false' then
    Result := FIRContext.ConstBool(False)
  else if (LValue.Length >= 2) and (LValue[1] = '"') then
    Result := FIRContext.GetStringReference(LValue)
  else if (LValue.Length >= 3) and (LValue[1] = '''') then
    Result := FIRContext.ConstInt8(Ord(LValue[2]))
  else if TryStrToInt(LValue, LIntValue) then
    Result := FIRContext.ConstInt32(LIntValue)
  else if TryStrToFloat(LValue, LFloatValue) then
    Result := FIRContext.ConstDouble(LFloatValue)
  else
  begin
    ReportError('Invalid literal: ' + LValue, ANode);
    Result := nil;
  end;
end;

function TCPCodeGen.GenerateFunctionCall(const ANode: TCPASTNode): LLVMValueRef;
var
  LFunctionName: string;
  LFunction: LLVMValueRef;
  LArgsNode: TCPASTNode;
  LArgs: TArray<LLVMValueRef>;
  I: Integer;
begin
  // Structure: function [arguments]
  
  LFunctionName := ANode.GetChild(0).Value;
  LFunction := FFunctions[LFunctionName];
  
  // Generate arguments
  if ANode.ChildCount() = 2 then
  begin
    LArgsNode := ANode.GetChild(1);
    SetLength(LArgs, LArgsNode.ChildCount());
    for I := 0 to LArgsNode.ChildCount() - 1 do
      LArgs[I] := GenerateNode(LArgsNode.GetChild(I));
  end
  else
    SetLength(LArgs, 0);
  
  Result := FIRContext.Call(LFunction, LArgs);
end;

function TCPCodeGen.GenerateBinaryOp(const ANode: TCPASTNode): LLVMValueRef;
var
  LLeft, LRight: LLVMValueRef;
  LOperator: string;
begin
  // Structure: left_operand right_operand
  
  LLeft := GenerateNode(ANode.GetChild(0));
  LRight := GenerateNode(ANode.GetChild(1));
  LOperator := ANode.Value;
  
  if LOperator = '+' then
    Result := FIRContext.Add(LLeft, LRight)
  else if LOperator = '-' then
    Result := FIRContext.Sub(LLeft, LRight)
  else if LOperator = '*' then
    Result := FIRContext.Mul(LLeft, LRight)
  else if LOperator = '/' then
    Result := FIRContext.SDiv(LLeft, LRight)
  else if LOperator = '=' then
    Result := FIRContext.ICmp(LLVMIntEQ, LLeft, LRight)
  else if LOperator = '<>' then
    Result := FIRContext.ICmp(LLVMIntNE, LLeft, LRight)
  else if LOperator = '<' then
    Result := FIRContext.ICmp(LLVMIntSLT, LLeft, LRight)
  else if LOperator = '>' then
    Result := FIRContext.ICmp(LLVMIntSGT, LLeft, LRight)
  else if LOperator = '<=' then
    Result := FIRContext.ICmp(LLVMIntSLE, LLeft, LRight)
  else if LOperator = '>=' then
    Result := FIRContext.ICmp(LLVMIntSGE, LLeft, LRight)
  else if LOperator = 'and' then
    Result := FIRContext.BitwiseAnd(LLeft, LRight)
  else if LOperator = 'or' then
    Result := FIRContext.BitwiseOr(LLeft, LRight)
  else if LOperator = 'mod' then
    Result := FIRContext.SRem(LLeft, LRight)
  else
    Result := nil;
end;

function TCPCodeGen.GenerateUnaryOp(const ANode: TCPASTNode): LLVMValueRef;
var
  LOperand: LLVMValueRef;
  LOperator: string;
begin
  // Structure: operand
  
  LOperand := GenerateNode(ANode.GetChild(0));
  LOperator := ANode.Value;
  
  if LOperator = '-' then
    Result := FIRContext.Sub(FIRContext.ConstInt32(0), LOperand)
  else if LOperator = '+' then
    Result := LOperand
  else if LOperator = 'not' then
    Result := FIRContext.BitwiseXor(LOperand, FIRContext.ConstBool(True))
  else if LOperator = '^' then
    Result := FIRContext.Load(LOperand, FIRContext.Int32Type())
  else
    Result := nil;
end;

function TCPCodeGen.GenerateArrayAccess(const ANode: TCPASTNode): LLVMValueRef;
var
  LArray, LIndex, LPtr: LLVMValueRef;
begin
  // Structure: array_expression index_expression
  
  LArray := GenerateNode(ANode.GetChild(0));
  LIndex := GenerateNode(ANode.GetChild(1));
  
  LPtr := FIRContext.GEP(LArray, [FIRContext.ConstInt32(0), LIndex]);
  Result := FIRContext.Load(LPtr, FIRContext.Int32Type());
end;

function TCPCodeGen.GenerateMemberAccess(const ANode: TCPASTNode): LLVMValueRef;
var
  LRecord: LLVMValueRef;
  LMemberName: string;
  LPtr: LLVMValueRef;
begin
  // Structure: record_expression member_identifier
  
  LRecord := GenerateNode(ANode.GetChild(0));
  LMemberName := ANode.GetChild(1).Value;
  
  // Simplified: assume field 0
  LPtr := FIRContext.GEP(LRecord, [FIRContext.ConstInt32(0), FIRContext.ConstInt32(0)]);
  Result := FIRContext.Load(LPtr, FIRContext.Int32Type());
end;

function TCPCodeGen.MapType(const ATypeName: string): LLVMTypeRef;
begin
  if (ATypeName = 'int') or (ATypeName = 'int32') then
    Result := FIRContext.Int32Type()
  else if ATypeName = 'char' then
    Result := FIRContext.Int8Type()
  else if ATypeName = 'bool' then
    Result := FIRContext.BoolType()
  else if ATypeName = 'float' then
    Result := FIRContext.FloatType()
  else if ATypeName = 'double' then
    Result := FIRContext.DoubleType()
  else if ATypeName = 'int8' then
    Result := FIRContext.Int8Type()
  else if ATypeName = 'int16' then
    Result := FIRContext.Int16Type()
  else if ATypeName = 'int64' then
    Result := FIRContext.Int64Type()
  else if ATypeName = 'uint8' then
    Result := FIRContext.Int8Type()
  else if ATypeName = 'uint16' then
    Result := FIRContext.Int16Type()
  else if ATypeName = 'uint32' then
    Result := FIRContext.Int32Type()
  else if ATypeName = 'uint64' then
    Result := FIRContext.Int64Type()
  else
    Result := FIRContext.Int32Type();
end;

function TCPCodeGen.ExtractTypeFromNode(const ANode: TCPASTNode): LLVMTypeRef;
begin
  if ANode.Value = '^' then
  begin
    // Pointer type: child 0 is target type
    Result := FIRContext.PointerType(ExtractTypeFromNode(ANode.GetChild(0)));
  end
  else if ANode.Value = 'array' then
  begin
    // Array type: child 0 is size (optional), last child is element type
    if ANode.ChildCount() = 1 then
      Result := FIRContext.PointerType(ExtractTypeFromNode(ANode.GetChild(0)))
    else
      Result := FIRContext.ArrayType(ExtractTypeFromNode(ANode.GetChild(ANode.ChildCount() - 1)), 100); // Default size
  end
  else
  begin
    // Basic type
    Result := MapType(ANode.Value);
  end;
end;

function TCPCodeGen.IsOrdinalType(const AType: LLVMTypeRef): Boolean;
var
  LKind: LLVMTypeKind;
  LBitWidth: Cardinal;
begin
  LKind := LLVMGetTypeKind(AType);
  
  if LKind = LLVMIntegerTypeKind then
  begin
    LBitWidth := LLVMGetIntTypeWidth(AType);
    // Allow 8, 16, 32, 64 bit integers (exclude 1-bit bool - impractical for loops)
    Result := (LBitWidth = 8) or (LBitWidth = 16) or (LBitWidth = 32) or (LBitWidth = 64);
  end
  else
    Result := False;
end;

function TCPCodeGen.GetTypeName(const AType: LLVMTypeRef): string;
var
  LKind: LLVMTypeKind;
  LBitWidth: Cardinal;
begin
  LKind := LLVMGetTypeKind(AType);
  
  case LKind of
    LLVMIntegerTypeKind:
      begin
        LBitWidth := LLVMGetIntTypeWidth(AType);
        case LBitWidth of
          1: Result := 'bool';
          8: Result := 'int8';
          16: Result := 'int16';
          32: Result := 'int32';
          64: Result := 'int64';
        else
          Result := 'int' + IntToStr(LBitWidth);
        end;
      end;
    LLVMFloatTypeKind: Result := 'float';
    LLVMDoubleTypeKind: Result := 'double';
    LLVMPointerTypeKind: Result := 'pointer';
    LLVMArrayTypeKind: Result := 'array';
    LLVMStructTypeKind: Result := 'record';
    LLVMFunctionTypeKind: Result := 'function';
    LLVMVoidTypeKind: Result := 'void';
  else
    Result := 'unknown';
  end;
end;

procedure TCPCodeGen.ReportError(const AMessage: string; const ANode: TCPASTNode);
begin
  FErrorCollector.AddError(
    TCPCompilerError.Create(
      AMessage,
      'CodeGen',
      '<source>',
      1, 1,
      esError
    )
  );
end;

end.
