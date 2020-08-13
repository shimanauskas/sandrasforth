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
%define	PAGE	1000h
%define FLAG	8000000000000000h

%macro	DUP	0
	add	rbp,	CELL
	mov	[rbp],	rax
%endmacro

%macro	DROP	0
	mov	rax,	[rbp]
	lea	rbp,	[rbp-CELL]
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

jump0:
	test rax,	rax
	DROP
	jz jump
	add r12,	CELL
	NEXT

align	CELL

dup:
	dq	3
	dq	`dup`
	dq	0

.x:
	DUP
	NEXT

align	CELL

drop:
	dq	4
	dq	`drop`
	dq	dup

.x:
	DROP
	NEXT

align	CELL

over:
	dq	4
	dq	`over`
	dq	drop

.x:
	lea	rbp,	[rbp+CELL]
	mov	[rbp],	rax
	mov	rax,	[rbp-CELL]
	NEXT

align	CELL

push:
	dq	4
	dq	`push`
	dq	over

.x:
	push	rax
	DROP
	NEXT

align	CELL

pull:
	dq	4
	dq	`pull`
	dq	push

.x:
	DUP
	pop	rax
	NEXT


align	CELL

shiftLeft:
	dq	9
	dq	`shiftLeft`
	dq	pull

.x:
	shl	rax,	1
	NEXT

align	CELL

shiftRight:
	dq	10
	dq	`shiftRight`
	dq	shiftLeft

.x:
	shr	rax,	1
	NEXT

align	CELL

rotateLeft:
	dq	10
	dq	`rotateLeft`
	dq	shiftRight

.x:
	rol	rax,	1
	NEXT

align	CELL

rotateRight:
	dq	11
	dq	`rotateRight`
	dq	rotateLeft

.x:
	ror	rax,	1
	NEXT

align	CELL

not:
	dq	1
	dq	`!`
	dq	rotateRight

.x:
	not	rax
	NEXT

align	CELL

and:
	dq	3
	dq	`and`
	dq	not

.x:
	and	[rbp],	rax
	DROP
	NEXT

align	CELL

or:
	dq	2
	dq	`or`
	dq	and

.x:
	or	[rbp],	rax
	DROP
	NEXT

align	CELL

xor:
	dq	1
	dq	`^`
	dq	or

.x:
	xor	[rbp],	rax
	DROP
	NEXT

align	CELL

add:
	dq	1
	dq	`+`
	dq	xor

.x:
	add	[rbp],	rax
	DROP
	NEXT

align	CELL

sub:
	dq	1
	dq	`-`
	dq	add

.x:
	sub	[rbp],	rax
	DROP
	NEXT

align	CELL

mul:
	dq	1
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
	dq	1
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

fetch:
	dq	5
	dq	`fetch`
	dq	div

.x:
	mov	rax,	[rax]
	NEXT

align	CELL

store:
	dq	5
	dq	`store`
	dq	fetch

.x:
	mov	rbx,	[rbp]
	mov	[rbx],	rax
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

align	CELL

fetchByte:
	dq	9
	dq	`fetchByte`
	dq	store

.x:
	mov	al,	[rax]
	and	rax,	0xFF
	NEXT	

align	CELL

storeByte:
	dq	9
	dq	`storeByte`
	dq	fetchByte

.x:
	mov	rbx,	[rbp]
	mov	[rbx],	al
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

align	CELL

read:
	dq	4
	dq	`read`
	dq	storeByte

.x:
	mov	rdx,	rax		; Count.
	mov	rsi,	[rbp]		; Address.
	mov	rdi,	0		; stdin
	mov	rax,	2000003h	; sys_read
	syscall
	NEXT

align	CELL

write:
	dq	5
	dq	`write`
	dq	read

.x:
	mov	rdx,	rax		; Count.
	mov	rsi,	[rbp]		; Address.
	mov	rdi,	1		; stdout
	mov	rax,	2000004h	; sys_write
	syscall
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

section	.data

align	CELL

execute:
	dq	7
	dq	`execute`
	dq	write

