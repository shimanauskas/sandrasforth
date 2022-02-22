// rax - top-of-stack, syscall number.
// rbx - threaded code pointer.
// rcx - temporary, syscall scratch.
// rdx - temporary, syscall argument.

// rsi - syscall argument.
// rdi - syscall argument.
// rbp - data stack pointer.
// rsp - code stack pointer.

// r8  - unused, syscall argument.
// r9  - unused, syscall argument.
// r10 - unused, syscall argument.
// r11 - unused, syscall scratch.

// r12 - unused.
// r13 - unused.
// r14 - unused.
// r15 - unused.

#ifdef __linux__
	#define sysread  0
	#define syswrite 1
	#define sysexit  60
#elif __APPLE__
	#include "TargetConditionals.h"
	#ifdef TARGET_OS_MAC
		#define sysread  0x2000003
		#define syswrite 0x2000004
		#define sysexit  0x2000001
	#endif
#elif
	#error "Unsupported platform."
#endif

#define stdin  0
#define stdout 1

#define cell 8
#define page 0x1000
#define flag (1<<((cell*8)-1))

.macro string name, string
\name:
	.quad 1f-0f

0:
	.ascii "\string"

1:
.balign cell
.endm

.macro define link, name, string, imm=0
head\name:
	.quad \link
	.quad \name+\imm
	string string\name, "\string"
.endm

// A - A A

.macro dup
	subq $(cell), %rbp
	movq %rax, (%rbp)
.endm

// A B - B

.macro nip
	leaq cell(%rbp), %rbp
.endm

// A -

.macro drop
	movq (%rbp), %rax
	nip
.endm

// A B -

.macro twodrop
	movq cell(%rbp), %rax
	addq $(cell*2), %rbp
.endm

.macro next
	addq $(cell), %rbx
	jmp *(%rbx)
.endm

.text

.global main

main:
	leaq stack+page(%rip), %rbp     // Our stacks grow downward.
	movq $-1, %rax                  // Top-of-stack magic value, aids in testing.

	leaq start(%rip), %rbx
	jmpq *(%rbx)

enter:
	addq $(cell), %rbx
	pushq %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

// A -

execute:
	pushq %rbx
	movq %rax, %rbx
	drop
	jmpq *(%rbx)

exit:
	popq %rbx
	next

jump:
	addq $(cell), %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

// A -

zjump:
	testq %rax, %rax
	drop
	leaq cell*2(%rbx), %rbx
	cmovzq -cell(%rbx), %rbx
	jmpq *(%rbx)

// - A

lit:
	dup
	addq $(cell), %rbx
	mov (%rbx), %rax
	next

// A - A A

dup:
	dup
	next

// A -

drop:
	drop
	next

// A B - B

nip:
	nip
	next

// A B - A B A

over:
	dup
	movq cell(%rbp), %rax
	next

// A -

push:
	pushq %rax
	drop
	next

// - A

pull:
	dup
	popq %rax
	next

// A - B

not:
	notq %rax
	next

// A B - C

and:
	andq (%rbp), %rax
	nip
	next

// A B - C

or:
	orq (%rbp), %rax
	nip
	next

// A B - C

xor:
	xorq (%rbp), %rax
	nip
	next

// A - B

negate:
	negq %rax
	next

// A B - C

sub:
	negq %rax

// A B - C

add:
	addq (%rbp), %rax
	nip
	next

mul:
	movq %rax, %rcx
	drop
	mulq %rcx
	dup
	movq %rdx, %rax
	next

div:
	movq %rax, %rcx
	movq (%rbp), %rdx
	nip
	movq (%rbp), %rax
	divq %rcx
	movq %rdx, (%rbp)
	next

fetch:
	movq (%rax), %rax
	next

store:
	movq (%rbp), %rcx
	movq %rcx, (%rax)
	twodrop
	next

bfetch:
	movzbq (%rax), %rax
	next

bstore:
	movb (%rbp), %cl
	movb %cl, (%rax)
	twodrop
	next

