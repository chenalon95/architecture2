
section	.rodata                                                                          ; we define (global) read-only variables in .rodata section



 ;;;;;;;;; CORS[i] IS CO ROUTINE NUMBER (i-1)
section .bss 
    struc position
        size_i:
                x: resq  1
                y: resq  1
    endstruc
    droneSize equ 28
    STKSIZE  equ 16*1024                     ; 16 Kb
    coSize equ 12    ; three pointers
    allStacks: resb 4
    dronesArray: resb 4
    CORS: resb 4            ; pointer to an array of co-routines
    STKi: resb STKSIZE
    STKTarget: resb STKSIZE
    STKScheduler: resb STKSIZE
    STKPrinter: resb STKSIZE
    board: resb 100*100*size_i
    CURR: resd 1 
    SPT: resd 1         ; temporary stack pointer
    SPMAIN: resd 1      ; stack pointer of main
      
    struc drone
                pos: resb size_i
                angle: resb  8
                scores: resb  4
    endstruc
          




section	.data
    
   
    resu: dq 0.0
    scaleParam: dd 65535.0
    input: dd 0    
    index: dd 0
    n: dd 9
    N:dd 0           ;number of drones 
    T:dd 0           ;number of targest needed to destroy in order to win the game 
    K:dd 0            ;how many drone steps between game board printings 
    Beta:dq 0.0         ;angle of drone field-of-view 
    dis:dq 0.0            ;maximum distance that allows to destroy a target 
    seed:dd 0             ;seed for initialization of LFSR shift register 
    p_16: db 0
    p_14: db 0
    p_13: db 0
    p_11: db 0
    funcOffset: equ 0                ; offset of pointer to co-routine function in co-routine struct 
    SPP: equ 4                          ; offset of pointer to co-routine stack in co-routine struct 
    indexOfNextCo: dd 0     ; index of routing after printer
    printTarget: db "%.2f,%.2f",10,0
    printDrone: db "%d,%.2f,%.2f,%.2f,%d",10,0
    floatInput: db "%lf",10,0
    IntegerInput: db "%d",10,0
    SpecialCORS: 
        dd printer
        dd target
        dd scheduler
    target:
        dd targetF                ; function
        dd STKTarget + STKSIZE    ; point to head of STKi
        dq 0.0                    ; x value
        dq 0.0                    ; y value
    printer:
        dd printerF
        dd STKPrinter + STKSIZE
    scheduler:
        dd schedFunc
        dd STKScheduler + STKSIZE




section .text
    global main 
    global initCo
    global K
    global N
    global seed
    global resu
    global resume
    global endCo
    global dis
    global T
    global CURR
    global CORS
    global Beta
    global coSize
    global do_shift
    global target
    global dronesArray
    global createTarget
    global scheduler
    global droneSize
    global printer
    extern printerF
    extern droneFunc
    extern printf
    extern fprintf
    extern malloc
    extern targetF
    extern schedFunc
    extern free
    extern sscanf

%macro scale 1 
            mov eax, dword[seed]
            mov ebx, %1
            mov edx, 0
            mov ecx, scaleParam
            mul ebx             ;eax <- seed*wanted range
            mov dword[n], eax
            fild dword[n]     ; result in st(0)
            fld dword[scaleParam]
            fdivp
            fstp qword[resu]

 %endmacro