.x:
	dq	push.x
	dq	exit

negate:
	dq	6
	dq	`negate`
	dq	execute

.x:
	dq	not.x
	dq	lit
	dq	1
	dq	add.x
	dq	exit

bool:
	dq	4
	dq	`bool`
	dq	negate

.x:
	dq	dup.x

.if:
	dq	jump0
	dq	.then

	dq	dup.x
	dq	xor.x
	dq	not.x

.then:
	dq	exit

negative:
	dq	8
	dq	`negative`
	dq	bool

.x:
	dq	lit
	dq	FLAG
	dq	and.x
	dq	enter
	dq	bool.x
	dq	exit

less:
	dq	4
	dq	`less`
	dq	negative

.x:
	dq	over.x
	dq	over.x
	dq	xor.x
	dq	enter
	dq	negative.x

.if:
	dq	jump0
	dq	.else

	dq	drop.x

	dq	jump
	dq	.then	

.else:
	dq	sub.x

.then:
	dq	enter
	dq	negative.x
	dq	exit

more:
	dq	4
	dq	`more`
	dq	less

.x:
	dq	over.x
	dq	over.x
	dq	xor.x
	dq	enter
	dq	negative.x

.if:
	dq	jump0
	dq	.else

	dq	drop.x
	dq	not.x

	dq	jump
	dq	.then	

.else:
	dq	sub.x
	dq	enter
	dq	negate.x

.then:
	dq	enter
	dq	negative.x
	dq	exit

string:
	dq	6
	dq	`string`
	dq	more

.x:
	dq	dup.x
	dq	push.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	pull.x
	dq	fetch.x
	dq	exit

stringCompare:
	dq	13
	dq	`stringCompare`
	dq	string

.x:
	dq	push.x
	dq	over.x
	dq	pull.x
	dq	sub.x

.if:
	dq	jump0
	dq	.then

	dq	drop.x
	dq	drop.x
	dq	exit

.then:
	dq	push.x
	dq	drop.x
	dq	pull.x

.begin:
	dq	over.x
	dq	over.x
	dq	fetchByte.x
	dq	push.x
	dq	fetchByte.x
	dq	pull.x

	dq	xor.x
	dq	enter
	dq	bool.x
	dq	not.x

	dq	over.x
	dq	fetchByte.x
	dq	and.x

.while:
	dq	jump0
	dq	.do
	
	dq	lit
	dq	1
	dq	add.x
	dq	push.x

	dq	lit
	dq	1
	dq	add.x
	dq	pull.x

	dq	jump
	dq	.begin
.do:

	dq	drop.x
	dq	fetchByte.x
	dq	exit

compile:
	dq	7
	dq	`compile`
	dq	stringCompare

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

range:
	dq	5
	dq	`range`
	dq	compile

.x:
	dq	push.x
	dq	over.x
	dq	push.x
	dq	enter
	dq	less.x
	dq	not.x
	dq	pull.x
	dq	pull.x
	dq	enter
	dq	more.x
	dq	not.x
	dq	and.x
	dq	exit

skipWhitespace:
	dq	14
	dq	`skipWhitespace`
	dq	range

.x:
.begin:
	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	1
	dq	lit
	dq	20h
	dq	enter
	dq	range.x

.while:
	dq	jump0
	dq	.do
	
	dq	lit
	dq	1
	dq	add.x

	dq	jump
	dq	.begin
.do:

	dq	exit

extractToken:
	dq	12
	dq	`extractToken`
	dq	skipWhitespace

.x:
.begin:
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
	dq	`!`
	dq	lit
	dq	`~`
	dq	enter
	dq	range.x

.while:
	dq	jump0
	dq	.do
	
	dq	jump
	dq	.begin
.do:

	dq	exit

literal:
	dq	7
	dq	`literal`
	dq	extractToken

.x:
	dq	lit
	dq	output+CELL

	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	`-`
	dq	sub.x

.if:
	dq	jump0
	dq	.then

	dq	enter
	dq	literalUnsigned.x

	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x

	dq	exit

.then:
	dq	lit
	dq	1
	dq	add.x

	dq	enter
	dq	literalUnsigned.x

	dq	enter
	dq	negate.x

	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	enter
	dq	bool.x
	dq	not.x

	dq	exit

literalUnsigned:
	dq	15
	dq	`literalUnsigned`
	dq	literal

.x:
	dq	lit
	dq	0

.begin:
	dq	over.x
	dq	fetchByte.x

.while:
	dq	jump0
	dq	.do

	dq	over.x
	dq	fetchByte.x

	dq	lit
	dq	`0`
	dq	sub.x

	dq	lit
	dq	0

	dq	lit
	dq	base
	dq	fetch.x	
	dq	div.x

	dq	push.x
	dq	push.x

	dq	lit
	dq	base
	dq	fetch.x
	dq	mul.x

	dq	pull.x
	dq	or.x

.if:
	dq	jump0
	dq	.then

	dq	pull.x
	dq	drop.x
	dq	drop.x
	dq	drop.x
	dq	lit
	dq	-1
	dq	exit

.then:
	dq	pull.x
	dq	add.x

	dq	push.x
	dq	lit
	dq	1
	dq	add.x
	dq	pull.x

	dq	jump
	dq	.begin
.do:

	dq	push.x
	dq	drop.x
	dq	pull.x
	dq	exit

native:
	dq	6
	dq	`native`
	dq	literalUnsigned

.x:
	dq	lit
	dq	execute
	dq	enter
	dq	less.x
	dq	not.x

.if:
	dq	jump0
	dq	.then

	dq	lit
	dq	enter

	dq	enter
	dq	compile.x

.then:
	dq	exit

skipString:
	dq	10
	dq	`skipString`
	dq	native

.x:
	dq	enter
	dq	string.x

	dq	lit
	dq	0
	dq	lit
	dq	CELL
	dq	div.x

.if:
	dq	jump0
	dq	.then
	
	dq	lit
	dq	1
	dq	add.x

.then:
	dq	shiftLeft.x
	dq	shiftLeft.x
	dq	shiftLeft.x
	dq	add.x
	dq	exit

find:
	dq	4
	dq	`find`
	dq	skipString

.x:
	dq	fetch.x
	dq	lit
	dq	~FLAG
	dq	and.x
	dq	dup.x

.if0:
	dq	jump0
	dq	.then0

	dq	dup.x
	dq	enter
	dq	string.x
	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	enter
	dq	stringCompare.x

.if1:
	dq	jump0
	dq	.then1

	dq	enter
	dq	skipString.x
	dq	jump
	dq	.x

.then1:
.then0:
	dq	exit

if:
	dq	2
	dq	`if`
	dq	find+FLAG

.x:
	dq	lit
	dq	jump0
	dq	enter
	dq	compile.x
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	lit
	dq	0
	dq	enter
	dq	compile.x
	dq	exit

else:
	dq	4
	dq	`else`
	dq	if+FLAG

.x:
	dq	lit
	dq	jump
	dq	enter
	dq	compile.x
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	push.x
	dq	lit
	dq	0
	dq	enter
	dq	compile.x
	dq	enter
	dq	then.x
	dq	pull.x
	dq	exit

then:
	dq	4
	dq	`then`
	dq	else+FLAG

.x:
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	store.x
	dq	exit

loop:
	dq	1
	dq	`[`
	dq	then+FLAG

.x:
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	exit

while:
	dq	5
	dq	`while`
	dq	loop+FLAG

.x:
	dq	jump
	dq	if.x

pool:
	dq	1
	dq	`]`
	dq	while+FLAG

.x:
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	lit
	dq	CELL*2
	dq	add.x
	dq	store.x

	dq	lit
	dq	jump
	dq	enter
	dq	compile.x
	dq	enter
	dq	compile.x
	dq	exit

binary:
	dq	6
	dq	`binary`
	dq	pool+FLAG

.x:
	dq	lit
	dq	base
	dq	lit
	dq	2
	dq	store.x
	dq	exit

