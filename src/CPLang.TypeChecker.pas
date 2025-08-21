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

unit CPLang.TypeChecker;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Common,
  CPLang.Parser,
  CPLang.Types,
  CPLang.Symbols,
  CPLang.Errors,
  CPLang.SourceMap;

type
  { TCPTypeChecker }
  TCPTypeChecker = class
  private
    FTypeManager: TCPTypeManager;
    FSymbolTable: TCPSymbolTable;
    FErrorCollector: TCPErrorCollector;
    FMainFileName: string;
    FSourceMapper: TCPSourceMapper;
    
    function GetNodePosition(const ANode: TCPASTNode): TCPSourcePosition;
    function GetBinaryOperatorResultType(const AOperator: string; const ALeftType, ARightType: TCPType): TCPType;
    function GetUnaryOperatorResultType(const AOperator: string; const AOperandType: TCPType): TCPType;
    function IsNumericType(const AType: TCPType): Boolean;
    function IsIntegerType(const AType: TCPType): Boolean;
    function IsBooleanType(const AType: TCPType): Boolean;
    function IsPointerType(const AType: TCPType): Boolean;
    function CanImplicitlyConvert(const AFromType, AToType: TCPType): Boolean;
    
  public
    constructor Create(const ATypeManager: TCPTypeManager;
      const ASymbolTable: TCPSymbolTable; const AErrorCollector: TCPErrorCollector;
      const AMainFileName: string = '<source>'; const ASourceMapper: TCPSourceMapper = nil);
    destructor Destroy(); override;
    
    function InferExpressionType(const ANode: TCPASTNode): TCPType;
    function CheckAssignmentCompatibility(const ALValueType, ARValueType: TCPType;
      const ANode: TCPASTNode): Boolean;
    function CheckFunctionCall(const AFunctionSymbol: TCPSymbol;
      const AArgumentTypes: TArray<TCPType>; const ANode: TCPASTNode): TCPType;
    function ValidateArrayAccess(const AArrayType: TCPType; const AIndexType: TCPType;
      const ANode: TCPASTNode): TCPType;
    function ValidateMemberAccess(const ARecordType: TCPType; const AMemberName: string;
      const ANode: TCPASTNode): TCPType;
    function ValidatePointerDereference(const APointerType: TCPType;
      const ANode: TCPASTNode): TCPType;
    procedure SetMainFileName(const AFileName: string);
  end;

implementation

{ TCPTypeChecker }
constructor TCPTypeChecker.Create(const ATypeManager: TCPTypeManager;
  const ASymbolTable: TCPSymbolTable; const AErrorCollector: TCPErrorCollector;
  const AMainFileName: string; const ASourceMapper: TCPSourceMapper);
begin
  inherited Create();

  FTypeManager := ATypeManager;
  FSymbolTable := ASymbolTable;
  FErrorCollector := AErrorCollector;
  FMainFileName := AMainFileName;
  FSourceMapper := ASourceMapper;
end;

destructor TCPTypeChecker.Destroy();
begin
  inherited;
end;

function TCPTypeChecker.GetNodePosition(const ANode: TCPASTNode): TCPSourcePosition;
begin
  if Assigned(ANode) and (ANode.Position > 0) and Assigned(FSourceMapper) then
  begin
    // Map character position through source mapper for includes
    Result := FSourceMapper.MapPosition(ANode.Position);
  end
  else if Assigned(ANode) and (ANode.Position > 0) then
  begin
    // Fallback: use main filename with calculated position
    Result := TCPSourcePosition.Create(FMainFileName, 0, 0, ANode.Position);
  end
  else
  begin
    // Last resort: use main filename with no position
    Result := TCPSourcePosition.Create(FMainFileName, 0, 0, 0);
  end;
end;

function TCPTypeChecker.IsNumericType(const AType: TCPType): Boolean;
begin
  if not (AType is TCPBasicTypeInfo) then
    Exit(False);
    
  case TCPBasicTypeInfo(AType).BasicType of
    btInt, btFloat, btDouble, btInt8, btInt16, btInt32, btInt64,
    btUInt8, btUInt16, btUInt32, btUInt64:
      Result := True;
  else
    Result := False;
  end;
end;

function TCPTypeChecker.IsIntegerType(const AType: TCPType): Boolean;
begin
  if not (AType is TCPBasicTypeInfo) then
    Exit(False);
    
  case TCPBasicTypeInfo(AType).BasicType of
    btInt, btInt8, btInt16, btInt32, btInt64,
    btUInt8, btUInt16, btUInt32, btUInt64:
      Result := True;
  else
    Result := False;
  end;
end;

function TCPTypeChecker.IsBooleanType(const AType: TCPType): Boolean;
begin
  Result := (AType is TCPBasicTypeInfo) and
            (TCPBasicTypeInfo(AType).BasicType = btBool);
end;

