.intel_syntax noprefix

.section .text

.section .bss
.align 16
.global isr_emergency_stack
isr_emergency_stack:
    .skip 16384
.global isr_emergency_stack_top
isr_emergency_stack_top:

.section .text

.global load_gdt
.type load_gdt, @function
load_gdt:
    lgdt [rdi]
    ret

.global load_tss
.type load_tss, @function
load_tss:
    mov ax, di
    ltr ax
    ret

.global load_idt
.type load_idt, @function
load_idt:
    lidt [rdi]
    ret

.global read_cr2
.type read_cr2, @function
read_cr2:
    mov rax, cr2
    ret

.macro ISR_NOERR name, vector
.global \name
.type \name, @function
\name:
    cli
    push 0
    push \vector
    mov rdi, rsp
    jmp isr_common
.endm

.macro ISR_ERR name, vector
.global \name
.type \name, @function
\name:
    cli
    push \vector
    mov rdi, rsp
    jmp isr_common
.endm

.global isr_common
.type isr_common, @function
isr_common:
    mov rdi, rsp
    sub rsp, 8
    call exception_common
    ud2

ISR_NOERR isr0, 0
ISR_NOERR isr1, 1
ISR_NOERR isr2, 2
ISR_NOERR isr3, 3
ISR_NOERR isr4, 4
ISR_NOERR isr5, 5
ISR_NOERR isr6, 6
ISR_NOERR isr7, 7
ISR_ERR   isr8, 8
ISR_NOERR isr9, 9
ISR_ERR   isr10, 10
ISR_ERR   isr11, 11
ISR_ERR   isr12, 12
ISR_ERR   isr13, 13
ISR_ERR   isr14, 14
ISR_NOERR isr15, 15
ISR_NOERR isr16, 16
ISR_ERR   isr17, 17
ISR_NOERR isr18, 18
ISR_NOERR isr19, 19
ISR_NOERR isr20, 20
ISR_NOERR isr21, 21
ISR_NOERR isr22, 22
ISR_NOERR isr23, 23
ISR_NOERR isr24, 24
ISR_NOERR isr25, 25
ISR_NOERR isr26, 26
ISR_NOERR isr27, 27
ISR_NOERR isr28, 28
ISR_NOERR isr29, 29
ISR_ERR   isr30, 30
ISR_NOERR isr31, 31
ISR_NOERR isr_spurious, 255