decimal:
	dq	7
	dq	`decimal`
	dq	binary+FLAG

.x:
	dq	lit
	dq	base
	dq	lit
	dq	10
	dq	store.x
	dq	exit

number:
	dq	1
	dq	`.`
	dq	decimal

.x:
	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x

.if:
	dq	jump0
	dq	.then

	dq	enter
	dq	negate.x

	dq	lit
	dq	output
	dq	lit
	dq	`-`
	dq	storeByte.x

	dq	lit
	dq	output
	dq	lit
	dq	1
	dq	write.x

.then:
	dq	jump
	dq	natural.x

natural:
	dq	7
	dq	`natural`
	dq	number

.x:
	dq	lit
	dq	output
	dq	lit
	dq	0
	dq	store.x

	dq	enter
	dq	.recurse

	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	write.x

	dq	exit
	
.recurse:
	dq	lit
	dq	0
	dq	lit
	dq	base
	dq	fetch.x
	dq	div.x
	dq	push.x
	dq	dup.x

.if:
	dq	jump0
	dq	.then

	dq	enter
	dq	.recurse

.then:
	dq	lit
	dq	output+CELL
	dq	lit
	dq	output
	dq	fetch.x
	dq	add.x

	dq	pull.x
	dq	lit
	dq	`0`
	dq	add.x
	dq	storeByte.x
	dq	drop.x

	dq	lit
	dq	output
	dq	dup.x
	dq	fetch.x
	dq	lit
	dq	1
	dq	add.x
	dq	store.x

	dq	exit

; Extract next token from the input.

token:
	dq	5
	dq	`token`
	dq	natural

.x:
	dq	lit
	dq	inputPointer
	dq	fetch.x

	dq	enter
	dq	skipWhitespace.x
	
	dq	dup.x
	dq	fetchByte.x

.if0:
	dq	jump0
	dq	.then0

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
	dq	lit
	dq	0
	dq	storeByte.x

	dq	lit
	dq	output+CELL
	dq	sub.x
	dq	store.x

	dq	lit
	dq	inputPointer
	dq	pull.x
	dq	store.x

	dq	lit
	dq	last

	dq	enter
	dq	find.x

	dq	dup.x

.if1:
	dq	jump0
	dq	.then1

	dq	enter
	dq	skipString.x
	dq	dup.x
	dq	fetch.x
	dq	lit
	dq	FLAG
	dq	and.x

.if2:
	dq	jump0
	dq	.else2
	
	dq	enter
	dq	execute.x

	dq	jump
	dq	.then2

.else2:
	dq	dup.x

	dq	enter
	dq	native.x

	dq	lit
	dq	CELL
	dq	add.x

	dq	enter
	dq	compile.x

.then2:
	dq	jump
	dq	token.x

.then1:
	dq	drop.x

	dq	enter
	dq	literal.x

.if3:
	dq	jump0
	dq	.then3

	dq	drop.x
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
	dq	exit

.then3:
	dq	lit
	dq	lit
	dq	enter
	dq	compile.x
	dq	enter
	dq	compile.x

	dq	jump
	dq	token.x

.then0:
	dq	drop.x

	dq	lit
	dq	exit
	dq	enter
	dq	compile.x

	dq	jump
	dq	code

start:
	dq	5
	dq	`start`
	dq	token

.x:
	dq	lit
	dq	prompt
	dq	enter
	dq	string.x
	dq	write.x

	dq	lit
	dq	inputPointer

	dq	lit
	dq	input
	dq	lit
	dq	PAGE

	dq	read.x

	dq	over.x
	dq	add.x
	dq	lit
	dq	0
	dq	storeByte.x

	dq	store.x

	dq	lit
	dq	codePointer
	dq	lit
	dq	code
	dq	store.x

	dq	enter
	dq	token.x

	dq	jump
	dq	start.x

base:
	dq	10

error:
	dq	3
	dq	` ?\n`

prompt:
	dq	2
	dq	`# `

last:
	dq	start

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

codePointer:
	resq	1

inputPointer:
	resq	1

