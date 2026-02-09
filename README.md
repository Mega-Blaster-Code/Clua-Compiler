# Clua Compiler
## *C like language that compiles to C*

Compiles a custom language named **Clua** to C11

## Clua code
``` lua
int x = 10;
int long long const number = 200;

float foo = 5.2;

float const bar = 0.0;

-- this is a comment

----*
mult-line comment!!!!
*----

void function add(int val1, int val2)
  return val1 + val2;
end

int function main()
  return add(x, 23);
end

int best = 0;

for (int i = 0; i < 100; i = i + 1) do
  best = best + 1;
end

while (best < 500) do
  best = best * 2
end

if (best < 0) then
  -- do something 1
elseif (best > 500) then
  -- do something 2
else
  -- do something 3
end
```


## Variable declaration

- **`<type> [qualifier] [modifier] ... <name> <;>`**
- **`<type> [qualifier] [modifier] ... <name> <=> <expression> <;>`**

a declaração de variaveis usa um sistema de static types

``` lua
int foo = 10;
```
existem 4 tipos de variaveis

- char   (8 bits)
- int    (32 bits)
- float  (32 bits)
- double (64 bits)

alem dos tipos padrões, exitem 4 qualificadores

- long
- short
- unsigned
- signed

contendo todas as possibilidades com o sintax correto

``` lua
char
int
int short
int long
int long long
float
double
double long
```

apos os qualificadores existem os modificadores que não tem limite de uso
os modificadores semprem aplicam seus atributos ao item a esquerda e podem ser colocados em qualquer lugar apos os qualificadores e antes do nome

existem 4 modificadores

- const
- volitale
- *
- []

``` lua
int * x; -- pointer to int
int const * x; -- pointer to a const int
int * const x; -- const pointer to a int

int [] list = [1, 2, 3, 4, 5]; -- fixed length array of 6 elements
int * [4] list; -- fixed length array of 4 pointer to int
int [4] * list; -- pointer to a fixed length array of 4 int
```