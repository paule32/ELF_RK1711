; -----------------------------------------------------------------------------
; MIT License
;
; Copyright (c) 2019 Jens Kallup
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
%include 'header32.asm'     ; elf32 binary header
%include "syslib32.asm"     ; system lib loader

; -----------------------------------------------------------------------------
; entry point of stub program ...
;
; Linux startup on console is stack based:
;
; EBX => numbers of arguments (see below)
; EBP => put the given argument value/name into EBP (depend by "pop ebp")
;
; $ ./stubprogram 42  A
;               |  |  |
;               |  |  +--- argv[2]
;               |  +------ argv[1]
;               +--------- argv[0]  (shall include path name + program name)
; -----------------------------------------------------------------------------
section .data
buffer1: db "PEMO", 0

fail_openkernel_str:  db "kernel32.dll could not be open.",10,0
fail_openkernel_len   equ $ - fail_openkernel_str
;
erro_openkernel_str:  db "kernel32.dll internal error.",10,0
erro_openkernel_len   equ $ - erro_openkernel_str
;
succ_openkernel_str:  db "kernel32.dll is open.",10,0
succ_openkernel_len   equ $ - succ_openkernel_str
;
fail_readkernel_str:  db "kernel32.dll read 5 bytes fail.",10,0
fail_readkernel_len   equ $ - fail_readkernel_str
;
succ_readkernel_str:  db "kernel32.dll read 5 bytes ok.",10,0
succ_readkernel_len   equ $ - succ_readkernel_str


section .text
global _start
_start:

        sys_prolog
        sys_getcmdline_args

;        sys_strlen module_hdr + m_magic
;        sys_write stdout, esi, edx



call _callfunc_test1_kernel32

.done:
mov eax, SYS_EXIT
mov ebx, 0
int 0x80
ret

_callfunc_test1_kernel32:
;
; open: "kernel32.dll"
mov edx, O_RDONLY
mov ecx, O_RDONLY
mov ebx, kernel32_dll           ; string of module
mov eax, SYS_OPEN
int 0x80
cmp eax, 0
jge .file_openok                ; error ?
mov edx, fail_openkernel_len
mov ecx, fail_openkernel_str
mov ebx, stdout
mov eax, SYS_WRITE
int 0x80
ret
.file_openok:
mov [kernel32_dll_file_desc], eax
cmp eax, 0
jge .print_ok_kernel
mov edx, erro_openkernel_len
mov ecx, erro_openkernel_str
mov ebx, stdout
mov eax, SYS_WRITE
int 0x80
ret
.print_ok_kernel:
mov edx, succ_openkernel_len
mov ecx, succ_openkernel_str
mov ebx, stdout
mov eax, SYS_WRITE
int 0x80
;
; read: m_magic: 5 bytes
mov ebx, [kernel32_dll_file_desc]
mov ecx, module_m_magic
mov edx, 5
mov eax, SYS_READ
int 0x80
cmp eax, -1
jg .file_read_ok
mov edx, fail_readkernel_len
mov ecx, fail_readkernel_str
mov ebx, stdout
mov eax, SYS_WRITE
int 0x80
ret
.file_read_ok:
mov edx, succ_readkernel_len
mov ecx, succ_readkernel_str
mov ebx, stdout
mov eax, SYS_WRITE
int 0x80
ret
;
; read: m_version: 3 bytes (3 x db)
mov ebx, [kernel32_dll_file_desc]
mov ecx, module_m_version
mov edx, 3
mov eax, SYS_READ
int 0x80
;
; read: m_filesize: 4 bytes (1 x dd)
mov ebx, [kernel32_dll_file_desc]
mov ecx, module_m_filesize
mov edx, 4
mov eax, SYS_READ
int 0x80
;
; read: m_functions: 4 bytes (1 x dd)
mov ebx, [kernel32_dll_file_desc]
mov ecx, module_m_functions
mov edx, 4
mov eax, SYS_READ
int 0x80
;
; read: m_entry: 4 bytes (1 x xdd)
mov ebx, [kernel32_dll_file_desc]
mov ecx, module_m_entry
mov edx, 4
mov eax, SYS_READ
int 0x80

;
; write
mov edx, 5              ; first 5 bytes of magic
mov esi, module_m_magic
mov ebx, stdout
mov eax, SYS_WRITE
int 0x80
.done:
        ret

; -----------------------------------------------------------------------------
; data segment - moved to the end of code
; -----------------------------------------------------------------------------
    section .data
error_text:
error_msg cant_loadstub_msg, "error", 10, 0
error_msg sys_open_error_str, "file can't be open", 0
error_msg sys_cmp_error_str, "buffers not equal", 0
error_msg sys_txt_test,"alles ok",0

kernel32_dll_file_desc: dd 0
tmp_desc:   dd 0

; -----------------------------------------------------------------------------
; bss segment - null data: static allocated memory ...
; -----------------------------------------------------------------------------
    section .bss
char_buff:   resb  1
temp_buffer: resb (1024 * 20)  ; 2 MegaByte

; module header
module_m_magic      resb 5
module_m_version    resb 3
module_m_filesize   resd 1
module_m_functions  resd 1
module_m_entry      resd 1

; -----------------------------------------------------------------------------
; E-O-F  - End Of File (stub) ...
; -----------------------------------------------------------------------------
filesize    equ $ - $$

section .data
; -----------------------------------------------------------------------------
; program dependcies: DLL + function name(s) ...
; -----------------------------------------------------------------------------
%define KERNEL32_DLL            ; nark, to tell nasm using kernel32.dll code
%define KERNEL32_DLL_FUNC1      ; mark, to tell nasm-lib use func1
%define KERNEL32_DLL_FUNC2      ; mark, func1 ...

; -----------------------------------------------------------------------------
; DLL import/include .data ...
; -----------------------------------------------------------------------------
%ifdef KERNEL32_DLL
%include "kernel32_mod.asm"
%endif

