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
#define line 0x100
#define page 0x1000

#define sign 1<<63
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
	.byte (1f-0f)+\mask
0:
	.ascii "\string"
1:
.balign cell
.endm

.macro define link, body, word, mask=0
head_\body:
	.quad \link
	.quad \body
	string 0, "\word", \mask
.endm

.text

.global main

main:
	leaq dstack(%rip), %rbp
	movq $-1, %rax
	leaq start(%rip), %rbx
	jmpq *(%rbx)

call: /* r: -- addr */
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

ret: /* r: addr -- */
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
	leaq cell*3(%rbp), %rbp
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

in: /* -- addr */
	.quad lit, _in
	.quad ret

out: /* -- addr */
	.quad lit, _out
	.quad ret

code: /* -- addr */
	.quad lit, _code
	.quad ret

vocab: /* -- addr */
	.quad lit, _vocab
	.quad ret

curr: /* -- addr */
	.quad var, _in+1
	.quad ret

state: /* -- addr */
	.quad var, 0
	.quad ret

here: /* -- addr */
	.quad var, _code
	.quad ret

top: /* -- addr */
	.quad var, _code
	.quad ret

head: /* -- addr */
	.quad var, _vocab
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

align: /* x -- x */
	.quad lit, cell-1
	.quad add
	.quad lit, ~(cell-1)
	.quad and
	.quad ret

string: /* addr1 -- addr2 u */
	.quad dup
	.quad push
	.quad inc
	.quad pop
	.quad bfetch
	.quad ret

reset: /* -- */
	.quad lit, _in+1
	.quad call, curr
	.quad store
	.quad ret

accept: /* -- */
	.quad lit, stdin
	.quad lit, _in+1
	.quad lit, line-2
	.quad lit, sys_read
	.quad syscall
	.quad call, qdup

	.quad zjump, 0f

	.quad lit, _in
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
	.quad lit, _in
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
	.quad lit, _out
	.quad bstore
	.quad ret

flush: /* -- */
	.quad lit, stdout
	.quad lit, _out
	.quad call, string
	.quad lit, sys_write
	.quad syscall
	.quad drop
	.quad jump, empty

emit: /* char -- */
	.quad lit, _out
	.quad call, string
	.quad add
	.quad bstore
	.quad lit, _out
	.quad bfetch
	.quad inc
	.quad lit, _out
	.quad bstore
	.quad lit, _out
	.quad bfetch
	.quad lit, line-1
	.quad xor

	.quad zjump, flush

	.quad ret

type: /* addr u -- */
	.quad call, qdup

	.quad zjump, 0f

	.quad push
	.quad dup
	.quad bfetch
	.quad call, emit
	.quad inc
	.quad pop
	.quad dec

	.quad jump, type
0:

	.quad drop
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

bmove: /* addr1 addr2 u -- */
	.quad call, qdup

	.quad zjump, 0f

	.quad push
	.quad over, bfetch
	.quad over, bstore
	.quad push
	.quad inc
	.quad pop
	.quad inc
	.quad pop
	.quad dec

	.quad jump, bmove

0:
	.quad nip
	.quad drop
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
	.quad lit, _out
	.quad bfetch
	.quad call, equals

	.quad zjump, 1f

	.quad lit, cell*2+1
	.quad add
	.quad lit, _out
	.quad call, string
	.quad call, sameq

1:
	.quad call, zequals

	.quad zjump, 0b

	.quad ret

comma: /* x -- */
	.quad call, top
	.quad fetch
	.quad dup
	.quad lit, cell
	.quad add
	.quad call, top
	.quad store
	.quad store
	.quad ret

link: /* x -- */
	.quad call, head
	.quad fetch
	.quad lit, cell
	.quad sub
	.quad dup
	.quad call, head
	.quad store
	.quad store
	.quad ret

apply: /* -- */
	.quad call, state
	.quad fetch

	.quad zjump, 0f

	.quad call, top
	.quad fetch
	.quad call, here
	.quad store
	.quad ret

0:
	.quad lit, ret
	.quad call, comma
	.quad call, empty
	.quad call, here
	.quad fetch
	.quad exec
	.quad call, flush
	.quad call, here
	.quad fetch
	.quad call, top
	.quad store
	.quad ret

