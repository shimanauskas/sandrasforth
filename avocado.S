/* rax - top-of-stack, syscall number.
   rbx - threaded code pointer.
   rcx - temporary, syscall scratch.
   rdx - temporary, syscall argument.

   rsi - syscall argument.
   rdi - syscall argument.
   rbp - data stack pointer.
   rsp - code stack pointer.

   r8  - unused, syscall argument.
   r9  - unused, syscall argument.
   r10 - unused, syscall argument.
   r11 - unused, syscall scratch.

   r12 - unused.
   r13 - unused.
   r14 - unused.
   r15 - unused. */

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

#define token .quad

#define cell 8
#define page 0x1000
#define flag (1<<((cell*8)-1))

.macro string name, string
\name:
	.byte 0f-(.+1)
	.ascii "\string"
0:

.balign cell
.endm

.macro define link, name, string, imm=0
head\name:
	token \link
	token \name+\imm
	string string\name, "\string"
.endm

.macro dup /* x -- x x */
	subq $(cell), %rbp
	movq %rax, (%rbp)
.endm

.macro nip /* x1 x2 -- x2 */
	leaq cell(%rbp), %rbp
.endm

.macro twonip /* x1 x2 x3 -- x3 */
	leaq cell*2(%rbp), %rbp
.endm

.macro threenip /* x1 x2 x3 x4 -- x4 */
	leaq cell*3(%rbp), %rbp
.endm

.macro drop /* x -- */
	movq (%rbp), %rax
	nip
.endm

.macro twodrop /* x1 x2 -- */
	movq cell(%rbp), %rax
	twonip
.endm

.macro next
	addq $(cell), %rbx
	jmp *(%rbx)
.endm

.text

.global main

main:
	leaq stack(%rip), %rbp
	movq $-1, %rax
	leaq start(%rip), %rbx
	jmpq *(%rbx)

enter:
	addq $(cell), %rbx
	pushq %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

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

zjump: /* x -- */
	testq %rax, %rax
	drop
	leaq cell*2(%rbx), %rbx
	cmovzq -cell(%rbx), %rbx
	jmpq *(%rbx)

lit: /* -- x */
	dup
	addq $(cell), %rbx
	movq (%rbx), %rax
	next

var: /* -- addr */
	dup
	addq $(cell), %rbx
	movq %rbx, %rax
	next

dup: /* x -- x x */
	dup
	next

nip: /* x1 x2 -- x2 */
	nip
	next

drop: /* x -- */
	drop
	next

over: /* x1 x2 -- x1 x2 x1 */
	dup
	movq cell(%rbp), %rax
	next

push: /* x -- */ /* r: -- x */
	pushq %rax
	drop
	next

pull: /* -- x */ /* r: x -- */
	dup
	popq %rax
	next

not: /* x1 -- x2 */
	notq %rax
	next

and: /* x1 x2 -- x3 */
	andq (%rbp), %rax
	nip
	next

or: /* x1 x2 -- x3 */
	orq (%rbp), %rax
	nip
	next

xor: /* x1 x2 -- x3 */
	xorq (%rbp), %rax
	nip
	next

neg: /* n1 -- n2 */
	negq %rax
	next

sub: /* n1|u1 n2|u2 -- n3|u3 */
	negq %rax

add: /* n1|u1 n2|u2 -- n3|u3 */
	addq (%rbp), %rax
	nip
	next

mul: /* n1 n2 -- d */
	movq %rax, %rcx
	drop
	mulq %rcx
	dup
	movq %rdx, %rax
	next

div: /* n1 n2 -- n3 n4 */
	movq %rax, %rcx
	movq (%rbp), %rdx
	nip
	movq (%rbp), %rax
	divq %rcx
	movq %rdx, (%rbp)
	next

fetch: /* addr -- x */
	movq (%rax), %rax
	next

store: /* x addr -- */
	movq (%rbp), %rcx
	movq %rcx, (%rax)
	twodrop
	next

bfetch: /* addr -- byte */
	movzbq (%rax), %rax
	next

bstore: /* byte addr -- */
	movb (%rbp), %cl
	movb %cl, (%rax)
	twodrop
	next

syscall: /* x1 x2 x3 x4 -- x5 */
	movq (%rbp), %rdx
	movq cell(%rbp), %rsi
	movq cell*2(%rbp), %rdi
	threenip
	syscall
	next

codeend:

.data

