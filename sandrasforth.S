/* rax - top-of-stack, syscall number.
   rbx - working register.
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

   r12 - threaded code pointer.
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

.set CELL,      8
.set IMMEDIATE, 0x80

.macro DUP /* x -- x x */
	leaq -CELL(%rbp), %rbp
	movq %rax, (%rbp)
.endm

.macro NIP /* x1 x2 -- x2 */
	leaq CELL(%rbp), %rbp
.endm

.macro TWONIP /* x1 x2 x3-- x3 */
	leaq CELL * 2(%rbp), %rbp
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
	movq (%r12), %rbx
	addq $CELL, %r12
	jmp *(%rbx)
.endm

.macro DEFINE previous, body, name, mask=0
head_\body:
	.quad \previous
	.byte (1f - 0f) | \mask
0:
	.ascii "\name"
1:
.balign CELL
\body:
.endm

.macro DEFCODE previous, body, name
DEFINE \previous, \body, "\name"
	.quad code_\body
.endm

.macro DEFWORD previous, body, name, mask=0
DEFINE \previous, \body, "\name", \mask
	.quad code_enter
.endm

.macro DEFCONST previous, body, name, val
DEFWORD \previous, \body, "\name"
	.quad lit, \val
	.quad exit
.endm

.macro DEFVAR previous, body, name, val
var_\body:
	.quad \val
DEFWORD \previous, \body, "\name"
	.quad lit, var_\body
	.quad exit
.endm

.text

.global START

START:
	leaq dstack(%rip), %rbp
	movq $-1, %rax
	leaq main(%rip), %r12
	NEXT

code_enter:
	pushq %r12
	addq $CELL, %rbx
	movq %rbx, %r12
	NEXT

code_branch:
	movq (%r12), %r12
	NEXT

code_zbranch: /* x -- */
	testq %rax, %rax
	DROP
	jz code_branch
	addq $CELL, %r12
	NEXT

code_execute: /* addr -- */
	movq %rax, %rbx
	DROP
	jmp *(%rbx)

code_exit:
	popq %r12
	NEXT

code_lit: /* -- x */
	DUP
	movq (%r12), %rax
	addq $CELL, %r12
	NEXT

code_dup: /* x -- x x */
	DUP
	NEXT

code_nip: /* x1 x2 -- x2 */
	NIP
	NEXT

code_drop: /* x -- */
	DROP
	NEXT

code_over: /* x1 x2 -- x1 x2 x1 */
	DUP
	movq CELL(%rbp), %rax
	NEXT

code_rpush: /* x -- */
	pushq %rax
	DROP
	NEXT

code_rpull: /* -- x */
	DUP
	popq %rax
	NEXT

code_invert: /* x1 -- x2 */
	notq %rax
	NEXT

code_twomul: /* x1 -- x2 */
	shlq %rax
	NEXT

code_twodiv: /* x1 -- x2 */
	shrq %rax
	NEXT

code_and: /* x1 x2 -- x3 */
	andq (%rbp), %rax
	NIP
	NEXT

code_or: /* x1 x2 -- x3 */
	orq (%rbp), %rax
	NIP
	NEXT

code_xor: /* x1 x2 -- x3 */
	xorq (%rbp), %rax
	NIP
	NEXT

code_negate: /* n1 -- n2 */
	negq %rax
	NEXT

code_inc: /* n1 -- n2 */
	incq %rax
	NEXT

code_dec: /* n1 -- n2 */
	decq %rax
	NEXT

code_add: /* n1|u1 n2|u2 -- n3|u3 */
	addq %rax, (%rbp)
	DROP
	NEXT

code_sub: /* n1|u1 n2|u2 -- n3|u3 */
	subq %rax, (%rbp)
	DROP
	NEXT

code_mul: /* n1 n2 -- n3 */
	imulq (%rbp)
	NIP
	NEXT

code_ummul: /* u1 u2 -- ud */
	mulq (%rbp)
	movq %rax, (%rbp)
	movq %rdx, %rax
	NEXT

code_div: /* n1 n2 -- n3 */
	movq %rax, %rcx
	movq (%rbp), %rax
	cqo
	idivq %rcx
	NIP
	NEXT

code_divmod: /* n1 n2 -- n3 n4 */
	movq %rax, %rcx
	movq (%rbp), %rax
	cqo
	idivq %rcx
	movq %rdx, (%rbp)
	NEXT

