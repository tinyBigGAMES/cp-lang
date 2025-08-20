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

unit ELang.Types;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ELang.Common,
  ELang.Parser,
  ELang.Errors;

type
  { TELTypeKind }
  TELTypeKind = (
    tkBasic,
    tkPointer,
    tkArray,
    tkRecord,
    tkFunction,
    tkProcedure,
    tkAlias
  );

  { TELBasicType }
  TELBasicType = (
    btInt, btChar, btBool, btFloat, btDouble,
    btInt8, btInt16, btInt32, btInt64,
    btUInt8, btUInt16, btUInt32, btUInt64
  );

  { TELType }
  TELType = class
  private
    FKind: TELTypeKind;
    FName: string;
    FSize: Integer;
    
  public
    constructor Create(const AKind: TELTypeKind; const AName: string); virtual;
    
    function IsCompatible(const AOther: TELType): Boolean; virtual;
    function GetTypeName(): string; virtual;
    function GetSize(): Integer; virtual;
    
    property Kind: TELTypeKind read FKind;
    property TypeName: string read FName;
    property Size: Integer read FSize;
  end;

  { TELBasicTypeInfo }
  TELBasicTypeInfo = class(TELType)
  private
    FBasicType: TELBasicType;
    
  public
    constructor Create(const ABasicType: TELBasicType); reintroduce;
    
    function IsCompatible(const AOther: TELType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property BasicType: TELBasicType read FBasicType;
  end;

  { TELPointerType }
  TELPointerType = class(TELType)
  private
    FTargetType: TELType;
    
  public
    constructor Create(const ATargetType: TELType); reintroduce;
    destructor Destroy(); override;
    
    function IsCompatible(const AOther: TELType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property TargetType: TELType read FTargetType;
  end;

  { TELArrayType }
  TELArrayType = class(TELType)
  private
    FElementType: TELType;
    FElementCount: Integer; // -1 for dynamic arrays
    
  public
    constructor Create(const AElementType: TELType; const AElementCount: Integer = -1); reintroduce;
    destructor Destroy(); override;
    
    function IsCompatible(const AOther: TELType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property ElementType: TELType read FElementType;
    property ElementCount: Integer read FElementCount;
  end;

  { TELRecordField }
  TELRecordField = record
    FieldName: string;
    FieldType: TELType;
    Offset: Integer;
  end;

  { TELRecordType }
  TELRecordType = class(TELType)
  private
    FFields: TArray<TELRecordField>;
    FFieldMap: TDictionary<string, Integer>;
    
  public
    constructor Create(); reintroduce;
    destructor Destroy(); override;
    
    procedure AddField(const AName: string; const AType: TELType);
    function GetField(const AName: string): TELRecordField;
    function HasField(const AName: string): Boolean;
    function GetFieldOffset(const AName: string): Integer;
    
    function IsCompatible(const AOther: TELType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property Fields: TArray<TELRecordField> read FFields;
  end;

  { TELFunctionType }
  TELFunctionType = class(TELType)
  private
    FParameterTypes: TArray<TELType>;
    FReturnType: TELType; // nil for procedures
    FIsVariadic: Boolean;
    
  public
    constructor Create(const AParameterTypes: TArray<TELType>; const AReturnType: TELType = nil; const AIsVariadic: Boolean = False); reintroduce;
    destructor Destroy(); override;
    
    function IsCompatible(const AOther: TELType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property ParameterTypes: TArray<TELType> read FParameterTypes;
    property ReturnType: TELType read FReturnType;
    property IsVariadic: Boolean read FIsVariadic;
  end;

  { TELTypeManager }
  TELTypeManager = class(TELObject)
  private
    FTypes: TObjectDictionary<string, TELType>;
    FBasicTypes: TDictionary<TELBasicType, TELBasicTypeInfo>;
    
    procedure InitializeBasicTypes();
    
  public
    constructor Create(); override;
    destructor Destroy(); override;
    
    function GetBasicType(const ABasicType: TELBasicType): TELBasicTypeInfo;
    function GetTypeByName(const ATypeName: string): TELType;
    function CreatePointerType(const ATargetType: TELType): TELPointerType;
    function CreateArrayType(const AElementType: TELType; const AElementCount: Integer = -1): TELArrayType;
    function CreateRecordType(const AName: string): TELRecordType;
    function CreateFunctionType(const AParameterTypes: TArray<TELType>; const AReturnType: TELType = nil; const AIsVariadic: Boolean = False): TELFunctionType;
    
    procedure RegisterType(const AName: string; const AType: TELType);
    function ResolveType(const ATypeNode: TELASTNode): TELType;
    
    function AreTypesCompatible(const AType1, AType2: TELType): Boolean;
    function GetCommonType(const AType1, AType2: TELType): TELType;
  end;

implementation

{ TELType }

constructor TELType.Create(const AKind: TELTypeKind; const AName: string);
begin
  inherited Create();
  FKind := AKind;
  FName := AName;
  FSize := 0;
end;

function TELType.IsCompatible(const AOther: TELType): Boolean;
begin
  Result := (Self = AOther) or (Self.ClassName = AOther.ClassName);
end;

function TELType.GetTypeName(): string;
begin
  Result := FName;
end;

function TELType.GetSize(): Integer;
begin
  Result := FSize;
end;

{ TELBasicTypeInfo }

constructor TELBasicTypeInfo.Create(const ABasicType: TELBasicType);
begin
  inherited Create(tkBasic, '');
  FBasicType := ABasicType;
  
  case ABasicType of
    btInt, btInt32: begin FName := 'int32'; FSize := 4; end;
    btChar: begin FName := 'char'; FSize := 1; end;
    btBool: begin FName := 'bool'; FSize := 1; end;
    btFloat: begin FName := 'float'; FSize := 4; end;
    btDouble: begin FName := 'double'; FSize := 8; end;
    btInt8: begin FName := 'int8'; FSize := 1; end;
    btInt16: begin FName := 'int16'; FSize := 2; end;
    btInt64: begin FName := 'int64'; FSize := 8; end;
    btUInt8: begin FName := 'uint8'; FSize := 1; end;
    btUInt16: begin FName := 'uint16'; FSize := 2; end;
    btUInt32: begin FName := 'uint32'; FSize := 4; end;
    btUInt64: begin FName := 'uint64'; FSize := 8; end;
  end;
end;

function TELBasicTypeInfo.IsCompatible(const AOther: TELType): Boolean;
begin
  if AOther is TELBasicTypeInfo then
    Result := FBasicType = TELBasicTypeInfo(AOther).FBasicType
  else
    Result := False;
end;

function TELBasicTypeInfo.GetTypeName(): string;
begin
  Result := FName;
end;

function TELBasicTypeInfo.GetSize(): Integer;
begin
  Result := FSize;
end;

{ TELPointerType }

constructor TELPointerType.Create(const ATargetType: TELType);
begin
  inherited Create(tkPointer, '^' + ATargetType.GetTypeName());
  FTargetType := ATargetType;
  FSize := 8; // 64-bit pointer
end;

destructor TELPointerType.Destroy();
begin
  // Note: We don't free FTargetType as it's managed by TypeManager
  inherited;
end;

function TELPointerType.IsCompatible(const AOther: TELType): Boolean;
begin
  if AOther is TELPointerType then
    Result := FTargetType.IsCompatible(TELPointerType(AOther).FTargetType)
  else
    Result := False;
end;

function TELPointerType.GetTypeName(): string;
begin
  Result := '^' + FTargetType.GetTypeName();
end;

function TELPointerType.GetSize(): Integer;
begin
  Result := 8; // 64-bit pointer
end;

{ TELArrayType }

constructor TELArrayType.Create(const AElementType: TELType; const AElementCount: Integer);
begin
  if AElementCount >= 0 then
    inherited Create(tkArray, Format('array[%d] of %s', [AElementCount, AElementType.GetTypeName()]))
  else
    inherited Create(tkArray, Format('array[] of %s', [AElementType.GetTypeName()]));
    
  FElementType := AElementType;
  FElementCount := AElementCount;
  
  if AElementCount >= 0 then
    FSize := AElementType.GetSize() * AElementCount
  else
    FSize := 8; // Pointer to dynamic array
end;

destructor TELArrayType.Destroy();
begin
  // Note: We don't free FElementType as it's managed by TypeManager
  inherited;
end;

function TELArrayType.IsCompatible(const AOther: TELType): Boolean;
begin
  if AOther is TELArrayType then
  begin
    Result := FElementType.IsCompatible(TELArrayType(AOther).FElementType) and
              (FElementCount = TELArrayType(AOther).FElementCount);
  end
  else
    Result := False;
end;

function TELArrayType.GetTypeName(): string;
begin
  if FElementCount >= 0 then
    Result := Format('array[%d] of %s', [FElementCount, FElementType.GetTypeName()])
  else
    Result := Format('array[] of %s', [FElementType.GetTypeName()]);
end;

function TELArrayType.GetSize(): Integer;
begin
  Result := FSize;
end;

{ TELRecordType }

constructor TELRecordType.Create();
begin
  inherited Create(tkRecord, 'record');
  SetLength(FFields, 0);
  FFieldMap := TDictionary<string, Integer>.Create();
  FSize := 0;
end;

destructor TELRecordType.Destroy();
begin
  FFieldMap.Free();
  inherited;
end;

procedure TELRecordType.AddField(const AName: string; const AType: TELType);
var
  LFieldIndex: Integer;
  LField: TELRecordField;
begin
  LFieldIndex := Length(FFields);
  SetLength(FFields, LFieldIndex + 1);
  
  LField.FieldName := AName;
  LField.FieldType := AType;
  LField.Offset := FSize;
  
  FFields[LFieldIndex] := LField;
  FFieldMap.Add(AName, LFieldIndex);
  
  // Update record size (simple alignment - no padding)
  FSize := FSize + AType.GetSize();
end;

function TELRecordType.GetField(const AName: string): TELRecordField;
var
  LIndex: Integer;
begin
  if FFieldMap.TryGetValue(AName, LIndex) then
    Result := FFields[LIndex]
  else
    raise EELException.Create('Field "%s" not found in record', [AName]);
end;

function TELRecordType.HasField(const AName: string): Boolean;
begin
  Result := FFieldMap.ContainsKey(AName);
end;

function TELRecordType.GetFieldOffset(const AName: string): Integer;
var
  LField: TELRecordField;
begin
  LField := GetField(AName);
  Result := LField.Offset;
end;

function TELRecordType.IsCompatible(const AOther: TELType): Boolean;
begin
  // Record types are compatible only if they're the same instance
  Result := Self = AOther;
end;

function TELRecordType.GetTypeName(): string;
begin
  Result := 'record';
end;

function TELRecordType.GetSize(): Integer;
begin
  Result := FSize;
end;

{ TELFunctionType }

constructor TELFunctionType.Create(const AParameterTypes: TArray<TELType>; const AReturnType: TELType; const AIsVariadic: Boolean);
begin
  if Assigned(AReturnType) then
    inherited Create(tkFunction, 'function')
  else
    inherited Create(tkProcedure, 'procedure');
    
  FParameterTypes := AParameterTypes;
  FReturnType := AReturnType;
  FIsVariadic := AIsVariadic;
  FSize := 8; // Function pointer size
end;

destructor TELFunctionType.Destroy();
begin
  // Note: We don't free parameter/return types as they're managed by TypeManager
  inherited;
end;

function TELFunctionType.IsCompatible(const AOther: TELType): Boolean;
var
  LIndex: Integer;
  LOtherFunc: TELFunctionType;
begin
  if not (AOther is TELFunctionType) then
    Exit(False);
    
  LOtherFunc := TELFunctionType(AOther);
  
  // Check return type compatibility
  if Assigned(FReturnType) <> Assigned(LOtherFunc.FReturnType) then
    Exit(False);
    
  if Assigned(FReturnType) and not FReturnType.IsCompatible(LOtherFunc.FReturnType) then
    Exit(False);
    
  // Check variadic flag
  if FIsVariadic <> LOtherFunc.FIsVariadic then
    Exit(False);
    
  // Check parameter count
  if Length(FParameterTypes) <> Length(LOtherFunc.FParameterTypes) then
    Exit(False);
    
  // Check parameter types
  for LIndex := 0 to High(FParameterTypes) do
  begin
    if not FParameterTypes[LIndex].IsCompatible(LOtherFunc.FParameterTypes[LIndex]) then
      Exit(False);
  end;
  
  Result := True;
end;

function TELFunctionType.GetTypeName(): string;
var
  LResult: string;
  LIndex: Integer;
begin
  if FKind = tkFunction then
    LResult := 'function('
  else
    LResult := 'procedure(';
    
  for LIndex := 0 to High(FParameterTypes) do
  begin
    if LIndex > 0 then
      LResult := LResult + ', ';
    LResult := LResult + FParameterTypes[LIndex].GetTypeName();
  end;
  
  if FIsVariadic then
  begin
    if Length(FParameterTypes) > 0 then
      LResult := LResult + ', ...'
    else
      LResult := LResult + '...';
  end;
  
  LResult := LResult + ')';
  
  if Assigned(FReturnType) then
    LResult := LResult + ': ' + FReturnType.GetTypeName();
    
  Result := LResult;
end;

function TELFunctionType.GetSize(): Integer;
begin
  Result := 8; // Function pointer size
end;

{ TELTypeManager }

constructor TELTypeManager.Create();
begin
  inherited;
  FTypes := TObjectDictionary<string, TELType>.Create([doOwnsValues]);
  FBasicTypes := TDictionary<TELBasicType, TELBasicTypeInfo>.Create();
  InitializeBasicTypes();
end;

destructor TELTypeManager.Destroy();
begin
  FBasicTypes.Free();
  FTypes.Free();
  inherited;
end;

procedure TELTypeManager.InitializeBasicTypes();
var
  LBasicType: TELBasicType;
  LTypeInfo: TELBasicTypeInfo;
begin
  for LBasicType := Low(TELBasicType) to High(TELBasicType) do
  begin
    LTypeInfo := TELBasicTypeInfo.Create(LBasicType);
    FBasicTypes.Add(LBasicType, LTypeInfo);
    FTypes.AddOrSetValue(LTypeInfo.GetTypeName(), LTypeInfo);
  end;
end;

function TELTypeManager.GetBasicType(const ABasicType: TELBasicType): TELBasicTypeInfo;
begin
  Result := FBasicTypes[ABasicType];
end;

function TELTypeManager.GetTypeByName(const ATypeName: string): TELType;
begin
  if not FTypes.TryGetValue(ATypeName, Result) then
    Result := nil;
end;

function TELTypeManager.CreatePointerType(const ATargetType: TELType): TELPointerType;
begin
  Result := TELPointerType.Create(ATargetType);
  // Note: Pointer types are typically not registered globally
end;

function TELTypeManager.CreateArrayType(const AElementType: TELType; const AElementCount: Integer): TELArrayType;
begin
  Result := TELArrayType.Create(AElementType, AElementCount);
  // Note: Array types are typically not registered globally
end;

function TELTypeManager.CreateRecordType(const AName: string): TELRecordType;
begin
  Result := TELRecordType.Create();
  if AName <> '' then
    RegisterType(AName, Result);
end;

function TELTypeManager.CreateFunctionType(const AParameterTypes: TArray<TELType>; const AReturnType: TELType; const AIsVariadic: Boolean): TELFunctionType;
begin
  Result := TELFunctionType.Create(AParameterTypes, AReturnType, AIsVariadic);
  // Note: Function types are typically not registered globally
end;

procedure TELTypeManager.RegisterType(const AName: string; const AType: TELType);
begin
  FTypes.AddOrSetValue(AName, AType);
end;

function TELTypeManager.ResolveType(const ATypeNode: TELASTNode): TELType;
var
  LTypeName: string;
  LTargetType: TELType;
  LElementType: TELType;
  LElementCount: Integer;
  LRecordType: TELRecordType;
  LFieldNode: TELASTNode;
  LFieldName: string;
  LFieldType: TELType;
  LIndex: Integer;
begin
  if not Assigned(ATypeNode) then
    Exit(nil);
    
  case ATypeNode.NodeType of
    astTypeSpec:
      begin
        LTypeName := ATypeNode.Value;
        
        if LTypeName = '^' then
        begin
          // Pointer type
          if ATypeNode.ChildCount() > 0 then
          begin
            LTargetType := ResolveType(ATypeNode.GetChild(0));
            Result := CreatePointerType(LTargetType);
          end
          else
            Result := nil;
        end
        else if LTypeName = 'array' then
        begin
          // Array type
          if ATypeNode.ChildCount() >= 1 then
          begin
            LElementType := ResolveType(ATypeNode.GetChild(ATypeNode.ChildCount() - 1));
            
            if ATypeNode.ChildCount() > 1 then
            begin
              // Fixed size array - would need expression evaluation
              LElementCount := 10; // Placeholder
            end
            else
              LElementCount := -1; // Dynamic array
              
            Result := CreateArrayType(LElementType, LElementCount);
          end
          else
            Result := nil;
        end
        else if LTypeName = 'record' then
        begin
          // Record type
          LRecordType := CreateRecordType('');
          
          for LIndex := 0 to ATypeNode.ChildCount() - 1 do
          begin
            LFieldNode := ATypeNode.GetChild(LIndex);
            if (LFieldNode.NodeType = astVariableDecl) and (LFieldNode.ChildCount() >= 2) then
            begin
              LFieldName := LFieldNode.GetChild(0).Value;
              LFieldType := ResolveType(LFieldNode.GetChild(LFieldNode.ChildCount() - 1));
              LRecordType.AddField(LFieldName, LFieldType);
            end;
          end;
          
          Result := LRecordType;
        end
        else
        begin
          // Named type or basic type
          Result := GetTypeByName(LTypeName);
        end;
      end;
  else
    Result := nil;
  end;
end;

function TELTypeManager.AreTypesCompatible(const AType1, AType2: TELType): Boolean;
begin
  if not Assigned(AType1) or not Assigned(AType2) then
    Result := False
  else
    Result := AType1.IsCompatible(AType2);
end;

function TELTypeManager.GetCommonType(const AType1, AType2: TELType): TELType;
begin
  if AreTypesCompatible(AType1, AType2) then
    Result := AType1
  else
    Result := nil; // No common type
end;

end.