interpret: /* -- */
	.quad call, word
	.quad lit, _out
	.quad bfetch

	.quad zjump, apply

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
	.quad call, comma

0:
	.quad call, comma
	.quad jump, interpret

1:
	.quad lit, 0
	.quad lit, _out
	.quad call, string
	.quad call, number
	.quad nip

	.quad zjump, 0f

	.quad drop
	.quad lit, '?'
	.quad call, emit
	.quad jump, flush

0:
	.quad lit, lit
	.quad call, comma
	.quad call, comma
	.quad jump, interpret

start: /* -- */
	.quad lit, prompt
	.quad call, string
	.quad call, type
	.quad call, flush
	.quad call, accept
	.quad call, interpret
	.quad jump, start

colon: /* -- */
	.quad call, apply

	.quad lit, -1
	.quad call, state
	.quad store

	.quad call, word
	.quad lit, _out
	.quad call, head
	.quad fetch
	.quad over
	.quad bfetch
	.quad inc
	.quad dup
	.quad push
	.quad call, align
	.quad sub
	.quad dup
	.quad call, head
	.quad store
	.quad pop
	.quad call, bmove

	.quad call, here
	.quad fetch
	.quad call, link
	.quad call, last
	.quad fetch
	.quad call, link

	.quad call, head
	.quad fetch
	.quad call, last
	.quad store
	.quad ret

semicolon: /* -- */
	.quad lit, ret
	.quad call, comma
	.quad call, top
	.quad fetch
	.quad call, here
	.quad store
	.quad lit, 0
	.quad call, state
	.quad store
	.quad ret

define head_syscall,   in,        "in"
define head_in,        out,       "out"
define head_out,       code,      "code"
define head_code,      vocab,     "vocab"
define head_vocab,     curr,      "curr"
define head_curr,      state,     "state"
define head_state,     here,      "here"
define head_here,      top,       "top"
define head_top,       head,      "head"
define head_head,      last,      "last"
define head_last,      base,      "base"
define head_base,      qdup,      "?dup"
define head_qdup,      less,      "<"
define head_less,      uless,     "u<"
define head_uless,     zless,     "0<"
define head_zless,     bool,      "bool"
define head_bool,      equals,    "="
define head_equals,    zequals,   "0="
define head_zequals,   within,    "within"
define head_within,    align,     "align"
define head_align,     string,    "string"
define head_string,    reset,     "reset"
define head_reset,     accept,    "accept"
define head_accept,    keyq,      "key?"
define head_keyq,      key,       "key"
define head_key,       empty,     "empty"
define head_empty,     flush,     "flush"
define head_flush,     emit,      "emit"
define head_emit,      type,      "type"
define head_type,      word,      "word"
define head_word,      digitq,    "digit?"
define head_digitq,    natural,   "natural"
define head_natural,   number,    "number"
define head_number,    bmove,     "bmove"
define head_bmove,     sameq,     "same?"
define head_sameq,     find,      "find"
define head_find,      comma,     ","
define head_comma,     link,      "link"
define head_link,      apply,     "apply",    imm
define head_apply,     interpret, "interpret"
define head_interpret, start,     "start"
define head_start,     colon,     ":",        imm
define head_colon,     semicolon, ";",        imm

/* The following definitions should be moved out of core
   once we can compile them at runtime. */

begin: /* c: -- addr */
	.quad call, top
	.quad fetch
	.quad ret

if: /* x -- */ /* c: -- addr */
	.quad lit, zjump
	.quad call, comma
	.quad call, top
	.quad fetch
	.quad lit, 0
	.quad jump, comma

then: /* c: addr -- */
	.quad push
	.quad call, top
	.quad fetch
	.quad pop
	.quad store
	.quad ret

again: /* c: addr1 addr2 -- */
	.quad push
	.quad lit, jump
	.quad call, comma
	.quad call, comma
	.quad call, top
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

_in:
	.skip line

_out:
	.skip line

_code:
	.skip page
_vocab:

	.skip page
dstack:
