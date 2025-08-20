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

unit ELang.Symbols;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ELang.Common,
  ELang.Parser,
  ELang.Types,
  ELang.Errors;

type
  { TELSymbolKind }
  TELSymbolKind = (
    skVariable,
    skFunction,
    skType,
    skParameter,
    skConstant
  );

  { TELSymbol }
  TELSymbol = class
  private
    FName: string;
    FKind: TELSymbolKind;
    FSymbolType: TELType;
    FDeclarationNode: TELASTNode;
    FDeclaredLine: Integer;
    FDeclaredColumn: Integer;
    FFileName: string;
    FIsUsed: Boolean;
    FIsInitialized: Boolean;
    
  public
    constructor Create(const AName: string; const AKind: TELSymbolKind; 
      const ASymbolType: TELType; const ADeclarationNode: TELASTNode);
    destructor Destroy(); override;
    
    function GetLocationString(): string;
    function GetKindString(): string;
    
    property SymbolName: string read FName;
    property Kind: TELSymbolKind read FKind;
    property SymbolType: TELType read FSymbolType write FSymbolType;
    property DeclarationNode: TELASTNode read FDeclarationNode;
    property DeclaredLine: Integer read FDeclaredLine;
    property DeclaredColumn: Integer read FDeclaredColumn;
    property FileName: string read FFileName;
    property IsUsed: Boolean read FIsUsed write FIsUsed;
    property IsInitialized: Boolean read FIsInitialized write FIsInitialized;
  end;

  { TELScope }
  TELScope = class
  private
    FParent: TELScope;
    FSymbols: TObjectDictionary<string, TELSymbol>;
    FScopeType: string;
    FStartLine: Integer;
    FEndLine: Integer;
    
  public
    constructor Create(const AParent: TELScope; const AScopeType: string);
    destructor Destroy(); override;
    
    function FindSymbol(const AName: string; const ASearchParent: Boolean = True): TELSymbol;
    function FindLocalSymbol(const AName: string): TELSymbol;
    procedure AddSymbol(const ASymbol: TELSymbol);
    function HasSymbol(const AName: string): Boolean;
    function GetSymbolCount(): Integer;
    function GetSymbols(): TArray<TELSymbol>;
    
    property Parent: TELScope read FParent;
    property ScopeType: string read FScopeType;
    property StartLine: Integer read FStartLine write FStartLine;
    property EndLine: Integer read FEndLine write FEndLine;
  end;

  { TELSymbolTable }
  TELSymbolTable = class(TELObject)
  private
    FCurrentScope: TELScope;
    FGlobalScope: TELScope;
    FScopeStack: TStack<TELScope>;
    
  public
    constructor Create(); override;
    destructor Destroy(); override;
    
    procedure EnterScope(const AScopeType: string);
    procedure ExitScope();
    function GetCurrentScopeDepth(): Integer;
    function IsInGlobalScope(): Boolean;
    
    function DeclareSymbol(const AName: string; const AKind: TELSymbolKind; 
      const ASymbolType: TELType; const ADeclarationNode: TELASTNode): TELSymbol;
    function LookupSymbol(const AName: string): TELSymbol;
    function LookupLocalSymbol(const AName: string): TELSymbol;
    
    function CheckForRedeclaration(const AName: string; const ANode: TELASTNode): Boolean;
    function GetAllSymbols(): TArray<TELSymbol>;
    function GetUnusedSymbols(): TArray<TELSymbol>;
    
    procedure Clear();
    
    property CurrentScope: TELScope read FCurrentScope;
    property GlobalScope: TELScope read FGlobalScope;
  end;

implementation

{ TELSymbol }

constructor TELSymbol.Create(const AName: string; const AKind: TELSymbolKind; 
  const ASymbolType: TELType; const ADeclarationNode: TELASTNode);
begin
  inherited Create();
  FName := AName;
  FKind := AKind;
  FSymbolType := ASymbolType;
  FDeclarationNode := ADeclarationNode;
  FIsUsed := False;
  FIsInitialized := False;
  
  if Assigned(ADeclarationNode) then
  begin
    FDeclaredLine := ADeclarationNode.Position;
    FDeclaredColumn := 1; // Simplified - could extract from token
    FFileName := '<unknown>'; // Could be enhanced with actual filename
  end
  else
  begin
    FDeclaredLine := 0;
    FDeclaredColumn := 0;
    FFileName := '<built-in>';
  end;
end;

destructor TELSymbol.Destroy();
begin
  // Note: We don't free FSymbolType as it's managed by TypeManager
  // Note: We don't free FDeclarationNode as it's managed by Parser
  inherited;
end;

function TELSymbol.GetLocationString(): string;
begin
  if FFileName <> '' then
    Result := Format('%s(%d,%d)', [FFileName, FDeclaredLine, FDeclaredColumn])
  else
    Result := Format('Line %d, Column %d', [FDeclaredLine, FDeclaredColumn]);
end;

function TELSymbol.GetKindString(): string;
begin
  case FKind of
    skVariable: Result := 'variable';
    skFunction: Result := 'function';
    skType: Result := 'type';
    skParameter: Result := 'parameter';
    skConstant: Result := 'constant';
  else
    Result := 'unknown';
  end;
end;

{ TELScope }

constructor TELScope.Create(const AParent: TELScope; const AScopeType: string);
begin
  inherited Create();
  FParent := AParent;
  FSymbols := TObjectDictionary<string, TELSymbol>.Create([doOwnsValues]);
  FScopeType := AScopeType;
  FStartLine := 0;
  FEndLine := 0;
end;

destructor TELScope.Destroy();
begin
  FSymbols.Free();
  inherited;
end;

function TELScope.FindSymbol(const AName: string; const ASearchParent: Boolean): TELSymbol;
begin
  if FSymbols.TryGetValue(AName, Result) then
    Exit;
    
  if ASearchParent and Assigned(FParent) then
    Result := FParent.FindSymbol(AName, True)
  else
    Result := nil;
end;

function TELScope.FindLocalSymbol(const AName: string): TELSymbol;
begin
  if not FSymbols.TryGetValue(AName, Result) then
    Result := nil;
end;

procedure TELScope.AddSymbol(const ASymbol: TELSymbol);
begin
  if not Assigned(ASymbol) then
    raise EELException.Create('Cannot add nil symbol to scope');
    
  if FSymbols.ContainsKey(ASymbol.SymbolName) then
    raise EELException.Create('Symbol "%s" already exists in current scope', [ASymbol.SymbolName]);
    
  FSymbols.Add(ASymbol.SymbolName, ASymbol);
end;

function TELScope.HasSymbol(const AName: string): Boolean;
begin
  Result := FSymbols.ContainsKey(AName);
end;

function TELScope.GetSymbolCount(): Integer;
begin
  Result := FSymbols.Count;
end;

function TELScope.GetSymbols(): TArray<TELSymbol>;
var
  LList: TList<TELSymbol>;
  LPair: TPair<string, TELSymbol>;
begin
  LList := TList<TELSymbol>.Create();
  try
    for LPair in FSymbols do
      LList.Add(LPair.Value);
    Result := LList.ToArray();
  finally
    LList.Free();
  end;
end;

{ TELSymbolTable }

constructor TELSymbolTable.Create();
begin
  inherited;
  FScopeStack := TStack<TELScope>.Create();
  FGlobalScope := TELScope.Create(nil, 'global');
  FCurrentScope := FGlobalScope;
end;

destructor TELSymbolTable.Destroy();
begin
  Clear();
  FGlobalScope.Free();
  FScopeStack.Free();
  inherited;
end;

procedure TELSymbolTable.EnterScope(const AScopeType: string);
var
  LNewScope: TELScope;
