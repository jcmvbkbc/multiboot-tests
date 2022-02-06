#define ASM     1
#include <multiboot.h>

        .text

        .globl  start, _start
        .code32
start:
_start:
        jmp     multiboot_entry

        /* Align 32 bits boundary.  */
        .align  4

        /* Multiboot header.  */
multiboot_header:
        /* magic */
        .long   MULTIBOOT_HEADER_MAGIC
        /* flags */
        .long   MULTIBOOT_HEADER_FLAGS
        /* checksum */
        .long   -(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS)
#ifndef __ELF__
        /* header_addr */
        .long   multiboot_header
        /* load_addr */
        .long   _start
        /* load_end_addr */
        .long   _edata
        /* bss_end_addr */
        .long   _end
        /* entry_addr */
        .long   multiboot_entry
#endif /* ! __ELF__ */

multiboot_entry:
        /* Initialize the stack pointer.  */
        movl    $(stack + STACK_SIZE), %esp

        /* Reset EFLAGS.  */
        pushl   $0
        popf

        /* Push the pointer to the Multiboot information structure.  */
        pushl   %ebx
        /* Push the magic value.  */
        pushl   %eax

        /* Set up IDT */
        movl    $vector0, %eax
        andl    $0xffff, %eax
        orl     $0x00080000, %eax
        movl    %eax, idt_base
        movl    $vector0, %eax
        andl    $0xffff0000, %eax
        orl     $0x8e00, %eax
        movl    %eax, idt_base + 4

	/* Initialize PIC */
	mov	$0x11, %al
	out	%al, $0x20
	out	%al, $0xa0
	mov	$0x00, %al
	out	%al, $0x21
	mov	$0x28, %al
	out	%al, $0xa1
	mov	$0x4, %al
	out	%al, $0x21
	mov	$0x2, %al
	out	%al, $0xa1
	mov	$1, %al
	out	%al, $0x21
	mov	$1, %al
	out	%al, $0xa1

	/* Enable IRQ0 line */
	in	$0x21, %al
	and	$0xfe, %al
	out	%al, $0x21

	/* Set up 8253 channel 0 mode 2, counter 0xffff */
	mov	$0x34, %al
	out	%al, $0x43
	mov	$0xff, %al
	out	%al, $0x40
	out	%al, $0x40

        /* Enable PAE */
        movl    %cr4, %eax
        btsl    $5, %eax
        movl    %eax, %cr4

        /*
         * Build early 4G boot pagetable
         */
        /* Initialize Page tables to 0 */
        leal    pgtable, %edi
        xorl    %eax, %eax
        movl    $((4096*6)/4), %ecx
        rep     stosl

        /* Build Level 4 */
        leal    pgtable + 0, %edi
        leal    0x1007 (%edi), %eax
        movl    %eax, 0(%edi)

        /* Build Level 3 */
        leal    pgtable + 0x1000, %edi
        leal    0x1007(%edi), %eax
        movl    $4, %ecx
1:      movl    %eax, 0x00(%edi)
        addl    $0x00001000, %eax
        addl    $8, %edi
        decl    %ecx
        jnz     1b

        /* Build Level 2 */
        leal    pgtable + 0x2000, %edi
        movl    $0x00000183, %eax
        movl    $2048, %ecx
1:      movl    %eax, 0(%edi)
        addl    $0x00200000, %eax
        addl    $8, %edi
        decl    %ecx
        jnz     1b

        /* Load gdt */
        lgdt    gdt
        lidt    idt

        /* Load Level 4 page table (page 128) */
        leal    pgtable, %eax
        movl    %eax, %cr3

        /* Enable long mode */
        movl    $0xc0000080, %ecx
        rdmsr
        btsl    $8, %eax
        wrmsr

        /* enable paging to activate long mode */
        movl    %cr0, %eax
        btsl    $1, %eax        /* protected mode */
        btsl    $31, %eax       /* paging */
        movl    %eax, %cr0

        /* jump to 64bit mode */
        pushl   $0x8
        movl    $startup_64, %eax
        pushl   %eax
        lret


        .code64
startup_64:
_startup_64:
	mov	$0xb8000, %rcx
	sti
loop4:
        // Dummy code that just twirls a char on the screen
        addq    $0x1, (%rcx)
        jmp     loop4

vector0:
        add    $4, %rcx
	/* Issue non-specific EOI to the PIC */
	mov	$0x20, %al
	out	%al, $0x20
        iretq

        /* Our stack area.  */
        .comm   stack, STACK_SIZE

        .data
gdt:
        .word   gdt_end - gdt_base
        .long   gdt_base
        .long   0
idt:
        .word   idt_end - idt_base
        .long   idt_base
        .long   0

        .balign 8
        .globl gdt_base
gdt_base:
        .quad   0x0000000000000000      /* NULL descriptor */
        .quad   0x00af9a000000ffff      /* __KERNEL_CS */
        .quad   0x00cf92000000ffff      /* __KERNEL_DS */
        .quad   0x0080890000000000      /* TS descriptor */
        .quad   0x0000000000000000      /* TS continued */
gdt_end:

        .balign 8
idt_base:
        .quad   0x0000000000000000
        .quad   0x0000000000000000
idt_end:
/*
 * Space for page tables (not in .bss so not zeroed)
 */
        .bss
        .balign 4096
pgtable:
        .fill 6*4096, 1, 0
