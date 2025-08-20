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

unit ELang.TypeChecker;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ELang.Common,
  ELang.Parser,
  ELang.Types,
  ELang.Symbols,
  ELang.Errors,
  ELang.SourceMap;

type
  { TELTypeChecker }
  TELTypeChecker = class(TELObject)
  private
    FTypeManager: TELTypeManager;
    FSymbolTable: TELSymbolTable;
    FErrorCollector: TELErrorCollector;
    
    function GetNodePosition(const ANode: TELASTNode): TELSourcePosition;
    function GetBinaryOperatorResultType(const AOperator: string; const ALeftType, ARightType: TELType): TELType;
    function GetUnaryOperatorResultType(const AOperator: string; const AOperandType: TELType): TELType;
    function IsNumericType(const AType: TELType): Boolean;
    function IsIntegerType(const AType: TELType): Boolean;
    function IsBooleanType(const AType: TELType): Boolean;
    function IsPointerType(const AType: TELType): Boolean;
    function CanImplicitlyConvert(const AFromType, AToType: TELType): Boolean;
    
  public
    constructor Create(const ATypeManager: TELTypeManager; 
      const ASymbolTable: TELSymbolTable; const AErrorCollector: TELErrorCollector); reintroduce;
    destructor Destroy(); override;
    
    function InferExpressionType(const ANode: TELASTNode): TELType;
    function CheckAssignmentCompatibility(const ALValueType, ARValueType: TELType; 
      const ANode: TELASTNode): Boolean;
    function CheckFunctionCall(const AFunctionSymbol: TELSymbol; 
      const AArgumentTypes: TArray<TELType>; const ANode: TELASTNode): TELType;
    function ValidateArrayAccess(const AArrayType: TELType; const AIndexType: TELType; 
      const ANode: TELASTNode): TELType;
    function ValidateMemberAccess(const ARecordType: TELType; const AMemberName: string; 
      const ANode: TELASTNode): TELType;
    function ValidatePointerDereference(const APointerType: TELType; 
      const ANode: TELASTNode): TELType;
  end;

implementation

{ TELTypeChecker }

constructor TELTypeChecker.Create(const ATypeManager: TELTypeManager; 
  const ASymbolTable: TELSymbolTable; const AErrorCollector: TELErrorCollector);
begin
  inherited Create();
  FTypeManager := ATypeManager;
  FSymbolTable := ASymbolTable;
  FErrorCollector := AErrorCollector;
end;

destructor TELTypeChecker.Destroy();
begin
  inherited;
end;

function TELTypeChecker.GetNodePosition(const ANode: TELASTNode): TELSourcePosition;
begin
  if Assigned(ANode) then
    Result := TELSourcePosition.Create('<unknown>', 0, 0, ANode.Position)
  else
    Result := TELSourcePosition.Create('<unknown>', 0, 0, 0);
end;

function TELTypeChecker.IsNumericType(const AType: TELType): Boolean;
begin
  if not (AType is TELBasicTypeInfo) then
    Exit(False);
    
  case TELBasicTypeInfo(AType).BasicType of
    btInt, btFloat, btDouble, btInt8, btInt16, btInt32, btInt64,
    btUInt8, btUInt16, btUInt32, btUInt64:
      Result := True;
  else
    Result := False;
  end;
end;

function TELTypeChecker.IsIntegerType(const AType: TELType): Boolean;
begin
  if not (AType is TELBasicTypeInfo) then
    Exit(False);
    
  case TELBasicTypeInfo(AType).BasicType of
    btInt, btInt8, btInt16, btInt32, btInt64,
    btUInt8, btUInt16, btUInt32, btUInt64:
      Result := True;
  else
    Result := False;
  end;
end;

function TELTypeChecker.IsBooleanType(const AType: TELType): Boolean;
begin
  Result := (AType is TELBasicTypeInfo) and 
            (TELBasicTypeInfo(AType).BasicType = btBool);
end;

