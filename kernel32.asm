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

section .text
module_header:
        db "BABL", 0        ; file header := PE module
        db 1,0,0            ; version
image_begin:
        dd mod_filesize     ; image size
        dd mod_functions    ; functions
        dd mod_entry        ; entry/start point of module

mod_entry:
        nop
        ret

entry_test1:
        ret
entry_test2:
        ret

section .data
mod_functions:
        db "test1", 0, 1    ; 0 = unknown, 1 = func, 2 = var
        dd entry_test1
        ;
        db "test2", 0, 1    ; 0 = unknown, 1 = func, 2 = var
        dd entry_test2

; -----------------------------------------------------------------------------
; E-O-F  end of file
; -----------------------------------------------------------------------------
mod_filesize equ $ - $$
