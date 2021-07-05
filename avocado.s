; rax	top of data stack / syscall number
; rbx	temporary
; rcx	unused / destroyed upon syscall
; rdx	syscall

; rsi	syscall
; rdi	syscall
; rbp	data stack
; rsp	code stack

; r8	syscall
; r9	syscall
; r10	syscall
; r11	unused / destroyed upon syscall

; r12	code pointer
; r13	unused
; r14	unused
; r15	unused

; Our stacks grow downward.

%include "platform.s"

%ifdef LINUX
	%define SYS_read  0
	%define SYS_write 1
	%define SYS_exit 60
%elif MACOS
	%define SYS_read  0x2000003
	%define SYS_write 0x2000004
	%define SYS_exit  0x2000001
%endif

%define CELL 8
%define PAGE 1000h
%define FLAG 8000000000000000h
%define LINK 0

%macro STRING 2
align CELL
%1:
	%strlen LENGTH %2
	dq LENGTH
	db %2, 0
align CELL
%endmacro

%macro DEFINE 2-3 0
	STRING %1, %2
	dq LINK+%3
	%define LINK %1
.x:
%endmacro

%macro DUP 0
	sub rbp, CELL
	mov [rbp], rax
%endmacro

%macro DROP 1
	mov rax, [rbp+CELL*(%1-1)]
	lea rbp, [rbp+CELL*%1]
%endmacro

%macro NEXT 0
	add r12, CELL
	jmp [r12]
%endmacro

section .text

global start

start:
	mov rbp, stack
	xor rax, rax

	mov r12, main.x
	jmp [r12]

lit:
	DUP
	add r12, CELL
	mov rax, [r12]
	NEXT

enter:
	add r12, CELL
	push r12
	mov r12, [r12]
	jmp [r12]

exit:
	pop r12
	NEXT

jump:
	add r12, CELL
	mov r12, [r12]
	jmp [r12]

jump0:
	test rax, rax
	DROP 1
	jz jump
	add r12, CELL
	NEXT

DEFINE dup, "dup"
	DUP
	NEXT

DEFINE drop, "drop"
	DROP 1
	NEXT

DEFINE nip, "nip"		; A, B -- B
	add rbp, CELL
	NEXT

DEFINE over, "over"
	DUP
	mov rax, [rbp+CELL]
	NEXT

DEFINE push, "push"
	push rax
	DROP 1
	NEXT

DEFINE pull, "pull"
	DUP
	pop rax
	NEXT

DEFINE shiftLeft, "shiftLeft"
	shl rax, 1
	NEXT

DEFINE shiftRight, "shiftRight"
	shr rax, 1
	NEXT

DEFINE rotateLeft, "rotateLeft"
	rol rax, 1
	NEXT

DEFINE rotateRight, "rotateRight"
	ror rax, 1
	NEXT

DEFINE not, "!"
	not rax
	NEXT

DEFINE and, "and"
	and [rbp], rax
	DROP 1
	NEXT

DEFINE or, "or"
	or [rbp], rax
	DROP 1
	NEXT

DEFINE xor, "xor"
	xor [rbp], rax
	DROP 1
	NEXT

DEFINE add, "+"
	add [rbp], rax
	DROP 1
	NEXT

DEFINE sub, "-"
	sub [rbp], rax
	DROP 1
	NEXT

DEFINE mul, "*"
	mov rbx, rax
	DROP 1
	mul rbx
	DUP
	mov rax, rdx
	NEXT

DEFINE div, "/"
	mov rbx, rax
	mov rdx, [rbp]
	lea rbp, [rbp+CELL]
	mov rax, [rbp]
	div rbx
	mov [rbp], rdx
	NEXT

DEFINE fetch, "fetch"
	mov rax, [rax]
	NEXT

DEFINE store, "store"
	mov rbx, [rbp]
	mov [rbx], rax
	DROP 2
	NEXT

DEFINE fetchByte, "fetchByte"
	mov al, [rax]
	and rax, 0xFF
	NEXT

DEFINE storeByte, "storeByte"
	mov rbx, [rbp]
	mov [rbx], al
	DROP 2
	NEXT

DEFINE read, "read"
	mov rdx, rax		; Count.
	mov rsi, [rbp]		; Address.
	mov rdi, 0		; stdin
	mov rax, SYS_read	; sys_read
	syscall
	NEXT

DEFINE write, "write"
	mov rdx, rax		; Count.
	mov rsi, [rbp]		; Address.
	mov rdi, 1		; stdout
	mov rax, SYS_write	; sys_write
	syscall
	DROP 2
	NEXT

DEFINE bye, "bye"
	xor rdi, rdi
	mov rax, SYS_exit
	syscall

section .data

DEFINE execute, "execute"
	dq push.x
	dq exit

DEFINE negate, "negate"
	dq not.x
	dq lit, 1
	dq add.x
	dq exit

DEFINE bool, "bool"
	dq dup.x

.if:
	dq jump0, .then

	dq dup.x
	dq xor.x
	dq not.x

.then:
	dq exit

DEFINE isZero, "isZero"
	dq enter
	dq bool.x
	dq not.x
	dq exit

DEFINE negative, "negative"
	dq lit, FLAG
	dq and.x
	dq jump, bool.x

DEFINE less, "less"
	dq over.x
	dq over.x
	dq xor.x
	dq enter, negative.x

.if:
	dq jump0, .else

	dq drop.x

	dq jump, .then
.else:

	dq sub.x

.then:
	dq jump, negative.x

DEFINE more, "more"
	dq lit, 1
	dq add.x
	dq enter, less.x
	dq not.x
	dq exit

DEFINE string, "string"
	dq dup.x
	dq push.x
	dq lit, CELL
	dq add.x
	dq pull.x
	dq fetch.x
	dq exit

DEFINE interleave, "interleave"		; A, B, C, D -- A, C, B, D
	dq push.x
	dq over.x
	dq push.x
	dq nip.x
	dq pull.x
	dq pull.x
	dq exit

DEFINE stringCompare, "stringCompare"	; string1Address, string1Size, string2Address, string2Size -- comparisonValue
	dq enter
	dq interleave.x
	dq xor.x

.if:	; If string sizes are not equal
	dq jump0, .then

	; Drop the string addresses and return error
	dq drop.x
	dq drop.x
	dq lit, -1
	dq exit

.then:
.begin:
	dq over.x
	dq fetchByte.x
	dq over.x
	dq fetchByte.x

	dq xor.x
	dq enter, isZero.x

	dq over.x
	dq fetchByte.x
	dq and.x

.while:
	dq jump0, .do

	dq lit, 1
	dq add.x
	dq push.x

	dq lit, 1
	dq add.x
	dq pull.x

	dq jump, .begin
.do:

	dq drop.x
	dq fetchByte.x
	dq exit

DEFINE stringTerminate, "stringTerminate"	; stringPointer, stringSize --
	dq add.x
	dq lit, 0
	dq storeByte.x
	dq exit

DEFINE compile, "compile"
	dq push.x
	dq lit, codePointer
	dq fetch.x
	dq pull.x
	dq store.x

	dq lit, codePointer
	dq lit, codePointer
	dq fetch.x
	dq lit, CELL
	dq add.x
	dq store.x
	dq exit

DEFINE range, "range"
	dq push.x
	dq over.x
	dq push.x
	dq enter
	dq less.x
	dq not.x
	dq pull.x
	dq pull.x
	dq enter
	dq more.x
	dq not.x
	dq and.x
	dq exit

DEFINE skipWhitespace, "skipWhitespace"
.begin:
	dq dup.x
	dq fetchByte.x
	dq lit, 1
	dq lit, 20h
	dq enter, range.x

.while:
	dq jump0, .do

	dq lit, 1
	dq add.x

	dq jump, .begin
.do:

	dq exit

DEFINE extractToken, "extractToken"
	dq push.x
	dq lit, output+CELL
	dq pull.x

.repeat:
	dq over.x
	dq over.x
	dq fetchByte.x
	dq storeByte.x

	dq lit, 1
	dq add.x
	dq push.x
	dq lit, 1
	dq add.x
	dq pull.x

	dq dup.x
	dq fetchByte.x
	dq lit, `!`
	dq lit, `~`
	dq enter, range.x
	dq not.x

.until:
	dq jump0, .repeat

	dq push.x
	dq lit, output+CELL
	dq sub.x
	dq push.x
	dq lit, output
	dq pull.x
	dq store.x
	dq pull.x

	dq lit, output
	dq enter, string.x
	dq jump, stringTerminate.x

DEFINE isLiteralUnsigned, "isLiteralUnsigned"
	dq dup.x
	dq fetchByte.x

.if:
	dq jump0, .then

.begin:
	dq dup.x
	dq fetchByte.x

	dq dup.x
	dq lit, `0`
	dq sub.x
	dq lit, 0
	dq lit, base
	dq fetch.x
	dq lit, 1
	dq sub.x
	dq enter, range.x
	dq and.x

.while:
	dq jump0, .do

	dq lit, 1
	dq add.x

	dq jump, .begin
.do:

	dq fetchByte.x
	dq jump, isZero.x

.then:
	dq drop.x
	dq lit, 0
	dq exit

DEFINE isLiteral, "isLiteral"
	dq lit, output+CELL

	dq dup.x
	dq fetchByte.x
	dq lit, `-`
	dq sub.x
	dq enter, isZero.x

.if:
	dq jump0, .then

	dq lit, 1
	dq add.x

.then:
	dq jump, isLiteralUnsigned.x

DEFINE literal, "literal"
	dq lit, 1		; Sign

	dq lit, output+CELL
	dq dup.x
	dq fetchByte.x
	dq lit, `-`
	dq sub.x
	dq enter, isZero.x

.if1:
	dq jump0, .then1

	dq lit, 1
	dq add.x

	dq push.x
	dq enter, negate.x	; Negate sign
	dq pull.x

.then1:
	dq lit, 0
	dq push.x

.begin:
	dq dup.x
	dq fetchByte.x

.while:
	dq jump0, .do

	dq pull.x
	dq lit, base
	dq fetch.x
	dq mul.x

.if2:
	dq jump0, .then2

	dq drop.x		; Drop erroneous conversion
	dq drop.x		; Drop token buffer address

	; Report an overflow error and restart from the beginning

	dq lit, output
	dq enter, string.x
	dq write.x

	dq lit, overflow
	dq enter, string.x
	dq write.x

	dq jump, main.x

.then2:
	dq over.x
	dq fetchByte.x
	dq lit, `0`
	dq sub.x
	dq add.x

	dq push.x
	dq lit, 1
	dq add.x

	dq jump, .begin
.do:

	dq drop.x		; Drop token buffer address
	dq pull.x		; Pull literal

	dq mul.x		; Multiply by sign
	dq drop.x

	dq lit, lit
	dq enter, compile.x
	dq enter, compile.x
	dq jump, token.x	; Take care of the next token

DEFINE naturalRecurse, "naturalRecurse"
	dq lit, 0
	dq lit, base
	dq fetch.x
	dq div.x
	dq dup.x

.if1:
	dq jump0, .then1

	dq dup.x

.then1:
.if2:
	dq jump0, .then2

	dq enter, naturalRecurse.x

.then2:
	dq lit, output
	dq fetch.x
	dq add.x

	dq lit, `0`
	dq add.x

	dq push.x
	dq lit, output+CELL
	dq pull.x

	dq storeByte.x

	dq lit, output
	dq dup.x
	dq fetch.x
	dq lit, 1
	dq add.x
	dq store.x
	dq exit

DEFINE natural, "natural"
	dq lit, output
	dq lit, 0
	dq store.x

	dq enter, naturalRecurse.x

	dq lit, output
	dq enter, string.x
	dq write.x
	dq exit

DEFINE number, "."
	dq dup.x
	dq enter, negative.x

.if:
	dq jump0, .then

	dq enter, negate.x

	dq lit, output
	dq lit, `-`
	dq storeByte.x

	dq lit, output
	dq lit, 1
	dq write.x

