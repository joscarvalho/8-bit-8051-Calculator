#include <REG51F380.H>

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! DELAY 50MS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
B0 EQU 18H 
B1 EQU 6AH
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! FLAG !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
F_REFRESH EQU 0D1H ;F1 do PSW
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! ENTRADAS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KLOAD EQU P0.7
KSET EQU P0.6
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! SAÍDAS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PRESULT EQU P0
POUT EQU P1
DISP EQU P2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! TAMANHOS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OPLEN EQU 8
DLEN EQU 10H
ALEN EQU 16
CLEN EQU 20H
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! DIGITOS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DISP_r EQU 0AFH
DISP_2 EQU 0A4H
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! ESTADOS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
S_READY EQU 0
S_OP1 EQU 1
S_OPX EQU 2
S_OP2 EQU 3
S_PROCESS EQU 4
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! VARIÁVEIS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OP1 DATA 30H
OP2 DATA 31H
OPX DATA 32H
RESULT DATA 33H
STATE DATA 34H
NEXT_STATE DATA 35H
INDEX DATA 36H

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! MAIN !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

CSEG AT 0H
SJMP INIT
CSEG AT 50H
	
INIT:
	MOV PCA0MD,#0
	MOV XBR1,#40H
MAIN:
	SETB KLOAD						;Inicia Kload a '1'
	SETB KSET						;Inicia Kset a '1'
	MOV STATE,#S_READY				;Define o estado atual para Ready
	MOV NEXT_STATE,#S_READY			;Define o proximo estado para Ready
	MOV INDEX,#0FFFFH				;Define o indice para '-1' para ao incrementar em Ready ir para 0
	MOV R2,#B1						;MSB do delay no R2
	MOV R3,#B0						;LSB do delay no R3
	MOV OP1,#0
	MOV OP2,#0
	MOV OPX,#0
	MOV RESULT,#0
CLOOP:	
	JB F_REFRESH,REFRESH		;Caso F_REFRESH esteja a 1 (indicado no final de uma operação) dá refresh ao estado				
MLOOP:	
	ACALL ENCODE	
	ACALL VKSET					
NEXTSTATE:					
	MOV STATE,NEXT_STATE
	SJMP CLOOP					
										                                                  															   					
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! REFRESH !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

REFRESH:							;Estado para dar "reset" á maquina de estados 
	MOV STATE,#S_READY
	MOV NEXT_STATE,#S_READY
	MOV INDEX,#0FFH
	CLR F_REFRESH
	SETB KLOAD
	SETB KSET
	SJMP NEXTSTATE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! LÓGICA ENTRADAS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
VKSET:
	JNB KSET,VKSET2   ;Caso KSET=0, avança para VKSET2. Caso contrário irá para VKLOAD
VKLOAD:
	JB KLOAD,VKSET	  ;Caso KLOAD=1, volta para VKSET. Caso contrário irá para o próximo estado
	JNB KLOAD,$ 	  ;Espera que largue KLOAD (prevenção)
	ACALL INCSTATE	
	MOV INDEX,#0
	SJMP NEXTSTATE
VKSET2:
	JB KSET,VSTATE  ;Caso KSET=1 avança o index e retorna ao inicio, senão vai para VKLOAD2
VKLOAD2:
	JB KLOAD,VKSET2 ;Se KLOAD=1 volta a VKSET2
	JNB KLOAD,$  ;Espera que largue KLOAD
	JNB KSET,$	 ;Espera que largue KSET
	MOV INDEX,#0
	MOV NEXT_STATE,#S_OPX  
	RET
VSTATE:
	INC INDEX
	MOV A,STATE
	SUBB A,#2  ;Se for OPX vai para AVANCA2 (para dar load ao array de operações)
	JZ CARREGA_OPERACOES
	SJMP CARREGA_DIGITS ;Se for OP1 ou OP2 vai para AVANCA (para dar load ao array de digitos)
INCSTATE:
	JNB KLOAD,$  ;Espera que largue KLOAD (prevenção)
	MOV A,STATE  
	JZ MLOOP	;se o estado for READY (0) ele salta para o inicio do loop
	INC NEXT_STATE
	MOV A,NEXT_STATE
	CLR C
	SUBB A,#S_OP2  ;verifica se o próximo estado for OP2 
	JZ VOPERACOES	;se for, irá verificar se a operação escolhida é o NOT,RR ou RL (para saltar OP2)
	RET
VOPERACOES:;Verifica qual operação é que o utilizador carregou
	MOV A,#4
	SUBB A,OPX   ;Subtrai OPX a 4 (NOT,RR,RL são as posições 5,6,7), ou seja, se estiver em uma destas operações Cy=1
	MOV A,NEXT_STATE
	ADDC A,#0	;Soma a NEXT_STATE o carry, caso este seja 1 (estando na presença de NOT,RR ou RL), salta OP2 e vai direto para PROCESS
	MOV NEXT_STATE,A
	SUBB A,#S_OP2 
	JZ DISP2	;Caso o próximo estado seja o OP2 vai para um loop onde mostra DISP2 no BCD e espera que o utilizador carregue em KSET
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! ESTADOS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	
ENCODE:						;Carrega a tabela de saltos por DPTR               
	MOV DPTR,#STATES										      
	MOV A,STATE										              
	RL A									                  
	JMP @A+DPTR										              
	RET	
STATES:						;Tabela de Saltos dos Estados		                      
	AJMP C_READY										 	 	  
	AJMP C_OP1										 		      
	AJMP C_OPX										   			  
	AJMP C_OP2										   			  
	AJMP C_PROCESS	
									   			  
