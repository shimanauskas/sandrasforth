; rax	syscall number, top of data stack
; rbx	temporary
; rcx	unused, syscall scratch
; rdx	syscall argument

; rsi	syscall argument
; rdi	syscall argument
; rbp	data stack pointer
; rsp	code stack pointer

; r8	unused, syscall argument
; r9	unused, syscall argument
; r10	unused, syscall argument
; r11	unused, syscall scratch

; r12	threaded code pointer
; r13	unused
; r14	unused
; r15	unused

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
	mov rbp, stack+PAGE	; Our stacks grow downward
	mov rax, -1		; Top-of-stack magic value aids in debugging

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
	mov [rax], rbx
	DROP 2
	NEXT

DEFINE fetchByte, "fetchByte"
	mov al, [rax]
	and rax, 0xFF
	NEXT

DEFINE storeByte, "storeByte"
	mov bl, [rbp]
	mov [rax], bl
	DROP 2
	NEXT

DEFINE read, "read"
	mov rdx, rax		; Size
	mov rsi, [rbp]		; Address
	mov rdi, 0		; stdin
	mov rax, SYS_read
	syscall
	NEXT

DEFINE write, "write"
	mov rdx, rax		; Size
	mov rsi, [rbp]		; Address
	mov rdi, 1		; stdout
	mov rax, SYS_write
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

DEFINE getChar, "getChar"
	dq lit, inputPtr
	dq fetch.x
	dq lit, inputTop
	dq fetch.x
	dq xor.x

.if0:
	dq jump0, .then0

	dq lit, inputPtr
	dq fetch.x
	dq fetchByte.x

	dq lit, inputPtr
	dq fetch.x
	dq lit, 1
	dq add.x
	dq lit, inputPtr
	dq store.x	
	dq exit

.then0:
	dq lit, input
	dq lit, PAGE-2
	dq read.x
	dq nip.x
	dq dup.x
	dq enter, negative.x
	dq over.x
	dq enter, isZero.x
	dq or.x

.if1:
	dq jump0, .then1

	dq drop.x
	dq bye.x

.then1:
	dq lit, input
	dq add.x

	; Append a terminating token upon end of input

	dq dup.x
	dq lit, 1
	dq sub.x
	dq fetchByte.x
	dq lit, `\n`
	dq xor.x
	dq enter, isZero.x

.if2:
	dq jump0, .then2

	dq lit, ';'
	dq over.x
	dq storeByte.x
	dq lit, 1
	dq add.x

	dq lit, ' '
	dq over.x
	dq storeByte.x
	dq lit,	1
	dq add.x

.then2:
	dq lit, inputTop
	dq store.x

	dq lit, input
	dq lit, inputPtr
	dq store.x
	dq jump, getChar.x

DEFINE putChar, "putChar"
	dq dup.x
	dq lit, outputPtr
	dq fetch.x
	dq storeByte.x

	dq lit, outputPtr
	dq fetch.x
	dq lit, 1
	dq add.x
	dq lit, outputPtr
	dq store.x

	dq lit, 10
	dq xor.x
	dq enter, isZero.x

	dq lit, outputPtr
	dq fetch.x
	dq lit, output+PAGE
	dq xor.x
	dq enter, isZero.x

	dq or.x

.if:
	dq jump0, .then

	dq lit, output
	dq lit, outputPtr
	dq fetch.x
	dq lit, output
	dq sub.x
	dq write.x

	dq lit, output
	dq lit, outputPtr
	dq store.x

.then:
	dq exit

DEFINE newLine, "newLine"
	dq lit, `\n`
	dq jump, putChar.x

DEFINE string, "string"
	dq dup.x
	dq push.x
	dq lit, CELL
	dq add.x
	dq pull.x
	dq fetch.x
	dq exit

DEFINE stringCompare, "stringCompare"	; stringA, stringB -- comparisonValue

	; Compare string sizes

	dq over.x, fetch.x
	dq over.x, fetch.x
	dq xor.x

.if:
	dq jump0, .then

	; Drop string addresses, return error

	dq drop.x
	dq drop.x
	dq lit, -1
	dq exit

.then:
	dq lit, CELL
	dq add.x
	dq push.x

	dq lit, CELL
	dq add.x
	dq pull.x

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

DEFINE stringSkip, "stringSkip"
	dq enter, string.x
	dq lit, ~(CELL-1)
	dq and.x
	dq lit, CELL
	dq add.x
	dq add.x
	dq exit

DEFINE isLiteralUnsigned, "isLiteralUnsigned"
	dq dup.x
	dq fetchByte.x

.if:
	dq jump0, .then

.begin:
	dq dup.x
	dq fetchByte.x

	dq dup.x
	dq lit, '0'
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
	dq lit, bufToken+CELL

	dq dup.x
	dq fetchByte.x
	dq lit, '-'
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

	dq lit, bufToken+CELL
	dq dup.x
	dq fetchByte.x
	dq lit, '-'
	dq sub.x
	dq enter, isZero.x

.if0:
	dq jump0, .then0

	dq lit, 1
	dq add.x

	dq push.x
	dq enter, negate.x	; Negate sign
	dq pull.x

.then0:
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

.if1:
	dq jump0, .then1

	dq nip.x		; Nip token buffer address
	dq nip.x		; Nip sign

	dq lit, -1
	dq exit

.then1:
	dq over.x
	dq fetchByte.x
	dq lit, '0'
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

	dq lit, 0
	dq exit

DEFINE binary, "binary", FLAG
	dq lit, 2
	dq lit, base
	dq store.x
	dq exit

DEFINE decimal, "decimal", FLAG
	dq lit, 10
	dq lit, base
	dq store.x
	dq exit

