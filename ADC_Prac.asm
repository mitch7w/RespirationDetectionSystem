; Mitchell Williams u18013555
; EMK Home Practical Am I Breathing?

    list	 p=PIC18F45K22
    #include	"p18f45k22.inc"

;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register
    CONFIG  LVP = ON              ; ***Single-Supply ICSP Enable bit (Single-Supply ICSP enabled if MCLRE is also 1)

    cblock
	ADCRESULT ;00
	LOWTHRESHOLD ;01
	HIGHTHRESHOLD ;02
	REACHEDHIGH ;03
	NUMBREATHSCOUNTED ;04
	TIMERROLLOVERS ;05
	TOTALROLLSHIGH ;06
	TOTALROLLSLOW ;07
	ROLLSPERBREATH ;08
	TMREXTRAHIGH ;09
	TMREXTRALOW ; A
	TABLECOUNT ; B
    endc
    
    org 00h ; Reset Vector
	GOTO STARTUP
    
    org 08h ; ISR Vector
	GOTO TimerISR

STARTUP
    ;Oscillator set at 4 MHz
	BSF 	OSCCON,IRCF0
	BCF	OSCCON,IRCF1
	BSF	OSCCON,IRCF2    
        
    ;------- Setup PORTA for ADC LED output ----------
    
	    CLRF PORTA
	    CLRF TRISA
	    MOVLW   B'00000000'
	    MOVWF PORTA ; All LEDs on PORTD off
	    
    ;---- Setup ADC ----
	    MOVLB 0xF ; ADC bank
	    CLRF ADRESH
	    MOVLW B'00001100'; ADC settings: left justified, Fosc/4 and 2TAD
	    MOVWF ADCON2
	    MOVLW B'00000000'; ADC settings: ADC refs are Vdd and Vss
	    MOVWF ADCON1
	    CLRF ADCON0
	    BSF ANSELA,0 ; RA0 used for ADC (not IO)
	    BSF TRISA,0 ; RA0 is an input
	    BSF ADCON0,ADON ; ADC's ANO enabled
	    MOVLB 0x0 ; Back to main bank
	    
	    ;------- Setup Timer2 for counting respiration rate ----------
	    MOVLW B'01111011' ; Timer 2 has 16 post and prescaler values
	    MOVWF T2CON ; Thus with additional counter can count around 16s
	    ; setup timer2 interrupt
	    BSF	PIE1,TMR2IE ; TMR2 interrupt enabled
	    BSF	INTCON,PEIE ; peripheral interrupt enable
	    BSF	INTCON,GIE	; global interrupt enable
	    
	    ;----- Set up data table pointer
	    CLRF    TBLPTRU,A
	    MOVLW   0x10
	    MOVWF   TBLPTRH,A
	    MOVLW   0x00
	    MOVWF   TBLPTRL,A
	    
    ;------Initialize variables-------------
    
	    CLRF REACHEDHIGH ; REACHEDHIGH = 0
	    CLRF NUMBREATHSCOUNTED ; numBreaths = 0
	    MOVLW 0x28
	    MOVWF LOWTHRESHOLD
	    MOVLW 0xD6
	    MOVWF HIGHTHRESHOLD
	    CLRF TIMERROLLOVERS
	    CLRF TOTALROLLSHIGH
	    CLRF TOTALROLLSLOW
	    CLRF ADCRESULT
	    CLRF TABLECOUNT
	    
    ;---- Conversion polling--------- TODO : CHANGE THIS TO AN INTERRUPT
POLL    BSF ADCON0,GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is donne
	    
	    ; Conversion now done
	    
	    MOVFF ADRESH,ADCRESULT ; Read upper eight bytes of ADC (8bit conversion)
	    CALL ADCISR ; proper interrupt not set up yet
	    GOTO POLL ;
   
	    ; ------ Turn on LED if value is high - exhaling-------
	    ; ------ Turn off LED if value is low - inhaling-------

ADCISR
	    MOVF LOWTHRESHOLD,0 ; put low threshold in W for comparison
EvaluateL   CPFSLT ADCRESULT; if ADCRESULT lower than lowThreshold call LOW subroutine
	    BRA EvaluateH ; Not lower than low threshold
            CALL SRLOW ; Calls LOW subroutine
	    BRA ADCEND ; Makes surehigh isn't evaluated
