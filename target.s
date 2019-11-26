


global targetF
extern createTarget
extern scheduler
extern resume


targetF:
            call createTarget
            mov ebx, scheduler
            call resume
            jmp targetF