function TELTypeChecker.IsPointerType(const AType: TELType): Boolean;
begin
  Result := AType is TELPointerType;
end;

function TELTypeChecker.CanImplicitlyConvert(const AFromType, AToType: TELType): Boolean;
begin
  // Same type
  if AFromType = AToType then
    Exit(True);
    
  // Compatible types check
  if FTypeManager.AreTypesCompatible(AFromType, AToType) then
    Exit(True);
    
  // Numeric conversions
  if IsNumericType(AFromType) and IsNumericType(AToType) then
  begin
    // Allow implicit widening conversions
    if (AFromType is TELBasicTypeInfo) and (AToType is TELBasicTypeInfo) then
    begin
      case TELBasicTypeInfo(AFromType).BasicType of
        btInt8: Result := TELBasicTypeInfo(AToType).BasicType in [btInt16, btInt32, btInt64];
        btInt16: Result := TELBasicTypeInfo(AToType).BasicType in [btInt32, btInt64];
        btInt32: Result := TELBasicTypeInfo(AToType).BasicType = btInt64;
        btUInt8: Result := TELBasicTypeInfo(AToType).BasicType in [btUInt16, btUInt32, btUInt64];
        btUInt16: Result := TELBasicTypeInfo(AToType).BasicType in [btUInt32, btUInt64];
        btUInt32: Result := TELBasicTypeInfo(AToType).BasicType = btUInt64;
        btFloat: Result := TELBasicTypeInfo(AToType).BasicType = btDouble;
      else
        Result := False;
      end;
    end
    else
      Result := False;
  end
  else
    Result := False;
end;

function TELTypeChecker.GetBinaryOperatorResultType(const AOperator: string; const ALeftType, ARightType: TELType): TELType;
begin
  Result := nil;
  
  if AOperator = '+' then
  begin
    if IsNumericType(ALeftType) and IsNumericType(ARightType) then
      Result := FTypeManager.GetCommonType(ALeftType, ARightType)
    else if IsPointerType(ALeftType) and IsIntegerType(ARightType) then
      Result := ALeftType
    else if IsIntegerType(ALeftType) and IsPointerType(ARightType) then
      Result := ARightType;
  end
  else if AOperator = '-' then
  begin
    if IsNumericType(ALeftType) and IsNumericType(ARightType) then
      Result := FTypeManager.GetCommonType(ALeftType, ARightType)
    else if IsPointerType(ALeftType) and IsIntegerType(ARightType) then
      Result := ALeftType
    else if IsPointerType(ALeftType) and IsPointerType(ARightType) then
      Result := FTypeManager.GetBasicType(btInt32); // Pointer difference
  end
  else if (AOperator = '*') or (AOperator = '/') then
  begin
    if IsNumericType(ALeftType) and IsNumericType(ARightType) then
      Result := FTypeManager.GetCommonType(ALeftType, ARightType);
  end
  else if (AOperator = 'div') or (AOperator = 'mod') then
  begin
    if IsIntegerType(ALeftType) and IsIntegerType(ARightType) then
      Result := FTypeManager.GetCommonType(ALeftType, ARightType);
  end
  else if (AOperator = 'and') or (AOperator = 'or') then
  begin
    if IsBooleanType(ALeftType) and IsBooleanType(ARightType) then
      Result := FTypeManager.GetBasicType(btBool);
  end
  else if (AOperator = '=') or (AOperator = '<>') then
  begin
    if FTypeManager.AreTypesCompatible(ALeftType, ARightType) then
      Result := FTypeManager.GetBasicType(btBool);
  end
  else if (AOperator = '<') or (AOperator = '>') or (AOperator = '<=') or (AOperator = '>=') then
  begin
    if IsNumericType(ALeftType) and IsNumericType(ARightType) then
      Result := FTypeManager.GetBasicType(btBool)
    else if IsPointerType(ALeftType) and IsPointerType(ARightType) then
      Result := FTypeManager.GetBasicType(btBool);
  end;