EvaluateH   MOVF HIGHTHRESHOLD,0 ; Put high threshold in W for comparison
	    CPFSGT ADCRESULT ; if ADCRESULT higher than high threshold call high subroutine
	    BRA ADCEND; not higher than high threshold - not low or high
	    CALL SRHIGH
ADCEND	    RETURN
	
	    ;------- SRLOW called when user inhaling ----------
SRLOW	    BTFSS REACHEDHIGH,0 ; skip next line if reachedHigh = true
	    GOTO TIMERCHECK ; reachedHigh not = true, go to timerCheck
	    ; reachedHigh is = true
	    BCF T2CON,TMR2ON ; switch off timer
	    BCF REACHEDHIGH,0 ; reachedHigh = false
	    ; One full breath has now occured
	    ; now account for small value leftover in counter not counted by TIMERROLLOVERS
	    MOVF    TMR2,0 ; W = last little bit of timer
	    ADDWF   TMREXTRALOW,1 ; TMREXTRALOW gets added to it extra value of timer
	    BNC	TableWrite ; there is no carry bit
	    INCF    TMREXTRAHIGH; there is a carry bit so increase TMREXTRAHIGH
TableWrite
	    ; now write timerrollovers to table
	    MOVF    TIMERROLLOVERS,0 ; W = Timerrolls
	    MOVWF   TABLAT
	    TBLWT*+ ; write TABLAT to that point in table with post increment
	    ; check if have gone through 8 breaths now
	    INCF NUMBREATHSCOUNTED; numBreathsCounted++
	    MOVLW 0x08
	    CPFSLT NUMBREATHSCOUNTED ; if numBreathsCounted < 8 skip next line
	    CALL SRAVERAGEBREATHS; numBreathsCounted = 8
	    CLRF TIMERROLLOVERS
	    BRA LOWRETURN
TIMERCHECK  
	    BTFSC T2CON,TMR2ON ; Skip next line if timer not started
	    BRA LOWRETURN ; timer has started
	    CLRF TMR2 ; if timer not started start it
	    BSF T2CON,TMR2ON    
LOWRETURN   RETURN
	    
	    ;-------- SRHIGH called when user exhaling------
SRHIGH	    BTFSC T2CON,TMR2ON ; Skip next line if timer not started
	    BSF REACHEDHIGH,0 ; reachedHigh = true	    
HIGHRETURN  RETURN
	    
	    
SRAVERAGEBREATHS    ; Average last 8 breaths to get respiration rate
	    ; Do long write for table
	    BSF	EECON1,EEPGD ; point to flash memory
	    BCF	EECON1,CFGS ; access program memory
	    BSF	EECON1,WREN ; enable memory writing
	    BCF	INTCON,GIE ; disable interrupts to not disturb write process
	    MOVLW   0x55
	    MOVWF   EECON2 ; write 55h to control register 2
	    MOVLW   0xAA
	    MOVWF   EECON2 ; write AAh to control register 2
	    BSF	EECON1,WR ; begin writing
	    BSF	INTCON,GIE; enable interrupts again
	    BCF	EECON1,WREN ; disable writes when writing complete
	    ; data table has 8 sets of rollovers - add all together and divide by 8 to get rollovers per breath 
	    ; add how ever many TMREXTRAHIGH rollovers to TOTALROLLS before divison
	    MOVF    TMREXTRAHIGH,0; W = TMREXTRAHIGH (amount of extra rollovers)
	    MOVWF   TOTALROLLSLOW ; totalrollsLOW = those extra rollovers
	    ; now add the rollovers from the table
	    ;Initalize Table pointer at 0x1000
	    CLRF    TBLPTRU,A
	    MOVLW   0x10
	    MOVWF   TBLPTRH,A
	    MOVLW   0x00
	    MOVWF   TBLPTRL,A
	    MOVLW   0x09 ; 8 values and an end of line TODO CHECK THIS shouldn't be 8
	    MOVWF   TABLECOUNT
TableLoop   TBLRD*+ ; TABLAT now has value in it
	    MOVF    TABLAT,0 ; W = TABLAT value
	    ADDWF   TOTALROLLSLOW ; adding value to timerRollsLow
	    BNC	    DecrementTC ; there is no carry
	    INCF    TOTALROLLSHIGH; there is a carry
DecrementTC 
	    DECFSZ  TABLECOUNT ; repeat until tableCount = 0
	    BRA TableLoop
	    ; reset tableCounter for next averaging
	    CLRF    TBLPTRU,A
	    MOVLW   0x10
	    MOVWF   TBLPTRH,A
	    MOVLW   0x00
	    MOVWF   TBLPTRL,A
