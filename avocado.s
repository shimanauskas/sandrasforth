; rax - top of data stack, syscall number.
; rbx - threaded code pointer.
; rcx - temporary, syscall scratch.
; rdx - syscall argument.

; rsi - syscall argument.
; rdi - syscall argument.
; rbp - data stack pointer.
; rsp - code stack pointer.

; r8  - unused, syscall argument.
; r9  - unused, syscall argument.
; r10 - unused, syscall argument.
; r11 - unused, syscall scratch.

; r12 - unused.
; r13 - unused.
; r14 - unused.
; r15 - unused.

%include "platform.s"

%ifdef LINUX
	%define SYSREAD  0
	%define SYSWRITE 1
	%define SYSEXIT	 60
%elif MACOS
	%define SYSREAD  0x2000003
	%define SYSWRITE 0x2000004
	%define SYSEXIT  0x2000001
%endif

%define STDIN  0
%define STDOUT 1

%define CELL 8
%define PAGE 0x1000
%define FLAG 0x8000000000000000
%define LINK 0

%macro STRING 2
align CELL
%1:
	%strlen LENGTH %2
	dq LENGTH
	db %2
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

%macro TWODROP 0
	mov rax, [rbp+CELL]
	add rbp, CELL*2
%endmacro

%macro NIP 0
	add rbp, CELL
%endmacro

%macro NEXT 0
	add rbx, CELL
	jmp [rbx]
%endmacro

section .text

global start

start:
	mov rbp, stack+PAGE ; Our stacks grow downward.
	mov rax, -1 ; Top-of-stack magic value aids in debugging.

	mov rbx, main.x
	jmp [rbx]

lit:
	DUP
	add rbx, CELL
	mov rax, [rbx]
	NEXT

enter:
	add rbx, CELL
	push rbx
	mov rbx, [rbx]
	jmp [rbx]

exit:
	pop rbx
	NEXT

jump:
	add rbx, CELL
	mov rbx, [rbx]
	jmp [rbx]

; A -

jump0:
	test rax, rax
	DROP 1
	jz jump
	add rbx, CELL
	NEXT

; A - A A

DEFINE dup, "dup"
	DUP
	NEXT

; A -

DEFINE drop, "drop"
	DROP 1
	NEXT

; A B - B

DEFINE nip, "nip"
	NIP
	NEXT

; A B - A B A

DEFINE over, "over"
	DUP
	mov rax, [rbp+CELL]
	NEXT

; A -

DEFINE push, "push"
	push rax
	DROP 1
	NEXT

; - A

DEFINE pull, "pull"
	DUP
	pop rax
	NEXT

; A - B

DEFINE shiftLeft, "shiftLeft"
	shl rax, 1
	NEXT

; A - B

DEFINE shiftRight, "shiftRight"
	shr rax, 1
	NEXT

; A - B

DEFINE not, "!"
	not rax
	NEXT

; A B - C

DEFINE and, "and"
	and rax, [rbp]
	NIP
	NEXT

; A B - C

DEFINE or, "or"
	or rax, [rbp]
	NIP
	NEXT

; A B - C

DEFINE xor, "xor"
	xor rax, [rbp]
	NIP
	NEXT

; A - B

DEFINE negate, "negate"
	neg rax
	NEXT

; A B - C

DEFINE sub, "-"
	neg rax
	jmp add.x ; Fallthrough?

; A B - C

DEFINE add, "+"
	add rax, [rbp]
	NIP
	NEXT

DEFINE mul, "*"			
	mov rcx, rax
	DROP 1
	mul rcx
	DUP
	mov rax, rdx
	NEXT

DEFINE div, "/"
	mov rcx, rax
	mov rdx, [rbp]
	lea rbp, [rbp+CELL]
	mov rax, [rbp]
	div rcx
	mov [rbp], rdx
	NEXT

DEFINE fetch, "fetch"
	mov rax, [rax]
	NEXT

DEFINE store, "store"
	mov rcx, [rbp]
	mov [rax], rcx
	TWODROP
	NEXT

DEFINE fetchByte, "fetchByte"
	movzx rax, byte [rax]
	NEXT

DEFINE storeByte, "storeByte"
	mov cl, [rbp]
	mov [rax], cl
	TWODROP
	NEXT

DEFINE read, "read"
	mov rdx, rax ; Size.
	mov rsi, [rbp] ; Address.
	mov rdi, STDIN
	mov rax, SYSREAD
	syscall
	NEXT

DEFINE write, "write"
	mov rdx, rax ; Size.
	mov rsi, [rbp] ; Address.
	mov rdi, STDOUT
	mov rax, SYSWRITE
	syscall
	TWODROP
	NEXT

DEFINE bye, "bye"
	xor rdi, rdi
	mov rax, SYSEXIT
	syscall

section .data

DEFINE execute, "execute"
	dq push.x
	dq exit

DEFINE less, "less"
	dq over.x, over.x
	dq xor.x
	dq enter, negative.x

.if:
	dq jump0, .then

	dq drop.x
	dq jump, negative.x

.then:
	dq sub.x
	dq jump, negative.x ; Fallthrough?

DEFINE negative, "negative"
	dq lit, FLAG
	dq and.x
	dq jump, bool.x ; Fallthrough?

DEFINE bool, "bool"
	dq dup.x

.if:
	dq jump0, .then

	dq dup.x
	dq xor.x
	dq not.x

.then:
	dq exit

DEFINE more, "more"
	dq lit, 1
	dq add.x
	dq enter, less.x
	dq not.x
	dq exit

DEFINE equals, "equals"
	dq xor.x
	dq jump, isZero.x ; Fallthrough?

DEFINE isZero, "isZero"
	dq enter, bool.x
	dq not.x
	dq exit

DEFINE fetchBaseAbsol, "fetchBaseAbsol"
	dq lit, base
	dq fetch.x
	dq jump, absol.x ; Fallthrough?

DEFINE absol, "absol"
	dq dup.x
	dq enter, negative.x

.if:
	dq jump0, .then

	dq negate.x

.then:
	dq exit

DEFINE range, "range"
	dq push.x
	dq over.x
	dq push.x
	dq enter, less.x
	dq not.x
	dq pull.x, pull.x
	dq enter, less.x
	dq and.x
	dq exit

DEFINE getChar, "getChar"
	dq lit, inputPtr
	dq fetch.x
	dq lit, inputTop
	dq fetch.x
	dq enter, less.x

.if0:
	dq jump0, .then0

	dq lit, inputPtr
	dq fetch.x
	dq dup.x
	dq lit, 1
	dq add.x
	dq lit, inputPtr
	dq store.x
	dq fetchByte.x
	dq exit

.then0:
	dq lit, input
	dq lit, PAGE
	dq read.x
	dq dup.x
	dq lit, 1
	dq enter, less.x

.if1:
	dq jump0, .then1

	dq bye.x

.then1:
	dq over.x
	dq add.x
	dq lit, inputTop
	dq store.x
	dq lit, inputPtr
	dq store.x
	dq jump, getChar.x

DEFINE newLine, "newLine"
	dq lit, `\n`
	dq jump, putChar.x ; Fallthrough?

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

	dq lit, `\n`
	dq enter, equals.x

	dq lit, outputPtr
	dq fetch.x
	dq lit, output+PAGE
	dq enter, equals.x

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

DEFINE strLoad, "strLoad"
	dq dup.x
	dq push.x
	dq lit, CELL
	dq add.x
	dq pull.x
	dq fetch.x
	dq exit

; stringA stringB - comparisonValue

DEFINE strCmp, "strCmp"
	dq dup.x
	dq fetch.x
	dq push.x

	; Compare string sizes.

	dq over.x, fetch.x
	dq over.x, fetch.x
	dq enter, equals.x

.if:
	dq jump0, .then

	dq lit, CELL
	dq add.x
	dq push.x

	dq lit, CELL
	dq add.x
	dq pull.x

	dq pull.x

.begin:
	dq dup.x
	dq push.x, push.x

	dq over.x, fetchByte.x
	dq over.x, fetchByte.x
	dq enter, equals.x

	dq pull.x
	dq and.x

.while:
	dq jump0, .do

	dq lit, 1
	dq add.x
	dq push.x

	dq lit, 1
	dq add.x
	dq pull.x

	dq pull.x
	dq lit, 1
	dq sub.x

	dq jump, .begin
.do:

.then:
	dq pull.x
	dq nip.x, nip.x ; Nip string pointers.
	dq exit

DEFINE strSkip, "strSkip"
	dq enter, strLoad.x
	dq add.x
	dq lit, CELL-1
	dq add.x
	dq lit, ~(CELL-1)
	dq and.x
	dq exit

DEFINE getToken, "getToken"

; The following loop reads input and discards spaces.
; It returns the first non-space character.

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

	dq lit, token+CELL
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

	dq drop.x ; Drop last getChar's return value.

	dq pull.x
	dq lit, token+CELL
	dq sub.x
	dq lit, token
	dq store.x
	dq exit

; - result unconvertedChars

DEFINE literal, "literal"
	dq lit, token
	dq enter, strLoad.x

	dq over.x
	dq fetchByte.x
	dq lit, '-'
	dq enter, equals.x

	dq over.x
	dq lit, 1
	dq xor.x

	dq lit, base
	dq fetch.x
	dq enter, negative.x

	dq and.x
	dq and.x

.if:
	dq jump0, .then

	dq lit, 1
	dq sub.x
	dq push.x

	dq lit, 1
	dq add.x
	dq pull.x

	dq enter, natural.x
	dq push.x
	dq negate.x
	dq pull.x
	dq exit

.then:
	dq jump, natural.x ; Fallthrough?

; tokenAddr tokenLength - result unconvertedChars

DEFINE natural, "natural"
	dq push.x
	dq lit, 0

.begin:
	dq over.x
	dq fetchByte.x
	dq lit, '0'
	dq sub.x

	dq enter, fetchBaseAbsol.x
	dq lit, 11
	dq enter, less.x