define 0, execute, "execute"
define headexecute, exit, "exit"
define headexit, dup, "dup"
define headdup, nip, "nip"
define headnip, drop, "drop"
define headdrop, over, "over"
define headover, push, "push"
define headpush, pull, "pull"
define headpull, not, "not"
define headnot, and, "and"
define headand, or, "or"
define heador, xor, "xor"
define headxor, neg, "neg"
define headneg, sub, "-"
define headsub, add, "+"
define headadd, mul, "*"
define headmul, div, "/"
define headdiv, fetch, "@"
define headfetch, store, "!"
define headstore, bfetch, "b@"
define headbfetch, bstore, "b!"
define headbstore, syscall, "syscall"

string prompt, "# "

currkey:
	token var, input
	token exit

here:
	token var, code
	token exit

last:
	token var, headudot
	token exit

base:
	token var, 10
	token exit

/* If top-of-stack not zero, duplicate it. */

qdup:
	token dup

	token zjump, 0f

	token dup

0:
	token exit

less:
	token over, over
	token xor
	token enter, negative

	token zjump, 0f

	token drop
	token jump, negative

0:
	token sub
	token jump, negative

uless:
	token over, over
	token xor
	token enter, negative

	token zjump, 0f

	token nip
	token jump, negative

0:
	token sub

negative:
	token lit, flag
	token and

bool:
	token dup

	token zjump, 0f

	token dup
	token xor
	token not

0:
	token exit

equals:
	token xor

zequals:
	token enter, bool
	token not
	token exit

within:
	token push
	token over
	token push
	token enter, uless
	token not
	token pull, pull
	token enter, uless
	token and
	token exit

load: /* addr1 -- addr2 u */
	token dup
	token push
	token lit, 1
	token add
	token pull
	token bfetch
	token exit

write: /* addr -- */
	token lit, stdout
	token over
	token enter, load
	token lit, syswrite
	token syscall
	token drop, drop
	token exit

accept:
	token lit, stdin
	token lit, input+1
	token lit, 0xFF-1
	token lit, sysread
	token syscall
	token dup
	token lit, 1
	token enter, less

	token zjump, 0f

	token drop
	token lit, 0
	token dup, dup
	token lit, sysexit
	token syscall

0:
	token lit, input
	token bstore
	token lit, input+1
	token enter, currkey
	token store
	token exit

keyq: /* -- bool */
	token enter, currkey
	token fetch
	token lit, input
	token enter, load
	token add
	token enter, uless
	token exit

key: /* -- byte */
	token enter, currkey
	token fetch
	token dup
	token lit, 1
	token add
	token enter, currkey
	token store
	token bfetch
	token exit

flush:
	token lit, output
	token enter, write
	token lit, 0
	token lit, output
	token bstore
	token exit

emit:
	token lit, output
	token enter, load
	token add
	token bstore
	token lit, output
	token bfetch
	token lit, 1
	token add
	token lit, output
	token bstore
	token lit, output
	token bfetch
	token lit, 0xFF
	token xor

	token zjump, flush

	token exit

/* Read input, skip spaces.
   Then deposit non-space characters to buffer.
   If end of input is reached, return with buffer empty. */

word:
	token enter, keyq
	token not

	token zjump, 0f

	token lit, 0
	token lit, output
	token bstore
	token exit

0:
	token enter, key
	token dup
	token lit, '!'
	token enter, uless

	token zjump, 0f

	token drop

	token jump, word
0:

	token lit, output+1
	token push

0:
	token dup
	token lit, '!'
	token enter, uless
	token not

	token zjump, 0f

	token pull
	token dup
	token lit, 1
	token add
	token push
	token bstore
	token enter, key

	token jump, 0b
0:

	token drop
	token pull
	token lit, output+1
	token sub
	token lit, output
	token bstore
	token exit

digitq: /* byte base -- u bool */
	token push
	token lit, '0'
	token sub
	token lit, 9
	token over
	token enter, less

	token zjump, 0f

	token lit, 'A'-'0'-10
	token sub
	token dup
	token lit, 10
	token enter, less
	token or

0:
	token dup
	token pull
	token jump, uless

natural: /* 0 addr1 u1 -- u2 addr2 u3 */
	token push
	token dup
	token push
	token bfetch
	token enter, base
	token fetch
	token enter, digitq
	token pull
	token over
	token pull
	token dup
	token push
	token and

	token zjump, 0f

	token push
	token drop
	token push
	token enter, base
	token fetch
	token mul
	token drop
	token pull
	token add
	token pull
	token lit, 1
	token add
	token pull
	token lit, 1
	token sub

	token jump, natural
0:

	token nip, nip
	token pull
	token exit

