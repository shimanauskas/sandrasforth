; rax - top-of-stack, syscall number.
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
%1:
	%strlen LENGTH %2
	dq LENGTH
	db %2
align CELL
%endmacro

%macro DEFINE 2-3 0
head%1:
	dq LINK
	%define LINK head%1
	dq %1+%3
	STRING .name, %2
%endmacro

; A - A A

%macro DUP 0
	sub rbp, CELL
	mov [rbp], rax
%endmacro

; A -

%macro DROP 0
	mov rax, [rbp]
	add rbp, CELL
%endmacro

; A B -

%macro TWODROP 0
	mov rax, [rbp+CELL]
	add rbp, CELL*2
%endmacro

; A B - B

%macro NIP 0
	add rbp, CELL
%endmacro

; -

%macro NEXT 0
	add rbx, CELL
	jmp [rbx]
%endmacro

section .text

global start

start:
	mov rbp, stack+PAGE ; Our stacks grow downward.
	mov rax, -1 ; Top-of-stack magic value, aids in testing.

	mov rbx, main
	jmp [rbx]

; - A

lit:
	DUP
	add rbx, CELL
	mov rax, [rbx]
	NEXT

; -

enter:
	add rbx, CELL
	push rbx
	mov rbx, [rbx]
	jmp [rbx]

; -

exit:
	pop rbx
	NEXT

; -

jump:
	add rbx, CELL
	mov rbx, [rbx]
	jmp [rbx]

; A -

jump0:
	test rax, rax
	mov rax, [rbp]
	lea rbp, [rbp+CELL]
	jz jump
	add rbx, CELL
	NEXT

; A - A A

dup:
	DUP
	NEXT

; A -

drop:
	DROP
	NEXT

; A B - B

nip:
	NIP
	NEXT

; A B - A B A

over:
	DUP
	mov rax, [rbp+CELL]
	NEXT

; A -

push:
	push rax
	DROP
	NEXT

; - A

pull:
	DUP
	pop rax
	NEXT

; A - B

not:
	not rax
	NEXT

; A B - C

and:
	and rax, [rbp]
	NIP
	NEXT

; A B - C

or:
	or rax, [rbp]
	NIP
	NEXT

; A B - C

xor:
	xor rax, [rbp]
	NIP
	NEXT

; A - B

negate:
	neg rax
	NEXT

; A B - C

sub:
	neg rax

; A B - C

add:
	add rax, [rbp]
	NIP
	NEXT

mul:
	mov rcx, rax
	DROP
	mul rcx
	DUP
	mov rax, rdx
	NEXT

div:
	mov rcx, rax
	mov rdx, [rbp]
	lea rbp, [rbp+CELL]
	mov rax, [rbp]
	div rcx
	mov [rbp], rdx
	NEXT

fetch:
	mov rax, [rax]
	NEXT

store:
	mov rcx, [rbp]
	mov [rax], rcx
	TWODROP
	NEXT

bfetch:
	movzx rax, byte [rax]
	NEXT

bstore:
	mov cl, [rbp]
	mov [rax], cl
	TWODROP
	NEXT

read:
	mov rdx, rax ; Size.
	mov rsi, [rbp] ; Address.
	mov rdi, STDIN
	mov rax, SYSREAD
	syscall
	NEXT

write:
	mov rdx, rax ; Size.
	mov rsi, [rbp] ; Address.
	mov rdi, STDOUT
	mov rax, SYSWRITE
	syscall
	TWODROP
	NEXT

bye:
	xor rdi, rdi
	mov rax, SYSEXIT
	syscall

section .data

execute:
	dq push
	dq exit

; If top-of-stack not zero, duplicate it.

dupq:
	dq dup

.if:
	dq jump0, .then

	dq dup

.then:
	dq exit

less:
	dq over, over
	dq xor
	dq enter, negative

.if:
	dq jump0, .then

	dq drop
	dq jump, negative

.then:
	dq sub

negative:
	dq lit, FLAG
	dq and

bool:
	dq dup

.if:
	dq jump0, .then

	dq dup
	dq xor
	dq not

.then:
	dq exit

more:
	dq lit, 1
	dq add
	dq enter, less
	dq not
	dq exit

equals:
	dq xor

zequals:
	dq enter, bool
	dq not
	dq exit

baseFetchAbsol:
	dq lit, base
	dq fetch

absol:
	dq dup
	dq enter, negative

.if:
	dq jump0, .then

	dq negate

.then:
	dq exit

range:
	dq push
	dq over
	dq push
	dq enter, less
	dq not
	dq pull, pull
	dq enter, less
	dq and
	dq exit

bget:
	dq lit, inputPtr
	dq fetch
	dq lit, inputTop
	dq fetch
	dq enter, less

.if0:
	dq jump0, .then0

	dq lit, inputPtr
	dq fetch
	dq dup
	dq lit, 1
	dq add
	dq lit, inputPtr
	dq store
	dq bfetch
	dq exit

.then0:
	dq lit, input
	dq lit, PAGE
	dq read
	dq dup
	dq lit, 1
	dq enter, less

.if1:
	dq jump0, .then1

	dq bye

.then1:
	dq over
	dq add
	dq lit, inputTop
	dq store
	dq lit, inputPtr
	dq store
	dq jump, bget

line:
	dq lit, `\n`

bput:
	dq dup
	dq lit, outputPtr
	dq fetch
	dq bstore

	dq lit, outputPtr
	dq fetch
	dq lit, 1
	dq add
	dq lit, outputPtr
	dq store

	dq lit, `\n`
	dq enter, equals

	dq lit, outputPtr
	dq fetch
	dq lit, output+PAGE
	dq enter, equals

	dq or

.if:
	dq jump0, .then

	dq lit, output
	dq lit, outputPtr
	dq fetch
	dq lit, output
	dq sub
	dq write

	dq lit, output
	dq lit, outputPtr
	dq store

.then:
	dq exit

strLoad:
	dq dup
	dq push
	dq lit, CELL
	dq add
	dq pull
	dq fetch
	dq exit

; stringA stringB - comparisonValue

strCmp:
	dq dup
	dq fetch
	dq push

	; Compare string sizes.

	dq over, fetch
	dq over, fetch
	dq enter, equals

.if:
	dq jump0, .then

	dq lit, CELL
	dq add
	dq push

	dq lit, CELL
	dq add
	dq pull

	dq pull

.begin:
	dq dup
	dq push, push

	dq over, bfetch
	dq over, bfetch
	dq enter, equals

	dq pull
	dq and

.while:
	dq jump0, .do

	dq lit, 1
	dq add
	dq push

	dq lit, 1
	dq add
	dq pull

	dq pull
	dq lit, 1
	dq sub

	dq jump, .begin
.do:

.then:
	dq pull
	dq nip, nip ; Nip string pointers.
	dq exit

getToken:

; The following loop reads input and discards spaces.
; It returns the first non-space character.

.begin0:
	dq enter, bget
	dq dup
	dq lit, '!'
	dq enter, less

.while0:
	dq jump0, .do0

	dq drop

	dq jump, .begin0
.do0:

	dq lit, token+CELL
	dq push

.begin1:
	dq dup
	dq lit, '!'
	dq enter, less
	dq not

.while1:
	dq jump0, .do1

	dq pull
	dq dup
	dq lit, 1
	dq add
	dq push
	dq bstore

	dq enter, bget

	dq jump, .begin1
.do1:

	dq drop ; Drop last bget's return value.

	dq pull
	dq lit, token+CELL
	dq sub
	dq lit, token
	dq store
	dq exit

; - result unconvertedChars

literal:
	dq lit, token
	dq enter, strLoad

	dq over
	dq bfetch
	dq lit, '-'
	dq enter, equals

	dq over
	dq lit, 1
	dq xor

	dq lit, base
	dq fetch
	dq enter, negative

	dq and
	dq and

.if:
	dq jump0, .then

	dq lit, 1
	dq sub
	dq push

	dq lit, 1
	dq add
	dq pull

	dq enter, natural
	dq push
	dq negate
	dq pull
	dq exit

.then:

; tokenAddr tokenLength - result unconvertedChars

natural:
	dq push
	dq lit, 0

.begin:
	dq over
	dq bfetch
	dq lit, '0'
	dq sub

	dq enter, baseFetchAbsol
	dq lit, 11
	dq enter, less

.if0:
	dq jump0, .else0

	dq lit, 0
	dq enter, baseFetchAbsol
	dq enter, range

	dq jump, .then0
.else0:

	dq dup
	dq lit, 0
	dq lit, 10
	dq enter, range

	dq over
	dq lit, 'A'-'0'
	dq sub
	dq lit, 0
	dq enter, baseFetchAbsol
	dq lit, 10
	dq sub
	dq enter, range

	dq or
	dq nip

.then0:
	dq pull
	dq dup
	dq push
	dq and

.while:
	dq jump0, .do

	dq enter, baseFetchAbsol
	dq mul
	dq drop

	dq over
	dq bfetch
	dq lit, '0'
	dq sub

	dq dup
	dq lit, 10
	dq enter, more

.if1:
	dq jump0, .then1

	dq lit, 'A'-'0'-10
	dq sub

.then1:
	dq add

	dq pull
	dq lit, 1
	dq sub
	dq push

	dq push
	dq lit, 1
	dq add
	dq pull

	dq jump, .begin
.do:

	dq nip
	dq pull
	dq exit

bin:
	dq lit, 2
	dq lit, base
	dq store
	dq exit

dec:
	dq lit, -10
	dq lit, base
	dq store
	dq exit

hexdec:
	dq lit, 16
	dq lit, base
	dq store
	dq exit

semiColon:
	dq lit, exit
	dq enter, compile
	dq enter, code
	dq pull, drop
	dq exit

find:
	dq lit, last

.begin:
	dq fetch
	dq dup, dup

.if:
	dq jump0, .then

	dq lit, CELL*2
	dq add
	dq lit, token
	dq enter, strCmp

.then:
	dq enter, zequals

	dq jump0, .begin
.repeat:

	dq exit