.then:
	dq jump, natural.x

DEFINE binary, "binary", FLAG
	dq lit, base
	dq lit, 2
	dq store.x
	dq exit

DEFINE decimal, "decimal", FLAG
	dq lit, base
	dq lit, 10
	dq store.x
	dq exit

DEFINE if, "if", FLAG
	dq lit, jump0
	dq enter, compile.x
	dq lit, codePointer
	dq fetch.x
	dq lit, 0
	dq jump, compile.x

DEFINE else, "else", FLAG
	dq lit, jump
	dq enter, compile.x
	dq lit, codePointer
	dq fetch.x
	dq push.x
	dq lit, 0
	dq enter, compile.x
	dq enter, then.x
	dq pull.x
	dq exit

DEFINE then, "then", FLAG
	dq lit, codePointer
	dq fetch.x
	dq store.x
	dq exit

DEFINE begin, "begin", FLAG
	dq lit, codePointer
	dq fetch.x
	dq exit

DEFINE while, "while", FLAG
	dq jump, if.x

DEFINE do, "do", FLAG
	dq lit, codePointer
	dq fetch.x
	dq lit, CELL*2
	dq add.x
	dq store.x

	dq lit, jump
	dq enter, compile.x
	dq jump, compile.x

DEFINE stringSkip, "stringSkip"
	dq enter, string.x
	dq lit, ~(CELL-1)
	dq and.x
	dq lit, CELL
	dq add.x
	dq add.x
	dq exit

DEFINE find, "find"
.begin:
	dq fetch.x
	dq lit, ~FLAG
	dq and.x
	dq dup.x
	dq dup.x

.if:
	dq jump0, .then

	dq enter, string.x
	dq lit, output
	dq enter, string.x
	dq enter, stringCompare.x

.then:
.while:
	dq jump0, .do

	dq enter, stringSkip.x

	dq jump, .begin
.do:

	dq exit

DEFINE token, "token"
	dq lit, inputPointer
	dq lit, inputPointer
	dq fetch.x

	dq enter, skipWhitespace.x

	dq dup.x
	dq fetchByte.x

	dq push.x
	dq store.x
	dq pull.x

.if1:
	dq jump0, .then1

	dq lit, inputPointer
	dq lit, inputPointer
	dq fetch.x

	dq enter, extractToken.x
	dq store.x

	dq enter, isLiteral.x
	dq enter, isZero.x
	dq jump0, literal.x

	dq lit, last
	dq enter, find.x
	dq dup.x

.if4:
	dq jump0, .then4

	dq enter, stringSkip.x
	dq dup.x
	dq fetch.x
	dq enter, negative.x		; Check for immediate flag.

.if5:
	dq jump0, .else5

	dq enter, execute.x

	dq jump, .then5
.else5:

	dq dup.x

	dq lit, execute
	dq enter, less.x
	dq not.x

.if6:
	dq jump0, .then6

	dq lit, enter
	dq enter, compile.x

.then6:
	dq lit, CELL
	dq add.x
	dq enter, compile.x

.then5:
	dq jump, token.x

.then4:
	dq drop.x

	dq lit, output
	dq enter, string.x
	dq write.x

	dq lit, error
	dq enter, string.x
	dq write.x

	dq jump, main.x

.then1:
	dq lit, exit
	dq enter, compile.x
	dq enter, code
	dq jump, main.x

DEFINE main, "main"
	dq lit, prompt
	dq enter, string.x
	dq write.x

	dq lit, inputPointer

	dq lit, input
	dq lit, PAGE

	dq read.x

	dq over.x
	dq enter, stringTerminate.x

	dq store.x

	dq lit, codePointer
	dq lit, code
	dq store.x

	dq jump, token.x

base:
	dq 10

last:
	dq LINK

STRING error, ` ?\n`
STRING overflow, ` !\n`
STRING prompt, `# `

section .bss

align PAGE

	resb PAGE
stack:

input:
	resb PAGE

output:
	resb PAGE

code:
	resb PAGE

codePointer:
	resb CELL

inputPointer:
	resb CELL
