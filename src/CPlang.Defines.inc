{===============================================================================
              _
  __ _ __ ___| |__ _ _ _  __ _ ™
 / _| '_ \___| / _` | ' \/ _` |
 \__| .__/   |_\__,_|_||_\__, |
    |_|                  |___/
    C Power | Pascal Clarity

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.
===============================================================================}

{$Z4}
{$A8}

{$INLINE AUTO}

{$IF not (defined(WIN64) or defined(LINUX64) or defined(MACOS64))}
  {$MESSAGE Error 'Unsupported platform'}
{$ENDIF}

{$IF (CompilerVersion < 36.0)}
  {$IFNDEF WIN64}
    {$MESSAGE Error 'Must use Delphi 12 or higher'}
  {$ENDIF}
{$IFEND}
