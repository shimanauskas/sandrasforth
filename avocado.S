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
	#define SYS_READ  0
	#define SYS_WRITE 1
	#define SYS_EXIT  60
#elif __APPLE__
	#include "TargetConditionals.h"
	#ifdef TARGET_OS_MAC
		#define SYS_READ  0x2000003
		#define SYS_WRITE 0x2000004
		#define SYS_EXIT  0x2000001
	#endif
#elif
	#error "Unsupported platform."
#endif

#define STDIN  0
#define STDOUT 1

#define CELL 8

#define LENGTH    0x7F
#define IMMEDIATE 0x80

.macro dup /* x -- x x */
	leaq -CELL(%rbp), %rbp
	movq %rax, (%rbp)
.endm

.macro nip /* x1 x2 -- x2 */
	leaq CELL(%rbp), %rbp
.endm

.macro twonip /* x1 x2 x3-- x3 */
	leaq CELL*2(%rbp), %rbp
.endm

.macro drop /* x -- */
	movq (%rbp), %rax
	nip
.endm

.macro twodrop /* x1 x2 -- */
	movq CELL(%rbp), %rax
	twonip
.endm

.macro next /* -- */
	addq $(CELL), %rbx
	jmp *(%rbx)
.endm

.macro define previous, body, name, mask=0
head_\body:
	.quad \previous
	.quad \body
	.byte (1f-0f)|\mask
0:
	.ascii "\name"
1:
.balign CELL
.endm

.text

.global _start

_start:
	leaq dstack(%rip), %rbp
	movq $-1, %rax
	leaq main(%rip), %rbx
	jmpq *(%rbx)

call: /* r: -- addr */
	addq $(CELL), %rbx
	pushq %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

jump: /* -- */
	addq $(CELL), %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

qjump: /* x -- */
	testq %rax, %rax
	drop
	leaq CELL*2(%rbx), %rbx
	cmovzq -CELL(%rbx), %rbx
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
	addq $(CELL), %rbx
	movq (%rbx), %rax
	next

var: /* -- addr */
	dup
	addq $(CELL), %rbx
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
	movq CELL(%rbp), %rax
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

mul: /* n1|u1 n2|u2 -- n3|u3 */
	movq (%rbp), %rcx
	imulq %rcx
	nip
	next

udivmod: /* n1 n2 -- n3 n4 */
	movq %rax, %rcx
	movq (%rbp), %rax
	xorq %rdx, %rdx
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
	movq CELL(%rbp), %rsi
	movq CELL*2(%rbp), %rdi
	leaq CELL*3(%rbp), %rbp
	syscall
	next

_end:

.data

define 0,            call,    "call"
define head_call,    jump,    "jump"
define head_jump,    qjump,   "?jump"
define head_qjump,   exec,    "exec"
define head_exec,    ret,     "ret"
define head_ret,     lit,     "lit"
define head_lit,     var,     "var"
define head_var,     dup,     "dup"
define head_dup,     nip,     "nip"
define head_nip,     drop,    "drop"
define head_drop,    over,    "over"
define head_over,    push,    "push"
define head_push,    pop,     "pop"
define head_pop,     not,     "not"
define head_not,     and,     "and"
define head_and,     or,      "or"
define head_or,      xor,     "xor"
define head_xor,     inc,     "1+"
define head_inc,     dec,     "1-"
define head_dec,     neg,     "neg"
define head_neg,     sub,     "-"
define head_sub,     add,     "+"
define head_add,     mul,     "*"
define head_mul,     udivmod, "u/mod"
define head_udivmod, fetch,   "@"
define head_fetch,   store,   "!"
define head_store,   bfetch,  "b@"
define head_bfetch,  bstore,  "b!"
define head_bstore,  syscall, "syscall"

cell: /* -- u */
	.quad lit, CELL
	.quad ret

mark: /* -- addr */
	.quad var, input+1
	.quad ret

state: /* -- addr */
	.quad var, -1
	.quad ret

here: /* -- addr */
	.quad var, code
	.quad ret

top: /* -- addr */
	.quad var, code
	.quad ret

head: /* -- addr */
	.quad var, vocab
	.quad ret

last: /* -- addr */
	.quad var, head_main
	.quad ret

base: /* -- addr */
	.quad var, 10
	.quad ret

zless: /* n - bool */
	.quad lit, 1<<(CELL*8-1)
	.quad and

	/* Fallthrough! */

bool: /* x -- bool */
	.quad qjump, 0f

	.quad lit, -1
	.quad ret

0:
	.quad lit, 0
	.quad ret

less: /* n1 n2 -- bool */
	.quad over
	.quad over
	.quad xor
	.quad call, zless

	.quad qjump, 0f

	.quad drop
	.quad jump, zless

0:
	.quad sub
	.quad jump, zless

uless: /* u1 u2 -- bool */
	.quad over
	.quad over
	.quad xor
	.quad call, zless

	.quad qjump, 0f

	.quad nip
	.quad jump, zless

0:
	.quad sub
	.quad jump, zless

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
	.quad pop
	.quad pop
	.quad call, uless
	.quad and
	.quad ret

align: /* x1 -- x2 */
	.quad lit, CELL-1
	.quad add
	.quad lit, ~(CELL-1)
	.quad and
	.quad ret

string: /* addr1 -- addr2 u */
	.quad dup
	.quad push
	.quad inc
	.quad pop
	.quad bfetch
	.quad ret

bye: /* n -- */
	.quad lit, 0
	.quad dup
	.quad lit, SYS_EXIT
	.quad syscall

accept: /* -- */
	.quad lit, STDIN
	.quad lit, input+1
	.quad lit, 0xFF
	.quad lit, SYS_READ
	.quad syscall
	.quad dup

	.quad qjump, bye

	.quad lit, input
	.quad bstore
	.quad lit, input+1
	.quad call, mark
	.quad store
	.quad ret

keyq: /* -- bool */
	.quad call, mark
	.quad fetch
	.quad lit, input
	.quad call, string
	.quad add
	.quad jump, uless

key: /* -- char */
	.quad call, mark
	.quad fetch
	.quad bfetch
	.quad ret

advance: /* -- */
	.quad call, mark
	.quad fetch
	.quad inc
	.quad call, mark
	.quad store
	.quad ret

flush: /* -- */
	.quad lit, STDOUT
	.quad lit, output
	.quad call, string
	.quad lit, SYS_WRITE
	.quad syscall
	.quad drop
	.quad lit, 0
	.quad lit, output
	.quad bstore
	.quad ret

emit: /* char -- */
	.quad lit, output
	.quad call, string
	.quad add
	.quad bstore
	.quad lit, output
	.quad bfetch
	.quad inc
	.quad dup
	.quad lit, output
	.quad bstore
	.quad lit, 0xFF
	.quad xor

	.quad qjump, flush

	.quad ret

type: /* addr u -- */
	.quad dup

	.quad qjump, 0f

	.quad push
	.quad dup
	.quad bfetch
	.quad call, emit
	.quad inc
	.quad pop
	.quad dec

	.quad jump, type
0:

	.quad nip
	.quad drop
	.quad ret

skip: /* -- */
	.quad call, keyq
	.quad call, key
	.quad lit, '!'
	.quad call, uless
	.quad and

	.quad qjump, 0f

	.quad call, advance

	.quad jump, skip
0:

	.quad ret

collision: /* -- */
	.quad call, top
	.quad fetch
	.quad call, head
	.quad fetch
	.quad call, uless
	.quad not

	.quad qjump, 0f

	.quad lit, head_collision+CELL*2
	.quad call, string
	.quad call, type
	.quad lit, '!'
	.quad call, emit
	.quad call, flush
	.quad lit, 1
	.quad jump, bye

0:
	.quad ret

comma: /* x -- */
	.quad call, top
	.quad fetch
	.quad dup
	.quad lit, CELL
	.quad add
	.quad call, top
	.quad store
	.quad store
	.quad jump, collision

commit: /* -- */
	.quad call, top
	.quad fetch
	.quad call, here
	.quad store
	.quad ret

apply: /* -- */
	.quad call, state
	.quad fetch

	.quad qjump, commit

	.quad lit, ret
	.quad call, comma
	.quad call, here
	.quad fetch
	.quad exec
	.quad call, flush
	.quad call, here
	.quad fetch
	.quad call, top
	.quad store
	.quad ret

