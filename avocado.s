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

zjump:
	test rax, rax
	mov rax, [rbp]
	lea rbp, [rbp+CELL]
	jz jump
	add rbx, CELL
	NEXT

execute:
	push rbx
	mov rbx, rax
	DROP
	jmp [rbx]

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

codeend:

section .data

; If top-of-stack not zero, duplicate it.

qdup:
	dq dup

.if:
	dq zjump, .then

	dq dup

.then:
	dq exit

less:
	dq over, over
	dq xor
	dq enter, negative

.if:
	dq zjump, .then

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
	dq zjump, .then

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

within:
	dq push
	dq over
	dq push
	dq enter, less
	dq not
	dq pull, pull
	dq enter, less
	dq and
	dq exit

accept:
	dq lit, input
	dq lit, PAGE
	dq read
	dq dup
	dq lit, 1
	dq enter, less

.if:
	dq zjump, .then

	dq bye

.then:
	dq over
	dq add
	dq lit, inputTop
	dq store
	dq lit, inputPtr
	dq store
	dq exit

; - char -1 | 0

bget:
	dq lit, inputPtr
	dq fetch
	dq lit, inputTop
	dq fetch
	dq enter, less

.if:
	dq zjump, .then

	dq lit, inputPtr
	dq fetch
	dq dup
	dq lit, 1
	dq add
	dq lit, inputPtr
	dq store
	dq bfetch
	dq lit, -1
	dq exit

.then:
	dq lit, 0
	dq exit

flush:
	dq lit, output
	dq lit, outputPtr
	dq over, over
	dq fetch
	dq lit, output
	dq sub
	dq write
	dq store
	dq exit

line:
	dq lit, `\n`

bput:
	dq lit, outputPtr
	dq fetch
	dq dup
	dq lit, 1
	dq add
	dq lit, outputPtr
	dq store
	dq bstore

	dq lit, outputPtr
	dq fetch
	dq lit, output+PAGE
	dq enter, equals

.if:
	dq zjump, .then

	dq jump, flush

.then:
	dq exit

load:
	dq dup
	dq push
	dq lit, CELL
	dq add
	dq pull
	dq fetch
	dq exit

; stringA stringB - comparisonValue

compare:
	dq dup
	dq fetch
	dq push

	; Compare string sizes.

	dq over, fetch
	dq over, fetch
	dq enter, equals

.if:
	dq zjump, .then

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
	dq zjump, .do

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

emptytoken:
	dq lit, 0
	dq lit, token
	dq store
	dq exit

gettoken:

; The following loop reads input and discards spaces.
; It returns the first non-space character.

.begin0:
	dq enter, bget
	dq zjump, emptytoken ; Hack.

	dq dup
	dq lit, '!'
	dq enter, less

.while0:
	dq zjump, .do0

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
	dq zjump, .do1

	dq pull
	dq dup
	dq lit, 1
	dq add
	dq push
	dq bstore

	dq enter, bget
	dq drop

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
	dq enter, load

	dq over
	dq bfetch
	dq lit, '-'
	dq enter, equals

	dq over
	dq lit, 1
	dq xor

	dq and

.if:
	dq zjump, .then

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

	dq lit, base
	dq fetch
	dq lit, 11
	dq enter, less

.if0:
	dq zjump, .else0

	dq lit, 0
	dq lit, base
	dq fetch
	dq enter, within

	dq jump, .then0
.else0:

	dq dup
	dq lit, 0
	dq lit, 10
	dq enter, within

	dq over
	dq lit, 'A'-'0'
	dq sub
	dq lit, 0
	dq lit, base
	dq fetch
	dq lit, 10
	dq sub
	dq enter, within

	dq or
	dq nip

.then0:
	dq pull
	dq dup
	dq push
	dq and

.while:
	dq zjump, .do

	dq lit, base
	dq fetch
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
	dq zjump, .then1

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

find:
	dq lit, last

.begin:
	dq fetch
	dq dup, dup

.if:
	dq zjump, .then

	dq lit, CELL*2
	dq add
	dq lit, token
	dq enter, compare

.then:
	dq enter, zequals

	dq zjump, .begin
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
	dq enter, gettoken
	dq lit, token
	dq fetch

.if0:
	dq zjump, .then0

	dq enter, find
	dq enter, qdup

.if1:
	dq zjump, .then1

	dq lit, CELL
	dq add
	dq fetch

	dq dup
	dq enter, negative
	dq push

	dq lit, ~FLAG
	dq and
	dq pull

.if2:
	dq zjump, .then2

	dq execute
	dq jump, interpret

.then2:
	dq dup
	dq lit, codeend
	dq enter, less
	dq not

.if3:
	dq zjump, .then3

	dq lit, enter
	dq enter, compile

.then3:
	dq enter, compile
	dq jump, interpret

.then1:
	dq enter, literal

.if4:
	dq zjump, .then4

	dq drop

	; Flush input.

	dq lit, input
	dq lit, inputTop
	dq store

	; Print error and tail-call line to flush output.

	dq lit, token
	dq enter, load
	dq write
	dq lit, '?'
	dq jump, bput

.then4:

	; Compile converted literal.

	dq lit, lit
	dq enter, compile
	dq enter, compile
	dq jump, interpret

.then0:
	dq lit, exit
	dq enter, compile
	dq jump, code

main:
	dq lit, prompt
	dq enter, load
	dq write

	dq enter, accept
	dq enter, interpret
	dq enter, flush

	dq lit, code
	dq lit, codePtr
	dq store
	dq jump, main

; The following definitions should be moved out of core once we can compile them at runtime.

while:
if:
	dq lit, zjump
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

bin:
	dq lit, 2
	dq lit, base
	dq store
	dq exit

dec:
	dq lit, 10
	dq lit, base
	dq store
	dq exit

hex:
	dq lit, 16
	dq lit, base
	dq store
	dq exit

dot:
	dq dup
	dq enter, negative

.if:
	dq zjump, udot

	dq negate

	dq lit, '-'
	dq enter, bput

udot:
	dq lit, 0
	dq lit, base
	dq fetch
	dq div
	dq enter, qdup

.if0:
	dq zjump, .then0

	dq enter, udot

.then0:
	dq dup
	dq lit, 10
	dq enter, less

.if1:
	dq zjump, .else1

	dq lit, '0'

	dq jump, .then1

.else1:
	dq lit, 10
	dq sub
	dq lit, 'A'

.then1:
	dq add
	dq jump, bput

DEFINE execute, "execute"
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

DEFINE qdup, "?dup"
DEFINE less, "<"
DEFINE negative, "negative"
DEFINE bool, "bool"
DEFINE more, ">"
DEFINE equals, "="
DEFINE zequals, "0="
DEFINE within, "within"
DEFINE accept, "accept"
DEFINE bget, "bget"
DEFINE flush, "flush"
DEFINE line, "line"
DEFINE bput, "bput"
DEFINE load, "load"
DEFINE compare, "compare"
DEFINE emptytoken, "emptytoken"
DEFINE gettoken, "gettoken"
DEFINE literal, "literal"
DEFINE natural, "natural"
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

DEFINE bin, "bin", FLAG
DEFINE dec, "dec", FLAG
DEFINE hex, "hex", FLAG
DEFINE dot, "."
DEFINE udot, "u."

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
