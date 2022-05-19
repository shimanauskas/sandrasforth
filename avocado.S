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
	#define sys_read  0
	#define sys_write 1
	#define sys_exit  60
#elif __APPLE__
	#include "TargetConditionals.h"
	#ifdef TARGET_OS_MAC
		#define sys_read  0x2000003
		#define sys_write 0x2000004
		#define sys_exit  0x2000001
	#endif
#elif
	#error "Unsupported platform."
#endif

#define stdin  0
#define stdout 1

#define cell (8)
#define flag (1<<cell*8-1)

.macro dup /* x -- x x */
	leaq -cell(%rbp), %rbp
	movq %rax, (%rbp)
.endm

.macro nip /* x1 x2 -- x2 */
	leaq cell(%rbp), %rbp
.endm

.macro twonip /* x1 x2 x3-- x3 */
	leaq cell*2(%rbp), %rbp
.endm

.macro threenip /* x1 x2 x3 x4-- x4 */
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

.macro next /* -- */
	addq $cell, %rbx
	jmp *(%rbx)
.endm

.macro string name, string
string_\name:
	.byte 0f-.-1
	.ascii "\string"
0:

.balign cell
.endm

.macro define link, name, string, mask=0
head_\name:
	.quad \link
	.quad \name+\mask
	string \name, "\string"
.endm

.text

.global main

main:
	leaq stack(%rip), %rbp
	movq $-1, %rax
	leaq start(%rip), %rbx
	jmpq *(%rbx)

enter: /* -- */
	addq $cell, %rbx
	pushq %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

execute: /* addr -- */
	pushq %rbx
	movq %rax, %rbx
	drop
	jmpq *(%rbx)

exit: /* -- */
	popq %rbx
	next

jump: /* -- */
	addq $cell, %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

zjump: /* x -- */
	testq %rax, %rax
	drop 1
	leaq cell*2(%rbx), %rbx
	cmovzq -cell(%rbx), %rbx
	jmpq *(%rbx)

lit: /* -- x */
	dup
	addq $cell, %rbx
	movq (%rbx), %rax
	next

var: /* -- addr */
	dup
	addq $cell, %rbx
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

incr: /* n1 -- n2 */
	incq %rax
	next

decr: /* n1 -- n2 */
	decq %rax
	next

neg: /* n1 -- n2 */
	negq %rax
	next

sub: /* n1|u1 n2|u2 -- n3|u3 */
	negq %rax

	/* Fallthrough! */

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
	movq (%rbp), %rdx
	movq %rdx, (%rax)
	twodrop
	next

bfetch: /* addr -- byte */
	movzbq (%rax), %rax
	next

bstore: /* byte addr -- */
	movb (%rbp), %dl
	movb %dl, (%rax)
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
define head_execute, exit, "exit"
define head_exit, dup, "dup"
define head_dup, nip, "nip"
define head_nip, drop, "drop"
define head_drop, over, "over"
define head_over, push, "push"
define head_push, pull, "pull"
define head_pull, not, "not"
define head_not, and, "and"
define head_and, or, "or"
define head_or, xor, "xor"
define head_xor, incr, "1+"
define head_incr, decr, "1-"
define head_decr, neg, "neg"
define head_neg, sub, "-"
define head_sub, add, "+"
define head_add, mul, "*"
define head_mul, div, "/"
define head_div, fetch, "@"
define head_fetch, store, "!"
define head_store, bfetch, "b@"
define head_bfetch, bstore, "b!"
define head_bstore, syscall, "syscall"

string prompt, "# "

currkey: /* -- addr */
	.quad var, input
	.quad exit

here: /* -- addr */
	.quad var, code
	.quad exit

last: /* -- addr */
	.quad var, head_udot
	.quad exit

base: /* -- addr */
	.quad var, 10
	.quad exit

qdup: /* x -- 0 | x x */
	.quad dup

	.quad zjump, 0f

	.quad dup

0:
	.quad exit

less: /* n1 n2 -- bool */
	.quad over, over
	.quad xor
	.quad enter, zless

	.quad zjump, 0f

	.quad drop
	.quad jump, zless

0:
	.quad sub
	.quad jump, zless

uless: /* u1 u2 -- bool */
	.quad over, over
	.quad xor
	.quad enter, zless

	.quad zjump, 0f

	.quad nip
	.quad jump, zless

0:
	.quad sub

	/* Fallthrough! */

zless: /* n - bool */
	.quad lit, flag
	.quad and

	/* Fallthrough! */

bool: /* x -- bool */
	.quad zjump, 0f

	.quad lit, -1
	.quad exit

0:
	.quad lit, 0
	.quad exit

equals: /* x1 x2 -- bool */
	.quad xor

	/* Fallthrough! */

zequals: /* x -- bool */
	.quad enter, bool
	.quad not
	.quad exit

within: /* u1 u2 u3 -- bool */
	.quad push
	.quad over
	.quad push
	.quad enter, uless
	.quad not
	.quad pull, pull
	.quad enter, uless
	.quad and
	.quad exit

load: /* addr1 -- addr2 u */
	.quad dup
	.quad push
	.quad incr
	.quad pull
	.quad bfetch
	.quad exit

write: /* addr -- */
	.quad lit, stdout
	.quad over
	.quad enter, load
	.quad lit, sys_write
	.quad syscall
	.quad drop, drop
	.quad exit

accept: /* -- */
	.quad lit, stdin
	.quad lit, input+1
	.quad lit, 0xFF-1
	.quad lit, sys_read
	.quad syscall
	.quad dup
	.quad lit, 1
	.quad enter, less

	.quad zjump, 0f

	.quad drop
	.quad lit, 0
	.quad dup, dup
	.quad lit, sys_exit
	.quad syscall

0:
	.quad lit, input
	.quad bstore
	.quad lit, input+1
	.quad enter, currkey
	.quad store
	.quad exit

keyq: /* -- bool */
	.quad enter, currkey
	.quad fetch
	.quad lit, input
	.quad enter, load
	.quad add
	.quad enter, uless
	.quad exit

key: /* -- char */
	.quad enter, currkey
	.quad fetch
	.quad dup
	.quad incr
	.quad enter, currkey
	.quad store
	.quad bfetch
	.quad exit

flush: /* -- */
	.quad lit, output
	.quad enter, write
	.quad lit, 0
	.quad lit, output
	.quad bstore
	.quad exit

emit: /* char -- */
	.quad lit, output
	.quad enter, load
	.quad add
	.quad bstore
	.quad lit, output
	.quad bfetch
	.quad incr
	.quad lit, output
	.quad bstore
	.quad lit, output
	.quad bfetch
	.quad lit, 0xFF
	.quad xor

	.quad zjump, flush

	.quad exit

/* Read input, skip spaces.
   Then deposit non-space characters to buffer.
   If end of input is reached, return with buffer empty. */

word: /* -- */
	.quad enter, keyq
	.quad not

	.quad zjump, 0f

	.quad lit, 0
	.quad lit, output
	.quad bstore
	.quad exit

0:
	.quad enter, key
	.quad dup
	.quad lit, '!'
	.quad enter, uless

	.quad zjump, 0f

	.quad drop

	.quad jump, word
0:

	.quad lit, output+1
	.quad push

0:
	.quad dup
	.quad lit, '!'
	.quad enter, uless
	.quad not

	.quad zjump, 0f

	.quad pull
	.quad dup
	.quad incr
	.quad push
	.quad bstore
	.quad enter, key

	.quad jump, 0b
0:

	.quad drop
	.quad pull
	.quad lit, output+1
	.quad sub
	.quad lit, output
	.quad bstore
	.quad exit

digitq: /* char base -- u bool */
	.quad push
	.quad lit, '0'
	.quad sub
	.quad lit, 9
	.quad over
	.quad enter, less

	.quad zjump, 0f

	.quad lit, 'A'-'0'-10
	.quad sub
	.quad dup
	.quad lit, 10
	.quad enter, less
	.quad or

0:
	.quad dup
	.quad pull
	.quad jump, uless

natural: /* 0 addr1 u1 -- u2 addr2 u3 */
	.quad push
	.quad dup
	.quad push
	.quad bfetch
	.quad enter, base
	.quad fetch
	.quad enter, digitq
	.quad pull
	.quad over
	.quad pull
	.quad dup
	.quad push
	.quad and

	.quad zjump, 0f

	.quad push
	.quad drop
	.quad push
	.quad enter, base
	.quad fetch
	.quad mul
	.quad drop
	.quad pull
	.quad add
	.quad pull
	.quad incr
	.quad pull
	.quad decr

	.quad jump, natural
0:

	.quad nip, nip
	.quad pull
	.quad exit

number: /* 0 addr1 u1 -- n addr2 u2 */
	.quad over
	.quad bfetch
	.quad lit, '-'
	.quad enter, equals

	.quad zjump, natural

	.quad decr
	.quad push
	.quad incr
	.quad pull
	.quad enter, natural
	.quad push, push
	.quad neg
	.quad pull, pull
	.quad exit

sameq: /* addr1 addr2 u1 -- u2 */
	.quad dup
	.quad push, push
	.quad over, bfetch
	.quad over, bfetch
	.quad enter, equals
	.quad pull
	.quad and

	.quad zjump, 0f

	.quad push
	.quad incr
	.quad pull
	.quad incr
	.quad pull
	.quad decr

	.quad jump, sameq
0:

	.quad pull
	.quad nip, nip
	.quad exit

find: /* -- */
	.quad enter, last

0:
	.quad fetch
	.quad dup, dup

	.quad zjump, 1f

	.quad dup
	.quad lit, cell*2
	.quad add
	.quad bfetch
	.quad lit, output
	.quad bfetch
	.quad enter, equals

	.quad zjump, 1f

	.quad lit, cell*2+1
	.quad add
	.quad lit, output
	.quad enter, load
	.quad enter, sameq

1:
	.quad enter, zequals

	.quad zjump, 0b

	.quad exit

compile: /* x -- */
	.quad enter, here
	.quad fetch
	.quad store
	.quad enter, here
	.quad fetch
	.quad lit, cell
	.quad add
	.quad enter, here
	.quad store
	.quad exit

interpret: /* -- */
	.quad enter, word
	.quad lit, output
	.quad bfetch

	.quad zjump, 2f

	.quad enter, find
	.quad enter, qdup

	.quad zjump, 1f

	.quad lit, cell
	.quad add
	.quad fetch
	.quad dup
	.quad enter, zless
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
	.quad enter, uless
	.quad not

	.quad zjump, 0f

	.quad lit, enter
	.quad enter, compile

0:
	.quad enter, compile
	.quad jump, interpret

1:
	.quad lit, 0
	.quad lit, output
	.quad enter, load
	.quad enter, number
	.quad nip

	.quad zjump, 0f

	.quad drop
	.quad lit, '?'
	.quad jump, emit

0:
	.quad lit, lit
	.quad enter, compile
	.quad enter, compile
	.quad jump, interpret

2:
	.quad lit, exit
	.quad enter, compile
	.quad jump, code

start: /* -- */
	.quad lit, code
	.quad enter, here
	.quad store
	.quad enter, flush	
	.quad lit, string_prompt
	.quad enter, write
	.quad enter, accept
	.quad enter, interpret
	.quad jump, start

define head_syscall, currkey, "currkey"
define head_currkey, here, "here"
define head_here, last, "last"
define head_last, base, "base"
define head_base, qdup, "?dup"
define head_qdup, less, "<"
define head_less, uless, "u<"
define head_uless, zless, "0<"
define head_zless, bool, "bool"
define head_bool, equals, "="
define head_equals, zequals, "0="
define head_zequals, within, "within"
define head_within, load, "load"
define head_load, write, "write"
define head_write, accept, "accept"
define head_accept, keyq, "key?"
define head_keyq, key, "key"
define head_key, flush, "flush"
define head_flush, emit, "emit"
define head_emit, word, "word"
define head_word, digitq, "digit?"
define head_digitq, natural, "natural"
define head_natural, number, "number"
define head_number, sameq, "same?"
define head_sameq, find, "find"
define head_find, compile, "compile"
define head_compile, interpret, "interpret"
define head_interpret, start, "start"

/* The following definitions should be moved out of core
   once we can compile them at runtime. */

begin: /* -- addr */
	.quad enter, here
	.quad fetch
	.quad exit

if: /* -- addr */
	.quad lit, zjump
	.quad enter, compile
	.quad enter, here
	.quad fetch
	.quad lit, 0
	.quad jump, compile

then: /* addr -- */
	.quad push
	.quad enter, here
	.quad fetch
	.quad pull
	.quad store
	.quad exit

again: /* addr1 addr2 -- */
	.quad push
	.quad lit, jump
	.quad enter, compile
	.quad enter, compile
	.quad enter, here
	.quad fetch
	.quad pull
	.quad store
	.quad exit

dec: /* -- */
	.quad lit, 10
	.quad enter, base
	.quad store
	.quad exit

hex: /* -- */
	.quad lit, 16
	.quad enter, base
	.quad store
	.quad exit

dot: /* n -- */
	.quad dup
	.quad enter, zless

	.quad zjump, udot

	.quad neg
	.quad lit, '-'
	.quad enter, emit

	/* Fallthrough! */

udot: /* u -- */
	.quad lit, 0
	.quad enter, base
	.quad fetch
	.quad div
	.quad enter, qdup

	.quad zjump, 0f

	.quad enter, udot

0:
	.quad dup
	.quad lit, 10
	.quad enter, uless

	.quad zjump, 0f

	.quad lit, '0'
	.quad add
	.quad jump, emit

0:
	.quad lit, 'A'-10
	.quad add
	.quad jump, emit

define head_start, begin, "begin", flag
define head_begin, if, "if", flag
define head_if, then, "then", flag
define head_then, again, "again", flag
define head_again, dec, "dec", flag
define head_dec, hex, "hex", flag
define head_hex, dot, "."
define head_dot, udot, "u."

.bss

input:
	.skip 0x100

output:
	.skip 0x100

code:
	.skip 0x1000

stack:
