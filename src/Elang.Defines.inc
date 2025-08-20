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

// E-Lang compiler defines and conditional compilation directives

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

// Delphi version compatibility
{$IF CompilerVersion >= 35.0}  // Delphi 11 Alexandria and newer
  {$DEFINE DELPHI11_UP}
{$ENDIF}

{$IF CompilerVersion >= 34.0}  // Delphi 10.4 Sydney and newer
  {$DEFINE DELPHI104_UP}
{$ENDIF}

{$IF CompilerVersion >= 33.0}  // Delphi 10.3 Rio and newer
  {$DEFINE DELPHI103_UP}
{$ENDIF}

// Common settings
{$ALIGN ON}
{$MINENUMSIZE 1}
{$WRITEABLECONST OFF}
{$TYPEDADDRESS ON}

// Debug settings
{$IFDEF DEBUG}
  {$ASSERTIONS ON}
  {$DEBUGINFO ON}
  {$LOCALSYMBOLS ON}
  {$OPTIMIZATION OFF}
  {$OVERFLOWCHECKS ON}
  {$RANGECHECKS ON}
  {$STACKFRAMES ON}
{$ELSE}
  {$ASSERTIONS OFF}
  {$DEBUGINFO OFF}
  {$LOCALSYMBOLS OFF}
  {$OPTIMIZATION ON}
  {$OVERFLOWCHECKS OFF}
  {$RANGECHECKS OFF}
  {$STACKFRAMES OFF}
{$ENDIF}

// Platform specific
{$IFDEF MSWINDOWS}
  {$DEFINE WINDOWS}
{$ENDIF}

{$IFDEF LINUX}
  {$DEFINE POSIX}
{$ENDIF}

{$IFDEF MACOS}
  {$DEFINE POSIX}
{$ENDIF}

// E-Lang specific defines
{$DEFINE ELANG_VERSION_MAJOR=1}
{$DEFINE ELANG_VERSION_MINOR=0}
{$DEFINE ELANG_VERSION_BUILD=0}
