// ============================================================================
// Copyright (c) 2013 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//
// Modified for displaying Digital Chess Clock to the LCD 128x64
// Date: 24 Mar 2025
// Team: Trong Nguyen & Pingan Luo
//
// ============================================================================

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/time.h> 

#include "terasic_os_includes.h"
#include "LCD_Lib.h"
#include "lcd_graphic.h"
#include "font.h"
#include "hps_0.h"

#define HW_REGS_BASE ( ALT_STM_OFST )
#define HW_REGS_SPAN ( 0x04000000 )
#define HW_REGS_MASK ( HW_REGS_SPAN - 1 )

#define FPGA_AXI_BASE   0xC0000000
#define FPGA_AXI_SPAN   0x00001000

#define DEBUG_ENABLE 0

// LCD 128x64 pixel, display 16x4 characters
LCD_CANVAS LcdCanvas;
#define LENGTH_LCD 16
#define HEIGHT_LCD 4
char lcd_buffer[HEIGHT_LCD][LENGTH_LCD];


/*
* Print buffer 16x4 to LCD screen
*/
void lcd_print_buffer(){
    DRAW_Clear(&LcdCanvas, LCD_WHITE);
	//DRAW_Rect(&LcdCanvas, 0,0, LcdCanvas.Width-1, LcdCanvas.Height-1, LCD_BLACK);
	for (int i=0; i<HEIGHT_LCD; i++){
		for (int j=0; j<LENGTH_LCD; j++){
			DRAW_PrintChar(&LcdCanvas, j*8, i*16, lcd_buffer[i][j], LCD_BLACK, &font_16x16);
		}
	}
    DRAW_Refresh(&LcdCanvas);
}

/*
* Clear LCD buffer 
*/
void lcd_clear_buffer(){
	for (int i=0; i<HEIGHT_LCD; i++){
		for (int j=0; j<LENGTH_LCD; j++){
			lcd_buffer[i][j] = ' ';
		}
	}
}

/*
* Update buffer one character
*/
void lcd_update_buffer_char(char new_char, int line, int col){
	if ((line < HEIGHT_LCD) && (line >= 0)){
		if ((col < LENGTH_LCD) && (col >= 0)){
			lcd_buffer[line][col] = new_char;
		} else {
			printf("Error: lcd_update_buffer_char() invalid column %d\n", col);
		}
	} else{
		printf("Error: lcd_update_buffer_char() invalid line %d\n", line);
	}
}

/*
* Update buffer from a string
*/
void lcd_update_buffer_string(char* new_string, int line, int col){
    int new_length = strlen(new_string);
    if(col + new_length > LENGTH_LCD){
        new_length = LENGTH_LCD - col;
		printf("Warning: lcd_update_buffer_string() new_string overflow\n");
    }
    for(int i=0; i<new_length; i++){
        lcd_update_buffer_char(*(new_string+i), line, col+i);
    }
}

/*
* Displaying the chess clock to the LCD
*/
void lcd_start_chess_clock(){
    LCDHW_BackLight(true);
    lcd_clear_buffer();
	//lcd_update_buffer_string("  Chess Clock   ", 0,0);
	lcd_update_buffer_string("  Time setup    ", 0,0);
	lcd_update_buffer_string("----------------", 1,0);
    lcd_update_buffer_string("Player1: 0:00:00", 2,0);
    lcd_update_buffer_string("Player2: 0:00:00", 3,0);
    lcd_print_buffer();
}

/*
* Display Welcome message to the LCD
*/
void lcd_welcome_chess_clock(){
    LCDHW_BackLight(true);
    lcd_clear_buffer();
	lcd_update_buffer_string("     Welcome    ", 0,0);
	lcd_update_buffer_string("     to the     ", 1,0);
	lcd_update_buffer_string("   chess clock  ", 2,0);
    lcd_print_buffer();
}

/*
* Format time (number of seconds) to time format H:MM:SS
*/
void format_time(unsigned int seconds, char *buffer) {
    unsigned int hrs = seconds / 3600;
    unsigned int mins = (seconds % 3600) / 60;
    unsigned int secs = seconds % 60;
    sprintf(buffer, "%01u:%02u:%02u", hrs, mins, secs);
}

void display_title(int clock_mode){
	switch (clock_mode) {
		case 0:
			printf("Mode: Init\n");
			lcd_update_buffer_string("  Time setup    ", 0, 0);
			break;
		case 1:
			printf("Mode: Ready\n");
			lcd_update_buffer_string("  Starting..    ", 0, 0);
			break;
		case 2:
			printf("Mode: Player 1\n");
			lcd_update_buffer_string("In game-Player 1", 0, 0);
			break;
		case 3:
			printf("Mode: Player 2\n");
			lcd_update_buffer_string("In game-Player 2", 0, 0);
			break;
		case 4:
			printf("Mode: Pause\n");
			lcd_update_buffer_string("  Game Paused   ", 0, 0);
			break;
		case 5:
			printf("Mode: Complete\n");
			lcd_update_buffer_string("    Time Out    ", 0, 0);
			break;
		default:
			printf("Mode: Unknown\n");
			lcd_update_buffer_string("  Time setup    ", 0, 0);
			//lcd_update_buffer_string("  Chess Clock   ", 0,0);
			break;
	}
}

