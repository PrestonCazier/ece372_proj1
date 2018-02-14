@=====================================================
@	Title:	Project 1, Part 1
@	Author:	Preston Cazier
@	Date:	2017/07/17
@	Class:	ECE372 - Summer 2017
@-----------------------------------------------------
@
@	Brief: This part covers step one of project one, in
@		which a button is set up to modulo 10 count
@
@	Detail: This program turns on GPIO1 and set up the
@		button on pin 31 as an interupt source.  Each
@		time the button is pushed the counter
@		decrements.  This is a modulo 10 counter that
@		starts at 10 and resets at 0
@
@-----------------------------------------------------
@
@	Current
@	Version:	201707221010pc
@
@	Changes:
@		- 201707220957pc
@		* realized a slightly different implementation of bintoascii where the base address to write to is the address of the empty part of message
@		- 201707220943pc
@		* moved on after a few hours to flushing out talker_svc
@		-201707220315pc
@		* got stuck on checking uart interrupts
@			coundnt figure out why rxd was throwing an interrupt
@		-201707220230pc	
@		* noticed i forgot to add counter resets for
@			button counter and char pointer, 
@			added them into timer_svc and talker_svc respectively 
@		-201707220145pc
@		* fixed array indexing erros in BINTOASCII
@		-201707220105pc
@		* test irq_handler, found issues in BINTOASCII indexing
@		-201707220037pc
@		* filled out timer and uart interrupt checks
@		-201707223135pc
@		* added sudo code for talker_svc
@		-201707212205pc
@		* added sudo code for timer_svc
@		-201707212140pc
@		* corrected mainline erors
@		-201707212130pc
@		* tested mainline
@		-201707211850pc
@		* imported BINTOASCII procedure
@		-201707211720pc
@		* filled out BUTTON_SVC procedure
@		-201707211620pc
@		* filled out irq_handler
@		-201707211545pc
@		* added BUTTON_SVC procedure and sudo code
@		-201707211510pc
@		* added sudo-code to irq_handler
@		-201707211425pc
@		* added base code to irq_handler
@		procedure
@		-201707211231pc
@		* added sudo-code and initialization
@		to mainline
@		-201707201600pc
@		* added .equ statements containing all
@		neccasary register addresses and
@		control words
@		-201707191300pc =Initial version
@		* added common base code and header
@
@-----------------------------------------------------
@
@	Algorithm
@	***********************
@	MAINLINE
@		* Setup stacks for supervisor and IRQ mode
@		* Turn on clock to GPIO1
@		* Initialize INTC - Reset INTC
@		* Enable IRQ input by clearing bit 7 in CPSR
@
@		INTERUPT DIRECTOR
@		* save registers to stack
@		* check INTC_PENDING for GPIO, UART and TIMER
@		* if any one of these is true go to that service
@			procedure
@		* if none reset INTC Controller
@		* order check is UART, TIMER then GPIO
@		* order is only semi important, see report
@
@		TALKER_SVC
@		* check interrupt source for ctsn
@		* chcek intterupt source for rtx
@		* if not both reset and leave
@		* if both load address to message to play
@		* load offset to get current byte to send
@		* if last character reset offset
@		* send character
@		* if last character turn off uart interupts
@
@		BUTTON_SVC
@		* reset irq for the button so that button press can
@			do something again
@		* load counter containing number of button presses
@		* increment that value
@		* store it again
@		* return to mmainline idle loop
@
@		TIMER_SVC
@		* load number button presses
@		* load address of message
@		* load up offset into middle of message
@		* check and deal with number of timer intervals without button press
@		* if 4 or more change message to no song message
@		* if less than 4 make sure message is normal message
@		* find number of hundred by successive subtraction
@		* 100s convert to ascii
@		* find number of tens by successive subtraction
@		* remaining amount is ones value
@		* 100s convert to ascii
@		* 100s convert to ascii
@		* write converted ascci characters to middle of message
@		* rest interrupt for timer
@		* turn on interrupts for uart
@		* return to mainline idle loop
@
@-----------------------------------------------------
@
@	Register Uses
@	(Pattern holds true for mainline, irq handler and)
@	(all procedures, except where stated		    )
@
@	R0  => Used to store current in use base address
@		of important memory mapped register
@	R1  => Used to store control words
@	R2  => Used to store control words, used for calculations
@	R3  => Used to store control words, used for calculations
@	R4  => used for calculations
@	R5  => used for calculations
@	R6  => NOT USED
@	R7  => NOT USED
@	R8  => NOT USED
@	R9  => NOT USED
@	R10 => NOT USED
@	R11 => NOT USED
@	R12 => NOT USED
@	R13 => STACK POINTER
@	R14 => LINK REGISTER
@	R15 => PROGRAM COUNTER
@
@-----------------------------------------------------
@=====================================================

.global	_start
.global	_irq_handler

@ CM_PER
.equ		CMP_U4_CLKCTRL		,0x44E00078	@ address of CM_PER_UART5_CLKCTRL		p.1031  write 0x02
.equ 	CMP_GPIO1_CLKCTRL	,0x44E000AC	@ address of CM_PER_GPIO1_CLKCTRL		p.	write 0x02
.equ		CMP_T5_CLKCTRL		,0x44E000EC	@ Address of CM_PER_TIMER5_CLKCTRL		p.	write px02
.equ		PRCMCLKSEL_T5		,0x44E00518	@ address of PRCM_CLKSEL_TIMER5	p.1147	write	0x02
@ INTC
.equ		INTC_SYSCONFIG		,0x48200010	@ address of INTC_SYSCONFIG	p.538	write 0x00004000
.equ 	INTC_MIR1_CLEAR	,0x482000A8	@ address of INTC_MIR1_CLEAR	p.558	write 0x00002000
.equ		INTC_U4_UNMASK		,0x00002000	@ Value to Unmask Interrupts from Timer5 INT# 45
.equ		INTC_MIR2_CLEAR	,0x482000C8	@ address of INTC_MIR2_CLEAR	p.566	read 0x20000000
.equ		INTC_T5_UNMASKWORD	,0x20000000	@ Value to Unmask Interrupts from Timer5 INT# 93
.equ 	INTC_MIR3_CLEAR	,0x482000E8	@ address of INTC_MIR3_CLEAR	p.574	read 0x00000004
.equ		INTC_GPIO1_UNMASK	,0x00000004	@ Value to Unmask Interrupts from Timer5 INT# 98
.equ 	INTC_PENDING_IRQ1	,0x482000B8	@ address of INTC_PENDING_IRQ1	p.562	read 0x00002000
.equ 	INTC_PENDING_IRQ3	,0x482000F8	@ address of INTC_PENDING_IRQ2	p.570	read 0x20000000
.equ		INTC_PENDING_IRQ2	,0x482000D8	@ address of INTC_PENDING_IRQ3	p.578	read 0x00000004
.equ 	INTC_CONTROL		,0x48200048	@ address of INTC_CONTROL		p.542	read 0x01
.equ 	INTC_CTRL_RESET	,0x01		@ p.542, pin1- a value of 1 resets to allow new IRQ generation
@ GPIO1
.equ 	GPIO1_FALLINGDETECT	,0x4804C14C	@ address of GPIO1_FALLINGDETECT	p.4527
.equ 	BUTTON_PIN		,0x80000000	@ GPIO1 pin that button is attached to BBB manual p. 83
.equ 	GPIO1_IRQSTATUSSET	,0x4804C034	@ address of GPIO1_IRQSTATUSSET	p.4522
.equ 	GPIO1_SYSCONFIG	,0x4804C010	@ address of GPIO1_SYSCONFIG		p.4519
.equ 	GPIO1_IRQSTATUS	,0x4804C02C	@ address of GPIO1_IRQSTATUS		p.4521
@ TIMER5
.equ		T5_RESET			,0x48046010	@ address of T5_RESET		p.4077
.equ		T5_IRQES			,0x4804602C	@ address of T5_IRQENABLESET	p.4081
.equ		T5_TCRR			,0x48046040	@ address of T5_TCRR		p.4085
.equ		T5_TLDR			,0x4804603C	@ address of T5_TLDR		p.4085
.equ		T5_TCLR			,0x48046038	@ address of T5_TCLR		p.4083
.equ		T5_IRQSTATUS		,0x48046028	@ address of T5_IRQSTATUS	p.4080
.equ		T5_CLKRESETVAL		,0x01		@ 
.equ		T5_STARTVAL		,0x01		@ bit 1 turns on autoreload, bit 0 starts
@ UART5
.equ		U4_RXD			,0x44E10870	@ address of U4_RXD		p.1278	write 0x04
.equ		U4_TXD			,0x44E10874	@ address of U4_TXD		p.1278	write 0x24 
.equ		U4_CTSn			,0x44E108D0	@ address of U4_CTSn	p.1278	write 0x26
.equ		U4_RTSn			,0x44E108D4	@ address of U4_RTSn	p.1278	write 0x06
.equ		MODE6			,0x06		@ control word to set to mode6	p.bbb83
.equ		U4_LCR			,0x481A800C	@ UART5_LINE_CONTROL_REGISTER	p.4033	write 0x03, 0x83, 0xBF
.equ		CONFIG_MODEA		,0x83		@ write to LCR, info gathered from table 19-39
.equ		OP_MODE			,0x03		@ write to LCR, info gathered from table 19-39
.equ		U4_DHL			,0x481A8004 	@ address of UART5_DIVISOR_LOW_LATCH		p.4054	write 0x00
.equ		DHL_WORD			,0x00		@ info gathered from table 19-25, p.3994
.equ		U4_DLL			,0x481A8000	@ address of UART5_DIVISOR_HIGH_LATCH		p.4054	write 0x4E
.equ		DLL_WORD			,0x1A		@ info gathered from table 19-25, p.3994
.equ		MDR1				,0x481A8020	@ address of UART5_MODE_DEFINTION_REGISTER1	p.4034	write 0x00
.equ		MDR1_WORD			,0x00		@ write to MDR1, info gathered from p.4034
.equ		U4_IER			,0x481A8004	@ address of UART5_INTERRUPT_ENABLE			p.4026
.equ		IER_U4_WORD		,0x0A		@ bit3 is modemstsit, bit1 is thrit		p.4026
.equ		U4_FCR			,0x481A8008	@ address of UART5_FIFO_CONTROL_REGISTER	p.4032
.equ		U4_FCR_WORD		,0x06		@ bit2 TX_FIFO_CLEAR, bit1 RX_FIFO_CLEAR, bit 0 FIFO_EN  p.4032 
.equ		U4_IIR			,0x481A8008	@ UART5_INTERRUPT_IDENTIFICATION_REGISTER	p.4029
.equ		U4_RHR			,0x481A8000	@ reciever holding register, MUST BE IN OPERATION MODE	p.4025
.equ		U4_THR			,0x481A8000	@ transmit holding register, MUST BE IN OPERATION MODE	p.4025
.equ		U4_MSR			,0x481A8018	@ uart5 modum status register		p.4038	0x
.equ		U4_LSR			,0x481A8014	@ UART5_LINE_STATUS_REGISTER		p.4035	0x
.equ		U4_SCR			,0x481A8040	@ uart4 supplementary control register
@ General values
.equ		FIFTEENSEC		,0xFFF8ACFF	@ value to set timers for 15s
.equ		RESET			,0x02		@ genreal value used by most register to reset them
.equ		message_length 	,0x2A		@ 
.equ		middle_of_message_pointer ,0x12	@ 

