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

#define CELL      8
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
	movq (%r12), %rbx
	addq $(CELL), %r12
	jmp *(%rbx)
.endm

.macro DEFINE previous, body, name, mask=0
head_\body:
	.quad \previous
	.byte (1f-0f)|\mask
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
	.quad code_docolon
.endm

.text

.global START

START:
	leaq dstack(%rip), %rbp
	movq $-1, %rax
	leaq interpret(%rip), %r12
	NEXT

code_docolon:
	pushq %r12
	addq $(CELL), %rbx
	movq %rbx, %r12
	NEXT

code_branch:
	movq (%r12), %r12
	NEXT

code_zbranch: /* x -- */
	testq %rax, %rax
	DROP
	jz code_branch
	addq $(CELL), %r12
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
	addq $(CELL), %r12
	NEXT

code_var: /* -- addr */
	DUP
	movq %r12, %rax
	addq $(CELL), %r12
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

code_push: /* x -- */
	pushq %rax
	DROP
	NEXT

code_pop: /* -- x */
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
	movq %rax, %rcx
	DROP
	imulq %rcx
	NEXT

code_ummul: /* u1 u2 -- ud */
	movq %rax, %rcx
	DROP
	mulq %rcx
	DUP
	movq %rdx, %rax
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
	movq CELL*2(%rbp), %rdi
	leaq CELL*3(%rbp), %rbp
	syscall
	NEXT

.data

DEFCODE 0,             docolon,  "docolon"
DEFCODE head_docolon,  branch,   "branch"
DEFCODE head_branch,   zbranch,  "0branch"
DEFCODE head_zbranch,  execute,  "execute"
DEFCODE head_execute,  exit,     "exit"
DEFCODE head_exit,     lit,      "lit"
DEFCODE head_lit,      var,      "var"
DEFCODE head_var,      dup,      "dup"
DEFCODE head_dup,      nip,      "nip"
DEFCODE head_nip,      drop,     "drop"
DEFCODE head_drop,     over,     "over"
DEFCODE head_over,     push,     "push"
DEFCODE head_push,     pop,      "pop"
DEFCODE head_pop,      invert,   "invert"
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
DEFCODE head_ummul,    umdivmod, "um/mod"
DEFCODE head_umdivmod, fetch,    "@"
DEFCODE head_fetch,    store,    "!"
DEFCODE head_store,    cfetch,   "c@"
DEFCODE head_cfetch,   cstore,   "c!"
DEFCODE head_cstore,   syscall,  "syscall"

DEFWORD head_syscall, cell, "cell" /* -- u */
	.quad lit, CELL
	.quad exit

DEFWORD head_cell, immediate_flag, "immediate-flag" /* -- x */
	.quad lit, IMMEDIATE
	.quad exit

DEFWORD head_immediate_flag, sys_read, "sys-read" /* -- x */
	.quad lit, SYS_read
	.quad exit

DEFWORD head_sys_read, sys_write, "sys-write" /* -- x */
	.quad lit, SYS_write
	.quad exit

DEFWORD head_sys_write, sys_exit, "sys-exit" /* -- x */
	.quad lit, SYS_exit
	.quad exit

DEFWORD head_sys_exit, tickinput, "'input" /* -- addr */
	.quad lit, input
	.quad exit

DEFWORD head_tickinput, tickoutput, "'output" /* -- addr */
	.quad lit, output
	.quad exit

DEFWORD head_tickoutput, tickbuffer, "'buffer" /* -- addr */
	.quad lit, buffer
	.quad exit

DEFWORD head_tickbuffer, mark, "mark" /* -- addr */
	.quad var, input+1
	.quad exit

DEFWORD head_mark, state, "state" /* -- addr */
	.quad var, 0
	.quad exit

DEFWORD head_state, here, "here" /* -- addr */
	.quad var, vocabulary
	.quad exit

DEFWORD head_here, latest, "latest" /* -- addr */
	.quad var, head_interpret
	.quad exit

DEFWORD head_latest, current, "current" /* -- addr */
	.quad var, head_interpret
	.quad exit

DEFWORD head_current, base, "base" /* -- addr */
	.quad var, 10
	.quad exit

DEFWORD head_base, bool, "bool" /* x -- bool */
	.quad zbranch, 0f

	.quad lit, -1

	.quad branch, 1f
0:

	.quad lit, 0

1:
	.quad exit

DEFWORD head_bool, zequals, "0=" /* x -- bool */
	.quad bool
	.quad invert
	.quad exit

DEFWORD head_zequals, equals, "=" /* x1 x2 -- bool */
	.quad xor
	.quad zequals
	.quad exit

DEFWORD head_equals, zless, "0<" /* n - bool */
	.quad lit, 1<<(CELL*8-1)
	.quad and
	.quad bool
	.quad exit

DEFWORD head_zless, less, "<" /* n1 n2 -- bool */
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

