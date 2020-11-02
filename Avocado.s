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
%define	LINK	0

%macro	DEFINE	2-3 0
align	CELL
%1:
%strlen	LENGTH	%2
	dq	LENGTH
	db	%2,	0
align	CELL
	dq	LINK+%3
%define	LINK	%1
.x:
%endmacro

%macro	DUP	0
	add	rbp,	CELL
	mov	[rbp],	rax
%endmacro

%macro	DROP	1
	mov	rax,	[rbp-CELL*(%1-1)]
	sub	rbp,	CELL*%1
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
	mov	rbx,	rax
	DROP	1
	test	rbx,	rbx
	jz	jump
	add	r12,	CELL
	NEXT

DEFINE	dup,	"dup"
	DUP
	NEXT

DEFINE	drop,	"drop"
	DROP	1
	NEXT

DEFINE	over,	"over"
	lea	rbp,	[rbp+CELL]
	mov	[rbp],	rax
	mov	rax,	[rbp-CELL]
	NEXT

DEFINE	push,	"push"
	push	rax
	DROP	1
	NEXT

DEFINE	pull,	"pull"
	DUP
	pop	rax
	NEXT

DEFINE	shiftLeft,	"shiftLeft"
	shl	rax,	1
	NEXT

DEFINE	shiftRight,	"shiftRight"
	shr	rax,	1
	NEXT

DEFINE	rotateLeft,	"rotateLeft"
	rol	rax,	1
	NEXT

DEFINE	rotateRight,	"rotateRight"
	ror	rax,	1
	NEXT

DEFINE	not,	"!"
	not	rax
	NEXT

DEFINE	and,	"and"
	and	[rbp],	rax
	DROP	1
	NEXT

DEFINE	or,	"or"
	or	[rbp],	rax
	DROP	1
	NEXT

DEFINE	xor,	"xor"
	xor	[rbp],	rax
	DROP	1
	NEXT

DEFINE	add,	"+"
	add	[rbp],	rax
	DROP	1
	NEXT

DEFINE	sub,	"-"
	sub	[rbp],	rax
	DROP	1
	NEXT

DEFINE	mul,	"*"
	mov	rbx,	rax
	DROP	1
	mul	rbx
	DUP
	mov	rax,	rdx
	NEXT

DEFINE	div,	"/"
	mov	rbx,	rax
	DROP	1
	mov	rdx,	rax
	DROP	1
	div	rbx
	DUP
	mov	rax,	rdx
	NEXT

DEFINE	fetch,	"fetch"
	mov	rax,	[rax]
	NEXT

DEFINE	store,	"store"
	mov	rbx,	[rbp]
	mov	[rbx],	rax
	DROP	2
	NEXT

DEFINE	fetchByte,	"fetchByte"
	mov	al,	[rax]
	and	rax,	0xFF
	NEXT	

DEFINE	storeByte,	"storeByte"
	mov	rbx,	[rbp]
	mov	[rbx],	al
	DROP	2
	NEXT

DEFINE	read,	"read"
	mov	rdx,	rax		; Count.
	mov	rsi,	[rbp]		; Address.
	mov	rdi,	0		; stdin
	mov	rax,	2000003h	; sys_read
	syscall
	NEXT

DEFINE	write,	"write"
	mov	rdx,	rax		; Count.
	mov	rsi,	[rbp]		; Address.
	mov	rdi,	1		; stdout
	mov	rax,	2000004h	; sys_write
	syscall
	DROP	2
	NEXT

section	.data

DEFINE	execute,	"execute"
	dq	push.x
	dq	exit

DEFINE	negate,	"negate"
	dq	not.x
	dq	lit
	dq	1
	dq	add.x
	dq	exit

DEFINE	bool,	"bool"
	dq	dup.x

.if:
	dq	jump0
	dq	.then

	dq	dup.x
	dq	xor.x
	dq	not.x

.then:
	dq	exit

DEFINE	isZero,	"isZero"
	dq	enter
	dq	bool.x
	dq	not.x
	dq	exit

DEFINE	negative,	"negative"
	dq	lit
	dq	FLAG
	dq	and.x
	dq	enter
	dq	bool.x
	dq	exit

DEFINE	less,	"less"
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

DEFINE	more,	"more"
	dq	lit
	dq	1
	dq	add.x
	dq	enter
	dq	less.x
	dq	not.x
	dq	exit

DEFINE	string,	"string"
	dq	dup.x
	dq	push.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	pull.x
	dq	fetch.x
	dq	exit

DEFINE	stringCompare,	"stringCompare"
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
	dq	isZero.x

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