compile:
	dq lit, codePtr
	dq fetch
	dq store

	dq lit, codePtr
	dq fetch
	dq lit, CELL
	dq add
	dq lit, codePtr
	dq store
	dq exit

interpret:
	dq enter, getToken
	dq enter, find
	dq enter, dupq

.if0:
	dq jump0, .then0

	dq lit, CELL
	dq add
	dq fetch

	dq dup
	dq enter, negative
	dq push

	dq lit, ~FLAG
	dq and
	dq pull

.if1:
	dq jump0, .then1

	dq lit, CELL
	dq sub
	dq enter, execute
	dq jump, interpret

.then1:
	dq dup
	dq lit, execute
	dq enter, less
	dq not

.if2:
	dq jump0, .then2

	dq lit, enter
	dq enter, compile

.then2:
	dq enter, compile
	dq jump, interpret

.then0:
	dq enter, literal

.if3:
	dq jump0, .then3

	dq drop

	; Flush input.

	dq lit, input
	dq lit, inputTop
	dq store

	; Print error and tail-call line to flush output.

	dq lit, token
	dq enter, strLoad
	dq write
	dq lit, '?'
	dq enter, bput
	dq jump, line

.then3:

	; Compile converted literal.

	dq lit, lit
	dq enter, compile
	dq enter, compile
	dq jump, interpret

main:
	dq lit, prompt
	dq enter, strLoad
	dq write

	dq enter, interpret

	dq lit, code
	dq lit, codePtr
	dq store
	dq jump, main

; The following definitions should be moved out of core once we can compile them at runtime.

while:
if:
	dq lit, jump0
	dq enter, compile
	dq lit, codePtr
	dq fetch
	dq lit, 0
	dq jump, compile

else:
	dq lit, jump
	dq enter, compile
	dq lit, codePtr
	dq fetch
	dq push
	dq lit, 0
	dq enter, compile
	dq enter, then
	dq pull
	dq exit

then:
	dq push
	dq lit, codePtr
	dq fetch
	dq pull
	dq store
	dq exit

begin:
	dq lit, codePtr
	dq fetch
	dq exit

do:
	dq push
	dq lit, codePtr
	dq fetch
	dq lit, CELL*2
	dq add
	dq pull
	dq store

	dq lit, jump
	dq enter, compile
	dq jump, compile

signed:
	dq dup
	dq enter, negative

.if:
	dq jump0, .then

	dq negate

	dq lit, '-'
	dq enter, bput

.then:
unsigned:
	dq lit, 0
	dq enter, baseFetchAbsol
	dq div
	dq enter, dupq

.if0:
	dq jump0, .then0

	dq enter, unsigned

.then0:
	dq dup
	dq lit, 10
	dq enter, less

.if1:
	dq jump0, .else1

	dq lit, '0'

	dq jump, .then1

.else1:
	dq lit, 10
	dq sub
	dq lit, 'A'

.then1:
	dq add
	dq jump, bput

dot:
	dq lit, base
	dq fetch
	dq enter, negative

.if:
	dq jump0, .then

	dq enter, signed
	dq jump, line

.then:
	dq enter, unsigned
	dq jump, line

DEFINE dup, "dup"
DEFINE drop, "drop"
DEFINE nip, "nip"
DEFINE over, "over"
DEFINE push, "push"
DEFINE pull, "pull"
DEFINE not, "not"
DEFINE and, "and"
DEFINE or, "or"
DEFINE xor, "xor"
DEFINE negate, "negate"
DEFINE sub, "-"
DEFINE add, "+"
DEFINE mul, "*"
DEFINE div, "/"
DEFINE fetch, "@"
DEFINE store, "!"
DEFINE bfetch, "b@"
DEFINE bstore, "b!"
DEFINE read, "read"
DEFINE write, "write"
DEFINE bye, "bye"

DEFINE execute, "execute"
DEFINE dupq, "dup?"
DEFINE less, "<"
DEFINE negative, "negative"
DEFINE bool, "bool"
DEFINE more, ">"
DEFINE equals, "="
DEFINE zequals, "0="
DEFINE baseFetchAbsol, "base@Absol"
DEFINE absol, "absol"
DEFINE range, "range"
DEFINE bget, "bget"
DEFINE line, "line"
DEFINE bput, "bput"
DEFINE strLoad, "strLoad"
DEFINE strCmp, "strCmp"
DEFINE getToken, "getToken"
DEFINE literal, "literal"
DEFINE natural, "natural"
DEFINE bin, "bin", FLAG
DEFINE dec, "dec", FLAG
DEFINE hexdec, "hexdec", FLAG
DEFINE semiColon, ";", FLAG
DEFINE find, "find"
DEFINE compile, "compile"
DEFINE interpret, "interpret"
DEFINE main, "main"

DEFINE while, "while", FLAG
DEFINE if, "if", FLAG
DEFINE else, "else", FLAG
DEFINE then, "then", FLAG
DEFINE begin, "begin", FLAG
DEFINE do, "do", FLAG

DEFINE signed, "signed"
DEFINE unsigned, "unsigned"
DEFINE dot, "."

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