Averaging
	    ; TOTALROLLSLOW and TOTALROLLSHIGH have all the rolls in them now
	    ; Multiply timer count by pre and postcaler value to get time in seconds
	    ; Each timer rollover worth 0.065536s
	    ; divide TotalRolls by 8 in order to get rolls for one breath
	    RRNCF TOTALROLLSLOW
	    RRNCF TOTALROLLSLOW
	    RRNCF TOTALROLLSLOW
	    MOVLW B'00011111'
	    ANDLW TOTALROLLSLOW
	    RRNCF TOTALROLLSHIGH
	    RRNCF TOTALROLLSHIGH
	    RRNCF TOTALROLLSHIGH
	    BTFSC TOTALROLLSHIGH,7
	    BSF TOTALROLLSLOW,7
	    BTFSC TOTALROLLSHIGH,6
	    BSF TOTALROLLSLOW,6
	    BTFSC TOTALROLLSHIGH,5
	    BSF TOTALROLLSLOW,5 
	    MOVLW B'00011111'
	    ANDLW TOTALROLLSHIGH
	    ; successfuly divided whole of totalRolls by 8
	    ; totalRolls now represents rollovers taken for one breath
	    ; only have to work with TOTALROLLSLOW in PICLEDS cause if value above a certain threshold the person is dead anyway
	    MOVFF TOTALROLLSLOW,ROLLSPERBREATH; timer rollovers per breath (average)
	    CALL PICLEDS
	    CLRF NUMBREATHSCOUNTED ; start counting numBreaths again
	    CLRF TOTALROLLSHIGH 
	    CLRF TOTALROLLSLOW ; the rollover count must be cleared
	    CLRF ROLLSPERBREATH
	    CLRF TIMERROLLOVERS
	    RETURN 
	    
; -------- Subroutine to SET PIC LEDs ----------
PICLEDS
	; Check value of BREATHPM and set various PIC LEDs accordingly		
Greater76
	    
	    MOVLW 0x4C ; 76 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 76
	    GOTO Greater57 ; ROLLSPERBREATH < 76
	    MOVLW   b'00000000' ; ROLLSPERBREATH > 76
	    MOVWF PORTA ; All LEDs on PORTA off
	    GOTO RETURNLEDS
Greater57
	    MOVLW 0x39 ; 57 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 57
	    GOTO Greater46 ; ROLLSPERBREATH < 57
	    MOVLW   b'10000000' ; ROLLSPERBREATH > 57
	    MOVWF PORTA ; 1 LEDs on PORTA on
	    GOTO RETURNLEDS
	    
Greater46
	    MOVLW 0x2E ; 46 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 46
	    GOTO Greater30 ; ROLLSPERBREATH < 46
	    MOVLW   b'11000000' ; ROLLSPERBREATH > 46
	    MOVWF PORTA ; 2 LEDs on PORTA on
	    GOTO RETURNLEDS
Greater30
	    MOVLW 0x1E ; 30 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 30
	    GOTO Less30 ; ROLLSPERBREATH < 30
	    MOVLW   b'11100000' ; ROLLSPERBREATH > 30
	    MOVWF PORTA ; 3 LEDs on PORTA on
	    GOTO RETURNLEDS
Less30
	    MOVLW   b'11110000' ; ROLLSPERBREATH < 30
	    MOVWF PORTA ; 4 LEDs on PORTA on
RETURNLEDS  RETURN ; PICLEDS Subroutine returns
	    
TimerISR
	    ; 0.065536s have elapsed (Timer gone through whole 16 periods)
	    INCF TIMERROLLOVERS ; Add one rollover count
	    BCF	PIR1,TMR2IF
	    RETFIE
	    
	    ;Initalize Table pointer at 0x1000
	    CLRF    TBLPTRU,A
	    MOVLW   0x10
	    MOVWF   TBLPTRH,A
	    MOVLW   0x00
	    MOVWF   TBLPTRL,A
	    ; TBLRD*+ read with post increment
	    MOVLW   0x00 ;
	    MOVWF   TABLAT
	    ;TBLWT*+ ; write TABLAT to that point in table with post increment
	    
	    
	    ORG 0x1000
tbl1:	db  0x77, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 ; All 8 breaths initially = 0
	    end