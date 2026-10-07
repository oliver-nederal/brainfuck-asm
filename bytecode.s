.data
format_str: .asciz "%c"
AAA: .skip 10
DATA: .skip 1
.text
/*
Opcodes:
000 : >(n)
001 : <(n)
010 : +(n)
011 : -(n)
100 : .
101 : ,
110 : [(i)
111 : ](i)
*/

# r9 - data pointer
# 000 - >(n)
add_dp:
    addq $0x1234, %r9

# 001 - <(n)
sub_dp:
    subq $0x1234, %r9

# 010 : +(n)
add_at_dp:
    addq $0x1234, 0x456(%r9)

# 011 : -(n)
sub_at_dp:
    subq $0x1234, 0x456(%r9)

# 100 : .
output_at_dp:
    movq $format_str, %rdi
    movzxb 0x456(%r9), %rsi
    xor %rax, %rax

    pushq %r9
    subq $8, %rsp

    call printf

    addq $8, %rsp
    popq %r9

# 101 : ,
accept_input:
    pushq %r9
    subq $8, %rsp

    call getchar

    addq $8, %rsp
    popq %r9

    movb %al, DATA(%r9)
# 110 : [
loop_start:
    jmp $0xABCD

# 110 : [
loop_end:
    jmp $0xCDEF