word: /* -- */
	.quad call, skip
	.quad call, keyq

	.quad qjump, 1f

	.quad lit, 0
	.quad lit, buffer
	.quad bstore

0:
	.quad call, key
	.quad dup
	.quad lit, '!'
	.quad call, uless
	.quad not
	.quad lit, buffer
	.quad bfetch
	.quad lit, LENGTH
	.quad call, uless
	.quad and

	.quad qjump, 0f

	.quad lit, buffer
	.quad call, string
	.quad dup
	.quad inc
	.quad lit, buffer
	.quad bstore
	.quad add
	.quad bstore
	.quad call, advance
	.quad call, keyq
	.quad not

	.quad qjump, 0b

	.quad call, accept

	.quad jump, 0b
0:

	.quad drop
	.quad ret

1:
	.quad call, apply
	.quad call, accept
	.quad jump, word

digitq: /* char base -- u bool */
	.quad push
	.quad lit, '0'
	.quad sub
	.quad lit, 9
	.quad over
	.quad call, less

	.quad qjump, 0f

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

natural: /* addr u1 -- u2 u3 */
	.quad push
	.quad lit, 0
	.quad pop

0:
	.quad push
	.quad over
	.quad bfetch
	.quad call, base
	.quad fetch
	.quad call, digitq
	.quad pop
	.quad dup
	.quad push
	.quad and

	.quad qjump, 0f

	.quad push
	.quad call, base
	.quad fetch
	.quad mul
	.quad pop
	.quad add
	.quad push
	.quad inc
	.quad pop
	.quad pop
	.quad dec

	.quad jump, 0b
0:

	.quad drop
	.quad nip
	.quad pop
	.quad ret

number: /* addr u1 -- n u2 */
	.quad over
	.quad bfetch
	.quad lit, '-'
	.quad call, equals

	.quad qjump, natural

	.quad push
	.quad inc
	.quad pop
	.quad dec
	.quad call, natural
	.quad push
	.quad neg
	.quad pop
	.quad ret

sameq: /* addr1 addr2 u1 -- u2 */
	.quad dup
	.quad push
	.quad push
	.quad over
	.quad bfetch
	.quad over
	.quad bfetch
	.quad call, equals
	.quad pop
	.quad and

	.quad qjump, 0f

	.quad push
	.quad inc
	.quad pop
	.quad inc
	.quad pop
	.quad dec

	.quad jump, sameq
0:

	.quad pop
	.quad nip
	.quad nip
	.quad jump, bool

find: /* -- 0 | addr */
	.quad call, last

0:
	.quad fetch
	.quad dup
	.quad dup

	.quad qjump, 1f

	.quad dup
	.quad lit, CELL*2
	.quad add
	.quad bfetch
	.quad lit, LENGTH
	.quad and
	.quad lit, buffer
	.quad bfetch
	.quad call, equals

	.quad qjump, 1f

	.quad lit, CELL*2+1
	.quad add
	.quad lit, buffer
	.quad call, string
	.quad call, sameq

1:
	.quad call, zequals

	.quad qjump, 0b

	.quad ret

bmove: /* addr1 addr2 u -- */
	.quad dup

	.quad qjump, 0f

	.quad push
	.quad over
	.quad bfetch
	.quad over
	.quad bstore
	.quad push
	.quad inc
	.quad pop
	.quad inc
	.quad pop
	.quad dec

	.quad jump, bmove
0:

	.quad nip
	.quad nip
	.quad drop
	.quad ret

link: /* x -- */
	.quad call, head
	.quad fetch
	.quad lit, CELL
	.quad sub
	.quad dup
	.quad call, head
	.quad store
	.quad store
	.quad jump, collision

tail: /* -- */
	.quad lit, jump
	.quad call, top
	.quad fetch
	.quad lit, CELL*2
	.quad sub
	.quad dup
	.quad fetch
	.quad lit, call
	.quad call, equals

	.quad qjump, 0f

	.quad store
	.quad ret

0:
	.quad nip
	.quad drop
	.quad lit, ret
	.quad jump, comma

colon: /* -- */
	.quad call, apply
	.quad call, word
	.quad lit, buffer
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
	.quad call, collision
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
	.quad lit, 0
	.quad call, state
	.quad store
	.quad ret

semicolon: /* -- */
	.quad call, tail
	.quad lit, -1
	.quad call, state
	.quad store
	.quad jump, commit

tick: /* -- 0 | xt */
	.quad call, word
	.quad call, find
	.quad dup

	.quad qjump, 0f

	.quad lit, CELL
	.quad add
	.quad fetch

0:
	.quad ret

postpone: /* -- */
	.quad call, tick
	.quad lit, call
	.quad call, comma
	.quad jump, comma

literal: /* x -- */
	.quad lit, lit
	.quad call, comma
	.quad jump, comma

immediate: /* -- */
	.quad call, last
	.quad fetch
	.quad lit, CELL*2
	.quad add
	.quad dup
	.quad bfetch
	.quad lit, IMMEDIATE
	.quad or
	.quad over
	.quad bstore
	.quad drop
	.quad ret

main: /* -- */
	.quad call, word
	.quad call, find
	.quad dup

	.quad qjump, 1f

	.quad lit, CELL
	.quad add
	.quad dup
	.quad lit, CELL
	.quad add
	.quad bfetch
	.quad lit, IMMEDIATE
	.quad and

	.quad qjump, 0f

	.quad fetch
	.quad exec
	.quad jump, main

0:
	.quad fetch
	.quad dup
	.quad lit, _start
	.quad lit, _end
	.quad call, within
	.quad not

	.quad qjump, 0f

	.quad lit, call
	.quad call, comma

0:
	.quad call, comma
	.quad jump, main

1:
	.quad drop
	.quad lit, buffer
	.quad call, string
	.quad call, number

	.quad qjump, 0f

	.quad drop
	.quad lit, buffer
	.quad call, string
	.quad call, type
	.quad lit, '?'
	.quad call, emit
	.quad call, flush
	.quad call, accept
	.quad jump, main

0:
	.quad call, literal
	.quad jump, main

define head_syscall,   cell,      "cell"

define head_cell,      input,     "input"
define head_input,     output,    "output"
define head_output,    buffer,    "buffer"
define head_buffer,    code,      "code"
define head_code,      vocab,     "vocab"

define head_vocab,     mark,      "mark"
define head_mark,      state,     "state"
define head_state,     here,      "here"
define head_here,      top,       "top"
define head_top,       head,      "head"
define head_head,      last,      "last"
define head_last,      base,      "base"

define head_base,      zless,     "0<"
define head_zless,     bool,      "bool"
define head_bool,      less,      "<"
define head_less,      uless,     "u<"
define head_uless,     equals,    "="
define head_equals,    zequals,   "0="
define head_zequals,   within,    "within"
define head_within,    align,     "align"
define head_align,     string,    "string"
define head_string,    bye,       "bye"
define head_bye,       accept,    "accept"
define head_accept,    keyq,      "key?"
define head_keyq,      key,       "key"
define head_key,       advance,   "advance"
define head_advance,   flush,     "flush"
define head_flush,     emit,      "emit"
define head_emit,      type,      "type"
define head_type,      skip,      "skip"
define head_skip,      collision, "collision"
define head_collision, comma,     ",",         IMMEDIATE
define head_comma,     commit,    "commit",    IMMEDIATE
define head_commit,    apply,     "apply",     IMMEDIATE
define head_apply,     word,      "word"
define head_word,      digitq,    "digit?"
define head_digitq,    natural,   "natural"
define head_natural,   number,    "number"
define head_number,    sameq,     "same?"
define head_sameq,     find,      "find"
define head_find,      bmove,     "bmove"
define head_bmove,     link,      "link",      IMMEDIATE
define head_link,      tail,      "tail",      IMMEDIATE
define head_tail,      colon,     ":",         IMMEDIATE
define head_colon,     semicolon, ";",         IMMEDIATE
define head_semicolon, tick,      "'",         IMMEDIATE
define head_tick,      postpone,  "postpone",  IMMEDIATE
define head_postpone,  literal,   "literal",   IMMEDIATE
define head_literal,   immediate, "immediate", IMMEDIATE
define head_immediate, main,      "main"

.bss

input:
	.skip 0x100

output:
	.skip 0x100

buffer:
	.skip 0x100

code:
	.skip 0x1000
vocab:

	.skip 0x100
dstack:
