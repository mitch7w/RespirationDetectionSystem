; Mitchell Williams u18013555
; EMK Home Practical Am I Breathing?

    list	 p=PIC18F45K22
    #include	"p18f45k22.inc"

;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register
    CONFIG  LVP = ON              ; ***Single-Supply ICSP Enable bit (Single-Supply ICSP enabled if MCLRE is also 1)
    
    ;Oscillator set at 4 MHz
	bsf 	OSCCON,IRCF0
	bcf	OSCCON,IRCF1
	bsf	OSCCON,IRCF2    
    
    cblock
	ADCRESULT
	LOWTHRESHOLD
	HIGHTHRESHOLD
	REACHEDHIGH
	BREATHPM
	NUMBREATHSCOUNTED
	TIMERROLLOVERS
	TOTALROLLSHIGH
	TOTALROLLSLOW
    endc
    org 08h ; ISR Vector
	GOTO TimerISR
    org 00h ; Reset Vector
    
    ;------- Setup PORTD for ADC LED output ----------
    
	    CLRF PORTA
	    CLRF TRISA
	    MOVLW   B'00000000'
	    MOVWF PORTA ; All LEDs on PORTD off
	    
    ;---- Setup ADC ----
	    MOVLB 0xF ; ADC bank
	    clrf ADRESH
	    clrf ADCRESULT
	    MOVLW B'00101111'; ADC settings: left justified,internal oscillator and 12TAD
	    MOVWF ADCON2
	    MOVLW B'00000000'; ADC settings: ADC refs are Vdd and Vss
	    MOVWF ADCON1
	    BSF ANSELA,0 ; RA0 used for ADC (not IO)
	    BSF TRISA,0 ; RA0 is an input
	    BSF ADCON0, ADON ; ADC's ANO enabled
	    MOVLB 0x0 ; Back to main bank
	    
	    ;------- Setup Timer2 for counting respiration rate ----------
	    MOVLW B'01111010' ; Timer 2 has 16 post and prescaler values
	    MOVF T2CON ; Thus with additional counter can count around 16s
	    
    ;------Initialize variables-------------
    
	    CLRF REACHEDHIGH ; REACHEDHIGH = 0
	    CLRF BREATHPM ; BREATHPM = 0
	    CLRF NUMBREATHSCOUNTED ; numBreaths = 0
	    MOVLW 0x64
	    MOVWF LOWTHRESHOLD
	    MOVLW 0x6A
	    MOVWF HIGHTHRESHOLD
	    CLRF TIMERROLLOVERS
	    CLRF TOTALROLLSHIGH
	    CLRF TOTALROLLSLOW
	    
    ;---- Conversion polling--------- TODO : CHANGE THIS TO AN INTERRUPT
POLL    BSF ADCON0, GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is donne
	    
	    ; Conversion now done
	    
	    MOVF ADRESH,W ; Read upper eight bytes of ADC (8bit conversion)
	    MOVWF ADCRESULT ;
	    CALL ADCISR ; proper interrupt not set up yet
	    CLRF ADCRESULT
	    GOTO POLL ;
   
	    ; ------ Turn on LED if value is high - exhaling-------
	    ; ------ Turn off LED if value is low - inhaling-------

ADCISR
	    MOVF LOWTHRESHOLD,W ; put low threshold in W for comparison
EvaluateL   CPFSLT ADCRESULT; if ADCRESULT lower than lowThreshold call LOW subroutine
	    BRA EvaluateH ; Not lower than low threshold
	    CALL SRHIGH ; Calls LOW subroutine
	    BRA ADCEND ; Makes surehigh isn't evaluated
EvaluateH   MOVF HIGHTHRESHOLD,W ; Put high threshold in W for comparison
	    CPFSGT ADCRESULT ; if ADCRESULT higher than high threshold call high subroutine
	    BRA ADCEND; not higher than high threshold - not low or high
	    CALL SRLOW
ADCEND	    RETURN
	
	    ;------- SRLOW called when user inhaling ----------
SRLOW	    BTFSS REACHEDHIGH,0 ; skip next line if reachedHigh = true
	    GOTO TIMERCHECK ; reachedHigh not = true, go to timerCheck
	    ; reachedHigh is = true
	    BCF T2CON,TMR2ON ; switch off timer
	    BCF REACHEDHIGH,0 ; reachedHigh = false
	    ; One full breath has now occured
	    MOVF TMR2,0; write last little bit of timer to W TODO implemetn something to account for these lost seconds
	    ; TIMERROLLOVERS now has how many times the timer rolled over
	    ; add timerrollovers to totalrollovers
	    MOVFF TIMERROLLOVERS,W ; W = TIMERROLLOVERS
	    ADDWF TOTALROLLSLOW,1
	    BNC IncrementNB; if there no carry don't add a high byte
	    INCF TOTALROLLSHIGH ;there was a carry add it to the totalrollshigh
IncrementNB
	    INCF NUMBREATHSCOUNTED; numBreathsCounted++
	    MOVLW 0x08
	    CPFSLT NUMBREATHSCOUNTED ; if numBreathsCounted < 8 skip next line
	    CALL SRAVERAGEBREATHS; numBreathsCounted = 8
	    CLRF TIMERROLLOVERS ; so can begin counting anew
	    BRA LOWRETURN
TIMERCHECK  
	    BTFSC TMR2ON,W ; Skip next line if timer not started
	    BRA LOWRETURN ; timer has started
	    CLRF TMR2 ; if timer not started start it
	    BSF T2CON,TMR2ON    
LOWRETURN   RETURN
	    
	    ;-------- SRHIGH called when user exhaling------
SRHIGH	    BTFSC T2CON,TMR2ON ; Skip next line if timer not started
	    BSF REACHEDHIGH,0 ; reachedHigh = true	    
HIGHRETURN  RETURN
	    
	    
SRAVERAGEBREATHS    ; Average last 8 breaths to get respiration rate
	    ; TOTALROLLSLOW and TOTALROLLS HIGH contains total number of timer rollovers
	    ; Multiply timer count by pre and postcaler value to get time in seconds
	    ; Each timer rollover worth 0.065536s
	    ; divide TotalRolls by 8 in order to get rolls for one breath
	    RRNCF TOTALROLLSLOW
	    RRNCF TOTALROLLSLOW
	    RRNCF TOTALROLLSLOW
	    MOVLW B'00011111'
	    ANDLW TOTALROLLSLOW,1
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
	    ANDLW TOTALROLLSHIGH,1
	    ; successfuly divided whole of totalRolls by 8
	    ; totalRolls now represents rollovers taken for one breath
	    ; only have to work with TOTALROLLSLOW in PICLEDS cause if value above a certain threshold the person is dead anyway
	    
	    MOVFF TOTALROLLSLOW ROLLSPERBREATH; timer rollovers per breath (average)
	    CALL PICLEDS
	    CLRF NUMBREATHSCOUNTED ; start counting numBreaths again
	    CLRF TOTALROLLSHIGH 
	    CLRF TOTALROLLSLOW ; the rollover count must be cleared
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
	    MOVLW   b'00000001' ; ROLLSPERBREATH > 57
	    MOVWF PORTA ; 1 LEDs on PORTA on
	    GOTO RETURNLEDS
	    
Less46
	    MOVLW 0x2E ; 46 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 46
	    GOTO Greater30 ; ROLLSPERBREATH < 46
	    MOVLW   b'00000011' ; ROLLSPERBREATH > 46
	    MOVWF PORTA ; 2 LEDs on PORTA on
	    GOTO RETURNLEDS
Greater30
	    MOVLW 0x1E ; 30 rolls
	    CPFSGT ROLLSPERBREATH ; skip next line if ROLLSPERBREATH > 30
	    GOTO Less30 ; ROLLSPERBREATH < 30
	    MOVLW   b'00000111' ; ROLLSPERBREATH > 30
	    MOVWF PORTA ; 3 LEDs on PORTA on
	    GOTO RETURNLEDS
Less30
	    MOVLW   b'00001111' ; ROLLSPERBREATH < 30
	    MOVWF PORTA ; 4 LEDs on PORTA on
RETURNLEDS  RETURN ; PICLEDS Subroutine returns
	    
TimerISR
	    ; 0.065536s have elapsed since Timer gone through whole 1 period
	    INCF TIMERROLLOVERS ; Add one rollover count
	    BCF T2CON,TMR2ON ; switch off timer
	    RETFIE
	    
	    end