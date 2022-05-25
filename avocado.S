/* rax - top-of-stack, syscall number.
   rbx - threaded code pointer.
   rcx - temporary, syscall scratch.
   rdx - temporary, syscall argument.

   rsi - syscall argument.
   rdi - syscall argument.
   rbp - data   stack pointer.
   rsp - return stack pointer.

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

#define cell 8
#define sign (1<<(cell*8-1))
#define buf  0x100
#define imm  0x80

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
	addq $(cell), %rbx
	jmp *(%rbx)
.endm

.macro string name, string, mask=0
\name:
	.byte 0f-(.+1)+\mask
	.ascii "\string"
0:

.balign cell
.endm

.macro define link, name, string, mask=0
head_\name:
	.quad \link
	.quad \name
	string 0, "\string", \mask
.endm

.text

.global main

main:
	leaq dstack(%rip), %rbp
	movq $-1, %rax
	leaq start(%rip), %rbx
	jmpq *(%rbx)

call: /* -- */ /* r: -- addr */
	addq $(cell), %rbx
	pushq %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

jump: /* -- */
	addq $(cell), %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

zjump: /* x -- */
	testq %rax, %rax
	drop
	leaq cell*2(%rbx), %rbx
	cmovzq -cell(%rbx), %rbx
	jmpq *(%rbx)

exec: /* addr1 -- */ /* r: -- addr2 */
	pushq %rbx
	movq %rax, %rbx
	drop
	jmpq *(%rbx)

ret: /* -- */ /* r: addr -- */
	popq %rbx
	next

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

pop: /* -- x */ /* r: x -- */
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

inc: /* n1 -- n2 */
	incq %rax
	next

dec: /* n1 -- n2 */
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

div: /* d n1 -- n2 n3 */
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

define 0,           exec,    "exec"
define head_exec,   ret,     "ret"
define head_ret,    dup,     "dup"
define head_dup,    nip,     "nip"
define head_nip,    drop,    "drop"
define head_drop,   over,    "over"
define head_over,   push,    "push"
define head_push,   pop,     "pop"
define head_pop,    not,     "not"
define head_not,    and,     "and"
define head_and,    or,      "or"
define head_or,     xor,     "xor"
define head_xor,    inc,     "1+"
define head_inc,    dec,     "1-"
define head_dec,    neg,     "neg"
define head_neg,    sub,     "-"
define head_sub,    add,     "+"
define head_add,    mul,     "*"
define head_mul,    div,     "/"
define head_div,    fetch,   "@"
define head_fetch,  store,   "!"
define head_store,  bfetch,  "b@"
define head_bfetch, bstore,  "b!"
define head_bstore, syscall, "syscall"

string prompt, "# "

ainput: /* -- addr */
	.quad lit, input
	.quad ret

aoutput: /* -- addr */
	.quad lit, output
	.quad ret

curr: /* -- addr */
	.quad var, input+1
	.quad ret

here: /* -- addr */
	.quad var, code
	.quad ret

top: /* -- addr */
	.quad var, code
	.quad ret

last: /* -- addr */
	.quad var, head_udot
	.quad ret

base: /* -- addr */
	.quad var, 10
	.quad ret

qdup: /* x -- 0 | x x */
	.quad dup

	.quad zjump, 0f

	.quad dup

0:
	.quad ret

less: /* n1 n2 -- bool */
	.quad over, over
	.quad xor
	.quad call, zless

	.quad zjump, 0f

	.quad drop
	.quad jump, zless

0:
	.quad sub
	.quad jump, zless

uless: /* u1 u2 -- bool */
	.quad over, over
	.quad xor
	.quad call, zless

	.quad zjump, 0f

	.quad nip
	.quad jump, zless

0:
	.quad sub

	/* Fallthrough! */

zless: /* n - bool */
	.quad lit, sign
	.quad and

	/* Fallthrough! */

bool: /* x -- bool */
	.quad zjump, 0f

	.quad lit, -1
	.quad ret

0:
	.quad lit, 0
	.quad ret

equals: /* x1 x2 -- bool */
	.quad xor

	/* Fallthrough! */

zequals: /* x -- bool */
	.quad call, bool
	.quad not
	.quad ret

within: /* u1 u2 u3 -- bool */
	.quad push
	.quad over
	.quad push
	.quad call, uless
	.quad not
	.quad pop, pop
	.quad call, uless
	.quad and
	.quad ret

string: /* addr1 -- addr2 u */
	.quad dup
	.quad push
	.quad inc
	.quad pop
	.quad bfetch
	.quad ret

type: /* addr u -- */
	.quad push, push
	.quad lit, stdout
	.quad pop, pop
	.quad lit, sys_write
	.quad syscall
	.quad drop
	.quad ret

reset: /* -- */
	.quad lit, input+1
	.quad call, curr
	.quad store
	.quad ret

