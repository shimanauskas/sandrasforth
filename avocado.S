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

#define immediate 0x80

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

.macro define previous, body, name, mask=0
head_\body:
	.quad \previous
	.quad \body
	.byte (1f-0f)+\mask
0:
	.ascii "\name"
1:
.balign cell
.endm

.text

.global _start

_start:
	leaq dstack(%rip), %rbp
	movq $-1, %rax
	leaq main(%rip), %rbx
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

mul: /* n1|u1 n2|u2 -- n3|u3 */
	movq (%rbp), %rcx
	imulq %rcx
	nip
	next

divmod: /* n1 n2 -- n3 n4 */
	movq %rax, %rcx
	movq (%rbp), %rax
	cqo
	idivq %rcx
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

_end:

.data

define 0,           call,    "call"
define head_call,   jump,    "jump"
define head_jump,   zjump,   "0jump"
define head_zjump,  exec,    "exec"
define head_exec,   ret,     "ret"
define head_ret,    lit,     "lit"
define head_lit,    var,     "var"
define head_var,    dup,     "dup"
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
define head_mul,    divmod,  "/mod"
define head_divmod, fetch,   "@"
define head_fetch,  store,   "!"
define head_store,  bfetch,  "b@"
define head_bfetch, bstore,  "b!"
define head_bstore, syscall, "syscall"

_cell: /* -- u */
	.quad lit, cell
	.quad ret

mark: /* -- addr */
	.quad var, input+1
	.quad ret

state: /* -- addr */
	.quad var, 0
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
	.quad lit, 1<<(cell*8-1)
	.quad and

	/* Fallthrough! */

bool: /* x -- bool */
	.quad zjump, 0f

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

	.quad zjump, 0f

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

	.quad zjump, 0f

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

accept: /* -- */
	.quad lit, stdin
	.quad lit, input+1
	.quad lit, 0xFF-1
	.quad lit, sys_read
	.quad syscall
	.quad dup

	.quad zjump, 0f

	.quad lit, input
	.quad bstore
	.quad lit, input+1
	.quad call, mark
	.quad store
	.quad ret

0:
	.quad dup
	.quad dup
	.quad lit, sys_exit
	.quad syscall

keyq: /* -- bool */
	.quad call, mark
	.quad fetch
	.quad lit, input
	.quad call, string
	.quad add
	.quad call, uless
	.quad ret

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
	.quad lit, stdout
	.quad lit, output
	.quad call, string
	.quad lit, sys_write
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

	.quad zjump, flush

	.quad ret

type: /* addr u -- */
	.quad dup

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
	.quad drop
	.quad ret

skip: /* -- */
	.quad call, keyq
	.quad call, key
	.quad lit, '!'
	.quad call, uless
	.quad and

	.quad zjump, 0f

	.quad call, advance

	.quad jump, skip
0:

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
	.quad not

	.quad zjump, 0f

	.quad call, apply
	.quad call, accept
	.quad jump, word

0:
	.quad lit, 0
	.quad lit, buffer
	.quad bstore

0:
	.quad call, keyq
	.quad not

	.quad zjump, 1f

	.quad call, accept

1:
	.quad call, key
	.quad dup
	.quad lit, '!'
	.quad call, uless
	.quad not
	.quad lit, buffer
	.quad bfetch
	.quad lit, 0x7F
	.quad call, uless
	.quad and

	.quad zjump, 0f

	.quad lit, buffer
	.quad call, string
	.quad dup
	.quad inc
	.quad lit, buffer
	.quad bstore
	.quad add
	.quad bstore
	.quad call, advance

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

	.quad zjump, 0f

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

	.quad zjump, natural

	.quad dec
	.quad push
	.quad inc
	.quad pop
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
	.quad nip
	.quad nip
	.quad ret

find: /* -- 0 | addr */
	.quad call, last

0:
	.quad fetch
	.quad dup
	.quad dup

	.quad zjump, 1f

	.quad dup
	.quad lit, cell*2
	.quad add
	.quad bfetch
	.quad lit, ~immediate
	.quad and
	.quad lit, buffer
	.quad bfetch
	.quad call, equals

	.quad zjump, 1f

	.quad lit, cell*2+1
	.quad add
	.quad lit, buffer
	.quad call, string
	.quad call, sameq

1:
	.quad call, zequals

	.quad zjump, 0b

	.quad ret

bmove: /* addr1 addr2 u -- */
	.quad dup

	.quad zjump, 0f

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
	.quad lit, cell
	.quad sub
	.quad dup
	.quad call, head
	.quad store
	.quad store
	.quad ret

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
	.quad lit, -1
	.quad call, state
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

tick: /* -- 0 | xt */
	.quad call, word
	.quad call, find
	.quad dup

	.quad zjump, 0f

	.quad lit, cell
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
	.quad call, comma
	.quad ret

main: /* -- */
	.quad call, word
	.quad call, find
	.quad dup

	.quad zjump, 1f

	.quad lit, cell
	.quad add
	.quad dup
	.quad lit, cell
	.quad add
	.quad bfetch
	.quad lit, immediate
	.quad and

	.quad zjump, 0f

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

	.quad zjump, 0f

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
	.quad call, zequals

	.quad zjump, 0f

	.quad call, literal
	.quad jump, main

0:
	.quad drop
	.quad lit, buffer
	.quad call, string
	.quad call, type
	.quad lit, '?'
	.quad call, emit
	.quad call, flush
	.quad call, accept
	.quad jump, main

define head_syscall,   _cell,     "cell"
define head__cell,     input,     "input"
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
define head_string,    accept,    "accept"
define head_accept,    keyq,      "key?"
define head_keyq,      key,       "key"
define head_key,       advance,   "advance"
define head_advance,   flush,     "flush"
define head_flush,     emit,      "emit"
define head_emit,      type,      "type"
define head_type,      skip,      "skip"
define head_skip,      comma,     ",",        immediate
define head_comma,     apply,     "apply",    immediate
define head_apply,     word,      "word"
define head_word,      digitq,    "digit?"
define head_digitq,    natural,   "natural"
define head_natural,   number,    "number"
define head_number,    sameq,     "same?"
define head_sameq,     find,      "find"
define head_find,      bmove,     "bmove"
define head_bmove,     link,      "link",     immediate
define head_link,      colon,     ":",        immediate
define head_colon,     semicolon, ";",        immediate
define head_semicolon, tick,      "'",        immediate
define head_tick,      postpone,  "postpone", immediate
define head_postpone,  literal,   "literal",  immediate
define head_literal,   main,      "main"

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

	.skip 0x1000
dstack:
