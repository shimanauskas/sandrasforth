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
	#define START     _start
	#define SYS_read  0
	#define SYS_write 1
	#define SYS_exit  60
#elif __APPLE__
	#define START      start
	#define SYS_read  0x2000003
	#define SYS_write 0x2000004
	#define SYS_exit  0x2000001
#else
	#error Unsupported platform.
#endif

#define CELL 8
#define NFA  CELL*2

#define IMMEDIATE 0x80

.macro DUP /* x -- x x */
	leaq -CELL(%rbp), %rbp
	movq %rax, (%rbp)
.endm

.macro NIP /* x1 x2 -- x2 */
	leaq CELL(%rbp), %rbp
.endm

.macro TWONIP /* x1 x2 x3-- x3 */
	leaq CELL*2(%rbp), %rbp
.endm

.macro DROP /* x -- */
	movq (%rbp), %rax
	NIP
.endm

.macro TWODROP /* x1 x2 -- */
	movq CELL(%rbp), %rax
	TWONIP
.endm

.macro NEXT
	addq $(CELL), %rbx
	jmp *(%rbx)
.endm

.macro DEFINE previous, body, name, mask=0
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

.global START

START:
	leaq dstack(%rip), %rbp
	movq $-1, %rax
	leaq main(%rip), %rbx
	jmpq *(%rbx)

call:
	addq $(CELL), %rbx
	pushq %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

jump:
	addq $(CELL), %rbx
	movq (%rbx), %rbx
	jmpq *(%rbx)

qjump: /* x -- */
	testq %rax, %rax
	DROP
	leaq CELL*2(%rbx), %rbx
	cmovzq -CELL(%rbx), %rbx
	jmpq *(%rbx)

execute: /* addr -- */
	pushq %rbx
	movq %rax, %rbx
	DROP
	jmpq *(%rbx)

ret:
	popq %rbx
	NEXT

lit: /* -- x */
	DUP
	addq $(CELL), %rbx
	movq (%rbx), %rax
	NEXT

var: /* -- addr */
	DUP
	addq $(CELL), %rbx
	movq %rbx, %rax
	NEXT

dup: /* x -- x x */
	DUP
	NEXT

nip: /* x1 x2 -- x2 */
	NIP
	NEXT

drop: /* x -- */
	DROP
	NEXT

over: /* x1 x2 -- x1 x2 x1 */
	DUP
	movq CELL(%rbp), %rax
	NEXT

push: /* x -- */
	pushq %rax
	DROP
	NEXT

pop: /* -- x */
	DUP
	popq %rax
	NEXT

invert: /* x1 -- x2 */
	notq %rax
	NEXT

twomul: /* x1 -- x2 */
	shlq %rax
	NEXT

twodiv: /* x1 -- x2 */
	shrq %rax
	NEXT

and: /* x1 x2 -- x3 */
	andq (%rbp), %rax
	NIP
	NEXT

or: /* x1 x2 -- x3 */
	orq (%rbp), %rax
	NIP
	NEXT

xor: /* x1 x2 -- x3 */
	xorq (%rbp), %rax
	NIP
	NEXT

negate: /* n1 -- n2 */
	negq %rax
	NEXT

inc: /* n1 -- n2 */
	incq %rax
	NEXT

dec: /* n1 -- n2 */
	decq %rax
	NEXT

add: /* n1|u1 n2|u2 -- n3|u3 */
	addq %rax, (%rbp)
	DROP
	NEXT

sub: /* n1|u1 n2|u2 -- n3|u3 */
	subq %rax, (%rbp)
	DROP
	NEXT

mul: /* n1 n2 -- n3 */
	movq %rax, %rcx
	DROP
	imulq %rcx
	NEXT

ummul: /* u1 u2 -- ud */
	movq %rax, %rcx
	DROP
	mulq %rcx
	DUP
	movq %rdx, %rax
	NEXT

