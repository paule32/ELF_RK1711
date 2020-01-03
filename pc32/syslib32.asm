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
; code/text section - helper function's ...
; -----------------------------------------------------------------------------
    section .text

sys_write:
    push    ebp
    mov     ebp, esp

    mov     ebx, dword [ebp +  8]   ; stdout
    mov     ecx, dword [ebp + 12]   ; buffer
    mov     edx, dword [ebp + 16]   ; len

    mov     eax, SYS_WRITE
    int     0x80

    mov     esp, ebp
    pop     ebp
    ret     12

sys_newline:
    push    ebp
    mov     ebp, esp

    mov     ebx, stdout             ; stdout
    mov     ecx, print_newline_char ; buffer
    mov     edx, 2                  ; len
    mov     eax, SYS_WRITE
    int     0x80

    mov     esp, ebp
    pop     ebp
    ret

; -----------------------------------------------------------------------------
; sys_open:     open stream, result is file descriptor. fd 0, 1, 2 are reserved
;               under Linux.
; Example:
;       mov     edx, <mode>         ; edx := mode
;       mov     ecx, <flags>        ; ecx := flags
;       mov     ebx, <file name>    ; ebx := file name str
;       mov     eax, SYS_OPEN       ; eax := linux syscall number
;       int     0x80                ; sys_read: syscall int
; -----------------------------------------------------------------------------
sys_open:
    push    ebp
    mov     ebp, esp

    mov     ebx, dword [ebp +  8]
    pop     ebx
    mov     ecx, dword [ebp + 12]
    pop     ecx
    mov     edx, dword [ebp + 16]
    pop     edx
    mov     eax, SYS_OPEN
    int     0x80

    mov     edi, eax
    push    edi

    mov     esp, ebp
    pop     ebp
    ret     12              ; 3x 4 bytes

sys_exit:
    mov     eax, SYS_EXIT
    int     0x80

; -----------------------------------------------------------------------------
; sys_read:     read buffer from fiven file descriptor. fd 0, 1, 2 are reserved
;               under Linux.
; Example:
;       mov     edx, <count>        ; edx := read buffer size
;       mov     ecx, <buffer>       ; ecx := read buffer
;       mov     ebx, <file desc>    ; ebx := file descriptor (e.g.: stdin)
;       mov     eax, SYS_READ       ; eax := linux syscall number
;       int     0x80                ; sys_read: syscall int
; -----------------------------------------------------------------------------
sys_read:
    push    ebp
    mov     ebp, esp

    mov     ebx, dword [ebp +  8]   ; fd
    push    ebx
    mov     ecx, dword [ebp + 12]   ; buffer
    mov     edx, dword [ebp + 16]   ; len

    mov     eax, SYS_READ
    int     0x80

    mov     esp, ebp
    pop     ebp
    ret

sys_open_fail_str:
    push    ebp
    mov     ebp, esp

    push    dword kernel32_rd_byte_len
    push    dword kernel32_rd_byte_str
    push    dword stdout
    call    sys_write

    push    dword fail_openkernel_len
    push    dword fail_openkernel_str
    push    dword stdout
    call    sys_write

    mov     esp, ebp
    pop     ebp
    ret

; -----------------------------------------------------------------------------
open_read_ok:
    push    ebp
    mov     ebp, esp

    mov     eax, dword [ebp + 8]
    cmp     eax, dword 1
    je      .open_ok
    cmp     eax, dword 2
    je      .read_ok
    jmp     .done

.open_ok:
    push    dword kernel32_rd_byte_len
    push    dword kernel32_rd_byte_str
    push    dword stdout
    call    sys_write

    push    dword succ_openkernel_len
    push    dword succ_openkernel_str
    push    dword stdout
    call    sys_write
    call    sys_newline
    jmp     .done

.read_ok:
    push    dword kernel32_rd_byte_len
    push    dword kernel32_rd_byte_str
    push    dword stdout
    call    sys_write

    push    dword succ_readkernel_len
    push    dword succ_readkernel_str
    push    dword stdout
    call    sys_write
    call    sys_newline

.done:
    mov     esp, ebp
    pop     ebp
    ret     4

; -----------------------------------------------------------------------------
; read buffer from loader
; -----------------------------------------------------------------------------
loader_read:
    push    ebp
    mov     ebp, esp

    mov     ebx, dword [ebp +  8]   ; fd
    mov     ecx, dword [ebp + 12]   ; buffer
    mov     edx, dword [ebp + 16]   ; len
    mov     eax, SYS_READ
    int     0x80

    cmp eax, -1
    jg  .file_read_ok                ; error at read file ...
        mov     ebx, dword stdout
        mov     ecx, dword fail_readkernel_str
        mov     edx, dword fail_readkernel_len
        mov     eax, SYS_WRITE
        int     0x80
        call    sys_newline
        jmp     .done

        ; -------------------------------------
        ; file_read_ok:
        ; -------------------------------------
        .file_read_ok:
        mov     ebx, dword stdout               ; stdout
        mov     ecx, dword succ_readkernel_str  ; buffer
        mov     edx, dword succ_readkernel_len  ; len

        mov     eax, SYS_WRITE
        int     0x80

        call    sys_newline
.done:
    mov     esp, ebp
    pop     ebp
    ret     12

; -----------------------------------------------------------------------------
; open file from loader ...
; -----------------------------------------------------------------------------
loader_open:
    push    ebp
    mov     ebp, esp

    mov     ebx, dword [ebp +  8]   ; file name
    mov     ecx, dword [ebp + 12]   ; flags
    mov     edx, dword [ebp + 16]   ; mode
    mov     eax, SYS_OPEN
    int     0x80

    mov     dword [kernel32_dll_file_desc], eax
    cmp     eax, -1
    jg  .file_openok
        call    sys_open_fail_str
        jmp     .done

        ; -------------------------------------
        ; file open ok:
        ; -------------------------------------
        .file_openok:
        push    dword 1
        call    open_read_ok
.done:
    mov     esp, ebp
    pop     ebp
    ret     12