@====================================================
@	MAINLINE
@=====================================================
_start:
@ set up stack_svc
	ldr		r13, =STACK_SVC			@ Setup Supervisor Stack
	add		r13, r13, #0x1000			@ Set top of stack
	cps		#0x12					@ Go to IRQ Mode
	ldr		r13, =STACK_IRQ			@ Setup IRQ Stack
	add		r13, r13, #0x1000			@ Set top of stack
	cps		#0x13					@ Return to Supervisor Mode
@----------------------------------------------------------------------------
@ turn on CM_PER_UART5_CLKCTRL
	ldr		r0, =CMP_U4_CLKCTRL			@ load address of CM_PER_UART4_CLKCTRL
	mov		r1, #RESET				@ value to turn on clk to UART4
	str		r1, [r0]					@ write to register to turn on UART4
@ turn on GPIO1
	ldr		r0, =CMP_GPIO1_CLKCTRL		@ Base address of CM_PER_GPIO1_CLKCNTL
	mov		r1, #RESET				@ control word to enable clock
	str		r1,[r0]					@ write back to enable clock
@ turn on clock module to timer5 and set frequency
	ldr		r0, =CMP_T5_CLKCTRL			@ load CM_PER_TIMER5_CLKCTRL register
	mov		r1, #RESET				@ load reset control word
	str		r1, [r0]					@ store reset in CM_PER_TIMER5_CLKCTRL
	ldr		r0, =PRCMCLKSEL_T5			@ ADDRESS OF PRCMCLKSEL_TIMER5
	mov		r1, #RESET				@ load reset control word, set frequency to 
	str		r1,[r0]					@ write to register to turn on PRCMCLKSEL
@---------------------------------------------------------------------------
@ intialize Interrupt Controller (INTC)
	ldr		r0, =INTC_SYSCONFIG			@ load address of INTC_SYSCONFIG
	mov		r1, #RESET				@ load value to reset INTC
	str		r1, [r0]					@ write back to INTC_SYSCONFIG
@ initialize INTC for UART4
	ldr		r0, =INTC_MIR1_CLEAR		@ load address of INTC_MIR1_CLEAR
	ldr		r1, =INTC_U4_UNMASK			@ load word to turn on UART5 interrupt in INTC
	str		r1, [r0]					@ write to INTC_MIR1_CLEAR to turn on
@ turn on timer 5 interrupt in INTC
	ldr		r0, =INTC_MIR2_CLEAR		@ load address of INTC_MIR_CLEAR2
	mov		r1, #INTC_T5_UNMASKWORD		@ load timer5 INTC unmask value
	str		r1, [r0]					@ write unmask word to INTC_MIR_CLEAR2
@ turn on GPIO1 interrupt in INTC
	ldr		r0, =INTC_MIR3_CLEAR		@ address of INTC_MIR3_CLEAR 
	mov		r1, #0x04					@ value to unmask INTC INT 98, GPIOINT1A
	str		r1, [r0]					@ write to INTC_MIR_CLEAR3
@---------------------------------------------------------------------------
@ set mode for lcd_data8 to map to uart4_TXD
	ldr		r0, =U4_TXD				@ load address of lcd_data8
	ldr		r1, [r0]				@ read register contents
	ldr		r2, =0xfffffff8			@ load and mask
	and		r1, r1, r2				@ modify to clear mode
	mov		r2, #MODE6				@ load word to set to mode4 with output
	orr		r1, r1, r2				@ modify to set mode
	str		r1, [r0]					@ write to change mode
@ set mode for lcd_data8 to map to uart4_RXD
	ldr		r0, =U4_RXD				@ load address of lcd_data9 
	ldr		r1, [r0]				@ read register contents
	ldr		r2, =0xfffffff8			@ load nand mask
	and		r1, r1, r2				@ modify to clear mode
	mov		r2, #MODE6				@ load word to set to mode4 with output
	orr		r1, r1, r2				@ modify to set mode
	str		r1, [r0]					@ write to change mode
@ set mode for lcd_data8 to map to uart4_CTSn
	ldr		r0, =U4_CTSn				@ load address of lcd_data14
	ldr		r1, [r0]				@ read register contents
	ldr		r2, =0xfffffff8			@ load nand mask
	and		r1, r1, r2				@ modify to clear mode
	mov		r2, #MODE6				@ load word to set to mode4 with output
	orr		r1, r1, r2				@ modify to set mode
	str		r1, [r0]					@ write to change mode
@ set mode for lcd_data8 to map to uart4_RTSn
	ldr		r0, =U4_RTSn				@ load address of lcd_data15
	ldr		r1, [r0]				@ read register contents
	ldr		r2, =0xfffffff8			@ load nand mask
	and		r1, r1, r2				@ modify to clear mode
	mov		r2, #MODE6				@ load word to set to mode4 with output
	orr		r1, r1, r2				@ modify to set mode
	str		r1, [r0]					@ write to change mode
@----------------------------------------------------------------------------
@ change uart to configuration mode a
	ldr		r0, =U4_LCR				@ load uart5 line control register
	mov		r1, #CONFIG_MODEA			@ load word to set lcr to configuration mode 1
	str		r1, [r0]					@ write to change mode
@ set uart5 divisor high and low latches for desired baud rate 
	ldr		r0, =U4_DHL				@ load address of divisor high latch
	mov		r1, #DHL_WORD				@ load value to be MSB of baud rate divisor 
	str		r1, [r0]					@ write to set MSB
	ldr		r0, =U4_DLL				@ load address of divisor low latch
	mov		r1, #DLL_WORD				@ load value to be LSB of baud rate divisor
	str		r1, [r0]					@ write to set LSB
@ set UART5_MDR1 to 16x divisor mode to achieve desired baud rate
	ldr		r0, =MDR1					@ load address of UART5 mode definition register 1
	mov		r1, #MDR1_WORD				@ load value to change mdr1 to 16x mode
	str		r1, [r0]					@ write to set MDR1 to 16x mode
@ change UART5 to operation mode
	ldr		r0, =U4_LCR				@ load uart5 line control register
	mov		r1, #OP_MODE				@ load word to set lcr to operation mode
	str		r1, [r0]					@ write to change mode
@ set UART5 to generate 2 types of interrupts
	ldr		r0, =U4_IER				@ load address for UART5_INTERRUPT_ENABLE_REGISTER
	mov		r1, #0x00					@ load word to turn on interrupts
	str		r1, [r0]					@ write to turn on THR and MODEM interrupts
@ adjust FIFO settings
	ldr		r0, =U4_FCR				@ load fifo control address
	mov		r1, #U4_FCR_WORD			@ load word to reset txd, rxd and disable fifo
	str		r1, [r0]					@ write to reset and disable fifo
@---------------------------------------------------------------------------------
@ initialize GPIO1
	ldr		r0, =GPIO1_SYSCONFIG		@ load address of GPIO1 Sysconfig register
	mov		r1, #RESET				@ load byte to reset GPIO1
	str		r1, [r0]					@ write byte to reset GPIO1
@ enable button as interupt source
	ldr		r0, =GPIO1_FALLINGDETECT		@ base address of GPIO1 control registers
	mov		r1, #BUTTON_PIN			@ control word to turn on bit 31
	ldr		r2,[r0]					@ read from GPIO1_FALLINGDETECT
	orr		r2, r1, r2				@ modify so that bit 31 gets turned on, w/o affecting other pins
	str		r2, [r0]					@ write back to GPIO1_FALLINGDETECT
	ldr		r0, =GPIO1_IRQSTATUSSET		@ load address of GPIO1_IRQSTATUSSET0
	str		r1, [r0]					@ write control word to GPIO1_IRQSTATUS_SET_0, turn on gpio irq
@--------------------------------------------------------------
@ TIMER REGISTER FOR COUNTER BASE OF TIMER 4 IS 48046000
	ldr		r0, =T5_RESET				@ ADDRESS OF RESETTING CLOCK
	mov		r1, #T5_CLKRESETVAL			@ VALUE TO RESET CLOCK
	str		r1, [r0]					@ RESET CLOCK
	ldr		r0, =T5_IRQES				@ ADDRES FOR IRQENABLE_SET
	mov		r1, #RESET				@ SET VALUE TO SEND INTERRUPT ON OVERFLOW
	str		r1, [r0]					@ TURN ON IRQ ENABLE OVERFLOW EVENTS
@ WRITE 1S TO TCRR(#0X40) AND TLDR(#0X3C)
	ldr		r1, =FIFTEENSEC			@ COUTNER OFFSET FOR 1 SEC
	ldr		r0, =T5_TLDR				@ RELOAD COUNTER ADDRESS (TLDR)
	str		r1, [r0]					@ LOAD COUNTER WITH NUMBER
	ldr		r0, =T5_TCRR				@ ADDRESS FOR COUNT REGISTER (TCRR)
	str		r1, [r0]					@ STORE VALUE TO TCRR
@--------------------------------------------------------------
@ enable irq in cspr
	mrs		r1, CPSR					@ copy CPSR
	bic		r1, #0x80					@ clear bit 7
	msr		CPSR_c, r1				@ write back to CPSR
@--------------------------------------------------------------
@ START TIMER AND SET AUTO RELOAD
	ldr		r0, =T5_TCLR				@ ADDRESS OF TCLR REGISTER
	mov		r1, #0x01 			@ LOAD VALUE TO AUTORELOAD
	str		r1,[r0]					@ STORE IT ---->HERE THE TIMER IS SET AND ON
	
@ wait for interrupt
idleloop:	nop
	b		idleloop
@=====================================================


@=====================================================
@	IRQ HANDLER
@=====================================================
_irq_handler:
@save registers to stack and check irq source
	stmfd	sp!, {r0-r5, lr}			@ push registers on the stack
	ldr		r0, =INTC_PENDING_IRQ1		@ load INTC_PENDING_IRQ1 register
	ldr		r1, [r0]					@ load value from INTC_PENDING_IRQ1
	tst		r1, #0x00002000			@ check to see if interrupt from uart
	bne		talker_svc				@ if not, go to modulo10count
	ldr		r0, =INTC_PENDING_IRQ2		@ load INTC_PENDING_IRQ2 register
	ldr		r1, [r0]					@ load value from INTC_PENDING_IRQ2
	tst		r1, #0x20000000			@ check to see if interrupt from clock
	bne		timer_svc					@ if not, go to modulo10count
	ldr		r0, =INTC_PENDING_IRQ3		@ load INTC_PENDING_IRQ3 register
	ldr		r1, [r0]					@ load value from INTC_PENDING_IRQ3
	tst		r1, #0x00000004			@ check to see if interrupt from gpio
	bne		button_svc				@ if it was go button_svc
backtowait:
	ldr		r0, =INTC_CONTROL			@ address of INTC_Control Register
	mov		r1, #0x01					@ value to clear bit 0
	str		r1, [r0]					@ write to INTC_Control Register
	ldmfd	sp!, {r0-r5,lr}			@ restore registers
	subs		pc, lr, #4				@ return from IRQ Handler
@=====================================================


@=====================================================
@	TALKER_SVC
@=====================================================
talker_svc:
@ load up UART4 MSR interrupt vector
	ldr		r0, =U4_MSR				@ load address of modem status register
	ldr		r1, [r0]					@ load MSR into r1 to be checked
@ grab the desired bit to check
	mov		r2, #0x10					@ load bit to check
	and		r1, r1, r2				@ use bit to check as a mask
@ test the interrupt and deal with the result
	tst		r1, r2					@ check to see if CTS == 1 
	bne		clearedtosend				@ if CTS is 1 then go to clearedtosend
	ldr		r0, =U4_LSR				@ else load address of line status register
	ldr		r1, [r0]					@ load value of LSR
	mov		r2, #0x20					@ load bit to check
	and		r1, r1, r2				@ use bit to check as a mask
	tst		r1, #0x20					@ check to see if THR == 1
	beq		backtowait				@ if thr is not 1 return to idle loop
	bne		end_talker_svc				@ else turn off interrupts before returning
clearedtosend:
@ get bit 5 from LSR to test
	ldr		r0, =U4_LSR				@ else load address of line status register
	ldr		r1, [r0]					@ load value of LSR
	mov		r2, #0x20					@ load bit to check
	and		r1, r1, r2				@ use bit to check as a mask
@ test lsr bit 5 and do something based on result
	tst		r1, #0x20					@ check to see if THR == 1
	beq		end_talker_svc				@ if not, turn off interrupts before returning
@ begin seding process
	ldr		r0, =messagetoplayaddress	@ get address of the place where message to play address is
	ldr		r1, [r0]					@ load message to play address
	ldr		r0, =char_pointer			@ load the character pointer to get to current spot in message
	ldr		r2, [r0]					@ load pointer value
	ldrb		r4, [r1, r2]			@ load byte stored in address of message at base of address + 
									@ current pointer value, this gives an actual byte address
	add		r2, r2, #1				@ increment current pointer to help with addressing bytes 
									@ in the message
	str		r2, [r0]
	ldr		r0, =U4_THR				@ load address of uart4 transmit holding register
	str		r4, [r0]					@ store ascii byte in transmit holding register
	ldr		r3, =message_length			@ load message length to get index of last char
	cmp		r2, r3					@ check to see if char pointer is larger than last index
	beq		reset_section
@continue to next char section
end_talker_svc:
	ldr		r0, =U4_IER				@ load address of UART4_INTERUPT_ENABLE_REGISTER
	mov		r1, #0x0A					@ move value to clear irq status of UART4
	str		r1, [r0]					@ write to clear current irq status
	b		backtowait
@ reset section
reset_section:
	ldr		r0, =char_pointer			@ load the character pointer to get to current spot in message
	mov		r1, #0x00					@ if char pointer is greater than last index, ie points off 
									@  end of string, then reset
	str		r1, [r0]					@ store character pointer for later use
	ldr		r0, =T5_IRQES
	mov		r1, #0x02
	str		r1, [r0]
	ldr		r1, =FIFTEENSEC			@ COUTNER OFFSET FOR 1 SEC
	ldr		r0, =T5_TLDR				@ RELOAD COUNTER ADDRESS (TLDR)
	str		r1, [r0]					@ LOAD COUNTER WITH NUMBER
	ldr		r0, =T5_TCRR				@ ADDRESS FOR COUNT REGISTER (TCRR)
	str		r1, [r0]					@ STORE VALUE TO TCRR
	ldr		r0, =T5_TCLR			@ load timer control register
	mov		r1, #0x01				@ load control word to start timer
	str		r1, [r0]				@ write to register to start timer
	ldr		r0, =U4_IER				@ load address of UART4_INTERUPT_ENABLE_REGISTER
	mov		r1, #0x00					@ move value to clear irq status of UART4
	str		r1, [r0]					@ write to clear current irq status
	bne		backtowait				@ since flags still set, skip reseting irq b/c message is done
									@ being sent
@=====================================================






@=====================================================
@	BUTTON_SVC
@=====================================================
button_svc:
	ldr		r0, =GPIO1_IRQSTATUS		@ get address of GPIO1_IRQSTATUS register
	ldr		r1, [r0]					@ load stored value
	tst		r1, #BUTTON_PIN			@ check if that value indicates that the button was pressed
	beq		backtowait				@ if not, leave
	str		r1, [r0]					@ write back to turn off interrupt request
	ldr		r0, =BUTTON_PRESS_COUNT		@ load address of button press counter variable
	ldr		r1, [r0]					@ get variable store value
	add		r1, r1, #1				@ increment that value to show the total number of times the 
									@ button was pressed
	str		r1, [r0]					@ store that value back in button press count variable
	ldr		r0, =NO_PRESS_COUNT			@ load no press counter
	mov		r1, #0x00					@ load value to reset counter b/c button was pressed
	str 		r1, [r0]					@ store that value
	b		backtowait
@=====================================================


@=====================================================
@	TIMER_SVC
@=====================================================
timer_svc:
	ldr		r0, =T5_IRQSTATUS			@ load TIMER5_IRQSTATUS
	ldr		r1, [R0]					@ load value from TIMER5_IRQSTATUS
	tst		r1, #0x02					@ check to see if interrupt was from timer5
	beq		leave_timer_svc				@ if it was not, go to beat procedure
bintoascii:
	ldr		r1, =BUTTON_PRESS_COUNT		@ load current value address
	ldr		r0,[r1]					@ load current value to be converted
	cpy		r5, r0					@ copy button press value for later comparison
	mov		r0, r0, lsl #2				@ store number to be converted in r0, multiply button 
									@ count in r0 that is ready to be converted by 4 so 
									@ that instead of beats/quarter second we have bps
	mov		r2, #0x00					@ load value to reset button count
	str		r2, [r1]					@ store reset button count back in variable
	mov		r1, #0x00					@ start counter to hold BCD of hundreds place
	ldr		r2, =MESSAGE				@ load ARRAY address
	ldr		r3, =middle_of_message_pointer @ load address that has offset
	add		r2, r2, r3				@ move meesage pointer to point into empty spac
loopBTA100:
@ convert hundreds place to BCD by successive subtraction
	cmp		r0, #0x63					@ check to see if there are still 100s to be subtracted off
	ble		finishBTA100				@ if not go to finishBTA100
	subs		r0, r0, #0x64				@ subtract 100 from value to convert
	add		r1, r1, #0x1				@ increment 100s BCD counter
	b		loopBTA100				@ go back to top of loop
finishBTA100:
@ convert hundreds from BCD to Ascii
	add		r1, r1, #0x30				@ convert 100s BCD to Ascii
	strb		r1, [r2]				@ store in corrent spot in array
	eor		r1, r1, r1				@ clear register to start counter to hold BCD of tens place
loopBTA10:
@ convert hundreds place to BCD by successive subtraction
	cmp		r0, #0x9					@ check to see if there are still 10s to be subtracted off
	ble		finishBTAConversion			@ if not go to finishBTA10
	subs		r0, r0, #0xA				@ subtract 10 from value to convert
	add		r1, r1, #0x1				@ increment 10s BCD counter
	b		loopBTA10					@ go back to top of loop
finishBTAConversion:
@
	add		r1, r1, #0x30				@ convert 10s BCD to Ascii
	strb	r1, [r2, #1]				@ store in corrent spot in array
	add		r0, r0, #0x30				@ convert 1s BCD to Ascii
	strb	r0, [r2, #2]				@ store in corrent spot in array
endBTA:
@
	cmp	 	r5, #0x00
	ldreq	r0, =NO_PRESS_COUNT			@ get address of no press count
	ldreq	r1, [r0]					@ get number of times timer went off without a button press
	addeq	r1, r1, #1				@ increment that value
	streq	r1, [r0]					@ put back in memory
	cmp		r1, #4					@ check to see if its been 4 time slice since a button was pressed
	ldrle	r1, =NO_SONG				@ if yes then load address of no song message 
	ldrgt	r1, =MESSAGE				@ if not then load address of message
	ldr		r0, =messagetoplayaddress	@ load address of place to store address of message to play
	str		r1, [r0]					@ store that address
@
	ldr		r0, =U4_IER				@ turn on interrupts for uart4
	mov		r1, #0x0A					@ load control word to enable thr and CTSn interrupts
	str		r1, [r0]					@ write to enable u4 interrupts 
leave_timer_svc:
	ldr		r0, =T5_IRQSTATUS			@ load address of timer 5 irq status register
	mov		r1, #RESET				@ load value to reset timer5 irq to allow new timer irq generation
	str		r1, [r0]					@ write to reset timer5 interrupt
	b		backtowait				@ return to idle loop
@=====================================================
	
.data
NO_PRESS_COUNT:	.word 0x0000
BUTTON_PRESS_COUNT:	.word 0x0000
char_pointer: 		.word 0x0000
messagetoplayaddress: .word 0x00000000

.align 4
STACK_SVC:
		.rept 1024
		.word 0x0000
		.endr
		
.align 4
STACK_IRQ:
		.rept 1024
		.word 0x0000
		.endr
		
.align 4	
MESSAGE:
.byte 0x01
.ascii "5o"
.ascii "song tempo is         beats per minute"
.byte 0x0D

.align 4
NO_SONG:
.byte 0x01
.ascii "5o"
.ascii "no song detected                      "
.byte 0x0D

.END