.if0:
	dq jump0, .else0

	dq lit, 0
	dq enter, fetchBaseAbsol.x
	dq enter, range.x

	dq jump, .then0
.else0:

	dq dup.x
	dq lit, 0
	dq lit, 10
	dq enter, range.x

	dq over.x
	dq lit, 'A'-'0'
	dq sub.x
	dq lit, 0
	dq enter, fetchBaseAbsol.x
	dq lit, 10
	dq sub.x
	dq enter, range.x

	dq or.x
	dq nip.x

.then0:
	dq pull.x
	dq dup.x
	dq push.x
	dq and.x

.while:
	dq jump0, .do

	dq enter, fetchBaseAbsol.x
	dq mul.x
	dq drop.x

	dq over.x
	dq fetchByte.x
	dq lit, '0'
	dq sub.x

	dq dup.x
	dq lit, 10
	dq enter, more.x

.if1:
	dq jump0, .then1

	dq lit, 'A'-'0'-10
	dq sub.x

.then1:
	dq add.x

	dq pull.x
	dq lit, 1
	dq sub.x
	dq push.x

	dq push.x
	dq lit, 1
	dq add.x
	dq pull.x

	dq jump, .begin
.do:

	dq nip.x
	dq pull.x
	dq exit

DEFINE bin, "bin", FLAG
	dq lit, 2
	dq lit, base
	dq store.x
	dq exit

DEFINE dec, "dec", FLAG
	dq lit, -10
	dq lit, base
	dq store.x
	dq exit

DEFINE hexdec, "hexdec", FLAG
	dq lit, 16
	dq lit, base
	dq store.x
	dq exit

DEFINE semiColon, ";", FLAG
	dq lit, exit
	dq enter, compile.x
	dq enter, code
	dq pull.x, drop.x
	dq exit

DEFINE find, "find"
	dq lit, last

.begin:
	dq fetch.x
	dq lit, ~FLAG
	dq and.x
	dq dup.x, dup.x

.if:
	dq jump0, .then

	dq lit, token
	dq enter, strCmp.x

.then:
.while:
	dq jump0, .do

	dq enter, strSkip.x

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

DEFINE interpret, "interpret"
	dq enter, getToken.x
	dq enter, literal.x
	dq enter, isZero.x

.if0:
	dq jump0, .then0

	; Compile converted literal.

	dq lit, lit
	dq enter, compile.x
	dq enter, compile.x
	dq jump, interpret.x

.then0:
	dq drop.x

	dq enter, find.x
	dq dup.x

.if1:
	dq jump0, .then1

	dq enter, strSkip.x
	dq dup.x
	dq fetch.x
	dq enter, negative.x ; Check for immediate flag.

.if2:
	dq jump0, .then2

	dq enter, execute.x
	dq jump, interpret.x

.then2:
	dq dup.x

	dq lit, execute
	dq enter, less.x
	dq not.x

.if3:
	dq jump0, .then3

	dq lit, enter
	dq enter, compile.x

.then3:
	dq lit, CELL
	dq add.x
	dq enter, compile.x
	dq jump, interpret.x

.then1:
	dq drop.x

	; Flush input.

	dq lit, input
	dq lit, inputTop
	dq store.x

	dq lit, token
	dq enter, strLoad.x
	dq write.x

	dq lit, '?'
	dq enter, putChar.x
	dq jump, newLine.x

DEFINE main, "main"
	dq lit, prompt
	dq enter, strLoad.x
	dq write.x

	dq enter, interpret.x

	dq lit, code
	dq lit, codePtr
	dq store.x
	dq jump, main.x

; The following definitions should be moved out of core once we can compile them at runtime.

DEFINE while, "while", FLAG
	dq jump, if.x ; Fallthrough?

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

DEFINE signed, "signed"
	dq dup.x
	dq enter, negative.x

.if:
	dq jump0, .then

	dq negate.x

	dq lit, '-'
	dq enter, putChar.x

.then:
	dq jump, unsigned.x

DEFINE unsigned, "unsigned"
	dq lit, 0
	dq enter, fetchBaseAbsol.x
	dq div.x
	dq dup.x

.if0:
	dq jump0, .then0

	dq dup.x

.then0:
.if1:
	dq jump0, .then1

	dq enter, unsigned.x

.then1:
	dq dup.x
	dq lit, 10
	dq enter, less.x

.if2:
	dq jump0, .else2

	dq lit, '0'

	dq jump, .then2

.else2:
	dq lit, 10
	dq sub.x
	dq lit, 'A'

.then2:
	dq add.x
	dq jump, putChar.x

DEFINE number, "."
	dq lit, base
	dq fetch.x
	dq enter, negative.x

.if:
	dq jump0, .then

	dq enter, signed.x
	dq jump, newLine.x

.then:
	dq enter, unsigned.x
	dq jump, newLine.x

base:
	dq -10

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

STRING prompt, "# "

section .bss

align PAGE

stack:
	resb PAGE

input:
	resb PAGE

output:
	resb PAGE

token:
	resb PAGE

code:
	resb PAGE