end;

function TELTypeChecker.GetUnaryOperatorResultType(const AOperator: string; const AOperandType: TELType): TELType;
begin
  Result := nil;
  
  if (AOperator = '+') or (AOperator = '-') then
  begin
    if IsNumericType(AOperandType) then
      Result := AOperandType;
  end
  else if AOperator = 'not' then
  begin
    if IsBooleanType(AOperandType) then
      Result := AOperandType;
  end
  else if AOperator = '@' then
  begin
    // Address-of operator
    Result := FTypeManager.CreatePointerType(AOperandType);
  end
  else if AOperator = '^' then
  begin
    // Pointer dereference
    if IsPointerType(AOperandType) then
      Result := TELPointerType(AOperandType).TargetType;
  end;
end;

function TELTypeChecker.InferExpressionType(const ANode: TELASTNode): TELType;
var
  LSymbol: TELSymbol;
  LLeftType: TELType;
  LRightType: TELType;
  LOperandType: TELType;
  LArrayType: TELType;
  LIndexType: TELType;
  LRecordType: TELType;
  LMemberName: string;
  LPointerType: TELType;
  LFunctionType: TELFunctionType;
  LArgumentTypes: TArray<TELType>;
  LArgIndex: Integer;
  LArgNode: TELASTNode;
begin
  Result := nil;
  
  if not Assigned(ANode) then
    Exit;
    
  case ANode.NodeType of
    astLiteral:
      begin
        // Infer type from literal value
        if ANode.Value = 'true' then
          Result := FTypeManager.GetBasicType(btBool)
        else if ANode.Value = 'false' then
          Result := FTypeManager.GetBasicType(btBool)
        else if ANode.Value.StartsWith('''') then
          Result := FTypeManager.GetBasicType(btChar)
        else if ANode.Value.StartsWith('"') then
          Result := FTypeManager.CreatePointerType(FTypeManager.GetBasicType(btChar)) // String as char*
        else if ANode.Value.Contains('.') then
          Result := FTypeManager.GetBasicType(btFloat)
        else
          Result := FTypeManager.GetBasicType(btInt32);
      end;
      
    astIdentifier:
      begin
        LSymbol := FSymbolTable.LookupSymbol(ANode.Value);
        if Assigned(LSymbol) then
        begin
          LSymbol.IsUsed := True;
          Result := LSymbol.SymbolType;
        end
        else
        begin
          FErrorCollector.AddSemanticError(
            Format('Undeclared identifier: %s', [ANode.Value]),
            ANode.Value,
            '<unknown>', 0, 0
          );
        end;
      end;
      
    astBinaryOp:
      begin
        if ANode.ChildCount() >= 2 then
        begin
          LLeftType := InferExpressionType(ANode.GetChild(0));
          LRightType := InferExpressionType(ANode.GetChild(1));
          
          if Assigned(LLeftType) and Assigned(LRightType) then
          begin
            Result := GetBinaryOperatorResultType(ANode.Value, LLeftType, LRightType);
            if not Assigned(Result) then
            begin
              FErrorCollector.AddTypeError(
                Format('Invalid operands for operator "%s"', [ANode.Value]),
                Format('%s %s %s', [LLeftType.GetTypeName(), ANode.Value, LRightType.GetTypeName()]),
                'compatible types',
                '<unknown>', 0, 0
              );
            end;
          end;
        end;
      end;
      
    astUnaryOp:
      begin
        if ANode.ChildCount() >= 1 then
        begin
          LOperandType := InferExpressionType(ANode.GetChild(0));
          if Assigned(LOperandType) then
          begin
            Result := GetUnaryOperatorResultType(ANode.Value, LOperandType);
            if not Assigned(Result) then
            begin
              FErrorCollector.AddTypeError(
                Format('Invalid operand for unary operator "%s"', [ANode.Value]),
                LOperandType.GetTypeName(),
                'compatible type',
                '<unknown>', 0, 0
              );
            end;
          end;
        end;
      end;
      
    astArrayAccess:
      begin
        if ANode.ChildCount() >= 2 then
        begin
          LArrayType := InferExpressionType(ANode.GetChild(0));
          LIndexType := InferExpressionType(ANode.GetChild(1));
          Result := ValidateArrayAccess(LArrayType, LIndexType, ANode);
        end;
      end;
      
    astMemberAccess:
      begin
        if ANode.ChildCount() >= 2 then
        begin
          LRecordType := InferExpressionType(ANode.GetChild(0));
          LMemberName := ANode.GetChild(1).Value;
          Result := ValidateMemberAccess(LRecordType, LMemberName, ANode);
        end;
      end;
      
    astFunctionCall:
      begin
        if ANode.ChildCount() >= 1 then
        begin
          // Get function type
          LSymbol := nil;
          if ANode.GetChild(0).NodeType = astIdentifier then
          begin
            LSymbol := FSymbolTable.LookupSymbol(ANode.GetChild(0).Value);
            if Assigned(LSymbol) then
              LSymbol.IsUsed := True;
          end;
          
          if Assigned(LSymbol) and (LSymbol.Kind = skFunction) then
          begin
            // Collect argument types
            if ANode.ChildCount() >= 2 then
            begin
              SetLength(LArgumentTypes, ANode.GetChild(1).ChildCount());
              for LArgIndex := 0 to ANode.GetChild(1).ChildCount() - 1 do
              begin
                LArgNode := ANode.GetChild(1).GetChild(LArgIndex);
                LArgumentTypes[LArgIndex] := InferExpressionType(LArgNode);
              end;
            end;
            
            Result := CheckFunctionCall(LSymbol, LArgumentTypes, ANode);
          end
          else
          begin
            FErrorCollector.AddSemanticError(
              Format('"%s" is not a function', [ANode.GetChild(0).Value]),
              ANode.GetChild(0).Value,
              '<unknown>', 0, 0
            );
          end;
        end;
      end;
  end;
end;

function TELTypeChecker.CheckAssignmentCompatibility(const ALValueType, ARValueType: TELType; 
  const ANode: TELASTNode): Boolean;
begin
  Result := False;
  
  if not Assigned(ALValueType) or not Assigned(ARValueType) then
    Exit;
    
  if CanImplicitlyConvert(ARValueType, ALValueType) then
    Result := True
  else
  begin
    FErrorCollector.AddTypeError(
      'Type mismatch in assignment',
      ALValueType.GetTypeName(),
      ARValueType.GetTypeName(),
      '<unknown>', 0, 0
    );
  end;
end;

function TELTypeChecker.CheckFunctionCall(const AFunctionSymbol: TELSymbol; 
  const AArgumentTypes: TArray<TELType>; const ANode: TELASTNode): TELType;
var
  LFunctionType: TELFunctionType;
  LParameterTypes: TArray<TELType>;
  LIndex: Integer;
begin
  Result := nil;
  
  if not Assigned(AFunctionSymbol) or not (AFunctionSymbol.SymbolType is TELFunctionType) then
    Exit;
    
  LFunctionType := TELFunctionType(AFunctionSymbol.SymbolType);
  LParameterTypes := LFunctionType.ParameterTypes;
  
  // Check parameter count
  if LFunctionType.IsVariadic then
  begin
    // For variadic functions, check minimum required parameters
    if Length(AArgumentTypes) < Length(LParameterTypes) then
    begin
      FErrorCollector.AddSemanticError(
        Format('Function "%s" expects at least %d parameters, got %d', 
          [AFunctionSymbol.SymbolName, Length(LParameterTypes), Length(AArgumentTypes)]),
        AFunctionSymbol.SymbolName,
        '<unknown>', 0, 0
      );
      Exit;
    end;
  end
  else
  begin
    // For non-variadic functions, check exact parameter count
    if Length(AArgumentTypes) <> Length(LParameterTypes) then
    begin
      FErrorCollector.AddSemanticError(
        Format('Function "%s" expects %d parameters, got %d', 
          [AFunctionSymbol.SymbolName, Length(LParameterTypes), Length(AArgumentTypes)]),
        AFunctionSymbol.SymbolName,
        '<unknown>', 0, 0
      );
      Exit;
    end;
  end;
  
  // Check parameter types (only for fixed parameters)
  for LIndex := 0 to Length(LParameterTypes) - 1 do
  begin
    if LIndex < Length(AArgumentTypes) then
    begin
      if not CanImplicitlyConvert(AArgumentTypes[LIndex], LParameterTypes[LIndex]) then
      begin
        FErrorCollector.AddTypeError(
          Format('Parameter %d type mismatch in call to "%s"', [LIndex + 1, AFunctionSymbol.SymbolName]),
          LParameterTypes[LIndex].GetTypeName(),
          AArgumentTypes[LIndex].GetTypeName(),
          '<unknown>', 0, 0
        );
      end;
    end;
  end;
  
  Result := LFunctionType.ReturnType;
end;

function TELTypeChecker.ValidateArrayAccess(const AArrayType: TELType; const AIndexType: TELType; 
  const ANode: TELASTNode): TELType;
begin
  Result := nil;
  
  if not Assigned(AArrayType) or not Assigned(AIndexType) then
    Exit;
    
  if AArrayType is TELArrayType then
  begin
    if not IsIntegerType(AIndexType) then
    begin
      FErrorCollector.AddTypeError(
        'Array index must be an integer type',
        'integer type',
        AIndexType.GetTypeName(),
        '<unknown>', 0, 0
      );
    end
    else
      Result := TELArrayType(AArrayType).ElementType;
  end
  else if AArrayType is TELPointerType then
  begin
    if not IsIntegerType(AIndexType) then
    begin
      FErrorCollector.AddTypeError(
        'Pointer index must be an integer type',
        'integer type',
        AIndexType.GetTypeName(),
        '<unknown>', 0, 0
      );
    end
    else
      Result := TELPointerType(AArrayType).TargetType;
  end
  else
  begin
    FErrorCollector.AddTypeError(
      'Cannot index non-array type',
      'array or pointer type',
      AArrayType.GetTypeName(),
      '<unknown>', 0, 0
    );
  end;
end;

function TELTypeChecker.ValidateMemberAccess(const ARecordType: TELType; const AMemberName: string; 
  const ANode: TELASTNode): TELType;
var
  LRecordType: TELRecordType;
  LField: TELRecordField;
begin
  Result := nil;
  
  if not Assigned(ARecordType) then
    Exit;
    
  if ARecordType is TELRecordType then
  begin
    LRecordType := TELRecordType(ARecordType);
    if LRecordType.HasField(AMemberName) then
    begin
      LField := LRecordType.GetField(AMemberName);
      Result := LField.FieldType;
    end
    else
    begin
      FErrorCollector.AddSemanticError(
        Format('Record has no member named "%s"', [AMemberName]),
        AMemberName,
        '<unknown>', 0, 0
      );
    end;
  end
  else
  begin
    FErrorCollector.AddTypeError(
      'Cannot access member of non-record type',
      'record type',
      ARecordType.GetTypeName(),
      '<unknown>', 0, 0
    );
  end;
end;

function TELTypeChecker.ValidatePointerDereference(const APointerType: TELType; 
  const ANode: TELASTNode): TELType;
begin
  Result := nil;
  
  if not Assigned(APointerType) then
    Exit;
    
  if APointerType is TELPointerType then
    Result := TELPointerType(APointerType).TargetType
  else
  begin
    FErrorCollector.AddTypeError(
      'Cannot dereference non-pointer type',
      'pointer type',
      APointerType.GetTypeName(),
      '<unknown>', 0, 0
    );
  end;
end;

end.