C_READY:				;Primeiro estado da maquina (READY)
	MOV DISP,#DISP_r	;Move para o display o digito r
	MOV OP1,RESULT		;Move para OP1 o Result (prevenção: caso carregue em KSET e KLOAD para reutilizar o valor da operação anterior)
	MOV NEXT_STATE,#S_OP1
	RET																		
C_OP1:						;Estado de escolha do primeiro operando
	MOV OP1,INDEX
	ACALL CARREGA_DIGITS	;Dá update ao display para aparecer digitos			
	RET							
C_OPX:						;Estado de escolha de operação
	MOV OPX,INDEX
	ACALL CARREGA_OPERACOES	;Dá update ao display para aparecer as operações				
	RET								                      
C_OP2:						;Estado de escolha do segundo operando		
	MOV OP2,INDEX
	ACALL CARREGA_DIGITS	;Dá update ao display para aparecer digitos							                      									  
	RET										                      
C_PROCESS:					;Estado de execução da operação
	MOV NEXT_STATE,#S_READY
	LJMP EXECUTE			;Executa a operação																					  
	RET					
	 		 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! UPDATE DISP !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

CARREGA_DIGITS:     			;Carrega para r7 o indice do array digits, r6 a máscara e para o DPTR o array digits e dá update ao display
	MOV A,INDEX
	ANL A,#(ALEN-1)
	MOV INDEX,A
	MOV DPTR,#ARRAYDIGITS
	MOV R7,INDEX
	MOV R6,#(DLEN-1)
	ACALL UPDATE_DISP
	RET
CARREGA_OPERACOES:			;Carrega para r7 o indice do array operacoes, r6 a máscara e para o DPTR o array operacoes e dá update ao display
	MOV A,INDEX
	ANL A,#(OPLEN-1)
	MOV INDEX,A
	MOV DPTR,#ARRAYOP
	MOV R7,INDEX
	MOV R6,#(CLEN-1)
	ACALL UPDATE_DISP
	RET
UPDATE_DISP:				;Dá update ao display de acordo com os parametros fornecidos
;Recebe R7 como parametro (INDEX)
;Recebe R6 como parametro (Mascara)
;DPTR apontado para um dos arrays (ARRAYDIGITS ou ARRAYOP) 
	MOV A,R7
	ANL A,R6
	MOVC A,@A+DPTR
	MOV R7,A
	MOV DISP,A
	MOV A,INDEX
	MOV INDEX,A
	RET	
DISP2:							;Estando em OP2, aparece um '2' no BCD a indicar que irá escolher o operando 2
	MOV DISP,#DISP_2			
	JB KSET,$		;Enquanto nao carregar no KSET fica preso neste loop
	JNB KSET,$
	MOV INDEX,#0
	LJMP NEXTSTATE
	RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! OPERAÇÕES !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

EXECUTE:					;Escolhe da tabela a operação a realizar									  
	MOV DPTR,#TABLE												  													  
	MOV A, OPX											 		  
	ANL A,#(OPLEN-1)											  
	RL A											  			  
	JMP @A+DPTR											 		  
TABLE:											  				  
	AJMP CODE_AND											 	  
	AJMP CODE_OR											  	  
	AJMP CODE_SUB										 	  
	AJMP CODE_XOR											 	  
	AJMP CODE_ADD										     	  											      
	AJMP CODE_NOT
	AJMP CODE_RL												  
	AJMP CODE_RR											 	  
CODE_AND:											              	 
	MOV A,OP1											          
	ANL A,OP2											   		  
	AJMP RETURN											 		  
CODE_OR:											 			  
	MOV A,OP1												 	  											  
	ORL A,OP2											 		  
	AJMP RETURN											 		  
CODE_NOT:											 			  
	MOV A,OP1											 		  
	CPL A											 			  
	AJMP RETURN											 		  
CODE_XOR:											 			  
	MOV A,OP1													  
	XRL A,OP2											 		  
	AJMP RETURN											  		  
CODE_ADD:											  			  
	MOV A,OP1													  
	ADD A,OP2											  		  
	AJMP RETURN											 		  
CODE_SUB:											 			  
	MOV A,OP1													  
	SUBB A,OP2											  		  
	AJMP RETURN											   		  
CODE_RL:											              
	MOV A,OP1											         
	RL A											  			  
	AJMP RETURN											  		  
CODE_RR:											  			  
	MOV A,OP1													  
	RR A														  
	AJMP RETURN		

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! SAÍDA !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
												  
RETURN:						;Retorna o resultado e apresenta-o na saída	
	SETB F_REFRESH			;F_REFRESH=1 para dizer que a conta acabou e pode dar refresh à maquina de estados						
	MOV RESULT,A			
	MOV POUT,RESULT			;Mover o resultado da operação para POUT (no caso: P1)
	ACALL DELAY
	LJMP CLOOP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! DELAY !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

DELAY: 
	CLR C
	MOV A,R2
	CPL A
	MOV R2,A
	MOV A,R2
	CPL A
	ADD A,#1
	MOV R2,A
	MOV A,R3
	ADDC A,#0H
	MOV R3,A
DLOOP:
	JC SAI
	MOV A,R2
	ADD A,#1
	MOV R2,A
	MOV A,R3
	ADDC A,#0H
	MOV R3,A
	SJMP DLOOP
SAI:
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;! ARRAYS !;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

CSEG AT 1000H
ARRAYDIGITS:
	DB 0C0H,0F9H,0A4H,0B0H,99H,92H,82H,0F8H,80H,98H,88H,83H,0C6H,0A1H,86H,8EH

CSEG AT 2000H
ARRAYOP:
	DB 88H,0A3H,92H,89H,8CH,0ABH,0C7H,0CCH

END