accept: /* -- */
	.quad lit, stdin
	.quad lit, input+1
	.quad lit, buf-2
	.quad lit, sys_read
	.quad syscall
	.quad call, qdup

	.quad zjump, 0f

	.quad lit, input
	.quad bstore
	.quad jump, reset

0:
	.quad lit, 0
	.quad dup, dup
	.quad lit, sys_exit
	.quad syscall

keyq: /* -- bool */
	.quad call, curr
	.quad fetch
	.quad lit, input
	.quad call, string
	.quad add
	.quad call, uless
	.quad ret

key: /* -- char */
	.quad call, keyq
	.quad not

	.quad zjump, 0f

	.quad call, reset

0:
	.quad call, curr
	.quad fetch
	.quad dup
	.quad inc
	.quad call, curr
	.quad store
	.quad bfetch
	.quad ret

empty: /* -- */
	.quad lit, 0
	.quad lit, output
	.quad bstore
	.quad ret

flush: /* -- */
	.quad lit, output
	.quad call, string
	.quad call, type
	.quad jump, empty

nl: /* -- */
	.quad lit, '\n'

	/* Fallthrough! */

emit: /* char -- */
	.quad dup
	.quad lit, output
	.quad call, string
	.quad add
	.quad bstore
	.quad lit, output
	.quad bfetch
	.quad inc
	.quad lit, output
	.quad bstore
	.quad lit, '\n'
	.quad call, equals
	.quad not
	.quad lit, output
	.quad bfetch
	.quad lit, buf-1
	.quad xor
	.quad and

	.quad zjump, flush

	.quad ret

/* Read input, skip spaces.
   Then deposit non-space characters to buffer.
   If end of input is reached, return with buffer empty. */

word: /* -- */
	.quad call, keyq

	.quad zjump, empty

	.quad call, key
	.quad dup
	.quad lit, '!'
	.quad call, uless

	.quad zjump, 0f

	.quad drop

	.quad jump, word
0:

	.quad call, empty

0:
	.quad dup
	.quad lit, '!'
	.quad call, uless
	.quad not

	.quad zjump, 0f

	.quad call, emit
	.quad call, key

	.quad jump, 0b
0:

	.quad drop
	.quad ret

digitq: /* char base -- u bool */
	.quad push
	.quad lit, '0'
	.quad sub
	.quad lit, 9
	.quad over
	.quad call, less

	.quad zjump, 0f

	.quad lit, 'A'-'0'-10
	.quad sub
	.quad dup
	.quad lit, 10
	.quad call, less
	.quad or

0:
	.quad dup
	.quad pop
	.quad jump, uless

natural: /* 0 addr1 u1 -- u2 addr2 u3 */
	.quad push
	.quad dup
	.quad push
	.quad bfetch
	.quad call, base
	.quad fetch
	.quad call, digitq
	.quad pop
	.quad over
	.quad pop
	.quad dup
	.quad push
	.quad and

	.quad zjump, 0f

	.quad push
	.quad drop
	.quad push
	.quad call, base
	.quad fetch
	.quad mul
	.quad drop
	.quad pop
	.quad add
	.quad pop
	.quad inc
	.quad pop
	.quad dec

	.quad jump, natural
0:

	.quad nip, nip
	.quad pop
	.quad ret

number: /* 0 addr1 u1 -- n addr2 u2 */
	.quad over
	.quad bfetch
	.quad lit, '-'
	.quad call, equals

	.quad zjump, natural

	.quad dec
	.quad push
	.quad inc
	.quad pop
	.quad call, natural
	.quad push, push
	.quad neg
	.quad pop, pop
	.quad ret

sameq: /* addr1 addr2 u1 -- u2 */
	.quad dup
	.quad push, push
	.quad over, bfetch
	.quad over, bfetch
	.quad call, equals
	.quad pop
	.quad and

	.quad zjump, 0f

	.quad push
	.quad inc
	.quad pop
	.quad inc
	.quad pop
	.quad dec

	.quad jump, sameq
0:

	.quad pop
	.quad nip, nip
	.quad ret

find: /* -- addr | 0 */
	.quad call, last

0:
	.quad fetch
	.quad dup, dup

	.quad zjump, 1f

	.quad dup
	.quad lit, cell*2
	.quad add
	.quad bfetch
	.quad lit, ~imm
	.quad and
	.quad lit, output
	.quad bfetch
	.quad call, equals

	.quad zjump, 1f

	.quad lit, cell*2+1
	.quad add
	.quad lit, output
	.quad call, string
	.quad call, sameq

1:
	.quad call, zequals

	.quad zjump, 0b

	.quad ret

compile: /* x -- */
	.quad call, top
	.quad fetch
	.quad store
	.quad call, top
	.quad fetch
	.quad lit, cell
	.quad add
	.quad call, top
	.quad store
	.quad ret

interpret: /* -- */
	.quad call, word
	.quad lit, output
	.quad bfetch

	.quad zjump, 2f

	.quad call, find
	.quad call, qdup

	.quad zjump, 1f

	.quad lit, cell
	.quad add
	.quad dup
	.quad lit, cell
	.quad add
	.quad bfetch
	.quad lit, imm
	.quad and

	.quad zjump, 0f

	.quad fetch
	.quad exec
	.quad jump, interpret

0:
	.quad fetch
	.quad dup
	.quad lit, main
	.quad lit, codeend
	.quad call, within
	.quad not

	.quad zjump, 0f

	.quad lit, call
	.quad call, compile

0:
	.quad call, compile
	.quad jump, interpret

1:
	.quad lit, 0
	.quad lit, output
	.quad call, string
	.quad call, number
	.quad nip

	.quad zjump, 0f

	.quad drop
	.quad lit, '?'
	.quad jump, emit

0:
	.quad lit, lit
	.quad call, compile
	.quad call, compile
	.quad jump, interpret

2:
	.quad lit, ret
	.quad call, compile
	.quad call, here
	.quad fetch
	.quad exec
	.quad ret

start: /* -- */
	.quad call, here
	.quad fetch
	.quad call, top
	.quad store
	.quad call, flush
	.quad lit, prompt
	.quad call, string
	.quad call, type
	.quad call, accept
	.quad call, interpret
	.quad jump, start

semicolon:
	.quad lit, ret
	.quad call, compile
	.quad call, top
	.quad fetch
	.quad call, here
	.quad store
	.quad ret

define head_syscall,   ainput,    "'input"
define head_ainput,    aoutput,   "'output"
define head_aoutput,   curr,      "curr"
define head_curr,      here,      "here"
define head_here,      top,       "top"
define head_top,       last,      "last"
define head_last,      base,      "base"
define head_base,      qdup,      "?dup"
define head_qdup,      less,      "<"
define head_less,      uless,     "u<"
define head_uless,     zless,     "0<"
define head_zless,     bool,      "bool"
define head_bool,      equals,    "="
define head_equals,    zequals,   "0="
define head_zequals,   within,    "within"
define head_within,    string,    "string"
define head_string,    type,      "type"
define head_type,      reset,     "reset"
define head_reset,     accept,    "accept"
define head_accept,    keyq,      "key?"
define head_keyq,      key,       "key"
define head_key,       empty,     "empty"
define head_empty,     flush,     "flush"
define head_flush,     nl,        "nl"
define head_nl,        emit,      "emit"
define head_emit,      word,      "word"
define head_word,      digitq,    "digit?"
define head_digitq,    natural,   "natural"
define head_natural,   number,    "number"
define head_number,    sameq,     "same?"
define head_sameq,     find,      "find"
define head_find,      compile,   "compile"
define head_compile,   interpret, "interpret"
define head_interpret, start,     "start"
define head_start,     semicolon, ";",        imm

/* The following definitions should be moved out of core
   once we can compile them at runtime. */

begin: /* -- */ /* c: -- addr */
	.quad call, here
	.quad fetch
	.quad ret

if: /* x -- */ /* c: -- addr */
	.quad lit, zjump
	.quad call, compile
	.quad call, here
	.quad fetch
	.quad lit, 0
	.quad jump, compile

then: /* -- */ /* c: addr -- */
	.quad push
	.quad call, here
	.quad fetch
	.quad pop
	.quad store
	.quad ret

again: /* -- */ /* c: addr1 addr2 -- */
	.quad push
	.quad lit, jump
	.quad call, compile
	.quad call, compile
	.quad call, here
	.quad fetch
	.quad pop
	.quad store
	.quad ret

deci: /* -- */
	.quad lit, 10
	.quad call, base
	.quad store
	.quad ret

hexa: /* -- */
	.quad lit, 16
	.quad call, base
	.quad store
	.quad ret

dot: /* n -- */
	.quad dup
	.quad call, zless

	.quad zjump, udot

	.quad neg
	.quad lit, '-'
	.quad call, emit

	/* Fallthrough! */

udot: /* u -- */
	.quad lit, 0
	.quad call, base
	.quad fetch
	.quad div
	.quad call, qdup

	.quad zjump, 0f

	.quad call, udot

0:
	.quad dup
	.quad lit, 10
	.quad call, uless

	.quad zjump, 0f

	.quad lit, '0'
	.quad add
	.quad jump, emit

0:
	.quad lit, 'A'-10
	.quad add
	.quad jump, emit

define head_semicolon, begin, "begin", imm
define head_begin,     if,    "if",    imm
define head_if,        then,  "then",  imm
define head_then,      again, "again", imm
define head_again,     deci,  "deci",  imm
define head_deci,      hexa,  "hexa",  imm
define head_hexa,      dot,   "."
define head_dot,       udot,  "u."

.bss

input:
	.skip buf

output:
	.skip buf

code:
	.skip 0x1000

dstack:
