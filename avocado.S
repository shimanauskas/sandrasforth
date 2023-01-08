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
	#define SYS_READ  0
	#define SYS_WRITE 1
	#define SYS_EXIT  60
#elif __APPLE__
	#define START      start
	#define SYS_READ  0x2000003
	#define SYS_WRITE 0x2000004
	#define SYS_EXIT  0x2000001
#else
	#error Unsupported platform.
#endif

#define STDIN  0
#define STDOUT 1

#define CELL 8
#define NFA  CELL*2

#define F_LENGTH    0x3F
#define F_HIDDEN    0x40
#define F_IMMEDIATE 0x80

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

not: /* x1 -- x2 */
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
	mulq %rcx
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

cell: /* -- u */
	.quad lit, CELL
	.quad jump, literal

nfa: /* -- u */
	.quad lit, NFA
	.quad jump, literal

f_length: /* -- u */
	.quad lit, F_LENGTH
	.quad jump, literal

f_hidden: /* -- x */
	.quad lit, F_HIDDEN
	.quad jump, literal

sys_read: /* -- x */
	.quad lit, SYS_READ
	.quad jump, literal

sys_write: /* -- x */
	.quad lit, SYS_WRITE
	.quad jump, literal

sys_exit: /* -- x */
	.quad lit, SYS_EXIT
	.quad jump, literal

tickinput: /* -- addr */
	.quad lit, input
	.quad jump, literal

tickoutput: /* -- addr */
	.quad lit, output
	.quad jump, literal

tickbuffer: /* -- addr */
	.quad lit, buffer
	.quad jump, literal

tickcode: /* -- addr */
	.quad lit, code
	.quad jump, literal

tickvocab: /* -- addr */
	.quad lit, vocab
	.quad jump, literal

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

bool: /* x -- bool */
	.quad qjump, 0f

	.quad lit, -1
	.quad ret

0:
	.quad lit, 0
	.quad ret

zequals: /* x -- bool */
	.quad call, bool
	.quad not
	.quad ret

equals: /* x1 x2 -- bool */
	.quad xor
	.quad jump, zequals

zless: /* n - bool */
	.quad lit, 1<<(CELL*8-1)
	.quad and
	.quad jump, bool

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

aligned: /* x1 -- x2 */
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

bye:
	.quad call, flush
	.quad lit, 0
	.quad dup
	.quad dup
	.quad lit, SYS_EXIT
	.quad syscall

accept:
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

flush:
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

advance:
	.quad call, mark
	.quad fetch
	.quad inc
	.quad call, mark
	.quad store
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

skip:
	.quad call, keyq
	.quad not

	.quad qjump, 0f

	.quad call, accept

0:
	.quad call, keyq
	.quad call, key
	.quad lit, '!'
	.quad call, uless
	.quad and

	.quad qjump, 0f

	.quad call, advance

	.quad jump, 0b
0:

	.quad ret

wordq:
	.quad call, skip
	.quad lit, 0
	.quad lit, buffer
	.quad bstore
	.quad call, keyq

	.quad qjump, 1f

0:
	.quad call, key
	.quad dup
	.quad lit, '!'
	.quad call, uless
	.quad not
	.quad lit, buffer
	.quad bfetch
	.quad lit, F_LENGTH
	.quad call, uless
	.quad and

	.quad qjump, 0f

	.quad call, accumulate
	.quad call, advance
	.quad call, keyq
	.quad not

	.quad qjump, 0b

	.quad call, accept

	.quad jump, 0b
0:

	.quad drop

1:
	.quad ret

word:
	.quad call, wordq
	.quad lit, buffer
	.quad bfetch

	.quad qjump, word

	.quad ret

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
	.quad jump, uless

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
	.quad negate
	.quad pop
	.quad ret

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
	.quad jump, zequals

find: /* -- 0 | addr */
	.quad call, last

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
	.quad lit, F_LENGTH|F_HIDDEN
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

collision:
	.quad call, top
	.quad fetch
	.quad call, head
	.quad fetch
	.quad call, uless
	.quad not

	.quad qjump, 0f

	.quad lit, head_collision+NFA
	.quad call, string
	.quad call, type
	.quad jump, bye

0:
	.quad ret

save:
	.quad lit, buffer
	.quad call, head
	.quad fetch
	.quad over
	.quad bfetch
	.quad inc
	.quad dup
	.quad push
	.quad call, aligned
	.quad sub
	.quad dup
	.quad call, head
	.quad store
	.quad call, collision
	.quad pop
	.quad jump, bmove

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

tail:
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

commit:
	.quad call, top
	.quad fetch
	.quad call, here
	.quad store
	.quad ret

apply:
	.quad call, tail
	.quad call, state
	.quad fetch

	.quad qjump, commit

	.quad call, here
	.quad fetch
	.quad dup
	.quad call, top
	.quad store
	.quad execute
	.quad ret

colon:
	.quad call, apply
	.quad call, word
	.quad call, save
	.quad call, head
	.quad fetch
	.quad bfetch
	.quad lit, F_HIDDEN
	.quad or
	.quad call, head
	.quad fetch
	.quad bstore
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

semicolon:
	.quad call, apply
	.quad call, last
	.quad fetch
	.quad lit, NFA
	.quad add
	.quad dup
	.quad bfetch
	.quad lit, ~F_HIDDEN
	.quad and
	.quad over
	.quad bstore
	.quad drop
	.quad lit, -1
	.quad call, state
	.quad store
	.quad ret

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

postpone:
	.quad call, tick
	.quad lit, call
	.quad call, comma
	.quad jump, comma

literal: /* x -- */
	.quad lit, lit
	.quad call, comma
	.quad jump, comma

immediate:
	.quad call, last
	.quad fetch
	.quad lit, NFA
	.quad add
	.quad dup
	.quad bfetch
	.quad lit, F_IMMEDIATE
	.quad or
	.quad over
	.quad bstore
	.quad drop
	.quad ret

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
	.quad lit, F_IMMEDIATE
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
	.quad not

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
	.quad jump, emit

0:
	.quad call, literal
	.quad jump, interpret

2:
	.quad ret

main:
	.quad call, accept
	.quad call, interpret
	.quad call, flush
	.quad jump, main

DEFINE 0,               call,       "call"
DEFINE head_call,       jump,       "jump"
DEFINE head_jump,       qjump,      "?jump"
DEFINE head_qjump,      execute,    "execute"
DEFINE head_execute,    ret,        "ret"
DEFINE head_ret,        lit,        "lit"
DEFINE head_lit,        var,        "var"
DEFINE head_var,        dup,        "dup"
DEFINE head_dup,        nip,        "nip"
DEFINE head_nip,        drop,       "drop"
DEFINE head_drop,       over,       "over"
DEFINE head_over,       push,       "push"
DEFINE head_push,       pop,        "pop"
DEFINE head_pop,        not,        "not"
DEFINE head_not,        twomul,     "2*"
DEFINE head_twomul,     twodiv,     "2/"
DEFINE head_twodiv,     and,        "and"
DEFINE head_and,        or,         "or"
DEFINE head_or,         xor,        "xor"
DEFINE head_xor,        negate,     "negate"
DEFINE head_negate,     inc,        "1+"
DEFINE head_inc,        dec,        "1-"
DEFINE head_dec,        add,        "+"
DEFINE head_add,        sub,        "-"
DEFINE head_sub,        mul,        "*"
DEFINE head_mul,        ummul,      "um*"
DEFINE head_ummul,      umdivmod,   "um/mod"
DEFINE head_umdivmod,   fetch,      "@"
DEFINE head_fetch,      store,      "!"
DEFINE head_store,      bfetch,     "b@"
DEFINE head_bfetch,     bstore,     "b!"
DEFINE head_bstore,     syscall,    "syscall"

DEFINE head_syscall,    cell,       "cell",      F_IMMEDIATE
DEFINE head_cell,       nfa,        "nfa",       F_IMMEDIATE
DEFINE head_nfa,        f_length,   "f-length",  F_IMMEDIATE
DEFINE head_f_length,   f_hidden,   "f-hidden",  F_IMMEDIATE
DEFINE head_f_hidden,   sys_read,   "sys-read",  F_IMMEDIATE
DEFINE head_sys_read,   sys_write,  "sys-write", F_IMMEDIATE
DEFINE head_sys_write,  sys_exit,   "sys-exit",  F_IMMEDIATE
DEFINE head_sys_exit,   tickinput,  "'input",    F_IMMEDIATE
DEFINE head_tickinput,  tickoutput, "'output",   F_IMMEDIATE
DEFINE head_tickoutput, tickbuffer, "'buffer",   F_IMMEDIATE
DEFINE head_tickbuffer, tickcode,   "'code",     F_IMMEDIATE
DEFINE head_tickcode,   tickvocab,  "'vocab",    F_IMMEDIATE

DEFINE head_tickvocab,  mark,       "mark"
DEFINE head_mark,       state,      "state"
DEFINE head_state,      here,       "here"
DEFINE head_here,       top,        "top"
DEFINE head_top,        head,       "head"
DEFINE head_head,       last,       "last"
DEFINE head_last,       base,       "base"

DEFINE head_base,       bool,       "bool"
DEFINE head_bool,       zequals,    "0="
DEFINE head_zequals,    equals,     "="
DEFINE head_equals,     zless,      "0<"
DEFINE head_zless,      less,       "<"
DEFINE head_less,       uless,      "u<"
DEFINE head_uless,      within,     "within"
DEFINE head_within,     aligned,    "aligned"
DEFINE head_aligned,    string,     "string"
DEFINE head_string,     bye,        "bye"
DEFINE head_bye,        accept,     "accept"
DEFINE head_accept,     flush,      "flush"
DEFINE head_flush,      keyq,       "key?"
DEFINE head_keyq,       key,        "key"
DEFINE head_key,        advance,    "advance"
DEFINE head_advance,    emit,       "emit"
DEFINE head_emit,       type,       "type"
DEFINE head_type,       accumulate, "accumulate"
DEFINE head_accumulate, skip,       "skip"
DEFINE head_skip,       wordq,      "word?"
DEFINE head_wordq,      word,       "word"
DEFINE head_word,       digitq,     "digit?"
DEFINE head_digitq,     natural,    "natural"
DEFINE head_natural,    number,     "number"
DEFINE head_number,     sameq,      "same?"
DEFINE head_sameq,      find,       "find"
DEFINE head_find,       bmove,      "bmove"
DEFINE head_bmove,      collision,  "collision"
DEFINE head_collision,  save,       "save"
DEFINE head_save,       comma,      ",",         F_IMMEDIATE
DEFINE head_comma,      link,       "link"
DEFINE head_link,       tail,       "tail",      F_IMMEDIATE
DEFINE head_tail,       commit,     "commit"
DEFINE head_commit,     apply,      "apply"
DEFINE head_apply,      colon,      ":",         F_IMMEDIATE
DEFINE head_colon,      semicolon,  ";",         F_IMMEDIATE
DEFINE head_semicolon,  tick,       "'",         F_IMMEDIATE
DEFINE head_tick,       postpone,   "postpone",  F_IMMEDIATE
DEFINE head_postpone,   literal,    "literal",   F_IMMEDIATE
DEFINE head_literal,    immediate,  "immediate", F_IMMEDIATE
DEFINE head_immediate,  interpret,  "interpret"
DEFINE head_interpret,  main,       "main",      F_IMMEDIATE

.bss

input:
	.skip 0x100

output:
	.skip 0x100

buffer:
	.skip 0x100

code:
	.skip 0x3000
vocab:

	.skip 0x100
dstack:
