; -----------------------------------------------------------------------------
; MIT License
;
; Copyright (c) 2020 Jens Kallup
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
; -----------------------------------------------------------------------------
; usage: nasm -f bin -o test test.asm
; -----------------------------------------------------------------------------
bits 32                 ; for ELF32 exec format
    org     0x08048000
;;----------------------------------------------------------------
;; ELF - 32-bit executable header ...
;;----------------------------------------------------------------
ehdr:                                                 ; Elf32_Ehdr
                db      0x7F, "ELF", 1, 1, 1, 0         ;   e_ident
        times 8 db      0
                dw      2                               ;   e_type
                dw      3                               ;   e_machine
                dd      1                               ;   e_version
                dd      _start                          ;   e_entry
                dd      phdr - $$                       ;   e_phoff
                dd      0                               ;   e_shoff
                dd      0                               ;   e_flags
                dw      ehdrsize                        ;   e_ehsize
                dw      phdrsize                        ;   e_phentsize
                dw      1                               ;   e_phnum
                dw      0                               ;   e_shentsize
                dw      0                               ;   e_shnum
                dw      0                               ;   e_shstrndx
  
ehdrsize      equ     $ - ehdr
  
phdr:                                                 ; Elf32_Phdr
                dd      1                               ;   p_type
                dd      0                               ;   p_offset
                dd      $$                              ;   p_vaddr
                dd      $$                              ;   p_paddr
                dd      filesize                        ;   p_filesz
                dd      filesize                        ;   p_memsz
                dd      7                               ;   p_flags
                dd      0x1000                          ;   p_align
  
phdrsize      equ     $ - phdr

; -----------------------------------------------------------------------------
; WARNING: Linux use different syscall numbers for each arch !!!
; -----------------------------------------------------------------------------
SYS_EXIT         equ   1     ; "exit"  32-bit x86 kernel ABI
SYS_FORK         equ   2     ; "fork"  ...
SYS_READ         equ   3     ; "read"  ...
SYS_WRITE        equ   4     ; "write" ...
SYS_OPEN         equ   5     ; "open"  ...
SYS_CLOSE        equ   6     ; "close" ...
SYS_CREAT        equ   8     ; "creat" ... (file create with perm.)
SYS_LSEEK        equ  19     ; "lseek" ...
SYS_SYNC         equ  36     ; "sync"  ... write buffers, and clear it

O_RDONLY         equ   0     ; read  only file mode
O_WRONLY         equ   1     ; write ...
O_RDWR           equ   2     ; both - read & write

%assign stdin    0           ; std input
%assign stdout   1           ; std output
%assign stderr   2           ; std error => (stdout)

%assign SEEK_SET 0           ; begin of file position
%assign SEEK_CUR 1           ; current ...
%assign SEEK_END 2           ; end

; -----------------------------------------------------------------------------
; a data section ...
; -----------------------------------------------------------------------------
    section .data
kernel32_dll:
kernel32_rd_byte_str: db "kernel32.dll", 0
kernel32_rd_byte_len  equ $ - kernel32_rd_byte_str

bytes_str_ok:         db " bytes ok.",0
bytes_str_ok_len      equ $ - bytes_str_ok
;
bytes_str_fail:       db " bytes fail.", 0
bytes_str_fail_len    equ $ - bytes_str_fail

fail_openkernel_str:  db " could not be open.",0
fail_openkernel_len   equ $ - fail_openkernel_str
;
erro_openkernel_str:  db " internal error.",0
erro_openkernel_len   equ $ - erro_openkernel_str
;
succ_openkernel_str:  db " is open",0
succ_openkernel_len   equ $ - succ_openkernel_str
;
fail_readkernel_str:  db " read error.",0
fail_readkernel_len   equ $ - succ_readkernel_str
;
succ_readkernel_str:  db " 5",0
succ_readkernel_len   equ $ - succ_readkernel_str
;
vers_readkernel_str:  db " 3",0
vers_readkernel_len   equ $ - vers_readkernel_str
;
sizs_readkernel_str:  db " 4",0
sizs_readkernel_len   equ $ - sizs_readkernel_str
;

print_newline_char: db 10,0

; kernel file descriptor
kernel32_dll_file_desc: dd 0

; -----------------------------------------------------------------------------
; bytes reserved section ...
; -----------------------------------------------------------------------------
    section .bss
; module header
module_m_magic      resb 5
module_m_version    resb 3
module_m_filesize   resd 1
module_m_functions  resd 1
module_m_entry      resd 1

; -----------------------------------------------------------------------------
; code/text section - helper function's ...
; -----------------------------------------------------------------------------
    section .text

write_kernel_str:
    mov     edx, kernel32_rd_byte_len
    mov     ecx, kernel32_rd_byte_str

sys_write:
    mov     ebx, stdout
    mov     eax, SYS_WRITE
    int     0x80
    ret

sys_newline:
    mov     edx, 2
    mov     ecx, print_newline_char
    call    sys_write
    ret

sys_read_dd:
    mov     edx, 4
sys_read:
    mov     eax, SYS_READ
    int     0x80
    ret

sys_write_text_nl:
    call    sys_write
    call    sys_newline
    ret

sys_write_bytes_ok:
    mov     edx, sizs_readkernel_len
    mov     ecx, sizs_readkernel_str
    call    sys_write
    mov     edx, bytes_str_ok_len
    mov     ecx, bytes_str_ok
    call    sys_write_text_nl
    ret
; -----------------------------------------------------------------------------
sys_write_bytes_fail:
    mov     edx, bytes_str_fail_len
    mov     ecx, bytes_str_fail
    call    sys_write
    mov     edx, sizs_readkernel_len
    mov     ecx, sizs_readkernel_str
    call    sys_write_text_nl
    ret

sys_write_kernel_b_ok:
    call    write_kernel_str
    call    sys_write_bytes_ok
    ret
sys_write_kernel_b_fail:
    call    write_kernel_str
    call    sys_write_bytes_fail
    ret

sys_write_text_nl_fail:
    call    write_kernel_str
    mov     edx, fail_openkernel_len
    mov     ecx, fail_openkernel_str
    call    sys_write_bytes_fail
    ret

; -----------------------------------------------------------------------------
; entry point of start ...
; -----------------------------------------------------------------------------
    section .text
global _start
_start:

    call test1

    mov     eax, SYS_EXIT
    xor     ebx, ebx              ; exit code: 0
    int     0x80

; -----------------------------------------------------------------------------
; open: "kernel32.dll"
; -----------------------------------------------------------------------------
test1:
    mov     edx, O_RDONLY
    mov     ecx, O_RDONLY
    mov     ebx, kernel32_dll          ; string of module
    mov     eax, SYS_OPEN
    int     0x80
        test eax, eax
        jg .file_openok                ; error at open file ...
            call    sys_write_text_nl_fail
            ret
        ; -------------------------------------
        ; file open ok:
        ; -------------------------------------
        .file_openok:
            mov     [kernel32_dll_file_desc], eax  ; save result from eax

            call    write_kernel_str
            mov     edx, succ_openkernel_len
            mov     ecx, succ_openkernel_str
            call    sys_write_text_nl

; -----------------------------------------------------------------------------
; read: m_magic: 5 bytes
; -----------------------------------------------------------------------------
    mov     ebx, [kernel32_dll_file_desc]
    mov     ecx, module_m_magic
    mov     edx, 5
    call    sys_read
        cmp eax, -1
        jg .file_read_ok                ; error at read file ...
            call    sys_write_text_nl_fail
            ret
        ; -------------------------------------
        ; file_read_ok:
        ; -------------------------------------
        .file_read_ok:
            call    write_kernel_str
            mov     edx, succ_readkernel_len
            mov     ecx, succ_readkernel_str
            call    sys_write_text_nl

; -----------------------------------------------------------------------------
; read: m_version: 3 bytes (3 x db)
; -----------------------------------------------------------------------------
    mov     ebx, [kernel32_dll_file_desc]
    mov     ecx, module_m_version
    mov     edx, 3
    call    sys_read
        cmp eax, -1
        jg .file_read_ok2                   ; error at read file ...
            call    sys_write_text_nl_fail
            ret
        ; -------------------------------------
        ; file_read_ok:
        ; -------------------------------------
        .file_read_ok2:
            call    write_kernel_str
            mov     edx, vers_readkernel_len
            mov     ecx, vers_readkernel_str
            call    sys_write_text_nl

; -----------------------------------------------------------------------------
; read: m_filesize: 4 bytes (1 x dd)
; -----------------------------------------------------------------------------
    mov     ebx, [kernel32_dll_file_desc]
    mov     ecx, module_m_filesize
    call    sys_read_dd
        cmp eax, -1
        jg .file_read_ok_size           ; error at read file ...
            call    sys_write_kernel_b_fail
            ret
        ; -------------------------------------
        ; file_read_ok:
        ; -------------------------------------
        .file_read_ok_size:
            call    sys_write_kernel_b_ok

; -----------------------------------------------------------------------------
; read: m_functions: 4 bytes (1 x dd)
; -----------------------------------------------------------------------------
    mov     ebx, [kernel32_dll_file_desc]
    mov     ecx, module_m_functions
    call    sys_read_dd
        cmp eax, -1
        jg .file_read_ok_funs           ; error at read file ...
            call    sys_write_kernel_b_fail
            ret
        ; -------------------------------------
        ; file_read_ok:
        ; -------------------------------------
        .file_read_ok_funs:
            call    sys_write_kernel_b_ok

; -----------------------------------------------------------------------------
; read: m_entry: 4 bytes (1 x dd)
; -----------------------------------------------------------------------------
    mov     ebx, [kernel32_dll_file_desc]
    mov     ecx, module_m_entry
    mov     edx, 4
    call    sys_read_dd
        cmp eax, -1
        jg .file_read_ok_entry          ; error at read file ...
            call    sys_write_kernel_b_fail
            ret
        ; -------------------------------------
        ; file_read_ok:
        ; -------------------------------------
        .file_read_ok_entry:
            call    sys_write_kernel_b_ok

; -----------------------------------------------------------------------------
; write
; -----------------------------------------------------------------------------
    mov     edx, 5              ; first 5 bytes of magic
    mov     ecx, module_m_magic
    mov     ebx, stdout
    call    sys_write_text_nl
.done:
    ret     ; return to caller (test1)

; -----------------------------------------------------------------------------
; E-O-F  - End Of File (stub) ...
; -----------------------------------------------------------------------------
filesize    equ $ - $$

