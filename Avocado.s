; rax	top of data stack / syscall number
; rbx	temporary
; rcx	unused (destroyed upon syscall?)
; rdx	syscall

; rsi	syscall
; rdi	syscall
; rbp	data stack
; rsp	code stack

; r8	syscall
; r9	syscall
; r10	syscall
; r11	unused

; r12	code pointer
; r13	code word
; r14	unused
; r15	unused

%define	CELL	8
%define	PAGE	4096
%define FLAG	0x8000000000000000

%macro	DUP	0
	db	0x48, 0x8D, 0x6D, 0x08	; lea	rbp,	[rbp+CELL]
	db	0x48, 0x89, 0x45, 0x00	; mov	[rbp],	rax
%endmacro

%macro	DROP	0
	db	0x48, 0x8B, 0x45, 0x00	; mov	rax,	[rbp]
	db	0x48, 0x8D, 0x6D, 0xF8	; lea	rbp,	[rbp-CELL]
%endmacro

%macro	NEXT	0
	add	r12,	CELL
	mov	r13,	[r12]
	jmp	r13
%endmacro

section	.text

global	_main

_main:
	mov	rbp,	stack
	xor	rax,	rax
	mov	r12,	start.x
	mov	r13,	[r12]
	jmp	r13

lit:
	DUP
	add	r12,	CELL
	mov	rax,	[r12]
	NEXT

enter:
	add	r12,	CELL
	push	r12
	mov	r12,	[r12]
	mov	r13,	[r12]
	jmp	r13

exit:
	pop	r12
	NEXT

jump:
	add	r12,	CELL
	mov	r12,	[r12]
	mov	r13,	[r12]
	jmp	r13

branch:
	test rax,	rax
	DROP
	jnz jump
	add r12,	CELL
	NEXT

align	CELL

if:
	dq	1|FLAG
	dq	`?`
	dq	0

.x:
	test	rax,	rax
	DROP
	jz	exit
	NEXT

align	CELL

dup:
	dq	3|FLAG
	dq	`dup`
	dq	if

.x:
	DUP
	NEXT

align	CELL

drop:
	dq	4|FLAG
	dq	`drop`
	dq	dup

.x:
	DROP
	NEXT

align	CELL

over:
	dq	4|FLAG
	dq	`over`
	dq	drop

.x:
	db	0x48, 0x8D, 0x6D, 0x08	; lea	rbp,	[rbp+CELL]
	db	0x48, 0x89, 0x45, 0x00	; mov	[rbp],	rax
	db	0x48, 0x8B, 0x45, 0xF8	; mov	rax,	[rbp-CELL]
	NEXT

align	CELL

push:
	dq	4|FLAG
	dq	`push`
	dq	over

.x:
	push	rax
	DROP
	NEXT

align	CELL

pull:
	dq	4|FLAG
	dq	`pull`
	dq	push

.x:
	DUP
	pop	rax
	NEXT


align	CELL

shiftLeft:
	dq	9|FLAG
	dq	`shiftLeft`
	dq	pull

.x:
	db	0x48, 0xD1, 0xE0	; shl	rax,	1
	NEXT

align	CELL

shiftRight:
	dq	10|FLAG
	dq	`shiftRight`
	dq	shiftLeft

.x:
	db	0x48, 0xD1, 0xE8	; shr	rax,	1
	NEXT

align	CELL

rotateLeft:
	dq	10|FLAG
	dq	`rotateLeft`
	dq	shiftRight

.x:
	db	0x48, 0xD1, 0xC0	; rol	rax,	1
	NEXT

align	CELL

rotateRight:
	dq	11|FLAG
	dq	`rotateRight`
	dq	rotateLeft

.x:
	db	0x48, 0xD1, 0xC8	; ror	rax,	1
	NEXT

align	CELL

not:
	dq	1|FLAG
	dq	`!`
	dq	rotateRight

.x:
	db	0x48, 0xF7, 0xD0	; not	rax
	NEXT

align	CELL

and:
	dq	3|FLAG
	dq	`and`
	dq	not

.x:
	db	0x48, 0x21, 0x45, 0x00	; and	[rbp],	rax
	DROP
	NEXT

align	CELL

or:
	dq	2|FLAG
	dq	`or`
	dq	and

.x:
	db	0x48, 0x09, 0x45, 0x00	; or	[rbp],	rax
	DROP
	NEXT

align	CELL

xor:
	dq	1|FLAG
	dq	`^`
	dq	or

.x:
	db	0x48, 0x31, 0x45, 0x00	; xor	[rbp],	rax
	DROP
	NEXT

align	CELL

add:
	dq	1|FLAG
	dq	`+`
	dq	xor

.x:
	db	0x48, 0x01, 0x45, 0x00	; add	[rbp],	rax
	DROP
	NEXT

align	CELL

sub:
	dq	1|FLAG
	dq	`-`
	dq	add

.x:
	db	0x48, 0x29, 0x45, 0x00	; sub	[rbp],	rax
	DROP
	NEXT

align	CELL

mul:
	dq	1|FLAG
	dq	`*`
	dq	sub

.x:
	mov	rbx,	rax
	DROP
	mul	rbx
	DUP
	mov	rax,	rdx
	NEXT

align	CELL

div:
	dq	1|FLAG
	dq	`/`
	dq	mul

.x:
	mov	rbx,	rax
	DROP
	mov	rdx,	rax
	DROP
	div	rbx
	DUP
	mov	rax,	rdx
	NEXT

align	CELL

fetchByte:
	dq	9|FLAG
	dq	`fetchByte`
	dq	div

.x:
	mov	al,	[rax]
	and	rax,	0xFF
	NEXT	

align	CELL

fetch:
	dq	5|FLAG
	dq	`fetch`
	dq	fetchByte

.x:
	mov	rax,	[rax]
	NEXT

align	CELL

storeByte:
	dq	9|FLAG
	dq	`storeByte`
	dq	fetch

.x:
	mov	rbx,	[rbp]
	mov	[rbx],	al
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

align	CELL

store:
	dq	5|FLAG
	dq	`store`
	dq	storeByte

.x:
	mov	rbx,	[rbp]
	mov	[rbx],	rax
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

align	CELL

read:
	dq	4|FLAG
	dq	`read`
	dq	store

.x:
	mov	rdx,	rax		; Count.
	mov	rsi,	[rbp]		; Address.
	mov	rdi,	0		; stdin
	mov	rax,	0x2000003	; sys_read
	syscall
	NEXT

align	CELL

write:
	dq	5|FLAG
	dq	`write`
	dq	read

.x:
	mov	rdx,	rax		; Count.
	mov	rsi,	[rbp]		; Address.
	mov	rdi,	1		; stdout
	mov	rax,	0x2000004	; sys_write
	syscall
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

align	CELL

emit:
	dq	4|FLAG
	dq	`emit`
	dq	write

.x:
	mov	rdx,	1		; Count.
	DUP
	mov	rsi,	rbp		; Address.
	mov	rdi,	1		; stdout
	mov	rax,	0x2000004	; sys_write
	syscall
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

section	.data

align	CELL

negate:
	dq	6
	dq	`negate`
	dq	emit

.x:
	dq	not.x
	dq	lit
	dq	1
	dq	add.x
	dq	exit

align	CELL

swap:
	dq	4
	dq	`swap`
	dq	negate

.x:
	dq	over.x
	dq	push.x
	dq	push.x
	dq	drop.x
	dq	pull.x
	dq	pull.x
	dq	exit

bool:
	dq	4
	dq	`bool`
	dq	swap

.x:
	dq	dup.x
	dq	if.x
	dq	dup.x
	dq	xor.x
	dq	not.x
	dq	exit

addresslower:
	dq	12
	dq	`addresslower`
	dq	bool

.x:
	dq	lit
	dq	CELL-1
	dq	and.x
	dq	exit

addressupper:
	dq	12
	dq	`addressupper`
	dq	addresslower

.x:
	dq	lit
	dq	~(CELL-1)
	dq	and.x
	dq	exit

addresssplit:
	dq	12
	dq	`addresssplit`
	dq	addressupper

.x:
	dq	dup.x
	dq	enter
	dq	addresslower.x
	dq	push.x
	dq	enter
	dq	addressupper.x
	dq	pull.x
	dq	exit

string:
	dq	6
	dq	`string`
	dq	addresssplit

.x:
	dq	dup.x
	dq	push.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	pull.x
	dq	fetch.x
	dq	exit

mshiftl:
	dq	7
	dq	`mshiftl`
	dq	string

.x:
	dq	enter
	dq	.loop
	dq	drop.x
	dq	exit

.loop:
	dq	dup.x
	dq	if.x
	dq	push.x
	dq	shiftLeft.x
	dq	pull.x
	dq	lit
	dq	1
	dq	sub.x
	dq	jump
	dq	.loop

mshiftr:
	dq	7
	dq	`mshiftr`
	dq	mshiftl

.x:
	dq	enter
	dq	.loop
	dq	drop.x
	dq	exit

.loop:
	dq	dup.x
	dq	if.x
	dq	push.x
	dq	shiftRight.x
	dq	pull.x
	dq	lit
	dq	1
	dq	sub.x
	dq	jump
	dq	.loop

mrotl:
	dq	5
	dq	`mrotl`
	dq	mshiftr