code_umdivmod: /* ud u1 -- u2 u3 */
	movq %rax, %rcx
	movq (%rbp), %rdx
	NIP
	movq (%rbp), %rax
	divq %rcx
	movq %rdx, (%rbp)
	NEXT

code_fetch: /* addr -- x */
	movq (%rax), %rax
	NEXT

code_store: /* x addr -- */
	movq (%rbp), %rdx
	movq %rdx, (%rax)
	TWODROP
	NEXT

code_cfetch: /* addr -- char */
	movzbq (%rax), %rax
	NEXT

code_cstore: /* char addr -- */
	movb (%rbp), %dl
	movb %dl, (%rax)
	TWODROP
	NEXT

code_syscall: /* x1 x2 x3 x4 -- x5 */
	movq (%rbp), %rdx
	movq CELL(%rbp), %rsi
	movq CELL * 2(%rbp), %rdi
	leaq CELL * 3(%rbp), %rbp
	syscall
	NEXT

.data

DEFCODE 0,             enter,    "enter"
DEFCODE head_enter,    branch,   "branch"
DEFCODE head_branch,   zbranch,  "0branch"
DEFCODE head_zbranch,  execute,  "execute"
DEFCODE head_execute,  exit,     "exit"
DEFCODE head_exit,     lit,      "lit"
DEFCODE head_lit,      dup,      "dup"
DEFCODE head_dup,      nip,      "nip"
DEFCODE head_nip,      drop,     "drop"
DEFCODE head_drop,     over,     "over"
DEFCODE head_over,     rpush,    ">r"
DEFCODE head_rpush,    rpull,    "r>"
DEFCODE head_rpull,    invert,   "invert"
DEFCODE head_invert,   twomul,   "2*"
DEFCODE head_twomul,   twodiv,   "2/"
DEFCODE head_twodiv,   and,      "and"
DEFCODE head_and,      or,       "or"
DEFCODE head_or,       xor,      "xor"
DEFCODE head_xor,      negate,   "negate"
DEFCODE head_negate,   inc,      "1+"
DEFCODE head_inc,      dec,      "1-"
DEFCODE head_dec,      add,      "+"
DEFCODE head_add,      sub,      "-"
DEFCODE head_sub,      mul,      "*"
DEFCODE head_mul,      ummul,    "um*"
DEFCODE head_ummul,    div,      "/"
DEFCODE head_div,      divmod,   "/mod"
DEFCODE head_divmod,   umdivmod, "um/mod"
DEFCODE head_umdivmod, fetch,    "@"
DEFCODE head_fetch,    store,    "!"
DEFCODE head_store,    cfetch,   "c@"
DEFCODE head_cfetch,   cstore,   "c!"
DEFCODE head_cstore,   syscall,  "syscall"

DEFCONST head_syscall,     cell,        "cell",        CELL       /* -- u */
DEFCONST head_cell,        lf,          "lf",          '\n'       /* -- char */
DEFCONST head_lf,          bl,          "bl",          ' '        /* -- char */
DEFCONST head_bl,          f_immediate, "f-immediate", IMMEDIATE  /* -- x */
DEFCONST head_f_immediate, sys_read,    "sys-read",    SYS_read   /* -- x */
DEFCONST head_sys_read,    sys_write,   "sys-write",   SYS_write  /* -- x */
DEFCONST head_sys_write,   sys_exit,    "sys-exit",    SYS_exit   /* -- x */
DEFCONST head_sys_exit,    tickinput,   "'input",      input      /* -- addr */
DEFCONST head_tickinput,   tickbuffer,  "'buffer",     buffer     /* -- addr */

DEFVAR   head_tickbuffer,  toin,        ">in",         0          /* -- addr */
DEFVAR   head_toin,        state,       "state",       0          /* -- addr */
DEFVAR   head_state,       here,        "here",        vocabulary /* -- addr */
DEFVAR   head_here,        latest,      "latest",      head_main  /* -- addr */
DEFVAR   head_latest,      current,     "current",     head_main  /* -- addr */
DEFVAR   head_current,     base,        "base",        10         /* -- addr */

DEFWORD head_base, flag, "flag" /* x -- flag */
	.quad zbranch, 0f

	.quad lit, -1

	.quad branch, 1f