read:
	movq %rax, %rdx                 // Size.
	movq (%rbp), %rsi               // Address.
	movq $stdin, %rdi
	movq $sysread, %rax
	syscall
	next

write:
	movq %rax, %rdx                 // Size.
	movq (%rbp), %rsi               // Address.
	movq $stdout, %rdi
	movq $syswrite, %rax
	syscall
	twodrop
	next

bye:
	xorq %rdi, %rdi
	movq $sysexit, %rax
	syscall

codeend:

.data

// If top-of-stack not zero, duplicate it.

qdup:
	.quad dup

	.quad zjump, 0f

	.quad dup

0:
	.quad exit

less:
	.quad over, over
	.quad xor
	.quad enter, negative

	.quad zjump, 0f

	.quad drop
	.quad jump, negative

0:
	.quad sub

negative:
	.quad lit, flag
	.quad and

bool:
	.quad dup

	.quad zjump, 0f

	.quad dup
	.quad xor
	.quad not

0:
	.quad exit

equals:
	.quad xor

zequals:
	.quad enter, bool
	.quad not
	.quad exit

within:
	.quad push
	.quad over
	.quad push
	.quad enter, less
	.quad not
	.quad pull, pull
	.quad enter, less
	.quad and
	.quad exit

accept:
	.quad lit, input
	.quad lit, page
	.quad read
	.quad dup
	.quad lit, 1
	.quad enter, less

	.quad zjump, 0f

	.quad bye

0:
	.quad over
	.quad add
	.quad lit, inputTop
	.quad store
	.quad lit, inputPtr
	.quad store
	.quad exit

// - char -1 | 0

bget:
	.quad lit, inputPtr
	.quad fetch
	.quad lit, inputTop
	.quad fetch
	.quad enter, less

	.quad zjump, 0f

	.quad lit, inputPtr
	.quad fetch
	.quad dup
	.quad lit, 1
	.quad add
	.quad lit, inputPtr
	.quad store
	.quad bfetch
	.quad lit, -1
	.quad exit

0:
	.quad lit, 0
	.quad exit

flush:
	.quad lit, output
	.quad lit, outputPtr
	.quad over, over
	.quad fetch
	.quad lit, output
	.quad sub
	.quad write
	.quad store
	.quad exit

line:
	.quad lit, '\n'

bput:
	.quad lit, outputPtr
	.quad fetch
	.quad dup
	.quad lit, 1
	.quad add
	.quad lit, outputPtr
	.quad store
	.quad bstore

	.quad lit, outputPtr
	.quad fetch
	.quad lit, output+page
	.quad xor

	.quad zjump, flush

	.quad exit

load:
	.quad dup
	.quad push
	.quad lit, cell
	.quad add
	.quad pull
	.quad fetch
	.quad exit

// stringA stringB - comparisonValue

compare:
	.quad dup
	.quad fetch
	.quad push

	// Compare string sizes.

	.quad over, fetch
	.quad over, fetch
	.quad enter, equals

	.quad zjump, 1f

	.quad lit, cell
	.quad add
	.quad push

	.quad lit, cell
	.quad add
	.quad pull

	.quad pull

0:
	.quad dup
	.quad push, push

	.quad over, bfetch
	.quad over, bfetch
	.quad enter, equals

	.quad pull
	.quad and

	.quad zjump, 0f

	.quad lit, 1
	.quad add
	.quad push

	.quad lit, 1
	.quad add
	.quad pull

	.quad pull
	.quad lit, 1
	.quad sub

	.quad jump, 0b
0:
1:
	.quad pull
	.quad nip, nip                  // Nip string pointers.
	.quad exit

emptytoken:
	.quad lit, 0
	.quad lit, token
	.quad store
	.quad exit

gettoken:

// The following loop reads input and discards spaces.
// It returns the first non-space character.

0:
	.quad enter, bget
	.quad zjump, emptytoken

	.quad dup
	.quad lit, '!'
	.quad enter, less

	.quad zjump, 0f

	.quad drop

	.quad jump, 0b
0:

	.quad lit, token+cell
	.quad push