.x:
	dq	enter
	dq	.loop
	dq	drop.x
	dq	exit

.loop:
	dq	dup.x
	dq	if.x
	dq	push.x
	dq	rotateLeft.x
	dq	pull.x
	dq	lit
	dq	1
	dq	sub.x
	dq	jump
	dq	.loop

mrotr:
	dq	5
	dq	`mrotr`
	dq	mrotl

.x:
	dq	enter
	dq	.loop
	dq	drop.x
	dq	exit

.loop:
	dq	dup.x
	dq	if.x
	dq	push.x
	dq	rotateRight.x
	dq	pull.x
	dq	lit
	dq	1
	dq	sub.x
	dq	jump
	dq	.loop

less:
	dq	4
	dq	`less`
	dq	mrotr

.x:
	dq	sub.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	enter
	dq	bool.x
	dq	exit

terminate:
	dq	9
	dq	`terminate`
	dq	mrotr

.x:
	dq	lit
	dq	0
	dq	storeByte.x
	dq	exit

strcmp:
	dq	6
	dq	`strcmp`
	dq	terminate

.x:
	dq	push.x
	dq	enter
	dq	swap.x
	dq	pull.x
	dq	enter
	dq	.if_equal
	dq	push.x
	dq	drop.x
	dq	drop.x
	dq	pull.x
	dq	exit

.if_equal:
	dq	sub.x
	dq	dup.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	if.x
	dq	drop.x
	dq	enter
	dq	.loop
	dq	drop.x
	dq	fetchByte.x
	dq	pull.x
	dq	drop.x
	dq	exit

.loop:
	dq	over.x
	dq	over.x
	dq	dup.x
	dq	fetchByte.x
	dq	push.x
	dq	fetchByte.x
	dq	push.x
	dq	fetchByte.x
	dq	pull.x
	dq	xor.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	pull.x
	dq	and.x
	dq	if.x
	dq	lit
	dq	1
	dq	add.x
	dq	push.x
	dq	lit
	dq	1
	dq	add.x
	dq	pull.x
	dq	jump
	dq	.loop

start:
	dq	5
	dq	`start`
	dq	strcmp

.x:
	dq	lit
	dq	prompt
	dq	enter
	dq	string.x
	dq	write.x

	dq	lit
	dq	input
	dq	lit
	dq	PAGE

	dq	read.x

	dq	over.x
	dq	add.x
	dq	enter
	dq	terminate.x

	dq	jump
	dq	token.x

compile:
	dq	7
	dq	`compile`
	dq	start

.x:
	dq	push.x
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	pull.x
	dq	store.x

	dq	lit
	dq	codePointer
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	store.x
	dq	exit

skipWhitespace:
	dq	14
	dq	`skipWhitespace`
	dq	compile

.x:
	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	1
	dq	over.x
	dq	lit
	dq	0x20+1
	dq	enter
	dq	less.x
	dq	push.x
	dq	enter
	dq	less.x
	dq	not.x
	dq	pull.x
	dq	and.x
	dq	if.x
	dq	lit
	dq	1
	dq	add.x
	dq	jump
	dq	skipWhitespace.x

definitionEnd:
	dq	13
	dq	`definitionEnd`
	dq	skipWhitespace

.x:
	dq	drop.x

	dq	lit
	dq	exit
	dq	enter
	dq	compile.x

	dq	enter
	dq	code

	dq	lit
	dq	codePointer
	dq	lit
	dq	code
	dq	store.x

	dq	jump
	dq	start.x

extractToken:
	dq	12
	dq	`extractToken`
	dq	definitionEnd

.x:
	dq	over.x
	dq	over.x

	dq	fetchByte.x
	dq	storeByte.x

	dq	lit
	dq	1
	dq	add.x
	dq	push.x
	dq	lit
	dq	1
	dq	add.x
	dq	pull.x

	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	0x21
	dq	over.x
	dq	lit
	dq	0x7E+1
	dq	enter
	dq	less.x
	dq	push.x
	dq	enter
	dq	less.x
	dq	not.x
	dq	pull.x
	dq	and.x

	dq	if.x
	dq	jump
	dq	.x

; Extract next token from the input.

token:
	dq	5
	dq	`token`
	dq	extractToken

.x:
	dq	enter
	dq	skipWhitespace.x
	
	dq	dup.x
	dq	fetchByte.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	branch
	dq	definitionEnd.x

	dq	push.x

	dq	lit
	dq	output
	dq	lit
	dq	output+CELL

	dq	pull.x

	dq	enter
	dq	extractToken.x

	dq	push.x

	dq	dup.x
	dq	enter
	dq	terminate.x

	dq	lit
	dq	output+CELL
	dq	sub.x
	dq	store.x

	dq	pull.x

	dq	jump
	dq	literal.x

literal:
	dq	7
	dq	`literal`
	dq	token

.x:
	dq	lit
	dq	1

	dq	lit
	dq	0
	dq	push.x

	dq	lit
	dq	output+CELL

	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	'-'
	dq	sub.x
	dq	branch
	dq	.loop

	dq	lit
	dq	1
	dq	add.x

	dq	push.x
	dq	enter
	dq	negate.x
	dq	pull.x

	dq	dup.x
	dq	fetchByte.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	branch
	dq	.exit

.loop:
	dq	dup.x
	dq	fetchByte.x

	dq	dup.x
	dq	branch
	dq	.literal

.compile:
	dq	drop.x
	dq	drop.x
	dq	lit
	dq	lit
	dq	enter
	dq	compile.x

	dq	pull.x
	dq	mul.x
	dq	drop.x
	dq	enter	
	dq	compile.x
	dq	jump
	dq	token.x

.literal:
	dq	lit
	dq	'0'
	dq	sub.x

	dq	dup.x
	dq	lit
	dq	0
	dq	lit
	dq	base
	dq	fetch.x
	dq	div.x
	dq	drop.x
	dq	branch
	dq	.drop

	dq	pull.x
	dq	lit
	dq	base
	dq	fetch.x
	dq	mul.x
	dq	branch
	dq	find.error
	dq	add.x
	dq	push.x

	dq	lit
	dq	1
	dq	add.x

	dq	jump
	dq	.loop

.drop:
	dq	drop.x
.exit:
	dq	drop.x
	dq	drop.x
	dq	pull.x
	dq	drop.x
	dq	jump
	dq	find.x

native:
	dq	4
	dq	`natv`
	dq	literal

.x:
	dq	lit
	dq	link
	dq	fetch.x
	dq	fetch.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	enter
	dq	bool.x
	dq	not.x

	dq	if.x

	dq	lit
	dq	enter

	dq	enter
	dq	compile.x

	dq	exit

skipstring:
	dq	10
	dq	`skipstring`
	dq	native

.x:
	dq	enter
	dq	string.x

	dq	lit
	dq	~FLAG
	dq	and.x

	dq	enter
	dq	addresssplit.x

	dq	push.x
	dq	add.x
	dq	pull.x

	dq	if.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	exit

find:
	dq	4
	dq	`find`
	dq	skipstring

.x:
	dq	lit
	dq	link
	dq	lit
	dq	number
	dq	store.x

.find:
	dq	enter
	dq	.not_found
	dq	enter
	dq	.found
	dq	lit
	dq	link
	dq	lit
	dq	link
	dq	fetch.x
	dq	enter
	dq	skipstring.x
	dq	fetch.x
	dq	store.x
	dq	jump
	dq	.find

.not_found:
	dq	lit
	dq	link
	dq	fetch.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	if.x
	dq	drop.x
.error:
	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	write.x
	dq	lit
	dq	error
	dq	enter
	dq	string.x
	dq	write.x
	dq	jump
	dq	start.x

.found:
	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	lit
	dq	link
	dq	fetch.x
	dq	enter
	dq	string.x
	dq	lit
	dq	FLAG
	dq	not.x
	dq	and.x
	dq	enter
	dq	strcmp.x
	dq	enter
	dq	bool.x
	dq	not.x

	dq	if.x

	dq	enter
	dq	native.x

	dq	lit
	dq	link
	dq	fetch.x

	dq	enter
	dq	skipstring.x

	dq	lit
	dq	CELL
	dq	add.x

	dq	enter
	dq	compile.x

	dq	jump
	dq	token.x

number:
	dq	1
	dq	`.`
	dq	find

.signed:
	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	branch
	dq	.negative

.natural:
	dq	dup.x
	dq	lit
	dq	0
	dq	lit
	dq	base
	dq	fetch.x
	dq	div.x
	dq	push.x
	dq	dup.x
	dq	branch
	dq	.recurse
	dq	drop.x

.print:
	dq	drop.x
	dq	pull.x
	dq	lit
	dq	'0'
	dq	add.x
	dq	emit.x
	dq	exit

.recurse:
	dq	enter
	dq	.natural
	dq	jump
	dq	.print

.negative:
	dq	enter
	dq	negate.x
	dq	lit
	dq	'-'
	dq	emit.x
	dq	jump
	dq	.natural

base:
	dq	10

link:
	dq	0

codePointer:
	dq	code

error:
	dq	3
	dq	` ?\n`

prompt:
	dq	2
	dq	`# `

section	.bss

align	PAGE

stack:
	resb	PAGE

input:
	resb	PAGE

output:
	resb	PAGE

code:
	resb	PAGE