umdivmod: /* ud u1 -- u2 u3 */
	movq %rax, %rcx
	movq (%rbp), %rdx
	NIP
	movq (%rbp), %rax
	divq %rcx
	movq %rdx, (%rbp)
	NEXT

fetch: /* addr -- x */
	movq (%rax), %rax
	NEXT

store: /* x addr -- */
	movq (%rbp), %rdx
	movq %rdx, (%rax)
	TWODROP
	NEXT

bfetch: /* addr -- byte */
	movzbq (%rax), %rax
	NEXT

bstore: /* byte addr -- */
	movb (%rbp), %dl
	movb %dl, (%rax)
	TWODROP
	NEXT

syscall: /* x1 x2 x3 x4 -- x5 */
	movq (%rbp), %rdx
	movq CELL(%rbp), %rsi
	movq CELL*2(%rbp), %rdi
	leaq CELL*3(%rbp), %rbp
	syscall
	NEXT

end:

.data

DEFINE 0,             call,     "call"
DEFINE head_call,     jump,     "jump"
DEFINE head_jump,     qjump,    "?jump"
DEFINE head_qjump,    execute,  "execute"
DEFINE head_execute,  ret,      "ret"
DEFINE head_ret,      lit,      "lit"
DEFINE head_lit,      var,      "var"
DEFINE head_var,      dup,      "dup"
DEFINE head_dup,      nip,      "nip"
DEFINE head_nip,      drop,     "drop"
DEFINE head_drop,     over,     "over"
DEFINE head_over,     push,     "push"
DEFINE head_push,     pop,      "pop"
DEFINE head_pop,      invert,   "invert"
DEFINE head_invert,   twomul,   "2*"
DEFINE head_twomul,   twodiv,   "2/"
DEFINE head_twodiv,   and,      "and"
DEFINE head_and,      or,       "or"
DEFINE head_or,       xor,      "xor"
DEFINE head_xor,      negate,   "negate"
DEFINE head_negate,   inc,      "1+"
DEFINE head_inc,      dec,      "1-"
DEFINE head_dec,      add,      "+"
DEFINE head_add,      sub,      "-"
DEFINE head_sub,      mul,      "*"
DEFINE head_mul,      ummul,    "um*"
DEFINE head_ummul,    umdivmod, "um/mod"
DEFINE head_umdivmod, fetch,    "@"
DEFINE head_fetch,    store,    "!"
DEFINE head_store,    bfetch,   "b@"
DEFINE head_bfetch,   bstore,   "b!"
DEFINE head_bstore,   syscall,  "syscall"

DEFINE head_syscall, cell, "cell"
cell: /* -- u */
	.quad lit, CELL
	.quad ret

DEFINE head_cell, nfa, "nfa"
nfa: /* -- u */
	.quad lit, NFA
	.quad ret

DEFINE head_nfa, sys_read, "sys-read"
sys_read: /* -- x */
	.quad lit, SYS_read
	.quad ret

DEFINE head_sys_read, sys_write, "sys-write"
sys_write: /* -- x */
	.quad lit, SYS_write
	.quad ret

DEFINE head_sys_write, sys_exit, "sys-exit"
sys_exit: /* -- x */
	.quad lit, SYS_exit
	.quad ret

DEFINE head_sys_exit, code_start, "code-start"
code_start: /* -- addr */
	.quad lit, START
	.quad ret

DEFINE head_code_start, code_end, "code-end"
code_end: /* -- addr */
	.quad lit, end
	.quad ret

DEFINE head_code_end, tickinput, "'input"
tickinput: /* -- addr */
	.quad lit, input
	.quad ret

DEFINE head_tickinput, tickoutput, "'output"
tickoutput: /* -- addr */
	.quad lit, output
	.quad ret

DEFINE head_tickoutput, tickbuffer, "'buffer"
tickbuffer: /* -- addr */
	.quad lit, buffer
	.quad ret

DEFINE head_tickbuffer, tickguard, "'guard"
tickguard: /* -- addr */
	.quad lit, guard
	.quad ret

DEFINE head_tickguard, mark, "mark"
mark: /* -- addr */
	.quad var, input+1
	.quad ret

DEFINE head_mark, state, "state"
state: /* -- addr */
	.quad var, 0
	.quad ret

DEFINE head_state, here, "here"
here: /* -- addr */
	.quad var, vocabulary
	.quad ret

DEFINE head_here, top, "top"
top: /* -- addr */
	.quad var, vocabulary
	.quad ret

DEFINE head_top, latest, "latest"
latest: /* -- addr */
	.quad var, head_main
	.quad ret

DEFINE head_latest, base, "base"
base: /* -- addr */
	.quad var, 10
	.quad ret

DEFINE head_base, bool, "bool"
bool: /* x -- bool */
	.quad qjump, 0f

	.quad lit, -1
	.quad ret

0:
	.quad lit, 0
	.quad ret

DEFINE head_bool, zequals, "0="
zequals: /* x -- bool */
	.quad call, bool
	.quad invert
	.quad ret

DEFINE head_zequals, equals, "="
equals: /* x1 x2 -- bool */
	.quad xor
	.quad call, zequals
	.quad ret

DEFINE head_equals, zless, "0<"
zless: /* n - bool */
	.quad lit, 1<<(CELL*8-1)
	.quad and
	.quad call, bool
	.quad ret

DEFINE head_zless, less, "<"
less: /* n1 n2 -- bool */
	.quad over
	.quad over
	.quad xor
	.quad call, zless

	.quad qjump, 0f

	.quad drop
	.quad call, zless
	.quad ret

0:
	.quad sub
	.quad call, zless
	.quad ret

DEFINE head_less, uless, "u<"
uless: /* u1 u2 -- bool */
	.quad over
	.quad over
	.quad xor
	.quad call, zless

	.quad qjump, 0f

	.quad nip
	.quad call, zless
	.quad ret

0:
	.quad sub
	.quad call, zless
	.quad ret

DEFINE head_uless, within, "within"
within: /* u1 u2 u3 -- bool */
	.quad push
	.quad over
	.quad push
	.quad call, uless
	.quad invert
	.quad pop
	.quad pop
	.quad call, uless
	.quad and
	.quad ret

DEFINE head_within, aligned, "aligned"
aligned: /* x1 -- x2 */
	.quad lit, CELL-1
	.quad add
	.quad lit, ~(CELL-1)
	.quad and
	.quad ret

DEFINE head_aligned, string, "string"
string: /* addr1 -- addr2 u */
	.quad dup
	.quad push
	.quad inc
	.quad pop
	.quad bfetch
	.quad ret

DEFINE head_string, bmove, "bmove"
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

DEFINE head_bmove, sameq, "same?"
sameq: /* addr1 addr2 u -- bool */
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
	.quad call, zequals
	.quad ret

DEFINE head_sameq, write, "write"
write:
	.quad lit, 1
	.quad lit, output
	.quad call, string
	.quad lit, SYS_write
	.quad syscall
	.quad drop
	.quad lit, 0
	.quad lit, output
	.quad bstore
	.quad ret

DEFINE head_write, bye, "bye"
bye:
	.quad call, write
	.quad lit, 0
	.quad dup
	.quad dup
	.quad lit, SYS_exit
	.quad syscall

DEFINE head_bye, read, "read"
read:
	.quad lit, 0
	.quad lit, input+1
	.quad lit, 0xFF
	.quad lit, SYS_read
	.quad syscall
	.quad dup

	.quad qjump, 0f

	.quad lit, input
	.quad bstore
	.quad lit, input+1
	.quad call, mark
	.quad store
	.quad ret

0:
	.quad call, bye

DEFINE head_read, keyq, "key?"
keyq: /* -- bool */
	.quad call, mark
	.quad fetch
	.quad lit, input
	.quad call, string
	.quad add
	.quad call, uless
	.quad ret

DEFINE head_keyq, key, "key"
key: /* -- char */
	.quad call, mark
	.quad fetch
	.quad bfetch
	.quad ret

DEFINE head_key, advance, "advance"
advance:
	.quad call, mark
	.quad fetch
	.quad inc
	.quad call, mark
	.quad store
	.quad ret

DEFINE head_advance, emit, "emit"
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

	.quad qjump, 0f

	.quad ret

0:
	.quad call, write
	.quad ret

DEFINE head_emit, type, "type"
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

DEFINE head_type, accumulate, "accumulate"
accumulate: /* char -- */
	.quad lit, buffer
	.quad call, string
	.quad dup
	.quad inc
	.quad lit, buffer
	.quad bstore
	.quad add
	.quad bstore
	.quad ret

DEFINE head_accumulate, skip, "skip"
skip:
	.quad call, keyq
	.quad invert

	.quad qjump, 0f

	.quad call, read

0:
	.quad call, key
	.quad lit, '!'
	.quad call, uless
	.quad call, key
	.quad lit, 10
	.quad xor
	.quad and

	.quad qjump, 0f

	.quad call, advance

	.quad jump, skip
0:

	.quad ret

DEFINE head_skip, wordq, "word?"
wordq:
	.quad call, skip
	.quad lit, 0
	.quad lit, buffer
	.quad bstore
	.quad call, key
	.quad lit, 10
	.quad xor

	.quad qjump, 2f

0:
	.quad call, keyq
	.quad invert

	.quad qjump, 1f

	.quad call, read

1:
	.quad call, key
	.quad dup
	.quad lit, '!'
	.quad call, uless
	.quad invert
	.quad lit, buffer
	.quad bfetch
	.quad lit, 0x3F
	.quad call, uless
	.quad and

	.quad qjump, 0f

	.quad call, accumulate
	.quad call, advance

	.quad jump, 0b
0:

	.quad drop

2:
	.quad ret

DEFINE head_wordq, word, "word"
word:
	.quad call, wordq
	.quad lit, buffer
	.quad bfetch
	.quad call, zequals

	.quad qjump, 0f

	.quad call, advance

	.quad jump, word
0:

	.quad ret

DEFINE head_word, digitq, "digit?"
digitq: /* char -- u bool */
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
	.quad call, base
	.quad fetch
	.quad call, uless
	.quad ret

DEFINE head_digitq, natural, "natural"
natural: /* addr u1 -- u2 u3 */
	.quad push
	.quad lit, 0
	.quad pop

0:
	.quad push
	.quad over
	.quad bfetch
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

DEFINE head_natural, number, "number"
number: /* addr u1 -- n u2 */
	.quad over
	.quad bfetch
	.quad lit, '-'
	.quad xor

	.quad qjump, 0f

	.quad call, natural
	.quad ret

0:
	.quad push
	.quad inc
	.quad pop
	.quad dec
	.quad call, natural
	.quad push
	.quad negate
	.quad pop
	.quad ret

DEFINE head_number, find, "find"
find: /* -- 0 | addr */
	.quad call, latest

0:
	.quad fetch
	.quad dup
	.quad call, zequals
	.quad over

	.quad qjump, 1f

	.quad over
	.quad lit, NFA
	.quad add
	.quad bfetch
	.quad lit, ~IMMEDIATE
	.quad and
	.quad lit, buffer
	.quad bfetch
	.quad call, equals

	.quad qjump, 1f

	.quad drop
	.quad dup
	.quad lit, NFA+1
	.quad add
	.quad lit, buffer
	.quad call, string
	.quad call, sameq

1:
	.quad qjump, 0b

	.quad ret