0:
	.quad lit, 0

1:
	.quad exit

DEFWORD head_flag, zequals, "0=" /* x -- flag */
	.quad flag
	.quad invert
	.quad exit

DEFWORD head_zequals, equals, "=" /* x1 x2 -- flag */
	.quad xor
	.quad zequals
	.quad exit

DEFWORD head_equals, zless, "0<" /* n - flag */
	.quad lit, 1 << (CELL * 8 - 1)
	.quad and
	.quad flag
	.quad exit

DEFWORD head_zless, less, "<" /* n1 n2 -- flag */
	.quad over
	.quad over
	.quad xor
	.quad zless

	.quad zbranch, 0f

	.quad drop
	.quad zless

	.quad branch, 1f

0:
	.quad sub
	.quad zless

1:
	.quad exit

DEFWORD head_less, uless, "u<" /* u1 u2 -- flag */
	.quad over
	.quad over
	.quad xor
	.quad zless

	.quad zbranch, 0f

	.quad nip
	.quad zless

	.quad branch, 1f

0:
	.quad sub
	.quad zless

1:
	.quad exit

DEFWORD head_uless, within, "within" /* u1 u2 u3 -- flag */
	.quad rpush
	.quad over
	.quad rpush
	.quad uless
	.quad invert
	.quad rpull
	.quad rpull
	.quad uless
	.quad and
	.quad exit

DEFWORD head_within, ccomma, "c," /* char -- */
	.quad here
	.quad fetch
	.quad dup
	.quad inc
	.quad here
	.quad store
	.quad cstore
	.quad exit

DEFWORD head_ccomma, comma, "," /* x -- */
	.quad here
	.quad fetch
	.quad dup
	.quad cell
	.quad add
	.quad here
	.quad store
	.quad store
	.quad exit

DEFWORD head_comma, aligned, "aligned" /* x1 -- x2 */
	.quad lit, CELL - 1
	.quad add
	.quad lit, ~(CELL - 1)
	.quad and
	.quad exit

DEFWORD head_aligned, count, "count" /* addr1 -- addr2 u */
	.quad inc
	.quad dup
	.quad dec
	.quad cfetch
	.quad exit

DEFWORD head_count, cmove, "cmove" /* addr1 addr2 u -- */
0:
	.quad dup

	.quad zbranch, 0f

	.quad rpush
	.quad over
	.quad cfetch
	.quad over
	.quad cstore
	.quad rpush
	.quad inc
	.quad rpull
	.quad inc
	.quad rpull
	.quad dec

	.quad branch, 0b

0:
	.quad nip
	.quad nip
	.quad drop
	.quad exit

DEFWORD head_cmove, scomma, "s," /* addr u -- */
	.quad dup
	.quad ccomma
	.quad dup
	.quad rpush
	.quad rpush
	.quad here
	.quad fetch
	.quad rpull
	.quad cmove
	.quad rpull
	.quad here
	.quad fetch
	.quad add
	.quad aligned
	.quad here
	.quad store
	.quad exit

DEFWORD head_scomma, sequals, "s=" /* addr1 u1 addr2 u2 -- flag */
	.quad rpush
	.quad over
	.quad rpush
	.quad nip
	.quad rpull
	.quad rpull
	.quad over
	.quad equals

	.quad zbranch, 1f

0:
	.quad dup
	.quad rpush
	.quad rpush
	.quad over
	.quad cfetch
	.quad over
	.quad cfetch
	.quad equals
	.quad rpull
	.quad and

	.quad zbranch, 0f

	.quad rpush
	.quad inc
	.quad rpull
	.quad inc
	.quad rpull
	.quad dec

	.quad branch, 0b

0:
	.quad rpull
	.quad nip
	.quad nip
	.quad zequals

	.quad branch, 0f

1:
	.quad nip
	.quad nip
	.quad drop
	.quad lit, 0

0:
	.quad exit

DEFWORD head_sequals, bye, "bye"
	.quad lit, 0
	.quad dup
	.quad dup
	.quad sys_exit
	.quad syscall

DEFWORD head_bye, key, "key" /* -- char */
	.quad lit, 0
	.quad here
	.quad fetch
	.quad lit, 1
	.quad sys_read
	.quad syscall
	.quad zequals

	.quad zbranch, 0f

	.quad bye

0:
	.quad here
	.quad fetch
	.quad cfetch
	.quad exit

DEFWORD head_key, emit, "emit" /* char -- */
	.quad here
	.quad fetch
	.quad cstore
	.quad lit, 1
	.quad here
	.quad fetch
	.quad lit, 1
	.quad sys_write
	.quad syscall
	.quad drop
	.quad exit

DEFWORD head_emit, refill, "refill"
	.quad lit, 0
	.quad tickinput
	.quad cstore
	.quad lit, 0
	.quad toin
	.quad store

0:
	.quad key
	.quad dup
	.quad dup
	.quad lf
	.quad equals

	.quad zbranch, 1f

	.quad drop
	.quad bl

1:
	.quad tickinput
	.quad count
	.quad add
	.quad cstore
	.quad tickinput
	.quad cfetch
	.quad inc
	.quad tickinput
	.quad cstore
	.quad lf
	.quad equals
	.quad tickinput
	.quad cfetch
	.quad lit, 0xFF
	.quad equals
	.quad or

	.quad zbranch, 0b

	.quad exit

DEFWORD head_refill, type, "type" /* addr u -- */
0:
	.quad dup

	.quad zbranch, 0f

	.quad rpush
	.quad dup
	.quad cfetch
	.quad emit
	.quad inc
	.quad rpull
	.quad dec

	.quad branch, 0b

0:
	.quad nip
	.quad drop
	.quad exit

DEFWORD head_type, parse, "parse" /* char - addr u */
	.quad rpush
	.quad toin
	.quad fetch
	.quad dup

0:
	.quad dup
	.quad tickinput
	.quad cfetch
	.quad uless
	.quad over
	.quad lit, input + 1
	.quad add
	.quad cfetch
	.quad rpull
	.quad dup
	.quad rpush
	.quad equals
	.quad invert
	.quad and

	.quad zbranch, 0f

	.quad inc

	.quad branch, 0b

0:
	.quad rpull
	.quad drop
	.quad dup
	.quad inc
	.quad toin
	.quad store
	.quad over
	.quad sub
	.quad rpush
	.quad lit, input + 1
	.quad add
	.quad rpull
	.quad exit

DEFWORD head_parse, word, "word" /* char -- addr */
	.quad rpush
	.quad tickbuffer
	.quad toin
	.quad fetch

0:
	.quad dup
	.quad tickinput
	.quad cfetch
	.quad uless
	.quad over
	.quad lit, input + 1
	.quad add
	.quad cfetch
	.quad rpull
	.quad dup
	.quad rpush
	.quad equals
	.quad and

	.quad zbranch, 0f

	.quad inc

	.quad branch, 0b

0:
	.quad toin
	.quad store
	.quad rpull
	.quad parse
	.quad dup
	.quad lit, IMMEDIATE - 1
	.quad uless
	.quad invert

	.quad zbranch, 0f

	.quad drop
	.quad lit, IMMEDIATE - 1

0:
	.quad rpush
	.quad over
	.quad rpull
	.quad over
	.quad cstore
	.quad count
	.quad cmove
	.quad exit

DEFWORD head_word, ctonumber, "c>number" /* char -- n */
	.quad lit, '0'
	.quad sub
	.quad lit, 9
	.quad over
	.quad less

	.quad zbranch, 0f

	.quad lit, 'A' - '0' - 10
	.quad sub
	.quad dup
	.quad lit, 10
	.quad less
	.quad or

0:
	.quad exit

DEFWORD head_ctonumber, utonumber, "u>number" /* 0 addr1 u1 -- u2 addr2 u3 */
0:
	.quad dup
	.quad rpush
	.quad rpush
	.quad dup
	.quad rpush
	.quad cfetch
	.quad ctonumber
	.quad rpull
	.quad over
	.quad base
	.quad fetch
	.quad uless
	.quad rpull
	.quad and

	.quad zbranch, 0f

	.quad rpush
	.quad rpush
	.quad base
	.quad fetch
	.quad mul
	.quad rpull
	.quad add
	.quad rpull
	.quad inc
	.quad rpull
	.quad dec

	.quad branch, 0b

0:
	.quad nip
	.quad rpull
	.quad exit

DEFWORD head_utonumber, tonumber, ">number" /* 0 addr1 u1 -- n addr2 u2 */
	.quad over
	.quad cfetch
	.quad lit, '-'
	.quad equals

	.quad zbranch, 0f

	.quad rpush
	.quad inc
	.quad rpull
	.quad dec
	.quad utonumber
	.quad rpush
	.quad rpush
	.quad negate
	.quad rpull
	.quad rpull

	.quad branch, 1f

0:
	.quad utonumber

1:
	.quad exit

DEFWORD head_tonumber, tocode, ">code" /* addr1 -- addr2 */
	.quad cell
	.quad add
	.quad count
	.quad lit, IMMEDIATE - 1
	.quad and
	.quad add
	.quad aligned
	.quad exit

DEFWORD head_tocode, find, "find" /* addr -- addr 0 | xt 1 | xt -1 */
	.quad dup
	.quad latest
	.quad rpush

0:
	.quad rpull
	.quad fetch
	.quad dup
	.quad rpush
	.quad zequals
	.quad dup
	.quad invert

	.quad zbranch, 1f

	.quad drop
	.quad dup
	.quad count
	.quad rpull
	.quad dup
	.quad rpush
	.quad cell
	.quad add
	.quad count
	.quad lit, IMMEDIATE - 1
	.quad and
	.quad sequals

1:
	.quad zbranch, 0b

	.quad drop
	.quad rpull
	.quad dup

	.quad zbranch, 0f

	.quad nip
	.quad dup
	.quad cell
	.quad add
	.quad cfetch
	.quad f_immediate
	.quad and
	.quad state
	.quad fetch
	.quad invert
	.quad or

	.quad zbranch, 1f

	.quad lit, 1

	.quad branch, 2f

1:
	.quad lit, -1

2:
	.quad rpush
	.quad tocode
	.quad rpull

0:
	.quad exit

DEFWORD head_find, lbracket, "[", IMMEDIATE
	.quad lit, 0
	.quad state
	.quad store
	.quad exit

DEFWORD head_lbracket, rbracket, "]"
	.quad lit, -1
	.quad state
	.quad store
	.quad exit

DEFWORD head_rbracket, colon, ":"
	.quad here
	.quad fetch
	.quad current
	.quad store
	.quad latest
	.quad fetch
	.quad comma
	.quad bl
	.quad word
	.quad count
	.quad scomma
	.quad lit, code_enter
	.quad comma
	.quad rbracket
	.quad exit

DEFWORD head_colon, reveal, "reveal"
	.quad current
	.quad fetch
	.quad latest
	.quad store
	.quad exit

DEFWORD head_reveal, semicolon, ";", IMMEDIATE
	.quad lit, exit
	.quad comma
	.quad reveal
	.quad lbracket
	.quad exit

DEFWORD head_semicolon, tick, "'" /* -- 0 | xt */
	.quad bl
	.quad word
	.quad find
	.quad dup

	.quad zbranch, 0f

	.quad drop

	.quad branch, 1f

0:
	.quad nip

1:
	.quad exit

DEFWORD head_tick, literal, "literal", IMMEDIATE /* x -- */
	.quad lit, lit
	.quad comma
	.quad comma
	.quad exit

DEFWORD head_literal, interpret, "interpret"
0:
	.quad bl
	.quad word
	.quad dup
	.quad cfetch

	.quad zbranch, 4f

	.quad find
	.quad dup

	.quad zbranch, 3f

	.quad zless

	.quad zbranch, 1f

	.quad comma

	.quad branch, 2f

1:
	.quad execute

2:
	.quad branch, 2f

3:
	.quad drop
	.quad lit, 0
	.quad over
	.quad count
	.quad tonumber
	.quad nip

	.quad zbranch, 1f

	.quad drop
	.quad count
	.quad type
	.quad lit, '?'
	.quad emit

	.quad branch, 2f

1:
	.quad nip
	.quad state
	.quad fetch

	.quad zbranch, 2f

	.quad literal

2:
	.quad branch, 0b

4:
	.quad drop
	.quad exit

DEFINE head_interpret, main, "main"
	.quad refill
	.quad interpret
	.quad branch, main

.bss

input:
	.skip 0x100

buffer:
	.skip 0x100

	.skip 0x1000
dstack:

vocabulary:
	.skip 0x3000