function TCPTypeChecker.IsPointerType(const AType: TCPType): Boolean;
begin
  Result := AType is TCPPointerType;
end;

function TCPTypeChecker.CanImplicitlyConvert(const AFromType, AToType: TCPType): Boolean;
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
    if (AFromType is TCPBasicTypeInfo) and (AToType is TCPBasicTypeInfo) then
    begin
      case TCPBasicTypeInfo(AFromType).BasicType of
        btInt8: Result := TCPBasicTypeInfo(AToType).BasicType in [btInt16, btInt32, btInt64];
        btInt16: Result := TCPBasicTypeInfo(AToType).BasicType in [btInt32, btInt64];
        btInt32: Result := TCPBasicTypeInfo(AToType).BasicType = btInt64;
        btUInt8: Result := TCPBasicTypeInfo(AToType).BasicType in [btUInt16, btUInt32, btUInt64];
        btUInt16: Result := TCPBasicTypeInfo(AToType).BasicType in [btUInt32, btUInt64];
        btUInt32: Result := TCPBasicTypeInfo(AToType).BasicType = btUInt64;
        btFloat: Result := TCPBasicTypeInfo(AToType).BasicType = btDouble;
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

function TCPTypeChecker.GetBinaryOperatorResultType(const AOperator: string; const ALeftType, ARightType: TCPType): TCPType;
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

function TCPTypeChecker.GetUnaryOperatorResultType(const AOperator: string; const AOperandType: TCPType): TCPType;
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
      Result := TCPPointerType(AOperandType).TargetType;
  end;
end;

function TCPTypeChecker.InferExpressionType(const ANode: TCPASTNode): TCPType;
var
  LSymbol: TCPSymbol;
  LLeftType: TCPType;
  LRightType: TCPType;
  LOperandType: TCPType;
  LArrayType: TCPType;
  LIndexType: TCPType;
  LRecordType: TCPType;
  LMemberName: string;
  LArgumentTypes: TArray<TCPType>;
  LArgIndex: Integer;
  LArgNode: TCPASTNode;
  LPos: TCPSourcePosition;
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
          LPos := GetNodePosition(ANode);
          FErrorCollector.AddSemanticError(
            Format('Undeclared identifier: %s', [ANode.Value]),
            ANode.Value,
            LPos.FileName, LPos.Line, LPos.Column
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
              LPos := GetNodePosition(ANode);
              FErrorCollector.AddTypeError(
                Format('Invalid operands for operator "%s"', [ANode.Value]),
                Format('%s %s %s', [LLeftType.GetTypeName(), ANode.Value, LRightType.GetTypeName()]),
                'compatible types',
                LPos.FileName, LPos.Line, LPos.Column
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
              LPos := GetNodePosition(ANode);
              FErrorCollector.AddTypeError(
                Format('Invalid operand for unary operator "%s"', [ANode.Value]),
                LOperandType.GetTypeName(),
                'compatible type',
                LPos.FileName, LPos.Line, LPos.Column
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
            LPos := GetNodePosition(ANode);
            FErrorCollector.AddSemanticError(
              Format('"%s" is not a function', [ANode.GetChild(0).Value]),
              ANode.GetChild(0).Value,
              LPos.FileName, LPos.Line, LPos.Column
            );
          end;
        end;
      end;
  end;
end;

function TCPTypeChecker.CheckAssignmentCompatibility(const ALValueType, ARValueType: TCPType;
  const ANode: TCPASTNode): Boolean;
var
  LPos: TCPSourcePosition;
begin
  Result := False;
  
  if not Assigned(ALValueType) or not Assigned(ARValueType) then
    Exit;
    
  if CanImplicitlyConvert(ARValueType, ALValueType) then
    Result := True
  else
  begin
    LPos := GetNodePosition(ANode);
    FErrorCollector.AddTypeError(
      'Type mismatch in assignment',
      ALValueType.GetTypeName(),
      ARValueType.GetTypeName(),
      LPos.FileName, LPos.Line, LPos.Column
    );
  end;
end;

function TCPTypeChecker.CheckFunctionCall(const AFunctionSymbol: TCPSymbol;
  const AArgumentTypes: TArray<TCPType>; const ANode: TCPASTNode): TCPType;
var
  LFunctionType: TCPFunctionType;
  LParameterTypes: TArray<TCPType>;
  LIndex: Integer;
  LPos: TCPSourcePosition;
begin
  Result := nil;
  
  if not Assigned(AFunctionSymbol) or not (AFunctionSymbol.SymbolType is TCPFunctionType) then
    Exit;
    
  LFunctionType := TCPFunctionType(AFunctionSymbol.SymbolType);
  LParameterTypes := LFunctionType.ParameterTypes;
  
  // Check parameter count
  if LFunctionType.IsVariadic then
  begin
    // For variadic functions, check minimum required parameters
    if Length(AArgumentTypes) < Length(LParameterTypes) then
    begin
      LPos := GetNodePosition(ANode);
      FErrorCollector.AddSemanticError(
        Format('Function "%s" expects at least %d parameters, got %d', 
          [AFunctionSymbol.SymbolName, Length(LParameterTypes), Length(AArgumentTypes)]),
        AFunctionSymbol.SymbolName,
        LPos.FileName, LPos.Line, LPos.Column
      );
      Exit;
    end;
  end
  else
  begin
    // For non-variadic functions, check exact parameter count
    if Length(AArgumentTypes) <> Length(LParameterTypes) then
    begin
      LPos := GetNodePosition(ANode);
      FErrorCollector.AddSemanticError(
        Format('Function "%s" expects %d parameters, got %d', 
          [AFunctionSymbol.SymbolName, Length(LParameterTypes), Length(AArgumentTypes)]),
        AFunctionSymbol.SymbolName,
        LPos.FileName, LPos.Line, LPos.Column
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
        LPos := GetNodePosition(ANode);
        FErrorCollector.AddTypeError(
          Format('Parameter %d type mismatch in call to "%s"', [LIndex + 1, AFunctionSymbol.SymbolName]),
          LParameterTypes[LIndex].GetTypeName(),
          AArgumentTypes[LIndex].GetTypeName(),
          LPos.FileName, LPos.Line, LPos.Column
        );
      end;
    end;
  end;
  
  Result := LFunctionType.ReturnType;
end;

function TCPTypeChecker.ValidateArrayAccess(const AArrayType: TCPType; const AIndexType: TCPType;
  const ANode: TCPASTNode): TCPType;
var
  LPos: TCPSourcePosition;
begin
  Result := nil;
  
  if not Assigned(AArrayType) or not Assigned(AIndexType) then
    Exit;
    
  if AArrayType is TCPArrayType then
  begin
    if not IsIntegerType(AIndexType) then
    begin
      LPos := GetNodePosition(ANode);
      FErrorCollector.AddTypeError(
        'Array index must be an integer type',
        'integer type',
        AIndexType.GetTypeName(),
        LPos.FileName, LPos.Line, LPos.Column
      );
    end
    else
      Result := TCPArrayType(AArrayType).ElementType;
  end
  else if AArrayType is TCPPointerType then
  begin
    if not IsIntegerType(AIndexType) then
    begin
      LPos := GetNodePosition(ANode);
      FErrorCollector.AddTypeError(
        'Pointer index must be an integer type',
        'integer type',
        AIndexType.GetTypeName(),
        LPos.FileName, LPos.Line, LPos.Column
      );
    end
    else
      Result := TCPPointerType(AArrayType).TargetType;
  end
  else
  begin
    LPos := GetNodePosition(ANode);
    FErrorCollector.AddTypeError(
      'Cannot index non-array type',
      'array or pointer type',
      AArrayType.GetTypeName(),
      LPos.FileName, LPos.Line, LPos.Column
    );
  end;
end;

function TCPTypeChecker.ValidateMemberAccess(const ARecordType: TCPType; const AMemberName: string;
  const ANode: TCPASTNode): TCPType;
var
  LRecordType: TCPRecordType;
  LField: TCPRecordField;
  LPos: TCPSourcePosition;
begin
  Result := nil;
  
  if not Assigned(ARecordType) then
    Exit;
    
  if ARecordType is TCPRecordType then
  begin
    LRecordType := TCPRecordType(ARecordType);
    if LRecordType.HasField(AMemberName) then
    begin
      LField := LRecordType.GetField(AMemberName);
      Result := LField.FieldType;
    end
    else
    begin
      LPos := GetNodePosition(ANode);
      FErrorCollector.AddSemanticError(
        Format('Record has no member named "%s"', [AMemberName]),
        AMemberName,
        LPos.FileName, LPos.Line, LPos.Column
      );
    end;
  end
  else
  begin
    LPos := GetNodePosition(ANode);
    FErrorCollector.AddTypeError(
      'Cannot access member of non-record type',
      'record type',
      ARecordType.GetTypeName(),
      LPos.FileName, LPos.Line, LPos.Column
    );
  end;
end;

function TCPTypeChecker.ValidatePointerDereference(const APointerType: TCPType;
  const ANode: TCPASTNode): TCPType;
var
  LPos: TCPSourcePosition;
begin
  Result := nil;
  
  if not Assigned(APointerType) then
    Exit;
    
  if APointerType is TCPPointerType then
    Result := TCPPointerType(APointerType).TargetType
  else
  begin
    LPos := GetNodePosition(ANode);
    FErrorCollector.AddTypeError(
      'Cannot dereference non-pointer type',
      'pointer type',
      APointerType.GetTypeName(),
      LPos.FileName, LPos.Line, LPos.Column
    );
  end;
end;

procedure TCPTypeChecker.SetMainFileName(const AFileName: string);
begin
  FMainFileName := AFileName;
end;

end.
