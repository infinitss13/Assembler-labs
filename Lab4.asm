.286
.model small
.stack 256
.data


handle dw 0					 
path db "m.txt", 0			;file path
pixels equ 2000				;amount of pixels on screen
words equ 4000				;amount of bytes on screen
screen db 4000 dup (00)		;screen array (contains ASCII's and colors)
map db 2200 dup(0)			;map array with characters
temp db 7 dup ('$')			;array for integer output
screen_start dw 0			;zero position in 0B800h

str_underline db "---------------$"
str_game_over db "!!! GAME OVER !!!$"
str_game_over_instruction db "PRESS [E] TO EXIT OR PRESS [R] TO RESTART GAME$"
str_level_completed db "CONGRATULATIONS, LEVEL COMPLETED$"
str_level_completed_instructions db "PRESS [E] TO EXIT OR PRESS [M] TO RETURN TO THE MAIN MENU$"
str_player_lives db "LIVES: $"		
str_enemies_left db " ENEMIES: $"		
str_start_game db "1. START GAME$"			
str_choose_difficulty db "2. LEVEL$"                                          
str_exit db "3. EXIT$"
str_easy db "1. EASY$"						
str_medium db "2. MEDIUM$"
str_hard db "3. HARD$"
output_pos_x db 0			;variable for convinient output
input db 1 dup (' ')				;contains last inputed character


game_is_over dw 0			;boolean game is over
level_is_completed dw 0		;boolean level is completed

rand dw 0					;contains last random number

hours db 0
minutes db 0
seconds db 0
prev_seconds db 0
new_seconds db 0
time_str db 9 dup ('$')		;string for time output


;*****Player variables*****
p_lives dw 0						;amount of player lives
p_moving dw 0						;boolean, present if player can move for one tile
p_pos dw 0							;position of player on screen, index in screen array
p_direction db 0					;can be 0[up], 1[right], 2[down], or 3[left]
p_directions db '^', '>', 'v', '<'	;direction characters
p_bullet_pos dw 1 dup (' ')					;position of player bullet
p_bullet_dir db 1 dup (' ')					;direction of player bullet
p_bullet_exist db 0					;1 - bullet is present, 0 - not gl_game_is_present
p_base_blocks dw 0					;amount of player base blocks(tiles)
p_base_blocks_were dw 0				;amount of player base blocks(tiles) at the start of the level

;*****Enemies varaiables*****
e_quantity equ 20					;size of enemies arrays
e_count dw 0						;how many of enemies from array are present
e_poss dw 20 dup (0)				;array of enemies positions, same to p_pos
e_dirs dw 20 dup (0)				;array of enemies directions, same to p_direction
e_moved_by dw 20 dup (0)			;how many tiles each enemy has moved for, need for enemies behavior
e_awaited dw 20 dup(0)				;how many ticks each enemy has moved for, needed for difficulty
e_exist dw 20 dup (0)				;1 - if enemy is present, 0 if not
e_b_poss dw 20 dup (0)				;array of positions of enemies bullets
e_b_dirs dw 20 dup (0)				;array of directions of enemies bullets
e_b_exist dw 20 dup (0)				;1 - if enemy bullet is present, 0 if not
e_b_delay dw 20 dup (0)				;each enemy shoots after a random period of time
e_awaiter dw 16 					;enemy deffault wait ticks, used for difficulty

;*****Constants*****
b_length equ 160					;[byte length] - how many characters are in one line
w_length equ 80						;[word length] - how many words are in one line
up_gap equ 480						;[gap in up direction] - amount of characters reserved in the top of screen for game statistic
w_up_gap equ 240					;[words size gap in up durection]
	
;*****Colors*****
c_player equ 9 
c_orange equ 7
c_white equ 15
c_metal equ 4
c_green equ 3
c_black equ 0
c_cyan equ 3h
c_red equ 6
c_p_bullet equ 7					
c_e_bullet equ 7					
c_p_base equ 9   					
c_enemy equ 4
c_bonus equ 5

;*****Characters*****
s_empty equ 'e'
s_wall equ 178
s_metal equ 178
s_tree equ 176
s_player db 41h
s_p_bullet equ 254					
s_p_base equ 220					
s_e_bullet equ 254					
s_enemy equ 'x'						
s_up equ '^'						
s_right equ '>'						
s_down equ 'v'						
s_left equ '<'						
	
.code
jmp start

strlen macro stroke					;finds amount of characters before '$', returns length in cx
	push di 
	push es
	push cx
	
	mov ax, @data
	mov es, ax
	mov al, '$'
	mov di, offset stroke
	mov cx, 70h
	repne scasb ; symbol search in string
	inc cx
	mov ax, 70h
	sub ax, cx  
	
	pop cx
	pop es
	pop di 
endm strlen

out_str macro str, pos_x, pos_y, color 		;outputs string in specific position with specific color
	push ax
	push es
	push bx
	push dx
	push bp
	push cx
	
	mov ax, @data
	mov es, ax
	strlen str 
	mov cx, ax
	mov bp, offset str
	mov ah, 13h		; output string
	mov al, 00h     ; set video regime
	mov bl, color
	mov dh, pos_y
	mov dl, pos_x
	int 10h

	pop cx
	pop bp
	pop dx
	pop bx
	pop es
	pop ax
endm out_str

;-------generate random position on the screen-------
rand_screen_pos macro 						
	push cx 
	push bx
	mov cx, 80
	call next_rand							;new random from 0 to 79
	mov ax ,rand 
	mov bx, 2
	mul bx 									;convert random number to x cordinate
	mov cx, 25								;new random y
	call next_rand
	mov bx, rand
	mul bx 									;mul x and y to get position on screen
	pop bx
	pop cx
endm rand_screen_pos

;--------generate rand below border---------
rand_by macro border 						
    push cx
    mov cx, border
    call next_rand    
    pop cx
endm rand_by

;---------generates rand below cx---------
next_rand proc  							
    push ax 			;rand = [time]*13+3+rand
    push bx 
    push dx   
    db 0fh, 31h         ;reading value of inner counter of processor clock cycles
	mov  dx, ax         ;and push this value into dx
	in  ax, 40h         ;load data from space input/output
	mul  dx
    xchg ax, bx         ;exchange
    mov ax, rand
    add ax, bx
    mov bx, 13
    mul bx
    add ax, 3
    mov bx, cx
    xor dx, dx
    div bx  
    mov rand, dx 
    pop dx 
    pop bx 
    pop ax
    ret 
next_rand endp

;-------call all render functions and copy screen array int 0B800h-------
render proc 								
	push si 
	push di
	call redraw_player
	call redraw_p_bullet
	call redraw_enemies
	call redraw_e_bullets
	mov cx, words
	sub cx, up_gap
	mov di, word ptr screen_start
	add di, up_gap
	mov si, offset screen
	cld ;clear dir flag
	rep movsb  ;copy bite
	pop di 
	pop si
	ret
render endp

;-----check positions in front of player and spawn bullet if position if empty-----	
check_bullet_spawn_pos proc 	
	push bx
	push ax
	push di

	mov bl, p_direction
	mov ax, p_pos
	call get_pos_by_dir						;gets position in front of player

	mov di, ax
	cmp screen[di], s_empty					;if position in front of player is empty - spawn bullet
	jne not_empty_sp

	mov ax, p_pos 							;spawning bullet
	mov p_bullet_pos, ax
	mov bl, p_direction
	mov p_bullet_dir, bl
	mov p_bullet_exist, 1
	jmp check_bullet_sp_end

	not_empty_sp:
	cmp screen[di], s_tree					;if tree or wall are in front of player - destroy them
	je check_bullet_destroy_tile
	cmp screen[di], s_wall
	je check_bullet_destroy_tile

	cmp screen[di], s_up 					;if enemy is in front of player - destroy it
	je check_bullet_destroy_enemy
	cmp screen[di], s_right
	je check_bullet_destroy_enemy
	cmp screen[di], s_down
	je check_bullet_destroy_enemy
	cmp screen[di], s_left
	je check_bullet_destroy_enemy

	cmp screen[di], s_p_base 				;if player base is in front of player - destroy it
	je check_bullet_destroy_base
	jmp check_bullet_sp_end

	check_bullet_destroy_enemy:				;destroy enemy
	mov ax, di
	call dont_exist_with_pos
	jmp check_bullet_destroy_tile

	check_bullet_destroy_base:				;destroy base
	dec p_base_blocks
	jmp check_bullet_destroy_tile

	check_bullet_destroy_tile:				;destroy a tile
	mov screen[di], s_empty
	mov screen[di+1], c_black
	mov p_bullet_exist, 0
	jmp check_bullet_sp_end

	check_bullet_sp_end:
	pop di
	pop ax
	pop bx
	ret
check_bullet_spawn_pos endp

;-------check position in front of enemy-------
check_eb_spawn_pos proc ;(mostly same as check_bullet_spawn_pos)
;[check enemy bullet spawn position]		;si - index in e_arrays
	push ax 
	push bx 
	push di
	push si

	cmp e_b_exist[si], 1					;if bullet is not present - exit proc
	je check_eb_sp_end

	mov bx, e_dirs[si]
	mov ax, e_poss[si]
	call get_pos_by_dir						;get position in front of enemy
		
	mov di, ax
	cmp screen[di], s_empty					;spawn bullet if position is empty
	jne not_empty_eb_sp
		
	mov ax, e_poss[si]
	mov e_b_poss[si], ax
	mov ax, e_dirs[si]
	mov e_b_dirs[si], ax
	mov e_b_exist[si], 1
	jmp check_eb_sp_end
		
	not_empty_eb_sp:
	cmp screen[di], s_tree					;if wall, tree or player base are in front - destroy them 
	je check_eb_destroy_tile
	cmp screen[di], s_wall
	je check_eb_destroy_tile
	cmp screen[di], s_p_base
	je check_eb_destroy_base
	jmp check_eb_sp_end

	check_eb_destroy_base:
	dec p_base_blocks
	jmp check_eb_destroy_tile
		
	check_eb_destroy_tile:
	mov screen[di], s_empty
	mov screen[di+1], c_black
	mov e_b_exist[si], 0
	jmp check_eb_sp_end

	check_eb_sp_end:

	pop si 
	pop di 
	pop bx 
	pop ax
	ret
check_eb_spawn_pos endp 

;------calculate position in front of ax by direction in bl and returns this position in ax------
get_pos_by_dir proc 						
;[get position by directon]		;bl - direction, ax - position; ret ax
	cmp bl, 0
	jne dir_not_0
	sub ax, b_length
	jmp get_tile_by_dir_end
	
	dir_not_0:
	cmp bl, 1
	jne dir_not_1
	add ax, 2
	jmp get_tile_by_dir_end

	dir_not_1:
	cmp bl, 2
	jne dir_not_2
	add ax, b_length
	jmp get_tile_by_dir_end

	dir_not_2:
	cmp bl, 3
	jne get_tile_by_dir_end
	sub ax, 2
	jmp get_tile_by_dir_end

	get_tile_by_dir_end:
	ret
get_pos_by_dir endp

;-----call all update functions and handle input-----
update proc 								
	push bx
	push ax
	push di
	push cx
	mov ah, 01h  ; set video regime (color regime 40x25)
	int 16h
	
	jnz keyboard_input						;if keyboard buffer isn't empty
	jmp update_continue
	keyboard_input:
	call get_key
	
	cmp input, 32							;[space] - shoot
	jne not_keySpace
	cmp p_bullet_exist, 1
	jne space_input
	jmp update_continue 
	
	space_input:
	add rand, 1
	call check_bullet_spawn_pos
	jmp update_continue

	not_keySpace:
	mov p_moving, 1
	cmp input, 'w'							;[w] - move up
	jne not_keyW
	mov p_direction, 0
	jmp update_continue

	not_keyW:								
	cmp input, 's'							;[s] - move down
	jne not_keyS
	mov p_direction, 2
	jmp update_continue

	not_keyS:								
	cmp input, 'a'							;[a] - move left
	jne not_keyA
	mov p_direction, 3
	jmp update_continue

	not_keyA:					
	cmp input, 'd'							;[d] - move right
	jne not_keyD
	mov p_direction, 1
	jmp update_continue

	not_keyD:
	cmp input, 'r'							;[r] - restart game
	jne not_keyR
	jmp start

	not_keyR:								;not hanled input
	update_continue:
	mov input, 0
	call update_player
	call update_p_bullet
	call update_enemies
	call update_e_bullets
	call update_clocks
	call update_game_status

	update_end:
	pop cx
	pop di
	pop ax
	pop bx
	ret
update endp

;------update game_is_over and level_is_completed------ 
update_game_status proc 					
	push ax
	mov ax, p_base_blocks_were
	cmp p_base_blocks, ax 					;if base is damaged - game over
	jne level_completed
	cmp p_lives, 0							;if player lives equal 0 - game over
	je ugs_game_is_over
	cmp e_count, 0							;if no more enemies left - level is completed
	je usg_level_is_completed
	jmp ugs_end

	usg_level_is_completed:
	mov level_is_completed, 1
	jmp ugs_end

	ugs_game_is_over:
	mov game_is_over, 1
	jmp ugs_end

	ugs_end:
	pop ax
	ret
update_game_status endp 

;------update player character by direction [^, >, v, <]------
update_player_symbol proc 					
	push ax
	push di
	push cx 
	xor cx, cx
	xor di, di
	mov cl, p_direction
	update_symbol_loop:
	inc di
	loop update_symbol_loop
	mov ah, p_directions[di]
	mov s_player, ah
	pop cx
	pop di
	pop ax
	ret
update_player_symbol endp

;------update player position------
update_player proc  						
	push ax
	push bx
	push di

	mov di, p_pos
	call erase_di_tile						;erase player in previous position
	cmp p_moving, 1
	jne update_player_end

	dec p_moving							;moved by one tile
	mov bl, p_direction
	mov ax, p_pos
	call get_pos_by_dir						;new position
	mov di, ax

	cmp screen[di], s_empty					;move to new position if it's empty
	jne up_not_empty
	mov p_pos, di
	jmp update_player_end

	up_not_empty:							
	cmp screen[di], s_tree					;smash tree in front of tank
	jne update_player_end
	mov p_pos, di
	jmp update_player_end

	update_player_end:
	call update_player_symbol

	pop di
	pop bx
	pop ax 
	ret
update_player endp

;------update position of player bullet------
update_p_bullet proc 						
	push di
	push bx
	push ax

	cmp p_bullet_exist, 1					;update position only if bullet is present
	jne update_p_b_end

	mov ax, p_bullet_pos
	mov bl, p_bullet_dir
	call get_pos_by_dir
	mov di, p_bullet_pos
	call erase_di_tile
	mov p_bullet_pos, ax

	update_p_b_end:
	pop ax
	pop bx
	pop di
	ret
update_p_bullet endp

;------update position of enemies bullets------
update_e_bullets proc 						
	push ax 
	push bx 
	push di
	push si 
	push cx 
	mov cx, e_quantity
	xor si, si 
	update_eb_loop:
		cmp e_b_exist[si], 1
		jne update_eb_loop_end

		mov di, e_b_poss[si]
		call erase_di_tile
		mov ax, e_b_poss[si]
		mov bx, e_b_dirs[si]
		call get_pos_by_dir
		
		mov e_b_poss[si], ax

		update_eb_loop_end:
		add si, 2
	loop update_eb_loop

	update_e_b_end:
	pop cx
	pop si
	pop di 
	pop bx
	pop ax
	ret 
update_e_bullets endp 

;------enemy's move and shoot logic-----
update_enemies proc 						
	push cx
	push si
	push di
	push ax

	mov cx, e_quantity
	xor si, si
	update_each_enemy_loop:
		cmp e_exist[si], 1
		je ue_exist
		jmp ue_loop_end_for_dead

		ue_exist:
		call enemy_shoot

		mov di, e_poss[si]
		cmp screen[di], s_empty
		je e_cant_exist
		jmp ue_loop_begin

		e_cant_exist:
		mov ax, e_poss[si]
		call dont_exist_with_pos

		ue_loop_begin:
		mov ax, e_awaiter
		cmp e_awaited[si], ax				;enemy slowdown
		jge ue_awaited
		jmp ue_loop_end

		ue_awaited:
		mov e_awaited[si], 0
		cmp e_moved_by[si], 8				;enemy random turn logic
		jl ue_loop_continue
 		
		mov e_moved_by[si], 0
		rand_by 4
		mov ax, rand
		mov e_dirs[si], ax
		jmp ue_loop_continue

		ue_loop_continue:
		mov ax, e_poss[si]
		mov bx, e_dirs[si]
		mov di, ax
		call erase_di_tile
		call get_pos_by_dir
		mov di, ax

		cmp di, p_pos 						;can't move into player
		je ue_not_empty

		push cx
		push si
		mov cx, e_quantity
		xor si, si
		update_eel_check_e_pos:
			cmp di, e_poss[si] 				;can't move into another enemy
			je ue_enemy_pos
			add si, 2
		loop update_eel_check_e_pos
		jmp ue_not_enemy_pos

		ue_enemy_pos:
		pop si
		pop cx
		jmp ue_not_empty

		ue_not_enemy_pos:
		pop si
		pop cx

		cmp screen[di], s_empty 			;move if position is empty
		jne ue_not_empty

		mov e_poss[si], ax
		inc e_moved_by[si]					;moved by one more tile
		jmp ue_loop_end_for_dead

		ue_not_empty:
		rand_by 4							;random turn
		mov ax, rand
		mov e_dirs[si], ax
		jmp ue_loop_end_for_dead
		ue_loop_end:
		inc e_awaited[si]
		ue_loop_end_for_dead:
	dec cx
	add si, 2
	jcxz end_e_update
	jmp update_each_enemy_loop
	end_e_update:
	pop ax
	pop di
	pop si
	pop cx
	ret
update_enemies endp

;------perform shoot by enemy------
enemy_shoot proc 							
	push ax
	cmp e_b_delay[si], 0					;shooting delay
	jne e_shoot_awaiting
	call check_eb_spawn_pos
	rand_by 100
	mov ax, rand 
	mov e_b_delay[si], ax 					;new shooting delay
	jmp enemy_shoot_end

	e_shoot_awaiting:
	dec e_b_delay[si]
	jmp enemy_shoot_end 

	enemy_shoot_end:
	pop ax
	ret
enemy_shoot endp

;------get user input------
get_key proc 								
	mov ax, 0
	int 16h     ;keyboard interruption
	cmp al, 0
	je get_extended
	mov input, al
	jmp get_key_end
	get_extended:
	mov input, ah
	get_key_end:
	call clear_keyboard_buffer	;clear al unhandled input
	ret
get_key endp

;------draw player character in p_pos on screen------

redraw_player proc 							
	push ax
	push bx
	push di

	mov di, p_pos
	mov ah, s_player
	mov al, c_player
	mov screen[di], ah
	mov screen[di+1], al

	pop di
	pop bx
	pop ax
	ret
redraw_player endp

;------draw bullet and handles bullet logic------
redraw_p_bullet proc 						
	push di
	push bx
	push ax

	cmp p_bullet_exist, 1					;only if bullet is present
	je redraw_p_b_continue
	jmp redraw_p_b_end
	redraw_p_b_continue:

	mov di, p_bullet_pos
	cmp screen[di], s_empty					;draw bullet if tile is empty
	jne rpb_not_empty
	mov screen[di], s_p_bullet
	mov screen[di+1], c_p_bullet
	jmp redraw_p_b_end

	rpb_not_empty:							;destroy tile if it isn't empty
	cmp screen[di], s_tree
	je rpb_erase_tile
	cmp screen[di], s_up
	je rpb_erase_enemy
	cmp screen[di], s_right
	je rpb_erase_enemy
	cmp screen[di], s_down
	je rpb_erase_enemy
	cmp screen[di], s_left
	je rpb_erase_enemy
	cmp screen[di], s_enemy
	je rpb_erase_enemy
	cmp screen[di], s_p_base
	je rpb_destroy_base_block
	cmp screen[di], s_wall
	je rpb_erase_tile
	jmp rpb_destroy_bullet

	rpb_destroy_base_block:
	dec p_base_blocks						;destroy player base block
	jmp rpb_erase_tile

	rpb_erase_enemy:
	cmp screen[di+1], c_player				;if it isn't player
	je rpb_erase_player
	mov ax, di
	call dont_exist_with_pos				;destroy enemy
	jmp rpb_erase_tile

	rpb_erase_player:
	dec p_lives 							;destroy player
	jmp rpb_erase_tile

	rpb_erase_tile:
	call erase_di_tile						;destroy tile
	jmp rpb_destroy_bullet

	rpb_destroy_bullet:
	mov p_bullet_exist, 0					;bullet isn't present
	redraw_p_b_end:
	pop ax
	pop bx
	pop di
	ret
redraw_p_bullet endp 

;------redraw enemies bullets------
redraw_e_bullets proc 						
	push di
	push bx
	push ax
	push si
	push cx 
	mov cx, e_quantity
	xor si, si 
	redraw_eb_loop:
		cmp e_b_exist[si], 1				;redraw only if bullet is present
		jne redraw_eb_loop_end

		mov di, e_b_poss[si]
		cmp screen[di], s_empty				;if tile is empty - draw bullet
		jne reb_not_empty
		mov screen[di], s_p_bullet
		mov screen[di+1], c_p_bullet
		jmp redraw_eb_loop_end

		reb_not_empty:						;destroy tile if it's tree, wall or player
		cmp screen[di], s_tree
		je reb_erase_tile
		cmp screen[di], s_up
		je reb_erase_player
		cmp screen[di], s_right
		je reb_erase_player
		cmp screen[di], s_down
		je reb_erase_player
		cmp screen[di], s_left
		je reb_erase_player
		cmp screen[di], s_p_base
		je reb_destroy_base_block
		cmp screen[di], s_wall
		je reb_erase_tile
		jmp reb_destroy_bullet

		reb_erase_player:					;erase player
		cmp screen[di+1],c_player
		jne reb_destroy_bullet
		dec p_lives
		jmp reb_destroy_bullet

		reb_destroy_base_block:
		dec p_base_blocks					;erase player base
		jmp reb_erase_tile

		reb_erase_tile:
		call erase_di_tile					;erase tile
		jmp reb_destroy_bullet

		reb_destroy_bullet:
		mov e_b_exist[si], 0				;bullet isn't present
		jmp redraw_eb_loop_end

		redraw_eb_loop_end:
		add si, 2
	loop redraw_eb_loop
	redraw_eb_end:
	pop cx 
	pop si 
	pop ax
	pop bx
	pop di
	ret 
redraw_e_bullets endp 

;------draw proper enemy character according to enemy direction------
redraw_enemies proc  						
	push di
	push si
	push cx
	push ax
	mov cx, e_quantity
	xor si, si
	redraw_each_enemy_loop:
		cmp e_exist[si], 0
		je re_before_end
		mov di, e_dirs[si]
		mov al, p_directions[di] 			;get direction character
		mov di, e_poss[si]
		mov screen[di], al
		mov screen[di+1], c_enemy

		re_before_end:
		add si, 2
	loop redraw_each_enemy_loop
	pop ax
	pop cx
	pop si
	pop di
	ret
redraw_enemies endp

;------erase tile with di position on screen------
erase_di_tile proc 							
	mov screen[di], s_empty
	mov screen[di+1], c_black
	ret
erase_di_tile endp

;------reset of enemy arrays------
clear_enemies proc 						
	push si
	push cx
	push di
	mov cx, e_quantity
	clear_enemies_loop:
		mov e_exist[si], 0
		mov di, e_b_poss[si]				;clear enemies positions on screen
		mov screen[di], s_empty 
		mov screen[di+1], c_black
		mov e_b_exist[si], 0
		add si, 2
		loop clear_enemies_loop
	mov e_count, 0
	pop di
	pop cx
	pop si 
	ret
clear_enemies endp

;------fill enemies direction array with random directions------
enemies_rand_directions proc 				
	push si
	push cx
	mov cx, e_quantity
	xor si, si
	erd_loop:
		rand_by 4
		mov ax, rand
		mov e_dirs[si], ax
		add si, 2
		loop erd_loop
	pop cx
	pop si 
	ret
enemies_rand_directions endp

;------destroy enemy with position equal ax------
dont_exist_with_pos proc 					
;ax - enemy pos
	push si
	push di

	call get_si_by_pos 						;get enemy index in arrays bu position
	mov di, e_poss[si]
	call erase_di_tile

	cmp e_b_exist[si], 0
	je dewp_bullet_dont_exist
	mov di, e_b_poss[si]					;erase bullet if it is present
	call erase_di_tile
	mov e_b_exist[si], 0

	dewp_bullet_dont_exist:
	mov e_exist[si], 0
	dec e_count

	pop di
	pop si 
	ret
dont_exist_with_pos endp

;------return index in enemies arrays by position------
get_si_by_pos proc  						
;[get si index by position]
;ax - enemy pos
	push cx
	mov cx, e_quantity
	xor si, si
	get_si_by_pos_loop:
		cmp e_poss[si], ax 					;if position equals to ax - index founded
		je get_si_by_pos_endloop
		add si, 2
	loop get_si_by_pos_loop
	get_si_by_pos_endloop:
	pop cx 
	ret 
get_si_by_pos endp 

;------update clock------
update_clocks proc 	;check real time on computer, if it's more, than saved previous time, than increment seconds
    push ax 
    push dx
    
    mov ah, 2ch   ; get time
    int 21h
    mov new_seconds, dh
    mov al, new_seconds
    cmp prev_seconds, al 					;compare previous time with new
    je clocks_end

    inc seconds 							;add second
    mov prev_seconds, dh
    cmp seconds, 60							;if seconds == 60, than increment minutes
    je seconds_60
    jmp clocks_end

    seconds_60:
    mov seconds, 0
    inc minutes
    cmp minutes, 60							;if minutes == 60, than increment hours
    je minutes_60
    jmp clocks_end

    minutes_60:
    mov minutes, 0
    inc hours
    cmp hours, 60							;if hours == 60, than make hours zero
    je hours_60 
    jmp clocks_end

    hours_60:
    mov hours, 0
    jmp clocks_end

    clocks_end:
    pop dx 
    pop ax
    ret
update_clocks endp 

;------output 2 numbers of time like 00------
out_time_part proc 							
    add al, '0'
    mov time_str[di], al
    inc di              
    add ah, '0'
    mov time_str[di], ah  
    inc di
    ret    
out_time_part endp

;------fill time_str array and output it like 01:10:12------
output_time proc 						
    push ax
    push bx
    push di    
    xor di, di
    xor ax, ax
    xor bx, bx
    mov al, hours 
    mov ah, 0
    mov bx, 10
    div bl              
    call out_time_part						;mov hours to time_str array
    mov time_str[di], ":" 
    inc di
    mov al, minutes  
    mov ah, 0
    div bl
    call out_time_part						;mov minutes to time_str array
    mov time_str[di], ":"
    inc di
    mov al, seconds 
    mov ah, 0
    div bl
    call out_time_part						;mov seconds to time_str array

    strlen time_str
    xchg ax, bx
    mov ax, w_length
    sub ax, bx 
    sub ax, 2

    mov output_pos_x, al
    out_str time_str, output_pos_x, 1, c_green
    pop di
    pop bx 
    pop ax
    ret
output_time endp

;------reverse------
reverse proc        	
    push si         ;si - begin, di - end of substring
    push di
    push ax
    push bx

    cld   ; clear dir flag 
    reverse_cycle:
        mov al, [si]  						;swapping symbols
        mov bl, [di]
        mov [si], bl
        mov [di], al

        dec di    							;moving borders towards each other
        inc si
        cmp si, di 
    jl reverse_cycle       					;if borders are met -> ret  

    pop bx
    pop ax
    pop di
    pop si
    ret
reverse endp

;------convert integer in ax to 'temp' string------
make_str_from_integer proc 				
    push di 
    push dx
    push cx     
    push si
    push es   

    push ax
      
    xor bx, bx  
    mov bx, @data
    push bx
    
    ;push @data
    pop es 

	mov si, offset temp

    mov cx, 10      
    cmp ax, 0     
    jge make_str_loop 
    neg ax									;make negative number positive
    make_str_loop:
    xor dx, dx
    div cx 									;div ax by 10 to get last numeral
    xchg ax, dx
    add al, '0'								;convert integer to ascii
    mov [si], al 							;put ascii in array 'temp'
    xchg ax, dx      
    inc si
    or ax, ax
    jne make_str_loop						;continue while ax>0
    pop ax
    cmp ax, 0      
    jge end_makestr 						
    clc  
    xor bx, bx
    mov bx, '-'
    mov [si], bx
    ;mov [si], '-'
    end_makestr: 

    push si
    pop di  
    dec di          
    mov si, offset temp 	
    call reverse 							;reverse 'temp' array

    inc di
    xor bx, bx
    mov bx, 0
    mov [di], bx
    ;mov [di], 0 
    xor bx, bx
    
    pop es
    pop si
    pop cx
    pop dx  
    pop di
    ret      
make_str_from_integer endp    

;------read symbol map from file------
read_map proc 								
	push dx
	push ax
	push bx
	push cx

	mov ax, 3D00h ; open file for reading
	lea dx, path
	int 21h
	jc file_read_err	
                
    mov handle, ax 		;save file handle
	mov bx, handle
    mov ah, 3fh    ; read file  
    lea dx, map
    mov cx, pixels       	
    int 21h

    mov handle, ax

    file_read_end: 	
	mov ah,3eh     ;close file
    int 21h

    pop cx
    pop bx
	pop ax
	pop dx
	ret
	file_read_err:
	jmp exit
read_map endp

;------convert single chars from file to word screen symbols------
convert_map proc 							
	push cx
	push di
	push si
	push ax
	push bx
	mov cx, pixels 							;amount of single characters on screen
	sub cx, w_up_gap 						;sub symbols for gap in the top of screen
	xor di, di
	xor si, si
	xor bx, bx
	convert_loop:
		cmp map[si], 31 					;if the symbol is service ascii - skip it
		ja convert_continue
		inc si
		jmp convert_loop

		convert_continue:
		cmp map[si], 'w' 					;convert 'w' into wall word
		jne not_wall
		mov ah, s_wall
		mov al, c_orange
		jmp convert_map_symbol

		not_wall:
		cmp map[si], 't' 					;convert 't' into tree word
		jne not_tree
		mov ah, s_tree
		mov al, c_green
		jmp convert_map_symbol

		not_tree:
		cmp map[si], 'b'  					;convert 'b' into base word
		jne not_p_base
		mov ah, s_p_base
		mov al, c_p_base
		inc p_base_blocks
		inc p_base_blocks_were
		jmp convert_map_symbol

		not_p_base:
		cmp map[si], 'v' 					;convert 'v' into enemy word
		jne not_enemy
			push si
			xor ax, ax
			mov ax, e_count
			mov bx, 2
			mul bx
			mov si, ax
			mov e_poss[si], di 				;save enemy position
			mov e_exist[si], 1
			pop si
		mov ah, s_enemy
		mov al, c_enemy	
		add e_count, 1 						;increment enemy count
		jmp convert_map_symbol

		not_enemy:
		cmp map[si], 'p' 					;convert 'p' into player word
		jne not_player
		mov p_pos, di
		mov ah, s_player
		mov al, c_player
		jmp convert_map_symbol

		not_player:
		cmp map[si], 'm' 					;convert 'm' into metal
		jne not_metal
		mov ah, s_metal
		mov al, c_metal
		jmp convert_map_symbol

		not_metal:
		convert_loop_inner_end:
		mov ah, 'e' 						;if symbol is unhandled - fill word with emptyness
		mov al, c_black

		convert_map_symbol:
		add bx, 2
		mov screen[di], ah
		mov screen[di+1], al

		convert_loop_end:
		inc si
		add di, 2
		dec cx
		jcxz convert_map_end
		jmp convert_loop
		convert_map_end:
	pop bx
	pop ax
	pop si
	pop di
	pop cx
	ret
convert_map endp

;------refresh all significant game variables, should be called before every start of the game------
refresh_game_variables proc 
	push si
	push cx
	push ax
	mov p_base_blocks, 0					;refresh player variables
	mov p_base_blocks_were, 0
	mov p_lives, 3
	mov p_moving, 0
	mov p_direction, 0

	call clear_enemies 						;refresh enemy variables
	mov cx, e_quantity
	refresh_gv_loop:
		rand_by 150
		mov ax, rand
		mov e_b_delay[si], ax
		add si, 2
	loop refresh_gv_loop

	mov game_is_over, 0
	mov level_is_completed, 0

	mov ah, 2ch								;refresh system time
    int 21h
    mov prev_seconds, dh
    mov seconds, 0
    mov hours, 0
    mov minutes, 0
	pop ax
	pop cx
	pop si
	ret
refresh_game_variables endp

;------output player lives, enemies amount and time------
print_game_stats proc 						
	push ax
	mov output_pos_x, 2
	out_str str_player_lives, output_pos_x, 1, c_green

	strlen str_player_lives
	add output_pos_x, al
	mov ax, p_lives
	call make_str_from_integer
	out_str temp, output_pos_x, 1, c_player

	strlen temp
	add output_pos_x, al
	add output_pos_x, 5
	out_str str_enemies_left, output_pos_x, 1, c_green

	strlen str_enemies_left
	add output_pos_x, al 
	mov ax, e_count
	call make_str_from_integer
	out_str temp, output_pos_x, 1, c_player

	call output_time

	pop ax
	ret 
print_game_stats endp 

;------flushes stored in keyboard buffer characters------
clear_keyboard_buffer proc 					
	push ax
	ckb_loop:
		mov ah, 01h		;check if buffer have symbol
		int 16h         ; keyboard interruption
		jz ckb_end
		mov ah, 00h 	;flush it
		int 16h         ; keyboard interruption
		jmp ckb_loop 	;repeat
	ckb_end:
	pop ax
	ret
clear_keyboard_buffer endp

;------wait one clock tick (1/18.2*second)------
wait_tick proc 								
	push ax
	push cx
	push dx
	push bx
	xor ax, ax
	int 1ah		;get current clock ticks
	mov bx, dx
	wait_tick_loop:
		xor ax, ax
		int 1ah      ;get current clock ticks
		cmp dx, bx 		;repeat cycle while ticks are remaining the same
	je wait_tick_loop
	pop bx
	pop dx
	pop cx
	pop ax
	ret
wait_tick endp

;------game over menu------
game_over: 									
	mov ax, 0003h  ; video regime #3
	int 10h 	   ;clear screen
	push 0B800h    ; load in 16-bit register of data     
	;push B800h
	pop es

	game_over_outp:
	
	out_str str_game_over, 2, 1, c_cyan 	;output messages
	out_str str_game_over_instruction, 2, 3, c_cyan

	go_wait_loop:
		mov ah, 01h ;input
		int 16h     ; keyboard interruption
		jz go_wait_loop
		call get_key 	;get user input
		cmp input, 'r'
		je game_over_to_start
		cmp input, 'e'
		je game_over_to_exit
		jmp go_wait_loop
	game_over_to_start:
	jmp game_start
	game_over_to_exit:
	jmp exit

level_completed: 	;level completed menu
	mov ax, 0003h   ;video regime #3
	int 10h 		;clear screen
	;push B800h     ;load in 16-bit register of data 
	push 0B800h
	pop es

	level_complete_outp:
	
	out_str str_level_completed, 2, 1, c_cyan
	out_str str_level_completed_instructions, 2, 3, c_cyan

	lc_wait_loop:
		mov ah, 01h     ;input
		int 16h         ;keyboard interruption
		jz lc_wait_loop
		call get_key 	;get user input
		cmp input, 'm'
		je lc_to_start
		cmp input, 'e'
		je lc_to_exit
	jmp lc_wait_loop

	lc_to_start:
	jmp game_menu
	lc_to_exit:
	jmp exit

choose_difficulty: 	;difficulty changes the time enemies think before their turn
	mov ax, 0003h   ;video regime #3
	int 10h         ;clear screen
	;push B800h     ;load in 16-bit register of data 
	push 0B800h
	pop es
	
	out_str str_easy, 2, 1, c_red
	out_str str_medium, 2, 2, c_red
	out_str str_hard, 2, 3, c_red

	cd_wait_loop:
		mov ah, 01h       ;input
		int 16h           ;keyboard interruption
		jz cd_wait_loop
		call get_key
		cmp input, '1'
		je cd_easy
		cmp input, '2'
		je cd_medium
		cmp input, '3'
		je cd_hard
	jmp cd_wait_loop

	cd_easy:
	mov e_awaiter, 32 	;change enemies ai to slow
	jmp game_menu
	cd_medium:
	mov e_awaiter, 16 	;change enemies ai to normal
	jmp game_menu
	cd_hard:
	mov e_awaiter, 4 	;change enemies ai to fast
	jmp game_menu

game_menu:	;main game menu
	mov ax, 0003h   ;video regime #3
	int 10h         ;clear screen
	;push B800h     ;load in 16-bit register of data   
	push 0B800h
	pop es
    
    out_str str_underline, 2, 0, c_red 
    ;1. START GAME
	out_str str_start_game, 2, 1, c_red
	
	out_str str_underline, 2, 2, c_red
	;2. LEVEL
	out_str str_choose_difficulty, 2, 3, c_red
	
	out_str str_underline, 2, 4, c_red
	;3. EXIT
	out_str str_exit, 2, 5, c_red
	
	out_str str_underline, 2, 6, c_red   

	gm_wait_loop: 	  ;get user input
		mov ah, 01h   ;input
		int 16h       ;keyboard interruption
		jz gm_wait_loop
		call get_key
		cmp input, '1'
		je gm_to_start
		cmp input, '2'
		je gm_to_choose_difficulty
		cmp input, '3'
		je gm_to_exit
	jmp gm_wait_loop

	gm_to_start:
	jmp game_start
	gm_to_choose_difficulty:
	jmp choose_difficulty
	gm_to_exit:
	jmp exit
	
start: 
	mov ax, @data
	mov ds, ax
	jmp game_menu

	game_start:
	mov ax, 0003h  ;video regime #3
	int 10h        ;clear screen
    ;load in 16-bit register of data    
	push 0B800h
	pop es	
	
	call refresh_game_variables				;refresh all significant variables
	call read_map							;read char map from file
	call convert_map 						;convert char map to word array
	call enemies_rand_directions 			;randomize start enemies directions

	game_loop:

		call render 						;render tiles
		call update 						;updates enemies, bullets, game stats, bonus and player
		call print_game_stats 				;outputs game stats
		call wait_tick 						;wait one tick to slow down the game

		cmp game_is_over, 0 				;check if game is over or level is completed
		je gl_game_is_present
		jmp game_over
		gl_game_is_present:
		cmp level_is_completed, 0
		je level_isnt_completed
		jmp level_completed
		level_isnt_completed:

	jmp game_loop


exit:
	mov ax, 0002h  ;video regime #3
	int 10h        ;clear screen
	mov ah, 4ch
	int 21h
end start