DEFWORD head_less, uless, "u<" /* u1 u2 -- bool */
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

DEFWORD head_uless, within, "within" /* u1 u2 u3 -- bool */
	.quad push
	.quad over
	.quad push
	.quad uless
	.quad invert
	.quad pop
	.quad pop
	.quad uless
	.quad and
	.quad exit

DEFWORD head_within, aligned, "aligned" /* x1 -- x2 */
	.quad lit, CELL-1
	.quad add
	.quad lit, ~(CELL-1)
	.quad and
	.quad exit

DEFWORD head_aligned, count, "count" /* addr1 -- addr2 u */
	.quad dup
	.quad push
	.quad inc
	.quad pop
	.quad cfetch
	.quad exit

DEFWORD head_count, cmove, "cmove" /* addr1 addr2 u -- */
0:
	.quad dup

	.quad zbranch, 0f

	.quad push
	.quad over
	.quad cfetch
	.quad over
	.quad cstore
	.quad push
	.quad inc
	.quad pop
	.quad inc
	.quad pop
	.quad dec

	.quad branch, 0b
0:

	.quad nip
	.quad nip
	.quad drop
	.quad exit

DEFWORD head_cmove, sameq, "same?" /* addr1 addr2 u -- bool */
0:
	.quad dup
	.quad push
	.quad push
	.quad over
	.quad cfetch
	.quad over
	.quad cfetch
	.quad equals
	.quad pop
	.quad and

	.quad zbranch, 0f

	.quad push
	.quad inc
	.quad pop
	.quad inc
	.quad pop
	.quad dec

	.quad branch, 0b
0:

	.quad pop
	.quad nip
	.quad nip
	.quad zequals
	.quad exit

DEFWORD head_sameq, write, "write"
	.quad lit, 1
	.quad tickoutput
	.quad count
	.quad sys_write
	.quad syscall
	.quad drop
	.quad lit, 0
	.quad tickoutput
	.quad cstore
	.quad exit

DEFWORD head_write, bye, "bye"
	.quad write
	.quad lit, 0
	.quad dup
	.quad dup
	.quad sys_exit
	.quad syscall

DEFWORD head_bye, read, "read"
	.quad lit, 0
	.quad lit, input+1
	.quad lit, 0xFF
	.quad sys_read
	.quad syscall
	.quad dup
	.quad zequals

	.quad zbranch, 0f

	.quad bye

0:
	.quad tickinput
	.quad cstore
	.quad lit, input+1
	.quad mark
	.quad store
	.quad exit

DEFWORD head_read, keyq, "key?" /* -- bool */
	.quad mark
	.quad fetch
	.quad tickinput
	.quad count
	.quad add
	.quad uless
	.quad exit

DEFWORD head_keyq, key, "key" /* -- char */
	.quad mark
	.quad fetch
	.quad cfetch
	.quad dup
	.quad lit, '\n'
	.quad equals

	.quad zbranch, 0f

	.quad drop
	.quad lit, ' '

0:
	.quad exit

DEFWORD head_key, advance, "advance"
	.quad mark
	.quad fetch
	.quad inc
	.quad mark
	.quad store
	.quad exit

DEFWORD head_advance, emit, "emit" /* char -- */
	.quad tickoutput
	.quad count
	.quad add
	.quad cstore
	.quad tickoutput
	.quad cfetch
	.quad inc
	.quad dup
	.quad tickoutput
	.quad cstore
	.quad lit, 0xFF
	.quad equals

	.quad zbranch, 0f

	.quad write

0:
	.quad exit

DEFWORD head_emit, type, "type" /* addr u -- */
0:
	.quad dup

	.quad zbranch, 0f

	.quad push
	.quad dup
	.quad cfetch
	.quad emit
	.quad inc
	.quad pop
	.quad dec

	.quad branch, 0b
0:

	.quad nip
	.quad drop
	.quad exit

DEFWORD head_type, accumulate, "accumulate" /* char -- */
	.quad tickbuffer
	.quad count
	.quad dup
	.quad inc
	.quad tickbuffer
	.quad cstore
	.quad add
	.quad cstore
	.quad exit

DEFWORD head_accumulate, parse, "parse"
0:
	.quad keyq
	.quad invert

	.quad zbranch, 1f

	.quad read

1:
	.quad key
	.quad lit, ' '
	.quad equals

	.quad zbranch, 0f

	.quad advance

	.quad branch, 0b
0:

	.quad lit, 0
	.quad tickbuffer
	.quad cstore

0:
	.quad keyq
	.quad invert

	.quad zbranch, 1f

	.quad read

1:
	.quad key
	.quad over
	.quad equals
	.quad invert

	.quad zbranch, 0f

	.quad key
	.quad accumulate
	.quad advance

	.quad branch, 0b
0:

	.quad drop
	.quad exit

DEFWORD head_parse, word, "word"
	.quad lit, ' '
	.quad parse
	.quad tickbuffer
	.quad cfetch
	.quad lit, IMMEDIATE-1
	.quad uless
	.quad invert

	.quad zbranch, 0f

	.quad lit, IMMEDIATE-1
	.quad tickbuffer
	.quad cstore

0:
	.quad exit

DEFWORD head_word, digitq, "digit?" /* char -- u bool */
	.quad lit, '0'
	.quad sub
	.quad lit, 9
	.quad over
	.quad less

	.quad zbranch, 0f

	.quad lit, 'A'-'0'-10
	.quad sub
	.quad dup
	.quad lit, 10
	.quad less
	.quad or

0:
	.quad dup
	.quad base
	.quad fetch
	.quad uless
	.quad exit

DEFWORD head_digitq, natural, "natural" /* addr u1 -- u2 u3 */
	.quad push
	.quad lit, 0
	.quad pop

0:
	.quad push
	.quad over
	.quad cfetch
	.quad digitq
	.quad pop
	.quad dup
	.quad push
	.quad and

	.quad zbranch, 0f

	.quad push
	.quad base
	.quad fetch
	.quad mul
	.quad pop
	.quad add
	.quad push
	.quad inc
	.quad pop
	.quad pop
	.quad dec

	.quad branch, 0b
0:

	.quad drop
	.quad nip
	.quad pop
	.quad exit

DEFWORD head_natural, number, "number" /* addr u1 -- n u2 */
	.quad over
	.quad cfetch
	.quad lit, '-'
	.quad equals

	.quad zbranch, 0f

	.quad push
	.quad inc
	.quad pop
	.quad dec
	.quad natural
	.quad push
	.quad negate
	.quad pop

	.quad branch, 1f
0:

	.quad natural

1:
	.quad exit

DEFWORD head_number, find, "find" /* -- 0 | addr */
	.quad latest

0:
	.quad fetch
	.quad dup
	.quad zequals
	.quad over

	.quad zbranch, 1f

	.quad over
	.quad cell
	.quad add
	.quad cfetch
	.quad lit, IMMEDIATE-1
	.quad and
	.quad tickbuffer
	.quad cfetch
	.quad equals

	.quad zbranch, 1f

	.quad drop
	.quad dup
	.quad lit, CELL+1
	.quad add
	.quad tickbuffer
	.quad count
	.quad sameq

1:
	.quad zbranch, 0b

	.quad exit

DEFWORD head_find, save, "save"
	.quad tickbuffer
	.quad here
	.quad fetch
	.quad over
	.quad cfetch
	.quad inc
	.quad dup
	.quad aligned
	.quad here
	.quad fetch
	.quad add
	.quad here
	.quad store
	.quad cmove
	.quad exit

DEFWORD head_save, tocode, ">code" /* addr1 -- addr2 */
	.quad cell
	.quad add
	.quad count
	.quad lit, IMMEDIATE-1
	.quad and
	.quad add
	.quad aligned
	.quad exit

DEFWORD head_tocode, comma, "," /* x -- */
	.quad here
	.quad fetch
	.quad dup
	.quad cell
	.quad add
	.quad here
	.quad store
	.quad store
	.quad exit

DEFWORD head_comma, lbracket, "[", IMMEDIATE
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
	.quad rbracket
	.quad here
	.quad fetch
	.quad current
	.quad store
	.quad latest
	.quad fetch
	.quad comma
	.quad word
	.quad save
	.quad lit, code_docolon
	.quad comma
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
	.quad word
	.quad find
	.quad dup

	.quad zbranch, 0f

	.quad tocode

0:
	.quad exit

DEFWORD head_tick, literal, "literal", IMMEDIATE /* x -- */
	.quad lit, lit
	.quad comma
	.quad comma
	.quad exit

DEFINE head_literal, interpret, "interpret"
	.quad word
	.quad find
	.quad dup

	.quad zbranch, 2f

	.quad dup
	.quad cell
	.quad add
	.quad cfetch
	.quad immediate_flag
	.quad and
	.quad state
	.quad fetch
	.quad invert
	.quad or

	.quad zbranch, 0f

	.quad tocode
	.quad execute

	.quad branch, 1f
0:

	.quad tocode
	.quad comma

1:

	.quad branch, 3f
2:

	.quad drop
	.quad tickbuffer
	.quad count
	.quad number

	.quad zbranch, 0f

	.quad drop
	.quad tickbuffer
	.quad count
	.quad type
	.quad lit, '?'
	.quad emit

	.quad branch, 3f
0:

	.quad state
	.quad fetch

	.quad zbranch, 3f

	.quad literal

3:
	.quad write
	.quad branch, interpret

.bss

input:
	.skip 0x100

output:
	.skip 0x100

buffer:
	.skip 0x100

	.skip 0x100
dstack:

vocabulary:
	.skip 0x3000
