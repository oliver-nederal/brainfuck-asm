.global brainfuck
.bss
DATA: .skip 64 * 1024
# 3 bits opcode, 16 bits operand (count), 3 bytes per instruction
# First byte is opcode, next 2 are operand
# Opcode 8 marks the end of the bytecode
BYTECODE: .skip 64 * 1024 * 3
.text

# RDI - instruction (character)
# Return rax (opcode, or 8 if the character is not a brainfuck command)
get_opcode:
	pushq %rbp
	movq %rsp, %rbp

	movq %rdi, %rax

	cmpb $'>', %al
	je opcode_0
	cmpb $'<', %al
	je opcode_1
	cmpb $'+', %al
	je opcode_2
	cmpb $'-', %al
	je opcode_3
	cmpb $'.', %al
	je opcode_4
	cmpb $',', %al
	je opcode_5
	cmpb $'[', %al
	je opcode_6
	cmpb $']', %al
	je opcode_7
	jmp opcode_8

	opcode_0:
	movq $0, %rax
	jmp done2
	opcode_1:
	movq $1,  %rax
	jmp done2
	opcode_2:
	movq $2,  %rax
	jmp done2
	opcode_3:
	movq $3,  %rax
	jmp done2
	opcode_4:
	movq $4,  %rax
	jmp done2
	opcode_5:
	movq $5,  %rax
	jmp done2
	opcode_6:
	movq $6,  %rax
	jmp done2
	opcode_7:
	movq $7,  %rax
	jmp done2
	opcode_8:
	movq $8,  %rax
	jmp done2

	done2:
	movq %rbp, %rsp
	popq %rbp
	ret


# Arguments: RDI - pointer to null terminated instruction string
# Writes bytecode to BYTECODE label
# Only runs of + - > < are compressed (the operand is the run length)
# Characters that are not commands are skipped
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
gen_bytecode:
	pushq %rbp
	movq %rsp, %rbp

	# See rle.py for high-level implementation
	movq %rdi, %rsi # rsi - pointer to instruction string
	xor %r10, %r10 # r10 - loop index
	xor %r11, %r11 # r11 - bytecode offset

	# For char in string
	gen_bytecode_loop:
		# Check if reached end of string
		movzbq (%rsi, %r10), %rdi # rdi - current char
		cmpb $0, %dil
		je gen_bytecode_loop_done

		call get_opcode
		cmpq $8, %rax
		je gen_bytecode_skip

		movq %rax, %rdx # rdx - opcode
		movq $1, %r9 # r9 - count
		inc %r10

		# Only + - > < (opcodes 0 to 3) are compressible
		cmpq $4, %rdx
		jge gen_bytecode_write

		# Count how many times the same char follows
		gen_bytecode_count:
			cmpb %dil, (%rsi, %r10)
			jne gen_bytecode_write
			# Operand is 16 bits, so stop at the maximum
			cmpq $0xFFFF, %r9
			je gen_bytecode_write
			inc %r9
			inc %r10
			jmp gen_bytecode_count

		gen_bytecode_write:
			# First byte is opcode, next 2 are operand
			movb %dl, BYTECODE(%r11)
			movw %r9w, BYTECODE+1(%r11)
			addq $3, %r11
			jmp gen_bytecode_loop

		gen_bytecode_skip:
			inc %r10
			jmp gen_bytecode_loop

	gen_bytecode_loop_done:
	# Mark end of bytecode with opcode 8
	movb $8, BYTECODE(%r11)

	movq %rbp, %rsp
	popq %rbp
	ret

# Machine code is written to the buffer in r14 at offset r15
# AL - byte to write
gen_byte:
	pushq %rbp
	movq %rsp, %rbp

	movb %al, (%r14, %r15)
	inc %r15

	movq %rbp, %rsp
	popq %rbp
	ret

# EAX - 4 byte value to write
gen_dword:
	pushq %rbp
	movq %rsp, %rbp

	movl %eax, (%r14, %r15)
	addq $4, %r15

	movq %rbp, %rsp
	popq %rbp
	ret

# Generates the compare instruction cmpb $0, (%rbx)
gen_cmp:
	pushq %rbp
	movq %rsp, %rbp

	movb $0x80, %al
	call gen_byte
	movb $0x3B, %al
	call gen_byte
	movb $0x00, %al
	call gen_byte

	movq %rbp, %rsp
	popq %rbp
	ret

# RDI - 0 to gen a read of 1 byte into (%rbx) from stdin
#       1 to gen a write of 1 byte from (%rbx) to stdout
gen_io:
	pushq %rbp
	movq %rsp, %rbp

	# mov $rdi, %eax (syscall number)
	movb $0xB8, %al
	call gen_byte
	movl %edi, %eax
	call gen_dword

	# mov $rdi, %edi (file descriptor)
	movb $0xBF, %al
	call gen_byte
	movl %edi, %eax
	call gen_dword

	# mov %rbx, %rsi (buffer)
	movb $0x48, %al
	call gen_byte
	movb $0x89, %al
	call gen_byte
	movb $0xDE, %al
	call gen_byte

	# mov $1, %edx (length)
	movb $0xBA, %al
	call gen_byte
	movl $1, %eax
	call gen_dword

	# syscall
	movb $0x0F, %al
	call gen_byte
	movb $0x05, %al
	call gen_byte

	movq %rbp, %rsp
	popq %rbp
	ret