DEFINE	compile,	"compile"
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

DEFINE	range,	"range"
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

DEFINE	skipWhitespace,	"skipWhitespace"
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

DEFINE	extractToken,	"extractToken"
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

DEFINE	isLiteralUnsigned,	"isLiteralUnsigned"
	dq	dup.x

.begin:
	dq	dup.x
	dq	fetchByte.x
	
	dq	dup.x
	dq	lit
	dq	`0`
	dq	sub.x
	dq	lit
	dq	0
	dq	lit
	dq	base
	dq	fetch.x
	dq	lit
	dq	1
	dq	sub.x
	dq	enter
	dq	range.x
	dq	and.x

.while:
	dq	jump0
	dq	.do

	dq	lit
	dq	1
	dq	add.x

	dq	jump
	dq	.begin
.do:

	dq	fetchByte.x
	dq	enter
	dq	isZero.x
	dq	exit

DEFINE	literalUnsigned,	"literalUnsigned"
	dq	enter
	dq	isLiteralUnsigned.x

.if:
	dq	jump0
	dq	.then

	dq	lit
	dq	0
	dq	dup.x
	dq	push.x

.begin:
	dq	over.x
	dq	fetchByte.x
	dq	pull.x
	dq	dup.x
	dq	push.x
	dq	enter
	dq	isZero.x
	dq	and.x

.while:
	dq	jump0
	dq	.do

	dq	lit
	dq	base
	dq	fetch.x
	dq	mul.x
	dq	pull.x
	dq	drop.x
	dq	push.x

	dq	over.x
	dq	fetchByte.x
	dq	lit
	dq	`0`
	dq	sub.x
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
	dq	pull.x
	dq	exit

.then:
	dq	lit
	dq	FLAG
	dq	exit

DEFINE	literal,	"literal"
	dq	lit
	dq	output+CELL

	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	`-`
	dq	sub.x

.if:
	dq	jump0
	dq	.else

	dq	enter
	dq	literalUnsigned.x

	dq	push.x
	dq	dup.x
	dq	enter
	dq	negative.x

	dq	jump
	dq	.then

.else:
	dq	lit
	dq	1
	dq	add.x

	dq	enter
	dq	literalUnsigned.x

	dq	push.x
	dq	enter
	dq	negate.x
	dq	dup.x
	dq	enter
	dq	negative.x
	dq	not.x

.then:
	dq	lit
	dq	~FLAG
	dq	and.x
	dq	pull.x
	dq	or.x
	dq	exit

DEFINE	skipString,	"skipString"
	dq	enter
	dq	string.x
	dq	lit
	dq	~(CELL-1)
	dq	and.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	add.x
	dq	exit

DEFINE	find,	"find"
.begin:
	dq	fetch.x
	dq	lit
	dq	~FLAG
	dq	and.x
	dq	dup.x
	dq	dup.x

.if:
	dq	jump0
	dq	.then

	dq	enter
	dq	string.x
	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	enter
	dq	stringCompare.x

.then:
.while:
	dq	jump0
	dq	.do

	dq	enter
	dq	skipString.x

	dq	jump
	dq	.begin
.do:

	dq	exit

DEFINE	if,	"if",	FLAG
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

DEFINE	else,	"else",	FLAG
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

DEFINE	then,	"then",	FLAG
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	store.x
	dq	exit

DEFINE	begin,	"begin",	FLAG
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	exit

DEFINE	while,	"while",	FLAG
	dq	jump
	dq	if.x

DEFINE	do,	"do",	FLAG
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

DEFINE	binary,	"binary",	FLAG
	dq	lit
	dq	base
	dq	lit
	dq	2
	dq	store.x
	dq	exit

DEFINE	decimal,	"decimal",	FLAG
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

	dq	drop.x

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

	dq	lit
	dq	execute
	dq	enter
	dq	less.x
	dq	not.x

.if3:
	dq	jump0
	dq	.then3

	dq	lit
	dq	enter

	dq	enter
	dq	compile.x

.then3:
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
	dq	dup.x

	dq	lit
	dq	0
	dq	enter
	dq	less.x

.if4:
	dq	jump0
	dq	.then4

	dq	drop.x
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

.then4:
	dq	lit
	dq	0
	dq	enter
	dq	more.x

.if5:
	dq	jump0
	dq	.then5

	dq	drop.x
	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	write.x
	dq	lit
	dq	overflow
	dq	enter
	dq	string.x
	dq	write.x
	dq	exit

.then5:
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

overflow:
	dq	3
	dq	` !\n`

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

