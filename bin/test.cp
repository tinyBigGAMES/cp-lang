// Main program

#include "math.e"
#include "math.e"

function printf(const AFormat: ^char, ...): int32 external "msvcrt.dll";

function main(): int32
begin
  printf("Hello, %s\n", "World!");
  printf("add(7, 3): %d\n", add(7, 3));
  
  var i: int32;
  
  printf("for-loop-to:\n");
  for i := 1 to 10 do 
  begin
    printf("%d\n", i);
  end   
  
  printf("\nfor-loop-downto:\n");
  for i := 10 downto 1 do
  begin
    printf("%d\n", i);
  end
  
  return 0;
end