int main(void)
{
	//==================================
	// Mapping
	//==================================
	int fd;
	void *virtual_base;
	void *h2p_virtual_base;
	volatile unsigned int * axi_pio_read_mode_ptr = NULL ;
	volatile unsigned int * axi_pio_read_time_ptr = NULL ;

	if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ) {
		printf( "ERROR: could not open \"/dev/mem\"...\n" );
		return( 1 );
	}

    virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE );
    if( virtual_base == MAP_FAILED ) {
        printf( "ERROR: mmap() failed...\n" );
        close( fd );
        return( 1 );
    }
    
    h2p_virtual_base = mmap( NULL, FPGA_AXI_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, FPGA_AXI_BASE);
    if( h2p_virtual_base == MAP_FAILED ) {
        printf( "ERROR: mmap3() failed...\n" );
        close( fd );
        return(1);
    }

    axi_pio_read_time_ptr =(unsigned int *)(h2p_virtual_base + PIO_CLOCK_TIME_BASE);
	axi_pio_read_mode_ptr =(unsigned int *)(h2p_virtual_base + PIO_CLOCK_MODE_BASE);
    
    //==================================
	// LCD Init
	//==================================
	printf("Graphic LCD for Chess Clock\n");

    LcdCanvas.Width = LCD_WIDTH;
    LcdCanvas.Height = LCD_HEIGHT;
    LcdCanvas.BitPerPixel = 1;
    LcdCanvas.FrameSize = LcdCanvas.Width * LcdCanvas.Height / 8;
    LcdCanvas.pFrame = (void *)malloc(LcdCanvas.FrameSize);
    if (LcdCanvas.pFrame == NULL){
        printf("failed to allocate lcd frame buffer\n");
		close(fd);
        return 1;
    }

	LCDHW_Init(virtual_base);
	LCDHW_BackLight(true); // turn on LCD backlight
	LCD_Init();
	DRAW_Clear(&LcdCanvas, LCD_WHITE); // clear screen

	lcd_welcome_chess_clock();
	usleep(1000*1000);

	//==================================
	// LCD Update from FPGA
	//==================================
	unsigned int pio_read_time, pio_read_mode, pio_read_time_prev, pio_read_mode_prev = 0;
	unsigned int time_A, time_B;
	unsigned int clock_mode;
	char time_A_str[8], time_B_str[8];
	lcd_start_chess_clock();

	while (1) {
		pio_read_time = *(axi_pio_read_time_ptr); //read 32 bits from FPGA
		pio_read_mode = *(axi_pio_read_mode_ptr); //read 32 bits from FPGA
		
		if (pio_read_mode != pio_read_mode_prev){
			clock_mode = pio_read_mode & 0x7;
#if DEBUG_ENABLE
			printf("Received new mode: ");
			for (int i = 31; i >= 0; i--) {
				printf("%c", (pio_read_mode & (1U << i)) ? '1' : '0');
				if (i % 4 == 0) 
					printf(" ");
			}
			printf("\n");
#endif
			display_title(clock_mode);
		}

		if (pio_read_time != pio_read_time_prev){		
			time_A = (pio_read_time >> 16) & 0xFFFF;
			time_B = pio_read_time & 0xFFFF;

#if DEBUG_ENABLE
			printf("Received new time: ");
			for (int i = 31; i >= 0; i--) {
				printf("%c", (pio_read_time & (1U << i)) ? '1' : '0');
				if (i % 4 == 0) 
					printf(" ");
			}
			printf("\n");
#endif
			format_time(time_A, time_A_str);
			format_time(time_B, time_B_str);
			printf("Time change: Player 1: %s\tPlayer 2: %s\n", time_A_str, time_B_str);

			lcd_update_buffer_string(time_A_str, 2, 9);
			lcd_update_buffer_string(time_B_str, 3, 9);
		}

		if ((pio_read_mode != pio_read_mode_prev) || (pio_read_time != pio_read_time_prev)){
			lcd_print_buffer();
		}
		
		pio_read_time_prev = pio_read_time;
		pio_read_mode_prev = pio_read_mode;
	}

	free(LcdCanvas.pFrame);

	//=======================================
	// clean up our memory mapping and exit
	//=======================================
	if (munmap(virtual_base, HW_REGS_SPAN) != 0){
		printf("ERROR: munmap() failed...\n");
		close(fd);
		return 1;
	}

	if (munmap(h2p_virtual_base, FPGA_AXI_SPAN) != 0){
		printf("ERROR: munmap() failed...\n");
		close(fd);
		return 1;
	}

	close(fd);
	return 0;
}