DEFINE semiColon, ";", FLAG
	dq lit, exit
	dq enter, compile.x
	dq enter, code
	dq pull.x, drop.x
	dq jump, main.x

DEFINE find, "find"
	dq lit, last

.begin:
	dq fetch.x
	dq lit, ~FLAG
	dq and.x
	dq dup.x
	dq dup.x

.if:
	dq jump0, .then

	dq lit, bufToken
	dq enter, stringCompare.x

.then:
.while:
	dq jump0, .do

	dq enter, stringSkip.x

	dq jump, .begin
.do:

	dq exit

DEFINE compile, "compile"
	dq lit, codePtr
	dq fetch.x
	dq store.x

	dq lit, codePtr
	dq fetch.x
	dq lit, CELL
	dq add.x
	dq lit, codePtr
	dq store.x
	dq exit

DEFINE token, "token"

	; The following loop reads input and discards spaces
	; It returns the first non-space character

.begin0:
	dq enter, getChar.x
	dq dup.x
	dq lit, '!'
	dq enter, less.x

.while0:
	dq jump0, .do0

	dq drop.x

	dq jump, .begin0
.do0:

	dq lit, bufToken+CELL
	dq push.x

.begin1:
	dq dup.x
	dq lit, '!'
	dq enter, less.x
	dq not.x

.while1:
	dq jump0, .do1

	dq pull.x
	dq dup.x
	dq lit, 1
	dq add.x
	dq push.x
	dq storeByte.x

	dq enter, getChar.x

	dq jump, .begin1
.do1:

	dq drop.x		; Drop last getChar's return value

	dq pull.x
	dq lit, bufToken+CELL
	dq sub.x
	dq lit, bufToken
	dq store.x

	dq lit, 0
	dq lit, bufToken
	dq enter, string.x
	dq add.x
	dq storeByte.x

	dq enter, isLiteral.x

.if0:
	dq jump0, .then0

	dq enter, literal.x

.if1:
	dq jump0, .then1

	dq drop.x		; Drop erroneous conversion

	; Report an overflow error and start from the beginning

	dq lit, bufToken
	dq enter, string.x
	dq write.x

	dq lit, overflow
	dq enter, string.x
	dq write.x
	dq enter, newLine.x
	dq jump, main.x

.then1:

	; Compile converted literal

	dq lit, lit
	dq enter, compile.x
	dq enter, compile.x
	dq jump, token.x

.then0:
	dq enter, find.x
	dq dup.x

.if2:
	dq jump0, .then2

	dq enter, stringSkip.x
	dq dup.x
	dq fetch.x
	dq enter, negative.x	; Check for immediate flag

.if3:
	dq jump0, .then3

	dq enter, execute.x
	dq jump, token.x

.then3:
	dq dup.x

	dq lit, execute
	dq enter, less.x
	dq not.x

.if4:
	dq jump0, .then4

	dq lit, enter
	dq enter, compile.x

.then4:
	dq lit, CELL
	dq add.x
	dq enter, compile.x
	dq jump, token.x

.then2:
	dq drop.x

	dq lit, bufToken
	dq enter, string.x
	dq write.x

	dq lit, error
	dq enter, string.x
	dq write.x
	dq enter, newLine.x
	dq jump, main.x

DEFINE main, "main"
	dq lit, input
	dq lit, inputPtr
	dq over.x
	dq lit, inputTop
	dq store.x, store.x

	dq lit, prompt
	dq enter, string.x
	dq write.x

	dq lit, code
	dq lit, codePtr
	dq store.x
	dq jump, token.x

; The following definitions should be moved out of core once we can compile them at runtime

DEFINE if, "if", FLAG
	dq lit, jump0
	dq enter, compile.x
	dq lit, codePtr
	dq fetch.x
	dq lit, 0
	dq jump, compile.x

DEFINE else, "else", FLAG
	dq lit, jump
	dq enter, compile.x
	dq lit, codePtr
	dq fetch.x
	dq push.x
	dq lit, 0
	dq enter, compile.x
	dq enter, then.x
	dq pull.x
	dq exit

DEFINE then, "then", FLAG
	dq push.x
	dq lit, codePtr
	dq fetch.x
	dq pull.x
	dq store.x
	dq exit

DEFINE begin, "begin", FLAG
	dq lit, codePtr
	dq fetch.x
	dq exit

DEFINE while, "while", FLAG
	dq jump, if.x

DEFINE do, "do", FLAG
	dq push.x
	dq lit, codePtr
	dq fetch.x
	dq lit, CELL*2
	dq add.x
	dq pull.x
	dq store.x

	dq lit, jump
	dq enter, compile.x
	dq jump, compile.x

DEFINE natural, "natural"
	dq lit, 0
	dq lit, base
	dq fetch.x
	dq div.x
	dq dup.x

.if0:
	dq jump0, .then0

	dq dup.x

.then0:
.if1:
	dq jump0, .then1

	dq enter, natural.x

.then1:
	dq lit, '0'
	dq add.x
	dq jump, putChar.x

DEFINE number, "."
	dq dup.x
	dq enter, negative.x

.if:
	dq jump0, .then

	dq enter, negate.x

	dq lit, '-'
	dq enter, putChar.x

.then:
	dq enter, natural.x
	dq jump, newLine.x

base:
	dq 10

last:
	dq LINK

inputPtr:
	dq input

inputTop:
	dq input

outputPtr:
	dq output

codePtr:
	dq code

STRING error, " ?"
STRING overflow, " !"
STRING prompt, "# "

section .bss

align PAGE

stack:
	resb PAGE

input:
	resb PAGE

output:
	resb PAGE

bufToken:
	resb PAGE

code:
	resb PAGE