main:

    push ebp
	mov ebp, esp	
	pushad

    ;convert input args into floating point
    mov ebx, dword[ebp + 12]      
    add ebx, 4
    push N                   ; number of drones
    push IntegerInput
    push dword[ebx]
    call sscanf
    add esp, 12
  
    ; allocate memory for adrones array
    mov ebx, droneSize
    mov eax, dword[N]
    mul ebx                         ; eax <- n*size_of_drone
    push eax                        ; pointer into eax
    call malloc
    add esp, 4
    mov dword[dronesArray], eax ; points to the head of the array

    
    ; allocate memory for co routines array
    mov ebx, 4
    mov eax, dword[N]
    mul ebx                         ; eax <- n*coSize
    push eax                        ; pointer into eax
    call malloc
    add esp, 4
    mov dword[CORS], eax            ; CORS points to head of co-routins' array

    mov esi, 0
    maLoop:
            mov eax, coSize
            push eax
            call malloc
            add esp, 4
            mov dword[CORS+esi*4], eax  
            inc esi 
            cmp esi, dword[N]
            jne maLoop 
    ; allocate memory for co routines stacks
    mov eax, 4
    mov ebx, dword[N]
    mul ebx
    push eax
    call malloc
    add esp, 4
    mov dword[allStacks], eax       ; all stacks holds pointer to co routins' stacks pointer
    
    mov esi, 0
    mallocLoop:
            mov eax, STKSIZE
            push eax
            call malloc
            add esp, 4
            add eax, STKSIZE
            mov dword[allStacks+esi*4], eax  
            inc esi 
            cmp esi, dword[N]
            jne mallocLoop 

    call buildCORS                  ; init CORS array

   ; continue with proccessing arguments
    mov ebx, dword[ebp + 12]
    add ebx, 8
    push T                  ; number of targets
    push IntegerInput
    push dword[ebx]
    call sscanf
    add esp, 12 
    
    mov ebx, dword[ebp + 12]
    add ebx, 12
    push K                  ; steps to print
    push IntegerInput
    push dword[ebx]
    call sscanf
    add esp, 12 

    mov ebx, dword[ebp + 12]
    add ebx, 16
    push Beta               ; angle
    push floatInput
    push dword[ebx]
    call sscanf
    add esp, 12 

    mov ebx, dword[ebp + 12]
    add ebx, 20
    push dis                ; angle
    push floatInput
    push dword[ebx]
    call sscanf
    add esp, 12 

    mov ebx, dword[ebp + 12]
    add ebx, 24
    push seed               ; seed
    push IntegerInput
    push dword[ebx]
    call sscanf
    add esp, 12 

    ; create first target x,y
    call createTarget

    ; create initial coordinates of all drones
    doLFSR:  
    mov edx, dword[N] 
    cmp edx, dword[index]
    je continueInit
    mov eax, droneSize
    mov ebx, dword[index]
    mul ebx                 ; eax <- size of drone * index, eax points to current drone
    pushad
    call do_shift           ; random x
    scale 100
    popad
    fld qword[resu]
    mov ebx, dword[dronesArray]
    fstp qword[ebx + eax ]   ; put the seed in the drone's x argument

    pushad
    call do_shift           ; random y
    scale 100
    popad

    fld qword[resu]
    fstp qword[ebx + eax + 8]

    pushad
    call do_shift           ; random angle
    scale 360
    popad
    fld qword[resu]
    fstp qword[ebx + eax + 16]  ;put the seed in the drone's angle argument
    
    mov dword[dronesArray + eax + 24], 0        ; init score
    inc dword [index]
    jmp doLFSR

    continueInit:           ; init and start co routines
    mov esi, 0              ; edx = j
    initCors:               ; loop to init all CORS
    jmp initCo             ; init co-routine with index EDX
    contInit:
    inc esi
    cmp esi, dword[N]
    jne  initCors 
    call initSpecialCo          ; init target, scheduler, printer
    
    startSched: 
    pushfd
    pushad                       ; save registers of main ()
    mov [SPMAIN], esp            ; save ESP of main ()
    mov ebx, scheduler           ; gets a pointer to a scheduler struct
    jmp do_resume                ; resume a scheduler co-routine

    endCo:
    mov esp, [SPMAIN]            ; restore ESP of main()
    popad                        ; restore registers of main ()
    jmp endGame
resume:                          ; save state of current co-routine,
                                 ; switch to the routine in ebx
    pushfd
    pushad
    mov edx, [CURR]
    mov [edx+SPP], esp           ; save current ESP
    
    ; switch routine to the one in ebx
    do_resume:                   ; load ESP for resumed co-routine
    mov esp, [ebx+SPP]      
    mov [CURR], ebx              ; ebx holds next routin
    popad                        ; restore resumed co-routine state
    popfd
    ret                          ; "return" to resumed co-routine

; a function that arrages CORS's pointers, 
; so that each 12 bytes of CORS will represent a CO Routine

section .data
temp: dd 0

section .text

buildCORS:

mov esi, 0                       ; drone/COR index
loopBuild:
mov eax, 4
mul esi                            
mov edx, eax                     ; edx <-coSize*index
mov ebx, droneFunc 
mov eax, dword[CORS+edx]
mov dword[eax], ebx              ; init function field with function
mov eax, 4
push edx
mul esi 
pop edx                          ; eax<- index* stksz
mov ecx, dword[allStacks + eax]  ; end of stack
mov eax, dword[CORS+edx]
mov dword[eax+4], ecx            ; ebx is a pointer  to the current stack field
mov dword[eax+8], esi            ; index of COR
inc esi
cmp esi, dword[N]                ; if we've reached the last co routine
mov edx, dword[CORS]
mov eax, [edx+4]


jne loopBuild 
ret

initCo:                          ; init co with index ESI
mov eax, esi                     ; get co-routine ID number
mov ebx, 4                       ; get pointer to COi struct
mul ebx
mov edx, dword[CORS+eax]
mov [SPT], esp                   ; save ESP value
mov esp, [edx +SPP]              ; get initial ESP value –pointer to COi stack
push droneFunc                   ; push initial “return” address
pushfd                           ; push flags
pushad                           ; push all other registers
mov [edx  +SPP], esp             ; save new SPi value (after all the pushes)
mov esp, [SPT]                   ; restore ESP val 
jmp contInit

initSpecialCo:
    initScheduler:
    mov ebx, scheduler           ; get pointer to COi struct
    mov eax, dword[ebx+funcOffset] ; get initial EIP value –pointer to COi function
    mov [SPT], esp               ; save ESP value
    mov esp, [ebx+SPP]           ; get initial ESP value –pointer to COi stack
    push eax                     ; push initial “return” address - function ptr
    pushfd                       ; push flags
    pushad                       ; push all other registers
    mov [ebx+SPP], esp           ; save new SPi value (after all the pushes)
    mov esp, [SPT]               ; restore ESP value

    initPrinter:
    mov ebx, printer             ; get pointer to COi struct
    mov eax, [ebx+funcOffset]    ; get initial EIP value –pointer to COi function
    mov [SPT], esp               ; save ESP value
    mov esp, [ebx+SPP]           ; get initial ESP value –pointer to COi stack
    push eax                     ; push initial “return” address - function ptr
    pushfd                       ; push flags
    pushad                       ; push all other registers
    mov [ebx+SPP], esp           ; save new SPi value (after all the pushes)
    mov esp, [SPT]               ; restore ESP value


    initTarget:
    mov ebx, target              ; get pointer to COi struct
    mov eax, [ebx+funcOffset]    ; get initial EIP value –pointer to COi function
    mov [SPT], esp               ; save ESP value
    mov esp, [ebx+SPP]           ; get initial ESP value –pointer to COi stack
    push eax                     ; push initial “return” address - function ptr
    pushfd                       ; push flags
    pushad                       ; push all other registers
    mov [ebx+SPP], esp           ; save new SPi value (after all the pushes)
    mov esp, [SPT]               ; restore ESP value    
    ret

createTarget:
    call do_shift
    scale 100
    fld qword[resu]
    fstp qword[target+8]      ; x
    call do_shift
    scale 100
    fld qword[resu]
    fstp qword[target+16]      ; y
    ret

do_shift:

        push ebx

        mov esi, 0
        shiftNum:
        mov eax, dword [seed]
        mov ebx, 2
        mov edx, 0
        div ebx                 ;edx has the remainder, eax has the result
        mov byte[p_16], dl
        mov dl, 0
        mov dword[seed], eax    ;divide seed by 2

        ;place 15
        mov ebx, 2
        mov edx, 0
        div ebx                 ;edx has the remainder, eax has the result
        
        ;place 14
        mov ebx, 2
        mov edx, 0
        div ebx                 ;edx has the remainder, eax has the result
        mov byte[p_14], dl
        mov dl, 0

        ;place 13
        mov ebx, 2
        mov edx, 0
        div ebx                 ;edx has the remainder, eax has the result
        mov byte[p_13], dl
        mov dl, 0

        ;place 12
        mov ebx, 2
        mov edx, 0
        div ebx                 ;edx has the remainder, eax has the result

        ;place 11
        mov ebx, 2
        mov edx, 0
        div ebx                 ;edx has the remainder, eax has the result
        mov byte[p_11], dl

        ;do xor
        mov al, byte [p_13]
        xor al, dl

        mov dl, 0
        mov dl, byte[p_14]
        xor al, dl

        mov dl, 0
        mov dl, byte[p_16]
        xor al, dl

        cmp al, 0
        je dont_add             ; if al=0, add 0 at the beginning of the number(dont change number) 
        mov eax, dword[seed]    ; if al=1, add 2^15 to  the number 
        add eax,32768
        mov dword[seed], eax  

        dont_add:

        inc esi
        cmp esi, 16
        jne shiftNum

        pop ebx
        ret



endGame:

    ;------------------------------------ all frees in comments give errors
        ; mov eax, dword [dronesArray]
        ; push eax
        ; call free
        ; add esp, 4

        mov eax, dword[N]
        free1:
        dec eax
        mov ebx, dword[CORS+eax*4]  
        push ebx  
        call free
        add esp,4
        cmp eax, 0
        jne free1

        ; mov eax, dword[CORS]
        ; push eax
        ; call free
        ; add esp,4


        mov eax, dword[N]
        free2:
        dec eax
        mov ebx, dword[allStacks+eax*4] 
        sub ebx, STKSIZE 
        push ebx
        call free
        add esp,4
        cmp eax, 0
        jne free1


        ; mov eax, allStacks
        ; push eax
        ; call free
        ; add esp,4


        ; without popad on purpose
        mov esp, ebp	
	    pop ebp
	    ret

 