number: /* 0 addr1 u1 -- n addr2 u2 */
	token over
	token bfetch
	token lit, '-'
	token enter, equals

	token zjump, natural

	token lit, 1
	token sub
	token push
	token lit, 1
	token add
	token pull
	token enter, natural
	token push, push
	token neg
	token pull, pull
	token exit

sameq: /* addr1 addr2 u1 -- u2 */
	token dup
	token push, push
	token over, bfetch
	token over, bfetch
	token enter, equals
	token pull
	token and

	token zjump, 0f

	token push
	token lit, 1
	token add
	token pull
	token lit, 1
	token add
	token pull
	token lit, 1
	token sub

	token jump, sameq
0:

	token pull
	token nip, nip
	token exit

find:
	token enter, last

0:
	token fetch
	token dup, dup

	token zjump, 1f

	token dup
	token lit, cell*2
	token add
	token bfetch
	token lit, output
	token bfetch
	token enter, equals

	token zjump, 1f

	token lit, cell*2+1
	token add
	token lit, output
	token enter, load
	token enter, sameq

1:
	token enter, zequals

	token zjump, 0b

	token exit

compile:
	token enter, here
	token fetch
	token store
	token enter, here
	token fetch
	token lit, cell
	token add
	token enter, here
	token store
	token exit

interpret:
	token enter, word
	token lit, output
	token bfetch

	token zjump, 2f

	token enter, find
	token enter, qdup

	token zjump, 1f

	token lit, cell
	token add
	token fetch
	token dup
	token enter, negative
	token push
	token lit, ~flag
	token and
	token pull

	token zjump, 0f

	token execute
	token jump, interpret

0:
	token dup
	token lit, codeend
	token enter, uless
	token not

	token zjump, 0f

	token lit, enter
	token enter, compile

0:
	token enter, compile
	token jump, interpret

1:
	token lit, 0
	token lit, output
	token enter, load
	token enter, number
	token nip

	token zjump, 0f

	token drop
	token lit, '?'
	token jump, emit

0:
	token lit, lit
	token enter, compile
	token enter, compile
	token jump, interpret

2:
	token lit, exit
	token enter, compile
	token jump, code

start:
	token lit, code
	token enter, here
	token store
	token enter, flush	
	token lit, prompt
	token enter, write
	token enter, accept
	token enter, interpret
	token jump, start

define headsyscall, currkey, "currkey"
define headcurrkey, here, "here"
define headhere, last, "last"
define headlast, base, "base"
define headbase, qdup, "?dup"
define headqdup, less, "<"
define headless, uless, "u<"
define headuless, negative, "0<"
define headnegative, bool, "bool"
define headbool, equals, "="
define headequals, zequals, "0="
define headzequals, within, "within"
define headwithin, load, "load"
define headload, write, "write"
define headwrite, accept, "accept"
define headaccept, keyq, "key?"
define headkeyq, key, "key"
define headkey, flush, "flush"
define headflush, emit, "emit"
define heademit, word, "word"
define headword, digitq, "digit?"
define headdigitq, natural, "natural"
define headnatural, number, "number"
define headnumber, sameq, "same?"
define headsameq, find, "find"
define headfind, compile, "compile"
define headcompile, interpret, "interpret"
define headinterpret, start, "start"

/* The following definitions should be moved out of core
   once we can compile them at runtime. */

begin:
	token enter, here
	token fetch
	token exit

if:
	token lit, zjump
	token enter, compile
	token enter, here
	token fetch
	token lit, 0
	token jump, compile

then:
	token push
	token enter, here
	token fetch
	token pull
	token store
	token exit

again:
	token push
	token lit, jump
	token enter, compile
	token enter, compile
	token enter, here
	token fetch
	token pull
	token store
	token exit

dec:
	token lit, 10
	token enter, base
	token store
	token exit

hex:
	token lit, 16
	token enter, base
	token store
	token exit

dot:
	token dup
	token enter, negative

	token zjump, udot

	token neg
	token lit, '-'
	token enter, emit

udot:
	token lit, 0
	token enter, base
	token fetch
	token div
	token enter, qdup

	token zjump, 0f

	token enter, udot

0:
	token dup
	token lit, 10
	token enter, uless

	token zjump, 0f

	token lit, '0'
	token add
	token jump, emit

0:
	token lit, 'A'-10
	token add
	token jump, emit

define headstart, begin, "begin", flag
define headbegin, if, "if", flag
define headif, then, "then", flag
define headthen, again, "again", flag
define headagain, dec, "dec", flag
define headdec, hex, "hex", flag
define headhex, dot, "."
define headdot, udot, "u."

.bss

input:
	.skip 0x100

output:
	.skip 0x100

code:
	.skip page

stack:
