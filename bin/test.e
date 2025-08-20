// Main program

function printf(const AFormat: ^char, ...): int32 external "msvcrt.dll";

function main(): int32
begin
  printf("Hello, %s\n", "World!");
  return 0;
end
