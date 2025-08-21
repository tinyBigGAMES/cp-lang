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

unit CPLang.Symbols;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Common,
  CPLang.Parser,
  CPLang.Types,
  CPLang.Errors;

type
  { TCPSymbolKind }
  TCPSymbolKind = (
    skVariable,
    skFunction,
    skType,
    skParameter,
    skConstant
  );

  { TCPSymbol }
  TCPSymbol = class
  private
    FName: string;
    FKind: TCPSymbolKind;
    FSymbolType: TCPType;
    FDeclarationNode: TCPASTNode;
    FDeclaredLine: Integer;
    FDeclaredColumn: Integer;
    FFileName: string;
    FIsUsed: Boolean;
    FIsInitialized: Boolean;
    
  public
    constructor Create(const AName: string; const AKind: TCPSymbolKind;
      const ASymbolType: TCPType; const ADeclarationNode: TCPASTNode);
    destructor Destroy(); override;
    
    function GetLocationString(): string;
    function GetKindString(): string;
    
    property SymbolName: string read FName;
    property Kind: TCPSymbolKind read FKind;
    property SymbolType: TCPType read FSymbolType write FSymbolType;
    property DeclarationNode: TCPASTNode read FDeclarationNode;
    property DeclaredLine: Integer read FDeclaredLine;
    property DeclaredColumn: Integer read FDeclaredColumn;
    property FileName: string read FFileName;
    property IsUsed: Boolean read FIsUsed write FIsUsed;
    property IsInitialized: Boolean read FIsInitialized write FIsInitialized;
  end;

  { TCPScope }
  TCPScope = class
  private
    FParent: TCPScope;
    FSymbols: TObjectDictionary<string, TCPSymbol>;
    FScopeType: string;
    FStartLine: Integer;
    FEndLine: Integer;
    
  public
    constructor Create(const AParent: TCPScope; const AScopeType: string);
    destructor Destroy(); override;
    
    function FindSymbol(const AName: string; const ASearchParent: Boolean = True): TCPSymbol;
    function FindLocalSymbol(const AName: string): TCPSymbol;
    procedure AddSymbol(const ASymbol: TCPSymbol);
    function HasSymbol(const AName: string): Boolean;
    function GetSymbolCount(): Integer;
    function GetSymbols(): TArray<TCPSymbol>;
    
    property Parent: TCPScope read FParent;
    property ScopeType: string read FScopeType;
    property StartLine: Integer read FStartLine write FStartLine;
    property EndLine: Integer read FEndLine write FEndLine;
  end;

  { TCPSymbolTable }
  TCPSymbolTable = class
  private
    FCurrentScope: TCPScope;
    FGlobalScope: TCPScope;
    FScopeStack: TStack<TCPScope>;
    
  public
    constructor Create();
    destructor Destroy(); override;
    
    procedure EnterScope(const AScopeType: string);
    procedure ExitScope();
    function GetCurrentScopeDepth(): Integer;
    function IsInGlobalScope(): Boolean;
    
    function DeclareSymbol(const AName: string; const AKind: TCPSymbolKind;
      const ASymbolType: TCPType; const ADeclarationNode: TCPASTNode): TCPSymbol;
    function LookupSymbol(const AName: string): TCPSymbol;
    function LookupLocalSymbol(const AName: string): TCPSymbol;
    
    function CheckForRedeclaration(const AName: string; const ANode: TCPASTNode): Boolean;
    function GetAllSymbols(): TArray<TCPSymbol>;
    function GetUnusedSymbols(): TArray<TCPSymbol>;
    
    procedure Clear();
    
    property CurrentScope: TCPScope read FCurrentScope;
    property GlobalScope: TCPScope read FGlobalScope;
  end;

implementation

{ TCPSymbol }
constructor TCPSymbol.Create(const AName: string; const AKind: TCPSymbolKind;
  const ASymbolType: TCPType; const ADeclarationNode: TCPASTNode);
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

destructor TCPSymbol.Destroy();
begin
  // Note: We don't free FSymbolType as it's managed by TypeManager
  // Note: We don't free FDeclarationNode as it's managed by Parser
  inherited;
end;

function TCPSymbol.GetLocationString(): string;
begin
  if FFileName <> '' then
    Result := Format('%s(%d,%d)', [FFileName, FDeclaredLine, FDeclaredColumn])
  else
    Result := Format('Line %d, Column %d', [FDeclaredLine, FDeclaredColumn]);
end;

function TCPSymbol.GetKindString(): string;
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

{ TCPScope }
constructor TCPScope.Create(const AParent: TCPScope; const AScopeType: string);
begin
  inherited Create();
  FParent := AParent;
  FSymbols := TObjectDictionary<string, TCPSymbol>.Create([doOwnsValues]);
  FScopeType := AScopeType;
  FStartLine := 0;
  FEndLine := 0;
end;

destructor TCPScope.Destroy();
begin
  FSymbols.Free();
  inherited;
end;

function TCPScope.FindSymbol(const AName: string; const ASearchParent: Boolean): TCPSymbol;
begin
  if FSymbols.TryGetValue(AName, Result) then
    Exit;
    
  if ASearchParent and Assigned(FParent) then
    Result := FParent.FindSymbol(AName, True)
  else
    Result := nil;
