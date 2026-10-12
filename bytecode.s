.bss
DATA: .skip 64 * 1024
.text
/*
Opcodes:
000 : >(n)
001 : <(n)
010 : +(n)
011 : -(n)
100 : .
101 : ,
110 : [
111 : ]
*/

# Prologue
	pushq %rbx
	movl $DATA, %ebx

# 000 - >(n)
add_dp:
    addq $0x1234, %rbx

# 001 - <(n)
sub_dp:
    subq $0x1234, %rbx

# 010 : +(n)
add_at_dp:
    addb $0x12, (%rbx)

# 011 : -(n)
sub_at_dp:
    subb $0x12, (%rbx)

# 100 : .
output_at_dp:
    movl $1, %eax
    movl $1, %edi
    movq %rbx, %rsi
    movl $1, %edx
    syscall

# 101 : ,
accept_input:
    movl $0, %eax
    movl $0, %edi
    movq %rbx, %rsi
    movl $1, %edx
    syscall

# 110 : [
# jump offset is always 4 bytes, patched once the ] is known
loop_start:
    cmpb $0, (%rbx)
    .byte 0x0f, 0x84
    .long 0

# 111 : ]
loop_end:
    cmpb $0, (%rbx)
    .byte 0x0f, 0x85
    .long 0

# Epilogue
	popq %rbx
	ret