1:
	.quad dup
	.quad lit, '!'
	.quad enter, less
	.quad not

	.quad zjump, 1f

	.quad pull
	.quad dup
	.quad lit, 1
	.quad add
	.quad push
	.quad bstore

	.quad enter, bget
	.quad drop

	.quad jump, 1b
1:

	.quad drop                      // Drop last bget's return value.

	.quad pull
	.quad lit, token+cell
	.quad sub
	.quad lit, token
	.quad store
	.quad exit

// - result unconvertedChars

literal:
	.quad lit, token
	.quad enter, load

	.quad over
	.quad bfetch
	.quad lit, '-'
	.quad enter, equals

	.quad zjump, natural

	.quad lit, 1
	.quad sub
	.quad push

	.quad lit, 1
	.quad add
	.quad pull

	.quad enter, natural
	.quad push
	.quad negate
	.quad pull
	.quad exit

// tokenAddr tokenLength - result unconvertedChars

natural:
	.quad push
	.quad lit, 0

0:
	.quad over
	.quad bfetch
	.quad lit, '0'
	.quad sub

	.quad lit, base
	.quad fetch
	.quad lit, 11
	.quad enter, less

	.quad zjump, 1f

	.quad lit, 0
	.quad lit, base
	.quad fetch
	.quad enter, within

	.quad jump, 2f
1:

	.quad dup
	.quad lit, 0
	.quad lit, 10
	.quad enter, within

	.quad over
	.quad lit, 'A'-'0'
	.quad sub
	.quad lit, 0
	.quad lit, base
	.quad fetch
	.quad lit, 10
	.quad sub
	.quad enter, within

	.quad or
	.quad nip

2:
	.quad pull
	.quad dup
	.quad push
	.quad and

	.quad zjump, 4f

	.quad lit, base
	.quad fetch
	.quad mul
	.quad drop

	.quad over
	.quad bfetch
	.quad lit, '0'
	.quad sub

	.quad dup
	.quad lit, 10-1
	.quad enter, less
	.quad not

	.quad zjump, 3f

	.quad lit, 'A'-'0'-10
	.quad sub

3:
	.quad add

	.quad pull
	.quad lit, 1
	.quad sub
	.quad push

	.quad push
	.quad lit, 1
	.quad add
	.quad pull

	.quad jump, 0b
4:

	.quad nip
	.quad pull
	.quad exit

find:
	.quad lit, last

0:
	.quad fetch
	.quad dup, dup

	.quad zjump, 1f

	.quad lit, cell*2
	.quad add
	.quad lit, token
	.quad enter, compare

1:
	.quad enter, zequals

	.quad zjump, 0b

	.quad exit

compile:
	.quad lit, codePtr
	.quad fetch
	.quad store

	.quad lit, codePtr
	.quad fetch
	.quad lit, cell
	.quad add
	.quad lit, codePtr
	.quad store
	.quad exit

interpret:
	.quad enter, gettoken
	.quad lit, token
	.quad fetch

	.quad zjump, 2f

	.quad enter, find
	.quad enter, qdup

	.quad zjump, 1f

	.quad lit, cell
	.quad add
	.quad fetch

	.quad dup
	.quad enter, negative
	.quad push

	.quad lit, ~flag
	.quad and
	.quad pull

	.quad zjump, 0f

	.quad execute
	.quad jump, interpret

0:
	.quad dup
	.quad lit, codeend
	.quad enter, less
	.quad not

	.quad zjump, 0f

	.quad lit, enter
	.quad enter, compile

0:
	.quad enter, compile
	.quad jump, interpret

1:
	.quad enter, literal

	.quad zjump, 0f

	.quad drop

	// Flush input.

	.quad lit, input
	.quad lit, inputTop
	.quad store

	// Print error and exit.

	.quad lit, token
	.quad enter, load
	.quad write
	.quad lit, '?'
	.quad jump, bput

0:

	// Compile converted literal.

	.quad lit, lit
	.quad enter, compile
	.quad enter, compile
	.quad jump, interpret

2:
	.quad lit, exit
	.quad enter, compile
	.quad jump, code