DEFINE head_find, collision, "collision"
collision:
	.quad call, top
	.quad fetch
	.quad call, tickguard
	.quad call, uless
	.quad invert

	.quad qjump, 0f

	.quad lit, head_collision+NFA
	.quad call, string
	.quad call, type
	.quad call, bye

0:
	.quad ret

DEFINE head_collision, save, "save"
save:
	.quad lit, buffer
	.quad call, top
	.quad fetch
	.quad over
	.quad bfetch
	.quad inc
	.quad dup
	.quad call, aligned
	.quad call, top
	.quad fetch
	.quad add
	.quad call, top
	.quad store
	.quad call, collision
	.quad call, bmove
	.quad call, commit
	.quad ret

DEFINE head_save, comma, ",", IMMEDIATE
comma: /* x -- */
	.quad call, top
	.quad fetch
	.quad dup
	.quad lit, CELL
	.quad add
	.quad call, top
	.quad store
	.quad store
	.quad call, collision
	.quad ret

DEFINE head_comma, commit, "commit"
commit:
	.quad call, top
	.quad fetch
	.quad call, here
	.quad store
	.quad ret

DEFINE head_commit, apply, "apply"
apply:
	.quad call, state
	.quad fetch

	.quad qjump, 0f

	.quad call, commit
	.quad ret

0:
	.quad lit, ret
	.quad call, comma
	.quad call, here
	.quad fetch
	.quad dup
	.quad call, top
	.quad store
	.quad execute
	.quad ret

DEFINE head_apply, lbracket, "[", IMMEDIATE
lbracket:
	.quad call, commit
	.quad lit, 0
	.quad call, state
	.quad store
	.quad ret

DEFINE head_lbracket, rbracket, "]", IMMEDIATE
rbracket:
	.quad call, apply
	.quad lit, -1
	.quad call, state
	.quad store
	.quad ret

DEFINE head_rbracket, colon, ":", IMMEDIATE
colon:
	.quad call, rbracket
	.quad call, latest
	.quad fetch
	.quad call, top
	.quad fetch
	.quad call, latest
	.quad store
	.quad call, comma
	.quad call, top
	.quad fetch
	.quad push
	.quad lit, 0
	.quad call, comma
	.quad call, word
	.quad call, save
	.quad call, top
	.quad fetch
	.quad pop
	.quad store
	.quad ret

DEFINE head_colon, semicolon, ";", IMMEDIATE
semicolon:
	.quad lit, ret
	.quad call, comma
	.quad call, lbracket
	.quad ret

DEFINE head_semicolon, tick, "'", IMMEDIATE
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

DEFINE head_tick, postpone, "postpone", IMMEDIATE
postpone:
	.quad call, tick
	.quad lit, call
	.quad call, comma
	.quad call, comma
	.quad ret

DEFINE head_postpone, literal, "literal", IMMEDIATE
literal: /* x -- */
	.quad lit, lit
	.quad call, comma
	.quad call, comma
	.quad ret

DEFINE head_literal, interpret, "interpret"
interpret:
	.quad call, wordq
	.quad lit, buffer
	.quad bfetch

	.quad qjump, 2f

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
	.quad execute
	.quad jump, interpret

0:
	.quad fetch
	.quad dup
	.quad lit, START
	.quad lit, end
	.quad call, within
	.quad invert

	.quad qjump, 0f

	.quad lit, call
	.quad call, comma

0:
	.quad call, comma
	.quad jump, interpret

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
	.quad ret

0:
	.quad call, literal
	.quad jump, interpret

2:
	.quad ret

DEFINE head_interpret, main, "main"
main:
	.quad call, interpret
	.quad call, apply
	.quad call, advance
	.quad call, write
	.quad jump, main

.bss

input:
	.skip 0x100

output:
	.skip 0x100

buffer:
	.skip 0x100

vocabulary:
	.skip 0x3000
guard:

	.skip 0x100
dstack:
