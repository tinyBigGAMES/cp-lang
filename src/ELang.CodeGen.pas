{===============================================================================
   ___    _
  | __|__| |   __ _ _ _  __ _ ™
  | _|___| |__/ _` | ' \/ _` |
  |___|  |____\__,_|_||_\__, |
                        |___/
    C Power | Pascal Clarity

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.
===============================================================================}

unit ELang.CodeGen;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ELang.Platform,
  ELang.Common,
  ELang.Parser,
  ELang.Types,
  ELang.Symbols,
  ELang.IRContext,
  ELang.Errors,
  ELang.LLVM;

type
  { TELValueContext }
  TELValueContext = class
  private
    FSymbolValues: TDictionary<TELSymbol, LLVMValueRef>;
    FStringLiterals: TDictionary<string, LLVMValueRef>;
    FCurrentFunction: LLVMValueRef;
    FCurrentBlock: LLVMBasicBlockRef;
    FParentContext: TELValueContext;

  public
    constructor Create(const AParentContext: TELValueContext = nil);
    destructor Destroy(); override;

    procedure SetSymbolValue(const ASymbol: TELSymbol; const AValue: LLVMValueRef);
    function GetSymbolValue(const ASymbol: TELSymbol): LLVMValueRef;
    function HasSymbolValue(const ASymbol: TELSymbol): Boolean;

    property CurrentFunction: LLVMValueRef read FCurrentFunction write FCurrentFunction;
    property CurrentBlock: LLVMBasicBlockRef read FCurrentBlock write FCurrentBlock;
  end;

  { TELTypeMapper }
  TELTypeMapper = class
  private
    FTypeManager: TELTypeManager;
    FIRContext: TELIRContext;
    FTypeCache: TDictionary<TELType, LLVMTypeRef>;
    
  public
    constructor Create(const ATypeManager: TELTypeManager; const AIRContext: TELIRContext);
    destructor Destroy(); override;
    
    function MapType(const AELangType: TELType): LLVMTypeRef;
    function MapBasicType(const ABasicType: TELBasicTypeInfo): LLVMTypeRef;
    function MapPointerType(const APointerType: TELPointerType): LLVMTypeRef;
    function MapArrayType(const AArrayType: TELArrayType): LLVMTypeRef;
    function MapRecordType(const ARecordType: TELRecordType): LLVMTypeRef;
    function MapFunctionType(const AFunctionType: TELFunctionType): LLVMTypeRef;
  end;

  { TELControlFlow }
  TELControlFlow = class
  private
    FBreakStack: TStack<LLVMBasicBlockRef>;
    FContinueStack: TStack<LLVMBasicBlockRef>;
    
  public
    constructor Create();
    destructor Destroy(); override;
    
    procedure PushLoop(const ABreakBlock, AContinueBlock: LLVMBasicBlockRef);
    procedure PopLoop();
    function GetBreakBlock(): LLVMBasicBlockRef;
    function GetContinueBlock(): LLVMBasicBlockRef;
    function IsInLoop(): Boolean;
  end;

  { TELCodeGen }
  TELCodeGen = class(TELObject)
  private
    FTypeManager: TELTypeManager;
    FSymbolTable: TELSymbolTable;
    FIRContext: TELIRContext;
    FErrorCollector: TELErrorCollector;
    
    FTypeMapper: TELTypeMapper;
    FValueContext: TELValueContext;
    FControlFlow: TELControlFlow;
    
    // Core generation methods
    procedure GenerateNode(const ANode: TELASTNode);
    procedure GenerateProgram(const ANode: TELASTNode);
    procedure GenerateFunction(const ANode: TELASTNode);
    procedure GenerateMainFunction(const ANode: TELASTNode);
    procedure GenerateVariableDecl(const ANode: TELASTNode);
    procedure GenerateStatementBlock(const ANode: TELASTNode);
    procedure GenerateStatement(const ANode: TELASTNode);
    
    // Expression generation
    function GenerateExpression(const ANode: TELASTNode): LLVMValueRef;
    function GenerateBinaryOp(const ANode: TELASTNode): LLVMValueRef;
    function GenerateUnaryOp(const ANode: TELASTNode): LLVMValueRef;
    function GenerateIdentifier(const ANode: TELASTNode): LLVMValueRef;
    function GenerateLiteral(const ANode: TELASTNode): LLVMValueRef;
    function GenerateFunctionCall(const ANode: TELASTNode): LLVMValueRef;
    function GenerateArrayAccess(const ANode: TELASTNode): LLVMValueRef;
    function GenerateMemberAccess(const ANode: TELASTNode): LLVMValueRef;
    
    // Statement generation
    procedure GenerateAssignment(const ANode: TELASTNode);
    procedure GenerateIfStatement(const ANode: TELASTNode);
    procedure GenerateWhileStatement(const ANode: TELASTNode);
    procedure GenerateForStatement(const ANode: TELASTNode);
    procedure GenerateRepeatStatement(const ANode: TELASTNode);
    procedure GenerateCaseStatement(const ANode: TELASTNode);
    procedure GenerateReturnStatement(const ANode: TELASTNode);
    procedure GenerateBreakStatement(const ANode: TELASTNode);
    procedure GenerateContinueStatement(const ANode: TELASTNode);
    
    // Helper methods
    function CreateFunctionSignature(const AFunctionSymbol: TELSymbol): LLVMValueRef;
    procedure GenerateFunctionParameters(const AFunctionSymbol: TELSymbol; const AFunctionValue: LLVMValueRef);
    function ResolveSymbol(const AName: string): TELSymbol;
    function GetNodeSymbol(const ANode: TELASTNode): TELSymbol;
    procedure ReportError(const AMessage: string; const ANode: TELASTNode);
    
  public
    constructor Create(const ATypeManager: TELTypeManager; const ASymbolTable: TELSymbolTable; 
      const AErrorCollector: TELErrorCollector; const AModuleName: string = 'elang_module'); reintroduce;
    destructor Destroy(); override;
    
    function Generate(const AAST: TELASTNode): string;
    
    property IRContext: TELIRContext read FIRContext;
  end;

implementation

{ TELValueContext }
constructor TELValueContext.Create(const AParentContext: TELValueContext);
begin
  inherited Create();
  FSymbolValues := TDictionary<TELSymbol, LLVMValueRef>.Create();
  FStringLiterals := TDictionary<string, LLVMValueRef>.Create();
  FCurrentFunction := nil;
  FCurrentBlock := nil;
  FParentContext := AParentContext;
end;

destructor TELValueContext.Destroy();
begin
  FStringLiterals.Free();
  FSymbolValues.Free();
  inherited;
end;

procedure TELValueContext.SetSymbolValue(const ASymbol: TELSymbol; const AValue: LLVMValueRef);
begin
  if not Assigned(ASymbol) then
    Exit;
  FSymbolValues.AddOrSetValue(ASymbol, AValue);
end;

function TELValueContext.GetSymbolValue(const ASymbol: TELSymbol): LLVMValueRef;
begin
  if not Assigned(ASymbol) then
    Exit(nil);
    
  if FSymbolValues.TryGetValue(ASymbol, Result) then
    Exit;
    
  // Search parent context
  if Assigned(FParentContext) then
    Result := FParentContext.GetSymbolValue(ASymbol)
  else
    Result := nil;
end;

function TELValueContext.HasSymbolValue(const ASymbol: TELSymbol): Boolean;
begin
  if not Assigned(ASymbol) then
    Exit(False);
    
  Result := FSymbolValues.ContainsKey(ASymbol);
  if not Result and Assigned(FParentContext) then
    Result := FParentContext.HasSymbolValue(ASymbol);
end;

{ TELTypeMapper }
constructor TELTypeMapper.Create(const ATypeManager: TELTypeManager; const AIRContext: TELIRContext);
begin
  inherited Create();
  FTypeManager := ATypeManager;
  FIRContext := AIRContext;
  FTypeCache := TDictionary<TELType, LLVMTypeRef>.Create();
end;

destructor TELTypeMapper.Destroy();
begin
  FTypeCache.Free();
  inherited;
end;

function TELTypeMapper.MapType(const AELangType: TELType): LLVMTypeRef;
begin
  if not Assigned(AELangType) then
    Exit(nil);
    
  // Check cache first
  if FTypeCache.TryGetValue(AELangType, Result) then
    Exit;
    
  // Map based on type kind
  if AELangType.Kind = tkBasic then
    Result := MapBasicType(TELBasicTypeInfo(AELangType))
  else if AELangType.Kind = tkPointer then
    Result := MapPointerType(TELPointerType(AELangType))
  else if AELangType.Kind = tkArray then
    Result := MapArrayType(TELArrayType(AELangType))
  else if AELangType.Kind = tkRecord then
    Result := MapRecordType(TELRecordType(AELangType))
  else if (AELangType.Kind = tkFunction) or (AELangType.Kind = tkProcedure) then
    Result := MapFunctionType(TELFunctionType(AELangType))
  else
    Result := nil;
  
  // Cache the result
  if Assigned(Result) then
    FTypeCache.Add(AELangType, Result);
end;

function TELTypeMapper.MapBasicType(const ABasicType: TELBasicTypeInfo): LLVMTypeRef;
begin
  if (ABasicType.BasicType = btInt) or (ABasicType.BasicType = btInt32) then
    Result := FIRContext.Int32Type()
  else if ABasicType.BasicType = btChar then
    Result := FIRContext.Int8Type()
  else if ABasicType.BasicType = btBool then
    Result := FIRContext.BoolType()
  else if ABasicType.BasicType = btFloat then
    Result := FIRContext.FloatType()
  else if ABasicType.BasicType = btDouble then
    Result := FIRContext.DoubleType()
  else if ABasicType.BasicType = btInt8 then
    Result := FIRContext.Int8Type()
  else if ABasicType.BasicType = btInt16 then
    Result := FIRContext.Int16Type()
  else if ABasicType.BasicType = btInt64 then
    Result := FIRContext.Int64Type()
  else if ABasicType.BasicType = btUInt8 then
    Result := FIRContext.Int8Type()
  else if ABasicType.BasicType = btUInt16 then
    Result := FIRContext.Int16Type()
  else if ABasicType.BasicType = btUInt32 then
    Result := FIRContext.Int32Type()
  else if ABasicType.BasicType = btUInt64 then
    Result := FIRContext.Int64Type()
  else
    Result := FIRContext.Int32Type(); // Default fallback
end;

function TELTypeMapper.MapPointerType(const APointerType: TELPointerType): LLVMTypeRef;
var
  LTargetType: LLVMTypeRef;
begin
  LTargetType := MapType(APointerType.TargetType);
  Result := FIRContext.PointerType(LTargetType);
end;

function TELTypeMapper.MapArrayType(const AArrayType: TELArrayType): LLVMTypeRef;
var
  LElementType: LLVMTypeRef;
begin
  LElementType := MapType(AArrayType.ElementType);
  
  if AArrayType.ElementCount > 0 then
    Result := FIRContext.ArrayType(LElementType, Cardinal(AArrayType.ElementCount))
  else
    Result := FIRContext.PointerType(LElementType); // Dynamic array as pointer
end;

function TELTypeMapper.MapRecordType(const ARecordType: TELRecordType): LLVMTypeRef;
var
  LFieldTypes: TArray<LLVMTypeRef>;
  LField: TELRecordField;
  LIndex: Integer;
begin
  SetLength(LFieldTypes, Length(ARecordType.Fields));
  
  for LIndex := 0 to High(ARecordType.Fields) do
  begin
    LField := ARecordType.Fields[LIndex];
    LFieldTypes[LIndex] := MapType(LField.FieldType);
  end;
  
  Result := FIRContext.StructType(LFieldTypes, False);
end;

function TELTypeMapper.MapFunctionType(const AFunctionType: TELFunctionType): LLVMTypeRef;
var
  LParamTypes: TArray<LLVMTypeRef>;
  LReturnType: LLVMTypeRef;
  LIndex: Integer;
begin
  // Map parameter types
  SetLength(LParamTypes, Length(AFunctionType.ParameterTypes));
  for LIndex := 0 to High(AFunctionType.ParameterTypes) do
    LParamTypes[LIndex] := MapType(AFunctionType.ParameterTypes[LIndex]);
    
  // Map return type
  if Assigned(AFunctionType.ReturnType) then
    LReturnType := MapType(AFunctionType.ReturnType)
  else
    LReturnType := FIRContext.VoidType();
    
  Result := FIRContext.FunctionType(LReturnType, LParamTypes, AFunctionType.IsVariadic);
end;

{ TELControlFlow }
constructor TELControlFlow.Create();
begin
  inherited Create();
  FBreakStack := TStack<LLVMBasicBlockRef>.Create();
  FContinueStack := TStack<LLVMBasicBlockRef>.Create();
end;

destructor TELControlFlow.Destroy();
begin
  FContinueStack.Free();
  FBreakStack.Free();
  inherited;
end;

procedure TELControlFlow.PushLoop(const ABreakBlock, AContinueBlock: LLVMBasicBlockRef);
begin
  FBreakStack.Push(ABreakBlock);
  FContinueStack.Push(AContinueBlock);
end;

procedure TELControlFlow.PopLoop();
begin
  if FBreakStack.Count > 0 then
    FBreakStack.Pop();
  if FContinueStack.Count > 0 then
    FContinueStack.Pop();
end;

function TELControlFlow.GetBreakBlock(): LLVMBasicBlockRef;
begin
  if FBreakStack.Count > 0 then
    Result := FBreakStack.Peek()
  else
    Result := nil;
end;

function TELControlFlow.GetContinueBlock(): LLVMBasicBlockRef;
begin
  if FContinueStack.Count > 0 then
    Result := FContinueStack.Peek()
  else
    Result := nil;
end;

function TELControlFlow.IsInLoop(): Boolean;
begin
  Result := FBreakStack.Count > 0;
end;

{ TELCodeGen }
constructor TELCodeGen.Create(const ATypeManager: TELTypeManager; const ASymbolTable: TELSymbolTable;
  const AErrorCollector: TELErrorCollector; const AModuleName: string);
begin
  inherited Create();
  FTypeManager := ATypeManager;
  FSymbolTable := ASymbolTable;
  FErrorCollector := AErrorCollector;
  
  FIRContext := TELIRContext.Create(AModuleName);
  FIRContext.TargetTriple(ELGetLLVMPlatformTargetTriple());
  FIRContext.DataLayout(ELGetLLVMPlatformDataLayout());
  FTypeMapper := TELTypeMapper.Create(FTypeManager, FIRContext);
  FValueContext := TELValueContext.Create();
  FControlFlow := TELControlFlow.Create();
end;

destructor TELCodeGen.Destroy();
begin
  FControlFlow.Free();
  FValueContext.Free();
  FTypeMapper.Free();
  FIRContext.Free();
  inherited;
end;

function TELCodeGen.Generate(const AAST: TELASTNode): string;
begin
  if not Assigned(AAST) then
  begin
    ReportError('No AST provided for code generation', nil);
    Exit('');
  end;
  
  try
    GenerateNode(AAST);
    Result := FIRContext.GetIR();
  except
    on E: Exception do
    begin
      ReportError('Code generation failed: ' + E.Message, AAST);
      Result := '';
    end;
  end;
end;

procedure TELCodeGen.GenerateNode(const ANode: TELASTNode);
begin
  if not Assigned(ANode) then Exit;
  
  if ANode.NodeType = astProgram then
    GenerateProgram(ANode)
  else if ANode.NodeType = astMainFunction then
    GenerateMainFunction(ANode)
  else if ANode.NodeType = astFunctionDecl then
    GenerateFunction(ANode)
  else if ANode.NodeType = astVariableDecl then
    GenerateVariableDecl(ANode)
  else if ANode.NodeType = astStatementBlock then
    GenerateStatementBlock(ANode)
  else if ANode.NodeType = astAssignment then
    GenerateAssignment(ANode)
  else if ANode.NodeType = astIfStatement then
    GenerateIfStatement(ANode)
  else if ANode.NodeType = astWhileStatement then
    GenerateWhileStatement(ANode)
  else if ANode.NodeType = astForStatement then
    GenerateForStatement(ANode)
  else if ANode.NodeType = astRepeatStatement then
    GenerateRepeatStatement(ANode)
  else if ANode.NodeType = astCaseStatement then
    GenerateCaseStatement(ANode)
  else if ANode.NodeType = astReturnStatement then
    GenerateReturnStatement(ANode)
  else if ANode.NodeType = astCallStatement then
    GenerateExpression(ANode.GetChild(0))
  else if ANode.NodeType = astBreakStatement then
    GenerateBreakStatement(ANode)
  else if ANode.NodeType = astContinueStatement then
    GenerateContinueStatement(ANode);
    // Expression nodes handled by GenerateExpression
end;

procedure TELCodeGen.GenerateProgram(const ANode: TELASTNode);
var
  LIndex: Integer;
begin
  // Generate all top-level declarations
  for LIndex := 0 to ANode.ChildCount() - 1 do
    GenerateNode(ANode.GetChild(LIndex));
end;

procedure TELCodeGen.GenerateMainFunction(const ANode: TELASTNode);
var
  LMainType: LLVMTypeRef;
  LMainFunc: LLVMValueRef;
  LSymbol: TELSymbol;
begin

  // Create main function signature: function main(): int32
  LMainType := FIRContext.FunctionType(FIRContext.Int32Type(), []);
  LMainFunc := FIRContext.BeginFunction('main', LMainType).CurrentFunction;

  // Store function in value context
  LSymbol := ResolveSymbol('main');
  if Assigned(LSymbol) then
    FValueContext.SetSymbolValue(LSymbol, LMainFunc);

  // Create entry block
  FIRContext.BasicBlock('entry');

  // Generate function body (second child is the statement block, first child is header)
  if ANode.ChildCount() > 1 then
    GenerateNode(ANode.GetChild(1)); // Statement block

  FIRContext.EndFunction();
end;

procedure TELCodeGen.GenerateFunction(const ANode: TELASTNode);
var
  LSymbol: TELSymbol;
  LFunctionValue: LLVMValueRef;
  LIsExternal: Boolean;
begin
  // Get function symbol
  LSymbol := GetNodeSymbol(ANode);
  if not Assigned(LSymbol) then
  begin
    ReportError('Function symbol not found', ANode);
    Exit;
  end;
  
  // Check if this is an external function
  LIsExternal := (ANode.ChildCount() >= 2) and 
                 (ANode.GetChild(1).NodeType = astLiteral);
  
  // Create function signature
  LFunctionValue := CreateFunctionSignature(LSymbol);
  FValueContext.SetSymbolValue(LSymbol, LFunctionValue);
  
  // For external functions, only declare - no body generation
  if LIsExternal then
    Exit;
  
  // Start function generation for non-external functions
  FIRContext.BeginFunction(LSymbol.SymbolName, LSymbol.SymbolType as TELFunctionType);
  
  // Generate parameters
  GenerateFunctionParameters(LSymbol, LFunctionValue);
  
  // Create entry block
  FIRContext.BasicBlock('entry');
  
  // Create new scope for function body
  FValueContext := TELValueContext.Create(FValueContext);
  try
    // Generate function body
    if ANode.ChildCount() > 1 then
      GenerateNode(ANode.GetChild(1)); // Statement block
      
    // Ensure return for void functions
    if Assigned(FIRContext.CurrentBlock) then
    begin
      if TELFunctionType(LSymbol.SymbolType).ReturnType = nil then
        FIRContext.RetVoid()
      else
        FIRContext.Ret(FIRContext.ConstNull(FTypeMapper.MapType(TELFunctionType(LSymbol.SymbolType).ReturnType)));
    end;
  finally
    // Exit function scope
    var LOldContext := FValueContext.FParentContext;
    FValueContext.Free();
    FValueContext := LOldContext;
  end;
  
  FIRContext.EndFunction();
end;

procedure TELCodeGen.GenerateVariableDecl(const ANode: TELASTNode);
var
  LSymbol: TELSymbol;
  LLVMType: LLVMTypeRef;
  LAlloca: LLVMValueRef;
  LInitValue: LLVMValueRef;
begin
  // Get symbol from semantic analysis
  LSymbol := GetNodeSymbol(ANode);
  if not Assigned(LSymbol) then Exit;
  
  // Map e-lang type to LLVM type
  LLVMType := FTypeMapper.MapType(LSymbol.SymbolType);
  
  // Allocate local variable
  LAlloca := FIRContext.Alloca(LLVMType);
  FValueContext.SetSymbolValue(LSymbol, LAlloca);
  
  // Handle initialization if present
  if ANode.ChildCount() > 2 then
  begin
    LInitValue := GenerateExpression(ANode.GetChild(2));
    if Assigned(LInitValue) then
      FIRContext.Store(LInitValue, LAlloca);
  end;
end;

procedure TELCodeGen.GenerateStatementBlock(const ANode: TELASTNode);
var
  LIndex: Integer;
begin
  // Generate all statements in the block
  for LIndex := 0 to ANode.ChildCount() - 1 do
    GenerateNode(ANode.GetChild(LIndex));
end;

procedure TELCodeGen.GenerateStatement(const ANode: TELASTNode);
begin
  GenerateNode(ANode);
end;

function TELCodeGen.GenerateExpression(const ANode: TELASTNode): LLVMValueRef;
begin
  if not Assigned(ANode) then
    Exit(nil);
    
  if ANode.NodeType = astBinaryOp then
    Result := GenerateBinaryOp(ANode)
  else if ANode.NodeType = astUnaryOp then
    Result := GenerateUnaryOp(ANode)
  else if ANode.NodeType = astIdentifier then
    Result := GenerateIdentifier(ANode)
  else if ANode.NodeType = astLiteral then
    Result := GenerateLiteral(ANode)
  else if ANode.NodeType = astFunctionCall then
    Result := GenerateFunctionCall(ANode)
  else if ANode.NodeType = astArrayAccess then
    Result := GenerateArrayAccess(ANode)
  else if ANode.NodeType = astMemberAccess then
    Result := GenerateMemberAccess(ANode)
  else
  begin
    Result := nil;
    ReportError('Unsupported expression type', ANode);
  end;
end;

function TELCodeGen.GenerateBinaryOp(const ANode: TELASTNode): LLVMValueRef;
var
  LLeft: LLVMValueRef;
  LRight: LLVMValueRef;
  LOperator: string;
begin
  if ANode.ChildCount() < 2 then
  begin
    ReportError('Binary operation requires two operands', ANode);
    Exit(nil);
  end;

  LLeft := GenerateExpression(ANode.GetChild(0));
  LRight := GenerateExpression(ANode.GetChild(1));
  LOperator := ANode.Value;

  if not Assigned(LLeft) or not Assigned(LRight) then
    Exit(nil);

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
  begin
    Result := nil;
    ReportError('Unsupported binary operator: ' + LOperator, ANode);
  end;
end;

function TELCodeGen.GenerateUnaryOp(const ANode: TELASTNode): LLVMValueRef;
var
  LOperand: LLVMValueRef;
  LOperator: string;
begin
  if ANode.ChildCount() < 1 then
  begin
    ReportError('Unary operation requires one operand', ANode);
    Exit(nil);
  end;
  LOperand := GenerateExpression(ANode.GetChild(0));
  LOperator := ANode.Value;
  if not Assigned(LOperand) then
    Exit(nil);

  if LOperator = '-' then
    Result := FIRContext.Sub(FIRContext.ConstInt32(0), LOperand)
  else if LOperator = '+' then
    Result := LOperand // Unary plus is no-op
  else if LOperator = 'not' then
  begin
    // For boolean NOT, XOR with 1
    Result := FIRContext.BitwiseXor(LOperand, FIRContext.ConstBool(True));
  end
  else if LOperator = '^' then
  begin
    // Pointer dereference - load from address
    Result := FIRContext.Load(LOperand, FIRContext.Int8Type()); // Assuming byte load
  end
  else
  begin
    Result := nil;
    ReportError('Unsupported unary operator: ' + LOperator, ANode);
  end;
end;

function TELCodeGen.GenerateIdentifier(const ANode: TELASTNode): LLVMValueRef;
var
  LSymbol: TELSymbol;
  LValue: LLVMValueRef;
begin
  LSymbol := ResolveSymbol(ANode.Value);
  if not Assigned(LSymbol) then
  begin
    ReportError('Undefined identifier: ' + ANode.Value, ANode);
    Exit(nil);
  end;
  
  LValue := FValueContext.GetSymbolValue(LSymbol);
  if not Assigned(LValue) then
  begin
    ReportError('Symbol not generated: ' + ANode.Value, ANode);
    Exit(nil);
  end;
  
  // For variables, load the value; for functions, return the function pointer
  if LSymbol.Kind = skVariable then
  begin
    Result := FIRContext.Load(LValue, FTypeMapper.MapType(LSymbol.SymbolType));
  end
  else
  begin
    Result := LValue;
  end;
end;

function TELCodeGen.GenerateLiteral(const ANode: TELASTNode): LLVMValueRef;
var
  LValue: string;
  LIntValue: Integer;
  LFloatValue: Double;
begin
  LValue := ANode.Value;
  
  // Boolean literals
  if LValue = 'true' then
    Result := FIRContext.ConstBool(True)
  else if LValue = 'false' then
    Result := FIRContext.ConstBool(False)
  // String literals
  else if (LValue.Length >= 2) and (LValue[1] = '"') and (LValue[LValue.Length] = '"') then
    Result := FIRContext.GetStringReference(LValue)
  // Character literals
  else if (LValue.Length >= 3) and (LValue[1] = '''') and (LValue[LValue.Length] = '''') then
    Result := FIRContext.ConstInt8(Ord(LValue[2]))
  // Numeric literals
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

function TELCodeGen.GenerateFunctionCall(const ANode: TELASTNode): LLVMValueRef;
var
  LFunctionNode: TELASTNode;
  LArgsNode: TELASTNode;
  LFunctionValue: LLVMValueRef;
  LArgs: TArray<LLVMValueRef>;
  LIndex: Integer;
  LSymbol: TELSymbol;
begin
  if ANode.ChildCount() < 1 then
  begin
    ReportError('Function call requires function reference', ANode);
    Exit(nil);
  end;
  
  LFunctionNode := ANode.GetChild(0);
  
  // Get function symbol and value
  if LFunctionNode.NodeType = astIdentifier then
  begin
    LSymbol := ResolveSymbol(LFunctionNode.Value);
    if not Assigned(LSymbol) then
    begin
      ReportError('Undefined function: ' + LFunctionNode.Value, ANode);
      Exit(nil);
    end;
    
    LFunctionValue := FValueContext.GetSymbolValue(LSymbol);
    if not Assigned(LFunctionValue) then
    begin
      ReportError('Function not generated: ' + LFunctionNode.Value, ANode);
      Exit(nil);
    end;
  end
  else
  begin
    LFunctionValue := GenerateExpression(LFunctionNode);
    if not Assigned(LFunctionValue) then
      Exit(nil);
  end;
  
  // Generate arguments
  if ANode.ChildCount() > 1 then
  begin
    LArgsNode := ANode.GetChild(1);
    SetLength(LArgs, LArgsNode.ChildCount());
    for LIndex := 0 to LArgsNode.ChildCount() - 1 do
    begin
      LArgs[LIndex] := GenerateExpression(LArgsNode.GetChild(LIndex));
      if not Assigned(LArgs[LIndex]) then
        Exit(nil);
    end;
  end
  else
    SetLength(LArgs, 0);
  
  // Generate call
  Result := FIRContext.Call(LFunctionValue, LArgs);
end;

function TELCodeGen.GenerateArrayAccess(const ANode: TELASTNode): LLVMValueRef;
var
  LArrayValue: LLVMValueRef;
  LIndexValue: LLVMValueRef;
  LPtr: LLVMValueRef;
begin
  if ANode.ChildCount() < 2 then
  begin
    ReportError('Array access requires array and index', ANode);
    Exit(nil);
  end;
  
  LArrayValue := GenerateExpression(ANode.GetChild(0));
  LIndexValue := GenerateExpression(ANode.GetChild(1));
  
  if not Assigned(LArrayValue) or not Assigned(LIndexValue) then
    Exit(nil);
  
  // Generate GEP for array access
  LPtr := FIRContext.GEP(LArrayValue, [FIRContext.ConstInt32(0), LIndexValue]);
  
  // Load the value at the computed address
  Result := FIRContext.Load(LPtr, FIRContext.Int32Type()); // Assuming int32 elements
end;

function TELCodeGen.GenerateMemberAccess(const ANode: TELASTNode): LLVMValueRef;
var
  LRecordValue: LLVMValueRef;
  LMemberName: string;
  LPtr: LLVMValueRef;
  LFieldIndex: LLVMValueRef;
begin
  if ANode.ChildCount() < 2 then
  begin
    ReportError('Member access requires record and member', ANode);
    Exit(nil);
  end;
  
  LRecordValue := GenerateExpression(ANode.GetChild(0));
  LMemberName := ANode.GetChild(1).Value;
  
  if not Assigned(LRecordValue) then
    Exit(nil);
  
  // For now, assume field index 0 (would need proper field resolution)
  LFieldIndex := FIRContext.ConstInt32(0);
  
  // Generate GEP for member access
  LPtr := FIRContext.GEP(LRecordValue, [FIRContext.ConstInt32(0), LFieldIndex]);
  
  // Load the value at the computed address
  Result := FIRContext.Load(LPtr, FIRContext.Int32Type()); // Assuming int32 field
end;

procedure TELCodeGen.GenerateAssignment(const ANode: TELASTNode);
var
  LLValue: TELASTNode;
  LExpression: TELASTNode;
  LTarget: LLVMValueRef;
  LValue: LLVMValueRef;
  LSymbol: TELSymbol;
begin
  if ANode.ChildCount() < 2 then
  begin
    ReportError('Assignment requires left value and expression', ANode);
    Exit;
  end;
  
  LLValue := ANode.GetChild(0);
  LExpression := ANode.GetChild(1);
  
  // Get target location
  if LLValue.NodeType = astIdentifier then
  begin
    LSymbol := ResolveSymbol(LLValue.Value);
    if not Assigned(LSymbol) then
    begin
      ReportError('Undefined variable: ' + LLValue.Value, ANode);
      Exit;
    end;
    
    LTarget := FValueContext.GetSymbolValue(LSymbol);
    if not Assigned(LTarget) then
    begin
      ReportError('Variable not allocated: ' + LLValue.Value, ANode);
      Exit;
    end;
  end
  else
  begin
    // For complex lvalues (array access, member access), generate address
    LTarget := GenerateExpression(LLValue);
    if not Assigned(LTarget) then
      Exit;
  end;
  
  // Generate value to store
  LValue := GenerateExpression(LExpression);
  if not Assigned(LValue) then
    Exit;
  
  // Store the value
  FIRContext.Store(LValue, LTarget);
end;

procedure TELCodeGen.GenerateIfStatement(const ANode: TELASTNode);
var
  LCondition: LLVMValueRef;
  LThenBlock: LLVMBasicBlockRef;
  LElseBlock: LLVMBasicBlockRef;
  LMergeBlock: LLVMBasicBlockRef;
begin
  if ANode.ChildCount() < 2 then
  begin
    ReportError('If statement requires condition and then clause', ANode);
    Exit;
  end;

  // Generate condition
  LCondition := GenerateExpression(ANode.GetChild(0));
  if not Assigned(LCondition) then
    Exit;

  // Create basic blocks
  LThenBlock := FIRContext.CreateBasicBlock('if.then');
  LElseBlock := FIRContext.CreateBasicBlock('if.else');
  LMergeBlock := FIRContext.CreateBasicBlock('if.merge');

  // Conditional branch
  FIRContext.CondBr(LCondition, LThenBlock, LElseBlock);

  // Generate then block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LThenBlock);
  GenerateNode(ANode.GetChild(1)); // Then statement
  FIRContext.Br(LMergeBlock);

  // Generate else block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LElseBlock);
  if ANode.ChildCount() > 2 then
    GenerateNode(ANode.GetChild(2)); // Else statement
  FIRContext.Br(LMergeBlock);

  // Continue with merge block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LMergeBlock);
end;

procedure TELCodeGen.GenerateWhileStatement(const ANode: TELASTNode);
var
  LCondition: LLVMValueRef;
  LLoopHeader: LLVMBasicBlockRef;
  LLoopBody: LLVMBasicBlockRef;
  LLoopExit: LLVMBasicBlockRef;
begin
  if ANode.ChildCount() < 2 then
  begin
    ReportError('While statement requires condition and body', ANode);
    Exit;
  end;
  
  // Create basic blocks
  LLoopHeader := FIRContext.CreateBasicBlock('while.header');
  LLoopBody := FIRContext.CreateBasicBlock('while.body');
  LLoopExit := FIRContext.CreateBasicBlock('while.exit');
  
  // Jump to header
  FIRContext.Br(LLoopHeader);
  
  // Generate loop header (condition check)
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopHeader);
  LCondition := GenerateExpression(ANode.GetChild(0));
  if not Assigned(LCondition) then
    Exit;
  FIRContext.CondBr(LCondition, LLoopBody, LLoopExit);
  
  // Generate loop body
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopBody);
  
  // Push loop blocks for break/continue
  FControlFlow.PushLoop(LLoopExit, LLoopHeader);
  try
    GenerateNode(ANode.GetChild(1)); // Loop body
    FIRContext.Br(LLoopHeader); // Jump back to condition
  finally
    FControlFlow.PopLoop();
  end;
  
  // Continue with exit block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopExit);
end;

procedure TELCodeGen.GenerateForStatement(const ANode: TELASTNode);
var
  LVariable: TELASTNode;
  LStartValue: LLVMValueRef;
  LEndValue: LLVMValueRef;
  LStepValue: LLVMValueRef;
  LLoopVar: LLVMValueRef;
  LLoopHeader: LLVMBasicBlockRef;
  LLoopBody: LLVMBasicBlockRef;
  LLoopIncrement: LLVMBasicBlockRef;
  LLoopExit: LLVMBasicBlockRef;
  LCondition: LLVMValueRef;
  LSymbol: TELSymbol;
  LIsDownTo: Boolean;
  LCurrentValue: LLVMValueRef;
begin
  if ANode.ChildCount() < 4 then
  begin
    ReportError('For statement requires variable, start, end, and body', ANode);
    Exit;
  end;
  
  LVariable := ANode.GetChild(0);
  LIsDownTo := ANode.Value = 'downto';
  
  // Generate start and end values
  LStartValue := GenerateExpression(ANode.GetChild(1));
  LEndValue := GenerateExpression(ANode.GetChild(2));
  
  if not Assigned(LStartValue) or not Assigned(LEndValue) then
    Exit;
  
  // Get loop variable
  LSymbol := ResolveSymbol(LVariable.Value);
  if not Assigned(LSymbol) then
  begin
    ReportError('Undefined loop variable: ' + LVariable.Value, ANode);
    Exit;
  end;
  
  LLoopVar := FValueContext.GetSymbolValue(LSymbol);
  if not Assigned(LLoopVar) then
  begin
    ReportError('Loop variable not allocated: ' + LVariable.Value, ANode);
    Exit;
  end;
  
  // Initialize loop variable
  FIRContext.Store(LStartValue, LLoopVar);
  
  // Create basic blocks
  LLoopHeader := FIRContext.CreateBasicBlock('for.header');
  LLoopBody := FIRContext.CreateBasicBlock('for.body');
  LLoopIncrement := FIRContext.CreateBasicBlock('for.increment');
  LLoopExit := FIRContext.CreateBasicBlock('for.exit');
  
  // Jump to header
  FIRContext.Br(LLoopHeader);
  
  // Generate loop header (condition check)
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopHeader);
  LCurrentValue := FIRContext.Load(LLoopVar, FIRContext.Int32Type());
  
  if LIsDownTo then
    LCondition := FIRContext.ICmp(LLVMIntSGE, LCurrentValue, LEndValue)
  else
    LCondition := FIRContext.ICmp(LLVMIntSLE, LCurrentValue, LEndValue);
    
  FIRContext.CondBr(LCondition, LLoopBody, LLoopExit);
  
  // Generate loop body
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopBody);
  
  // Push loop blocks for break/continue
  FControlFlow.PushLoop(LLoopExit, LLoopIncrement);
  try
    GenerateNode(ANode.GetChild(3)); // Loop body
    FIRContext.Br(LLoopIncrement);
  finally
    FControlFlow.PopLoop();
  end;
  
  // Generate increment
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopIncrement);
  LCurrentValue := FIRContext.Load(LLoopVar, FIRContext.Int32Type());
  
  if LIsDownTo then
    LStepValue := FIRContext.Sub(LCurrentValue, FIRContext.ConstInt32(1))
  else
    LStepValue := FIRContext.Add(LCurrentValue, FIRContext.ConstInt32(1));
    
  FIRContext.Store(LStepValue, LLoopVar);
  FIRContext.Br(LLoopHeader);
  
  // Continue with exit block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopExit);
end;

procedure TELCodeGen.GenerateRepeatStatement(const ANode: TELASTNode);
var
  LCondition: LLVMValueRef;
  LLoopBody: LLVMBasicBlockRef;
  LLoopExit: LLVMBasicBlockRef;
begin
  if ANode.ChildCount() < 2 then
  begin
    ReportError('Repeat statement requires body and condition', ANode);
    Exit;
  end;
  
  // Create basic blocks
  LLoopBody := FIRContext.CreateBasicBlock('repeat.body');
  LLoopExit := FIRContext.CreateBasicBlock('repeat.exit');
  
  // Jump to body (repeat executes at least once)
  FIRContext.Br(LLoopBody);
  
  // Generate loop body
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopBody);
  
  // Push loop blocks for break/continue
  FControlFlow.PushLoop(LLoopExit, LLoopBody);
  try
    GenerateNode(ANode.GetChild(0)); // Loop body
  finally
    FControlFlow.PopLoop();
  end;
  
  // Generate condition check (repeat until condition is true)
  LCondition := GenerateExpression(ANode.GetChild(1));
  if not Assigned(LCondition) then
    Exit;
    
  // Branch: if condition is true, exit; otherwise repeat
  FIRContext.CondBr(LCondition, LLoopExit, LLoopBody);
  
  // Continue with exit block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LLoopExit);
end;

procedure TELCodeGen.GenerateCaseStatement(const ANode: TELASTNode);
var
  LExpression: LLVMValueRef;
  LDefaultBlock: LLVMBasicBlockRef;
  LExitBlock: LLVMBasicBlockRef;
  LSwitchInst: LLVMValueRef;
  LIndex: Integer;
  LCaseItem: TELASTNode;
  LCaseBlock: LLVMBasicBlockRef;
  LLabelValue: LLVMValueRef;
begin
  if ANode.ChildCount() < 1 then
  begin
    ReportError('Case statement requires expression', ANode);
    Exit;
  end;
  
  // Generate switch expression
  LExpression := GenerateExpression(ANode.GetChild(0));
  if not Assigned(LExpression) then
    Exit;
  
  // Create blocks
  LDefaultBlock := FIRContext.CreateBasicBlock('case.default');
  LExitBlock := FIRContext.CreateBasicBlock('case.exit');
  
  // Create switch instruction
  LSwitchInst := FIRContext.Switch(LExpression, LDefaultBlock);
  
  // Generate case items
  for LIndex := 1 to ANode.ChildCount() - 1 do
  begin
    LCaseItem := ANode.GetChild(LIndex);
    
    // Skip else clause
    if (LCaseItem.NodeType = astStatementBlock) and (LCaseItem.Value = 'else') then
      Continue;
    
    LCaseBlock := FIRContext.CreateBasicBlock('case.' + IntToStr(LIndex));
    
    // For simplicity, assume first child is the case value
    if LCaseItem.ChildCount() > 0 then
    begin
      LLabelValue := GenerateExpression(LCaseItem.GetChild(0));
      if Assigned(LLabelValue) then
        FIRContext.AddSwitchCase(LSwitchInst, LLabelValue, LCaseBlock);
    end;
    
    // Generate case body
    LLVMPositionBuilderAtEnd(FIRContext.Builder, LCaseBlock);
    
    if LCaseItem.ChildCount() > 1 then
      GenerateNode(LCaseItem.GetChild(1));
      
    FIRContext.Br(LExitBlock);
  end;
  
  // Generate default block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LDefaultBlock);
  
  // Check for else clause
  for LIndex := 1 to ANode.ChildCount() - 1 do
  begin
    LCaseItem := ANode.GetChild(LIndex);
    if (LCaseItem.NodeType = astStatementBlock) and (LCaseItem.Value = 'else') then
    begin
      if LCaseItem.ChildCount() > 0 then
        GenerateNode(LCaseItem.GetChild(0));
      Break;
    end;
  end;
  
  FIRContext.Br(LExitBlock);
  
  // Continue with exit block
  LLVMPositionBuilderAtEnd(FIRContext.Builder, LExitBlock);
end;

procedure TELCodeGen.GenerateReturnStatement(const ANode: TELASTNode);
var
  LReturnValue: LLVMValueRef;
begin
  if ANode.ChildCount() > 0 then
  begin
    LReturnValue := GenerateExpression(ANode.GetChild(0));
    if Assigned(LReturnValue) then
      FIRContext.Ret(LReturnValue);
  end
  else
  begin
    FIRContext.RetVoid();
  end;
end;

procedure TELCodeGen.GenerateBreakStatement(const ANode: TELASTNode);
var
  LBreakBlock: LLVMBasicBlockRef;
begin
  LBreakBlock := FControlFlow.GetBreakBlock();
  if Assigned(LBreakBlock) then
    FIRContext.Br(LBreakBlock)
  else
    ReportError('Break statement outside loop', ANode);
end;

procedure TELCodeGen.GenerateContinueStatement(const ANode: TELASTNode);
var
  LContinueBlock: LLVMBasicBlockRef;
begin
  LContinueBlock := FControlFlow.GetContinueBlock();
  if Assigned(LContinueBlock) then
    FIRContext.Br(LContinueBlock)
  else
    ReportError('Continue statement outside loop', ANode);
end;

function TELCodeGen.CreateFunctionSignature(const AFunctionSymbol: TELSymbol): LLVMValueRef;
var
  LFunctionType: TELFunctionType;
  LLVMFunctionType: LLVMTypeRef;
begin
  if not (AFunctionSymbol.SymbolType is TELFunctionType) then
  begin
    ReportError('Symbol is not a function type', nil);
    Exit(nil);
  end;
  
  LFunctionType := TELFunctionType(AFunctionSymbol.SymbolType);
  LLVMFunctionType := FTypeMapper.MapFunctionType(LFunctionType);
  
  Result := FIRContext.DeclareFunction(AFunctionSymbol.SymbolName, LLVMFunctionType);
end;

procedure TELCodeGen.GenerateFunctionParameters(const AFunctionSymbol: TELSymbol; const AFunctionValue: LLVMValueRef);
var
  LFunctionType: TELFunctionType;
  LParameterIndex: Integer;
  LParameter: LLVMValueRef;
  LAlloca: LLVMValueRef;
  LParameterType: LLVMTypeRef;
begin
  if not (AFunctionSymbol.SymbolType is TELFunctionType) then
    Exit;
  
  LFunctionType := TELFunctionType(AFunctionSymbol.SymbolType);
  
  // For each parameter, create an alloca and store the parameter value
  for LParameterIndex := 0 to High(LFunctionType.ParameterTypes) do
  begin
    LParameter := LLVMGetParam(AFunctionValue, Cardinal(LParameterIndex));
    LParameterType := FTypeMapper.MapType(LFunctionType.ParameterTypes[LParameterIndex]);
    
    // Create alloca for parameter
    LAlloca := FIRContext.Alloca(LParameterType);
    
    // Store parameter value
    FIRContext.Store(LParameter, LAlloca);
    
    // Note: Would need to map parameter symbol to alloca here
    // This requires enhanced symbol table integration
  end;
end;

function TELCodeGen.ResolveSymbol(const AName: string): TELSymbol;
begin
  Result := FSymbolTable.LookupSymbol(AName);
end;

function TELCodeGen.GetNodeSymbol(const ANode: TELASTNode): TELSymbol;
var
  LFunctionName: string;
begin
  if not Assigned(ANode) then
    Exit(nil);
    
  // For function declarations, extract the function name from the header
  if ANode.NodeType = astFunctionDecl then
  begin
    // Function name is in the FIRST child of the function header (first child)
    if (ANode.ChildCount() > 0) and (ANode.GetChild(0).ChildCount() > 0) then
    begin
      LFunctionName := ANode.GetChild(0).GetChild(0).Value;
      Result := ResolveSymbol(LFunctionName);
    end
    else
      Result := nil;
  end
  else if ANode.Value <> '' then
    Result := ResolveSymbol(ANode.Value)
  else
    Result := nil;
end;

procedure TELCodeGen.ReportError(const AMessage: string; const ANode: TELASTNode);
var
  LFileName: string;
  LLine: Integer;
  LColumn: Integer;
begin
  if Assigned(ANode) and (ANode.Position > 0) then
  begin
    // For now, approximate line number from character position
    // This is a simplified calculation - proper source mapping would be better
    LFileName := '<source>';
    
    // Rough approximation: assume average line length of 50 characters
    LLine := (ANode.Position div 50) + 1;
    LColumn := (ANode.Position mod 50) + 1;
    
    if LLine < 1 then LLine := 1;
    if LColumn < 1 then LColumn := 1;
  end
  else
  begin
    LFileName := '<unknown>';
    LLine := 0;
    LColumn := 0;
  end;
  
  FErrorCollector.AddError(
    TELCompilerError.Create(
      AMessage,
      'CodeGen',
      LFileName,
      LLine,
      LColumn,
      esError
    )
  );
end;

end.