start:
	.quad lit, prompt
	.quad enter, load
	.quad write

	.quad enter, accept
	.quad enter, interpret
	.quad enter, flush

	.quad lit, code
	.quad lit, codePtr
	.quad store
	.quad jump, start

// The following definitions should be moved out of core once we can compile them at runtime.

while:
if:
	.quad lit, zjump
	.quad enter, compile
	.quad lit, codePtr
	.quad fetch
	.quad lit, 0
	.quad jump, compile

else:
	.quad lit, jump
	.quad enter, compile
	.quad lit, codePtr
	.quad fetch
	.quad push
	.quad lit, 0
	.quad enter, compile
	.quad enter, then
	.quad pull
	.quad exit

then:
	.quad push
	.quad lit, codePtr
	.quad fetch
	.quad pull
	.quad store
	.quad exit

begin:
	.quad lit, codePtr
	.quad fetch
	.quad exit

do:
	.quad push

	.quad lit, jump
	.quad enter, compile
	.quad enter, compile

	.quad lit, codePtr
	.quad fetch
	.quad pull
	.quad store
	.quad exit

bin:
	.quad lit, 2
	.quad lit, base
	.quad store
	.quad exit

dec:
	.quad lit, 10
	.quad lit, base
	.quad store
	.quad exit

hex:
	.quad lit, 16
	.quad lit, base
	.quad store
	.quad exit

dot:
	.quad dup
	.quad enter, negative

	.quad zjump, udot

	.quad negate

	.quad lit, '-'
	.quad enter, bput

udot:
	.quad lit, 0
	.quad lit, base
	.quad fetch
	.quad div
	.quad enter, qdup

	.quad zjump, 0f

	.quad enter, udot

0:
	.quad dup
	.quad lit, 10
	.quad enter, less

	.quad zjump, 0f

	.quad lit, '0'
	.quad add
	.quad jump, bput

0:
	.quad lit, 'A'-10
	.quad add
	.quad jump, bput

define 0, execute, "execute"
define headexecute, dup, "dup"
define headdup, drop, "drop"
define headdrop, nip, "nip"
define headnip, over, "over"
define headover, push, "push"
define headpush, pull, "pull"
define headpull, not, "not"
define headnot, and, "and"
define headand, or, "or"
define heador, xor, "xor"
define headxor, negate, "negate"
define headnegate, sub, "-"
define headsub, add, "+"
define headadd, mul, "*"
define headmul, div, "/"
define headdiv, fetch, "@"
define headfetch, store, "!"
define headstore, bfetch, "b@"
define headbfetch, bstore, "b!"
define headbstore, read, "read"
define headread, write, "write"
define headwrite, bye, "bye"

define headbye, qdup, "?dup"
define headqdup, less, "<"
define headless, negative, "negative"
define headnegative, bool, "bool"
define headbool, equals, "="
define headequals, zequals, "0="
define headzequals, within, "within"
define headwithin, accept, "accept"
define headaccept, bget, "bget"
define headbget, flush, "flush"
define headflush, line, "line"
define headline, bput, "bput"
define headbput, load, "load"
define headload, compare, "compare"
define headcompare, emptytoken, "emptytoken"
define heademptytoken, gettoken, "gettoken"
define headgettoken, literal, "literal"
define headliteral, natural, "natural"
define headnatural, find, "find"
define headfind, compile, "compile"
define headcompile, interpret, "interpret"
define headinterpret, start, "start"

define headstart, while, "while", flag
define headwhile, if, "if", flag
define headif, else, "else", flag
define headelse, then, "then", flag
define headthen, begin, "begin", flag
define headbegin, do, "do", flag

define headdo, bin, "bin", flag
define headbin, dec, "dec", flag
define headdec, hex, "hex", flag
define headhex, dot, "."
define headdot, udot, "u."

base:
	.quad 10

last:
	.quad headudot

inputPtr:
	.quad input

inputTop:
	.quad input

outputPtr:
	.quad output

codePtr:
	.quad code

string prompt, "# "

.bss

stack:
	.skip page

input:
	.skip page

output:
	.skip page

token:
	.skip page

code:
	.skip page
