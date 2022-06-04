#include <stdio.h>
#include <stdlib.h>
#define LENGTH 10
int main(void)
{
    double arr[LENGTH]; int i; char aft;
    for (i = 0; i < LENGTH; ++i) {
        printf("[%d]: ", i);
        scanf_s("%lf%c", &arr[i], &aft);
        if (aft != '\n') {
            fprintf(stderr, "Invalid input\n"); --i;
            continue;
        }
    }
    putchar('\n');
    double max = 0.0;

    _asm {
        finit
        mov esi, 0
        mov ecx, LENGTH
        max_loop :
        fld arr[esi]
            fcom max //сравнить вещественные числа, сравниваем max с вершиной стека
            fstsw ax // копировать регистр состояния в АХ (с1, с2, с3)
            and ah, 00000001b //проверяем биты (001)
            jnz max_else
            fstp max // переместить вершину стека в max
            max_else :
            add esi, 8
            loop max_loop
            fwait //для синхронизации
    }

    if (max == 0.0) {
        fprintf(stderr, "Zero division error\n");
        return 1;
    }

    _asm {
        mov esi, 0
        mov ecx, LENGTH
        change_loop :
        fld arr[esi]
            fdiv max
            fstp arr[esi]
            add esi, 8
            loop change_loop
            fwait
            //127 - 1,18 - 3,40 - 38
            //1024 - 308
            //16383 - 4932

    }

    for (i = 0; i < LENGTH; ++i)
        printf("%4d:%8.3g\n", i, arr[i]);

    return 0;
}
