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

unit CPLang.Types;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Common,
  CPLang.Parser,
  CPLang.Errors;

type
  { TCPTypeKind }
  TCPTypeKind = (
    tkBasic,
    tkPointer,
    tkArray,
    tkRecord,
    tkFunction,
    tkProcedure,
    tkAlias
  );

  { TCPBasicType }
  TCPBasicType = (
    btInt, btChar, btBool, btFloat, btDouble,
    btInt8, btInt16, btInt32, btInt64,
    btUInt8, btUInt16, btUInt32, btUInt64
  );

  { TCPType }
  TCPType = class
  private
    FKind: TCPTypeKind;
    FName: string;
    FSize: Integer;
    
  public
    constructor Create(const AKind: TCPTypeKind; const AName: string); virtual;
    
    function IsCompatible(const AOther: TCPType): Boolean; virtual;
    function GetTypeName(): string; virtual;
    function GetSize(): Integer; virtual;
    
    property Kind: TCPTypeKind read FKind;
    property TypeName: string read FName;
    property Size: Integer read FSize;
  end;

  { TCPBasicTypeInfo }
  TCPBasicTypeInfo = class(TCPType)
  private
    FBasicType: TCPBasicType;
    
  public
    constructor Create(const ABasicType: TCPBasicType); reintroduce;
    
    function IsCompatible(const AOther: TCPType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property BasicType: TCPBasicType read FBasicType;
  end;

  { TCPPointerType }
  TCPPointerType = class(TCPType)
  private
    FTargetType: TCPType;
    
  public
    constructor Create(const ATargetType: TCPType); reintroduce;
    destructor Destroy(); override;
    
    function IsCompatible(const AOther: TCPType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property TargetType: TCPType read FTargetType;
  end;

  { TCPArrayType }
  TCPArrayType = class(TCPType)
  private
    FElementType: TCPType;
    FElementCount: Integer; // -1 for dynamic arrays
    
  public
    constructor Create(const AElementType: TCPType; const AElementCount: Integer = -1); reintroduce;
    destructor Destroy(); override;
    
    function IsCompatible(const AOther: TCPType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property ElementType: TCPType read FElementType;
    property ElementCount: Integer read FElementCount;
  end;

  { TCPRecordField }
  TCPRecordField = record
    FieldName: string;
    FieldType: TCPType;
    Offset: Integer;
  end;

  { TCPRecordType }
  TCPRecordType = class(TCPType)
  private
    FFields: TArray<TCPRecordField>;
    FFieldMap: TDictionary<string, Integer>;
    
  public
    constructor Create(); reintroduce;
    destructor Destroy(); override;
    
    procedure AddField(const AName: string; const AType: TCPType);
    function GetField(const AName: string): TCPRecordField;
    function HasField(const AName: string): Boolean;
    function GetFieldOffset(const AName: string): Integer;
    
    function IsCompatible(const AOther: TCPType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property Fields: TArray<TCPRecordField> read FFields;
  end;

  { TCPFunctionType }
  TCPFunctionType = class(TCPType)
  private
    FParameterTypes: TArray<TCPType>;
    FReturnType: TCPType; // nil for procedures
    FIsVariadic: Boolean;
    
  public
    constructor Create(const AParameterTypes: TArray<TCPType>; const AReturnType: TCPType = nil; const AIsVariadic: Boolean = False); reintroduce;
    destructor Destroy(); override;
    
    function IsCompatible(const AOther: TCPType): Boolean; override;
    function GetTypeName(): string; override;
    function GetSize(): Integer; override;
    
    property ParameterTypes: TArray<TCPType> read FParameterTypes;
    property ReturnType: TCPType read FReturnType;
    property IsVariadic: Boolean read FIsVariadic;
  end;

  { TCPTypeManager }
  TCPTypeManager = class
  private
    FTypes: TObjectDictionary<string, TCPType>;
    FBasicTypes: TDictionary<TCPBasicType, TCPBasicTypeInfo>;
    
    procedure InitializeBasicTypes();
    
  public
    constructor Create();
    destructor Destroy(); override;
    
    function GetBasicType(const ABasicType: TCPBasicType): TCPBasicTypeInfo;
    function GetTypeByName(const ATypeName: string): TCPType;
    function CreatePointerType(const ATargetType: TCPType): TCPPointerType;
    function CreateArrayType(const AElementType: TCPType; const AElementCount: Integer = -1): TCPArrayType;
    function CreateRecordType(const AName: string): TCPRecordType;
    function CreateFunctionType(const AParameterTypes: TArray<TCPType>; const AReturnType: TCPType = nil; const AIsVariadic: Boolean = False): TCPFunctionType;
    
    procedure RegisterType(const AName: string; const AType: TCPType);
    function ResolveType(const ATypeNode: TCPASTNode): TCPType;
    
    function AreTypesCompatible(const AType1, AType2: TCPType): Boolean;
    function GetCommonType(const AType1, AType2: TCPType): TCPType;
  end;

implementation

{ TCPType }
constructor TCPType.Create(const AKind: TCPTypeKind; const AName: string);
begin
  inherited Create();
  FKind := AKind;
  FName := AName;
  FSize := 0;
end;

function TCPType.IsCompatible(const AOther: TCPType): Boolean;
begin
  Result := (Self = AOther) or (Self.ClassName = AOther.ClassName);
end;

function TCPType.GetTypeName(): string;
begin
  Result := FName;
end;

function TCPType.GetSize(): Integer;
begin
  Result := FSize;
end;

{ TCPBasicTypeInfo }
constructor TCPBasicTypeInfo.Create(const ABasicType: TCPBasicType);
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

function TCPBasicTypeInfo.IsCompatible(const AOther: TCPType): Boolean;
begin
  if AOther is TCPBasicTypeInfo then
    Result := FBasicType = TCPBasicTypeInfo(AOther).FBasicType
  else
    Result := False;
end;

function TCPBasicTypeInfo.GetTypeName(): string;
begin
  Result := FName;
end;

function TCPBasicTypeInfo.GetSize(): Integer;
begin
  Result := FSize;
end;

{ TCPPointerType }
constructor TCPPointerType.Create(const ATargetType: TCPType);
begin
  inherited Create(tkPointer, '^' + ATargetType.GetTypeName());
  FTargetType := ATargetType;
  FSize := 8; // 64-bit pointer
end;

destructor TCPPointerType.Destroy();
begin
  // Note: We don't free FTargetType as it's managed by TypeManager
  inherited;
end;

function TCPPointerType.IsCompatible(const AOther: TCPType): Boolean;
begin
  if AOther is TCPPointerType then
    Result := FTargetType.IsCompatible(TCPPointerType(AOther).FTargetType)
  else
    Result := False;
end;

function TCPPointerType.GetTypeName(): string;
begin
  Result := '^' + FTargetType.GetTypeName();
end;

function TCPPointerType.GetSize(): Integer;
begin
  Result := 8; // 64-bit pointer
end;

{ TCPArrayType }
constructor TCPArrayType.Create(const AElementType: TCPType; const AElementCount: Integer);
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

destructor TCPArrayType.Destroy();
begin
  // Note: We don't free FElementType as it's managed by TypeManager
  inherited;
end;

function TCPArrayType.IsCompatible(const AOther: TCPType): Boolean;
begin
  if AOther is TCPArrayType then
  begin
    Result := FElementType.IsCompatible(TCPArrayType(AOther).FElementType) and
              (FElementCount = TCPArrayType(AOther).FElementCount);
  end
  else
    Result := False;
end;

function TCPArrayType.GetTypeName(): string;
begin
  if FElementCount >= 0 then
    Result := Format('array[%d] of %s', [FElementCount, FElementType.GetTypeName()])
  else
    Result := Format('array[] of %s', [FElementType.GetTypeName()]);
end;

function TCPArrayType.GetSize(): Integer;
begin
  Result := FSize;
end;

{ TCPRecordType }
constructor TCPRecordType.Create();
begin
  inherited Create(tkRecord, 'record');
  SetLength(FFields, 0);
  FFieldMap := TDictionary<string, Integer>.Create();
  FSize := 0;
end;

destructor TCPRecordType.Destroy();
begin
  FFieldMap.Free();
  inherited;
end;

procedure TCPRecordType.AddField(const AName: string; const AType: TCPType);
var
  LFieldIndex: Integer;
  LField: TCPRecordField;
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

function TCPRecordType.GetField(const AName: string): TCPRecordField;
var
  LIndex: Integer;
begin
  if FFieldMap.TryGetValue(AName, LIndex) then
    Result := FFields[LIndex]
  else
    raise ECPException.Create('Field "%s" not found in record', [AName]);
end;

function TCPRecordType.HasField(const AName: string): Boolean;
begin
  Result := FFieldMap.ContainsKey(AName);
end;

function TCPRecordType.GetFieldOffset(const AName: string): Integer;
var
  LField: TCPRecordField;
begin
  LField := GetField(AName);
  Result := LField.Offset;
end;

function TCPRecordType.IsCompatible(const AOther: TCPType): Boolean;
begin
  // Record types are compatible only if they're the same instance
  Result := Self = AOther;
end;

function TCPRecordType.GetTypeName(): string;
begin
  Result := 'record';
end;

function TCPRecordType.GetSize(): Integer;
begin
  Result := FSize;
end;

{ TCPFunctionType }
constructor TCPFunctionType.Create(const AParameterTypes: TArray<TCPType>; const AReturnType: TCPType; const AIsVariadic: Boolean);
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

destructor TCPFunctionType.Destroy();
begin
  // Note: We don't free parameter/return types as they're managed by TypeManager
  inherited;
end;

function TCPFunctionType.IsCompatible(const AOther: TCPType): Boolean;
var
  LIndex: Integer;
  LOtherFunc: TCPFunctionType;
begin
  if not (AOther is TCPFunctionType) then
    Exit(False);
    
  LOtherFunc := TCPFunctionType(AOther);
  
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

function TCPFunctionType.GetTypeName(): string;
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

function TCPFunctionType.GetSize(): Integer;
begin
  Result := 8; // Function pointer size
end;

{ TCPTypeManager }
constructor TCPTypeManager.Create();
begin
  inherited;
  FTypes := TObjectDictionary<string, TCPType>.Create([doOwnsValues]);
  FBasicTypes := TDictionary<TCPBasicType, TCPBasicTypeInfo>.Create();
  InitializeBasicTypes();
end;

destructor TCPTypeManager.Destroy();
begin
  FBasicTypes.Free();
  FTypes.Free();
  inherited;
end;

procedure TCPTypeManager.InitializeBasicTypes();
var
  LBasicType: TCPBasicType;
  LTypeInfo: TCPBasicTypeInfo;
begin
  for LBasicType := Low(TCPBasicType) to High(TCPBasicType) do
  begin
    LTypeInfo := TCPBasicTypeInfo.Create(LBasicType);
    FBasicTypes.Add(LBasicType, LTypeInfo);
    FTypes.AddOrSetValue(LTypeInfo.GetTypeName(), LTypeInfo);
  end;
end;

function TCPTypeManager.GetBasicType(const ABasicType: TCPBasicType): TCPBasicTypeInfo;
begin
  Result := FBasicTypes[ABasicType];
end;

function TCPTypeManager.GetTypeByName(const ATypeName: string): TCPType;
begin
  if not FTypes.TryGetValue(ATypeName, Result) then
    Result := nil;
end;

function TCPTypeManager.CreatePointerType(const ATargetType: TCPType): TCPPointerType;
begin
  Result := TCPPointerType.Create(ATargetType);
  // Note: Pointer types are typically not registered globally
end;

function TCPTypeManager.CreateArrayType(const AElementType: TCPType; const AElementCount: Integer): TCPArrayType;
begin
  Result := TCPArrayType.Create(AElementType, AElementCount);
  // Note: Array types are typically not registered globally
end;

function TCPTypeManager.CreateRecordType(const AName: string): TCPRecordType;
begin
  Result := TCPRecordType.Create();
  if AName <> '' then
    RegisterType(AName, Result);
end;

function TCPTypeManager.CreateFunctionType(const AParameterTypes: TArray<TCPType>; const AReturnType: TCPType; const AIsVariadic: Boolean): TCPFunctionType;
begin
  Result := TCPFunctionType.Create(AParameterTypes, AReturnType, AIsVariadic);
  // Note: Function types are typically not registered globally
end;

procedure TCPTypeManager.RegisterType(const AName: string; const AType: TCPType);
begin
  FTypes.AddOrSetValue(AName, AType);
end;

function TCPTypeManager.ResolveType(const ATypeNode: TCPASTNode): TCPType;
var
  LTypeName: string;
  LTargetType: TCPType;
  LElementType: TCPType;
  LElementCount: Integer;
  LRecordType: TCPRecordType;
  LFieldNode: TCPASTNode;
  LFieldName: string;
  LFieldType: TCPType;
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

function TCPTypeManager.AreTypesCompatible(const AType1, AType2: TCPType): Boolean;
begin
  if not Assigned(AType1) or not Assigned(AType2) then
    Result := False
  else
    Result := AType1.IsCompatible(AType2);
end;

function TCPTypeManager.GetCommonType(const AType1, AType2: TCPType): TCPType;
begin
  if AreTypesCompatible(AType1, AType2) then
    Result := AType1
  else
    Result := nil; // No common type
end;

end.
