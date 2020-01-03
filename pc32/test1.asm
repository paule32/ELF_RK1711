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
%include "header32.asm"
%include "syslib32.asm"

; -----------------------------------------------------------------------------
; entry point of start ...
; -----------------------------------------------------------------------------
    section .text
global _start
_start:

    call    read_module

    mov     eax, SYS_EXIT
    mov     ebx, 0              ; exit-code
    int     0x80

; -----------------------------------------------------------------------------
; open: "kernel32.dll"
; -----------------------------------------------------------------------------
read_module:
    push    ebp
    mov     ebp, esp
    ;
    push    dword O_RDONLY                 ; edx => mode
    push    dword O_RDONLY                 ; ecx => flags
    push    dword kernel32_rd_byte_str     ; ebx => file name
    call    loader_open
    

; -----------------------------------------------------------------------------
; read: m_magic: 5 bytes
; -----------------------------------------------------------------------------
    push    dword 5                             ; length of buffer
    push    dword module_m_magic                ; the buffer
    push    dword [kernel32_dll_file_desc]      ; file descriptor
    call    loader_read                         ; did a loader header read

; -----------------------------------------------------------------------------
; read: m_version: 3 bytes (3 x db)
; -----------------------------------------------------------------------------
    push    dword 3
    push    dword module_m_version
    push    dword [kernel32_dll_file_desc]
    call    loader_read

; -----------------------------------------------------------------------------
; read: m_filesize: 4 bytes (1 x dd)
; -----------------------------------------------------------------------------
    push    dword 4
    push    dword module_m_filesize
    push    dword [kernel32_dll_file_desc]
    call    loader_read

; -----------------------------------------------------------------------------
; read: m_functions: 4 bytes (1 x dd)
; -----------------------------------------------------------------------------
    push    dword 4
    push    dword module_m_functions
    push    dword [kernel32_dll_file_desc]
    call    loader_read

; -----------------------------------------------------------------------------
; read: m_entry: 4 bytes (1 x dd)
; -----------------------------------------------------------------------------
    push    dword 4
    push    dword module_m_entry
    push    dword [kernel32_dll_file_desc]
    call    loader_read

.done:
    ret     ; return to caller (test1)


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
succ_readkernel_str:  db " read ok",0
succ_readkernel_len   equ $ - succ_readkernel_str
;

print_newline_char: db 10,0

; -----------------------------------------------------------------------------
kernel32_dll_file_desc: dd 0        ; kernel file descriptor

; -----------------------------------------------------------------------------
; bytes reserved section ...
; -----------------------------------------------------------------------------
    section .bss
; module header
kernel32_module_hdr:
    module_m_magic      resb 5
    module_m_version    resb 3
    module_m_filesize   resd 1
    module_m_functions  resd 1
    module_m_entry      resd 1

; -----------------------------------------------------------------------------
; E-O-F  - End Of File (stub) ...
; -----------------------------------------------------------------------------
filesize    equ $ - $$