begin
  FScopeStack.Push(FCurrentScope);
  LNewScope := TELScope.Create(FCurrentScope, AScopeType);
  FCurrentScope := LNewScope;
end;

procedure TELSymbolTable.ExitScope();
var
  LOldScope: TELScope;
begin
  if FScopeStack.Count = 0 then
    raise EELException.Create('Cannot exit scope: already at global scope');
    
  LOldScope := FCurrentScope;
  FCurrentScope := FScopeStack.Pop();
  
  // Free the old scope (this will free all its symbols)
  LOldScope.Free();
end;

function TELSymbolTable.GetCurrentScopeDepth(): Integer;
begin
  Result := FScopeStack.Count;
end;

function TELSymbolTable.IsInGlobalScope(): Boolean;
begin
  Result := FCurrentScope = FGlobalScope;
end;

function TELSymbolTable.DeclareSymbol(const AName: string; const AKind: TELSymbolKind; 
  const ASymbolType: TELType; const ADeclarationNode: TELASTNode): TELSymbol;
begin
  // Check for redeclaration in current scope only
  if FCurrentScope.HasSymbol(AName) then
  begin
    raise EELException.Create('Symbol "%s" is already declared in current scope', [AName], 
      AName, '<unknown>', 0, 0);
  end;
  
  Result := TELSymbol.Create(AName, AKind, ASymbolType, ADeclarationNode);
  FCurrentScope.AddSymbol(Result);
end;

function TELSymbolTable.LookupSymbol(const AName: string): TELSymbol;
begin
  Result := FCurrentScope.FindSymbol(AName, True);
end;

function TELSymbolTable.LookupLocalSymbol(const AName: string): TELSymbol;
begin
  Result := FCurrentScope.FindLocalSymbol(AName);
end;

function TELSymbolTable.CheckForRedeclaration(const AName: string; const ANode: TELASTNode): Boolean;
var
  LExistingSymbol: TELSymbol;
begin
  LExistingSymbol := FCurrentScope.FindLocalSymbol(AName);
  Result := Assigned(LExistingSymbol);
end;

function TELSymbolTable.GetAllSymbols(): TArray<TELSymbol>;
var
  LAllSymbols: TList<TELSymbol>;
  LCurrentScope: TELScope;
  LSymbols: TArray<TELSymbol>;
  LSymbol: TELSymbol;
begin
  LAllSymbols := TList<TELSymbol>.Create();
  try
    LCurrentScope := FCurrentScope;
    
    // Walk up the scope chain
    while Assigned(LCurrentScope) do
    begin
      LSymbols := LCurrentScope.GetSymbols();
      for LSymbol in LSymbols do
        LAllSymbols.Add(LSymbol);
      LCurrentScope := LCurrentScope.Parent;
    end;
    
    Result := LAllSymbols.ToArray();
  finally
    LAllSymbols.Free();
  end;
end;

function TELSymbolTable.GetUnusedSymbols(): TArray<TELSymbol>;
var
  LUnusedSymbols: TList<TELSymbol>;
  LAllSymbols: TArray<TELSymbol>;
  LSymbol: TELSymbol;
begin
  LUnusedSymbols := TList<TELSymbol>.Create();
  try
    LAllSymbols := GetAllSymbols();
    for LSymbol in LAllSymbols do
    begin
      if not LSymbol.IsUsed and (LSymbol.Kind = skVariable) then
        LUnusedSymbols.Add(LSymbol);
    end;
    
    Result := LUnusedSymbols.ToArray();
  finally
    LUnusedSymbols.Free();
  end;
end;

procedure TELSymbolTable.Clear();
begin
  // Exit all scopes except global
  while FScopeStack.Count > 0 do
    ExitScope();
    
  // Clear global scope
  FGlobalScope.Free();
  FGlobalScope := TELScope.Create(nil, 'global');
  FCurrentScope := FGlobalScope;
end;

end.