# Reads the bytecode and writes machine code to buffer (r14, with offset r15)
# rbx = data pointer
# stack = where the jump of each [ must be patched
# RAX = 0 on success, 1 if the brackets do not match
# Pain
gen_machine_code:
	pushq %rbp
	movq %rsp, %rbp

	# Prologue: push rbx; mov $DATA, %ebx
	movb $0x53, %al
	call gen_byte
	movb $0xBB, %al
	call gen_byte
	movl $DATA, %eax
	call gen_dword

	xor %r8, %r8 # r8 - bytecode index

	gen_machine_code_loop:
		movzbq BYTECODE(%r8), %r9 # r9 - opcode
		movzwq BYTECODE+1(%r8), %r10 # r10 - operand
		addq $3, %r8

		cmpq $0, %r9
		je gen_machine_code_inc_dp
		cmpq $1, %r9
		je gen_machine_code_dec_dp
		cmpq $2, %r9
		je gen_machine_code_inc_at_dp
		cmpq $3, %r9
		je gen_machine_code_dec_at_dp
		cmpq $4, %r9
		je gen_machine_code_output
		cmpq $5, %r9
		je gen_machine_code_input
		cmpq $6, %r9
		je gen_machine_code_loop_start
		cmpq $7, %r9
		je gen_machine_code_loop_end

		# opcode 8, end of bytecode
		jmp gen_machine_code_loop_done

		# >(n) add $n, %rbx
		gen_machine_code_inc_dp:
			movb $0x48, %al
			call gen_byte
			movb $0x81, %al
			call gen_byte
			movb $0xC3, %al
			call gen_byte
			movl %r10d, %eax
			call gen_dword
			jmp gen_machine_code_loop

		# <(n) sub $n, %rbx
		gen_machine_code_dec_dp:
			movb $0x48, %al
			call gen_byte
			movb $0x81, %al
			call gen_byte
			movb $0xEB, %al
			call gen_byte
			movl %r10d, %eax
			call gen_dword
			jmp gen_machine_code_loop

		# +(n) addb $n, (%rbx)
		gen_machine_code_inc_at_dp:
			movb $0x80, %al
			call gen_byte
			movb $0x03, %al
			call gen_byte
			movb %r10b, %al
			call gen_byte
			jmp gen_machine_code_loop

		# -(n) subb $n, (%rbx)
		gen_machine_code_dec_at_dp:
			movb $0x80, %al
			call gen_byte
			movb $0x2B, %al
			call gen_byte
			movb %r10b, %al
			call gen_byte
			jmp gen_machine_code_loop

		# . write(1, rbx, 1)
		gen_machine_code_output:
			movq $1, %rdi
			call gen_io
			jmp gen_machine_code_loop

		# , read(0, rbx, 1)
		gen_machine_code_input:
			movq $0, %rdi
			call gen_io
			jmp gen_machine_code_loop

		# [ cmpb $0, (%rbx) je <after matching ]>
		gen_machine_code_loop_start:
			call gen_cmp
			movb $0x0F, %al
			call gen_byte
			movb $0x84, %al
			call gen_byte

			# Remember where the jump offset is, and write a placeholder while we figure shit out
			pushq %r15
			movl $0, %eax
			call gen_dword
			jmp gen_machine_code_loop

		# ] : cmpb $0, (%rbx); jne <after matching [>
		gen_machine_code_loop_end:
			# Stack is empty, so there is no matching [
			cmpq %rbp, %rsp
			je gen_machine_code_error

			call gen_cmp
			movb $0x0F, %al
			call gen_byte
			movb $0x85, %al
			call gen_byte

			# %rcx = position of the offset of the matching [
			# %r15 = position of the offset of this ]
			# Both jumps are 4 bytes past their offset field, so the
			# forward distance is r15 - rcx and the backward one is the negative
			popq %rcx
			movq %r15, %rdx
			subq %rcx, %rdx
			movl %edx, (%r14, %rcx) # Patch the [
			negl %edx
			movl %edx, %eax
			call gen_dword
			jmp gen_machine_code_loop

	gen_machine_code_loop_done:
	# Stack is not empty, so brackets are invalid
	cmpq %rbp, %rsp
	jne gen_machine_code_error

	# Epilogue, pop %rbx and ret
	movb $0x5B, %al
	call gen_byte
	movb $0xC3, %al
	call gen_byte

	xor %rax, %rax
	jmp gen_machine_code_exit

	gen_machine_code_error:
	movq $1, %rax

	gen_machine_code_exit:
	movq %rbp, %rsp
	popq %rbp
	ret

brainfuck:
	pushq %rbp
	movq %rsp, %rbp
	pushq %r14
	pushq %r15

	pushq %rdi

	# create mmap table for code buffer
	movq    $0, %rdi                        # addr = NULL
	movq    $4*1000000, %rsi                # length fixed here to 4MB
	movq    $(0x1|0x2), %rdx                # prot = PROT_READ | PROT_WRITE
	movq    $(0x02|0x20), %r10              # flags = MAP_PRIVATE | MAP_ANON
	movq    $-1, %r8                        # fd = -1
	movq    $0, %r9                         # offset = 0
	movq    $9, %rax
	syscall
	movq    %rax, %r14                      # move the code buffer space address into r14

	popq %rdi

	xor %r15, %r15
	# r14 = buffer pointer
	# r15 = buffer offset

	call gen_bytecode
	call gen_machine_code

	# brackets do not match, do not run
	cmpq $0, %rax
	jne brainfuck_cleanup

	# mprotect the code buffer (make executable)
	movq    %r14, %rdi
	movq    $4*1000000, %rsi
	movq    $(0x1|0x4), %rdx
	movq    $10, %rax
	syscall

	call *%r14

	brainfuck_cleanup:
	# m-unmap the code buffer (remove mappings)
	movq    %r14, %rdi
	movq    $4*1000000, %rsi
	movq    $11, %rax
	syscall

	popq %r15
	popq %r14

	movq %rbp, %rsp
	popq %rbp
	ret