end;

function TCPScope.FindLocalSymbol(const AName: string): TCPSymbol;
begin
  if not FSymbols.TryGetValue(AName, Result) then
    Result := nil;
end;

procedure TCPScope.AddSymbol(const ASymbol: TCPSymbol);
begin
  if not Assigned(ASymbol) then
    raise ECPException.Create('Cannot add nil symbol to scope');
    
  if FSymbols.ContainsKey(ASymbol.SymbolName) then
    raise ECPException.Create('Symbol "%s" already exists in current scope', [ASymbol.SymbolName]);
    
  FSymbols.Add(ASymbol.SymbolName, ASymbol);
end;

function TCPScope.HasSymbol(const AName: string): Boolean;
begin
  Result := FSymbols.ContainsKey(AName);
end;

function TCPScope.GetSymbolCount(): Integer;
begin
  Result := FSymbols.Count;
end;

function TCPScope.GetSymbols(): TArray<TCPSymbol>;
var
  LList: TList<TCPSymbol>;
  LPair: TPair<string, TCPSymbol>;
begin
  LList := TList<TCPSymbol>.Create();
  try
    for LPair in FSymbols do
      LList.Add(LPair.Value);
    Result := LList.ToArray();
  finally
    LList.Free();
  end;
end;

{ TCPSymbolTable }
constructor TCPSymbolTable.Create();
begin
  inherited;
  FScopeStack := TStack<TCPScope>.Create();
  FGlobalScope := TCPScope.Create(nil, 'global');
  FCurrentScope := FGlobalScope;
end;

destructor TCPSymbolTable.Destroy();
begin
  Clear();
  FGlobalScope.Free();
  FScopeStack.Free();
  inherited;
end;

procedure TCPSymbolTable.EnterScope(const AScopeType: string);
var
  LNewScope: TCPScope;
begin
  FScopeStack.Push(FCurrentScope);
  LNewScope := TCPScope.Create(FCurrentScope, AScopeType);
  FCurrentScope := LNewScope;
end;

procedure TCPSymbolTable.ExitScope();
var
  LOldScope: TCPScope;
begin
  if FScopeStack.Count = 0 then
    raise ECPException.Create('Cannot exit scope: already at global scope');
    
  LOldScope := FCurrentScope;
  FCurrentScope := FScopeStack.Pop();
  
  // Free the old scope (this will free all its symbols)
  LOldScope.Free();
end;

function TCPSymbolTable.GetCurrentScopeDepth(): Integer;
begin
  Result := FScopeStack.Count;
end;

function TCPSymbolTable.IsInGlobalScope(): Boolean;
begin
  Result := FCurrentScope = FGlobalScope;
end;

function TCPSymbolTable.DeclareSymbol(const AName: string; const AKind: TCPSymbolKind;
  const ASymbolType: TCPType; const ADeclarationNode: TCPASTNode): TCPSymbol;
begin
  // Check for redeclaration in current scope only
  if FCurrentScope.HasSymbol(AName) then
  begin
    raise ECPException.Create('Symbol "%s" is already declared in current scope', [AName],
      AName, '<unknown>', 0, 0);
  end;
  
  Result := TCPSymbol.Create(AName, AKind, ASymbolType, ADeclarationNode);
  FCurrentScope.AddSymbol(Result);
end;

function TCPSymbolTable.LookupSymbol(const AName: string): TCPSymbol;
begin
  Result := FCurrentScope.FindSymbol(AName, True);
end;

function TCPSymbolTable.LookupLocalSymbol(const AName: string): TCPSymbol;
begin
  Result := FCurrentScope.FindLocalSymbol(AName);
end;

function TCPSymbolTable.CheckForRedeclaration(const AName: string; const ANode: TCPASTNode): Boolean;
var
  LExistingSymbol: TCPSymbol;
begin
  LExistingSymbol := FCurrentScope.FindLocalSymbol(AName);
  Result := Assigned(LExistingSymbol);
end;

function TCPSymbolTable.GetAllSymbols(): TArray<TCPSymbol>;
var
  LAllSymbols: TList<TCPSymbol>;
  LCurrentScope: TCPScope;
  LSymbols: TArray<TCPSymbol>;
  LSymbol: TCPSymbol;
begin
  LAllSymbols := TList<TCPSymbol>.Create();
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

function TCPSymbolTable.GetUnusedSymbols(): TArray<TCPSymbol>;
var
  LUnusedSymbols: TList<TCPSymbol>;
  LAllSymbols: TArray<TCPSymbol>;
  LSymbol: TCPSymbol;
begin
  LUnusedSymbols := TList<TCPSymbol>.Create();
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

procedure TCPSymbolTable.Clear();
begin
  // Exit all scopes except global
  while FScopeStack.Count > 0 do
    ExitScope();
    
  // Clear global scope
  FGlobalScope.Free();
  FGlobalScope := TCPScope.Create(nil, 'global');
  FCurrentScope := FGlobalScope;
end;

end.
