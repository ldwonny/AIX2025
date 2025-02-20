/******************************************************************************
* Copyright (c) 2021 Xilinx, Inc.  All rights reserved.
* SPDX-License-Identifier: MIT
 ******************************************************************************/
#define AIX2024_FIRMWARE_ENABLE 1

#ifdef AIX2024_FIRMWARE_ENABLE

#include "xparameters.h"
#include "xstatus.h"
#include "xuartlite.h"
#include <stdio.h>
#include "xil_io.h"


#define MODE_TEST_HELLO	0x01
#define MODE_TEST_ECHO	0x02
#define MODE_STORE_RAM	0x03
#define MODE_LOAD_RAM	0x04
#define MODE_STORE_CFG	0x05
#define MODE_RUN_ENGINE 0x06
#define MODE_PAUSE		0x07

#define NUM_CONV_LAYER 11
int base_addr_config[2*NUM_CONV_LAYER];

#define UARTLITE_DEVICE_ID	XPAR_UARTLITE_0_DEVICE_ID

/************************** Variable Definitions *****************************/

XUartLite UartLite;		/* Instance of the UartLite Device */

/*
 * The following buffers are used in this example to send and receive data
 * with the UartLite.
 */
uint8_t RecvBuffer[100];	/* Buffer for Receiving Data */

uint8_t cHello[16] 	    = 	{ ' ', ' ', 'H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!', ' '};
uint8_t cWaiting[16] 	= 	{ ' ', ' ', 'W', 'a', 'i', 't', 'i', 'n', 'g', '_', 'C', 'M', 'D', ' ', ' ', ' '};
uint8_t cCmd_recv[16] 	= 	{ ' ', ' ', 'C', 'M', 'D', '_', 'R', 'e', 'c', 'e', 'i', 'v', 'e', ' ', ' ', ' '};
uint8_t cComplete[16]	=	{ ' ', 'S', 't', 'o', 'r', 'e', ' ', 'c', 'o', 'm', 'p', 'l', 'e', 't', 'e', ' '};
uint8_t cEngine_run[16] =	{ 'E', 'n', 'g', 'i', 'n', 'e', ' ', 'R', 'u', 'n', ' ', ' ', ' ', ' ', ' ', ' '};
uint8_t cEngine_done[16]=	{ 'E', 'n', 'g', 'i', 'n', 'e', ' ', 'c', 'o', 'm', 'p', 'l', 'e', 't', 'e', ' '};
uint8_t cPause[16] 		= 	{ ' ', ' ', ' ', ' ', ' ', ' ', 'P', 'a', 'u', 's', 'e', ' ', ' ', ' ', ' ', ' '};
uint8_t cResume[16] 	= 	{ ' ', ' ', ' ', ' ', ' ', 'R', 'e', 's', 'u', 'm', 'e', ' ', ' ', ' ', ' ', ' '};

int init_uart(u16 DeviceID);
void uart_recv(u8 num_bytes);
void uart_send(u8* data, u32 num_bytes);
void write_addr(u32 addr, u8* data, u32 num_bytes);
void read_addr(u32 addr, u8* readbuffer, u32 num_bytes);


int main(){

	init_uart(UARTLITE_DEVICE_ID);

	while (1) {
		uart_recv(1);
		if (RecvBuffer[0] == MODE_TEST_HELLO) {
			uart_send(cHello, 16);
		}
		else if(RecvBuffer[0] == MODE_TEST_ECHO) {
			uart_recv(16);
			uart_send(RecvBuffer, 16);
		}
		else if(RecvBuffer[0] == MODE_STORE_RAM){	//store to DRAM
			//send response
			uart_send(cWaiting, 16);

			//receive base addr and data size
			uart_recv(8);
			uint32_t addr = (RecvBuffer[3] << 24) + (RecvBuffer[2] << 16) + (RecvBuffer[1] << 8) + RecvBuffer[0];
			uint32_t data_size = (RecvBuffer[7] << 24) + (RecvBuffer[6] << 16) + (RecvBuffer[5] << 8) + RecvBuffer[4];

			//send response
			uart_send(cCmd_recv,16);

			//store to DRAM
			for(int i = 0; i < data_size; i++){
				uart_recv(4);
				write_addr(XPAR_MIG_7SERIES_0_BASEADDR + addr + i * 4, RecvBuffer, 4);
			}

			uart_send(cComplete, 16);


		}
		else if(RecvBuffer[0] == MODE_LOAD_RAM){ //load from DRAM
			//send response
			uart_send(cWaiting, 16);

			//receive base addr and data size
			uart_recv(8);
			uint32_t addr = (RecvBuffer[3] << 24) + (RecvBuffer[2] << 16) + (RecvBuffer[1] << 8) + RecvBuffer[0];
			uint32_t data_size = (RecvBuffer[7] << 24) + (RecvBuffer[6] << 16) + (RecvBuffer[5] << 8) + RecvBuffer[4];

			uart_send(cCmd_recv,16);

			//load from DRAM and send
			uint8_t temp[4];
			for(int i = 0; i < data_size; i++){
				read_addr(XPAR_MIG_7SERIES_0_BASEADDR + addr + i * 4, temp, 4);
				uart_send(temp, 4);
			}
		}
		else if(RecvBuffer[0] == MODE_STORE_CFG){ //  Write configurations
			//send response
			uart_send(cWaiting, 16);

			//receive offset and data
			for(int i = 0; i <2*NUM_CONV_LAYER; i++){
				uart_recv(8);
				uint32_t offset = (RecvBuffer[3] << 24) + (RecvBuffer[2] << 16) + (RecvBuffer[1] << 8) + RecvBuffer[0];

				base_addr_config[offset] = (RecvBuffer[7] << 24) + (RecvBuffer[6] << 16) + (RecvBuffer[5] << 8) + RecvBuffer[4];
			}
			//send response
			uart_send(cComplete, 16);

		}
		else if(RecvBuffer[0] == MODE_RUN_ENGINE){ //  Write configurations
			// FIX ME:
			// {{{
            // 1. Activate Engine: Set START
			write_addr(XPAR_YOLO_ENGINE_IP_0_BASEADDR + 0x04, 4096, 4);              // IFM: Input Feature Map
			write_addr(XPAR_YOLO_ENGINE_IP_0_BASEADDR + 0x08, 4096 + 256*256*4, 4);  // OFM: Output Feature Map
			write_addr(XPAR_YOLO_ENGINE_IP_0_BASEADDR + 0x0C, 4096 + 256*256*16, 4); // WGT: Weight

			// Read the control and status register
			// Start engine
			uart_send(cEngine_run, 16);
			write_addr(XPAR_YOLO_ENGINE_IP_0_BASEADDR + 0x00, 0x01, 4);	// START is stored in the bit 0
			write_addr(XPAR_YOLO_ENGINE_IP_0_BASEADDR + 0x00, 0x00, 4);
			// 2. Polling: Wait until the engine completes
			int is_dummy = 1;
			int layer_done = 0;
			while(layer_done == 0){
				if(is_dummy){
					write_addr(XPAR_YOLO_ENGINE_IP_0_BASEADDR + 0x00, 0x02, 4);	// Dummy the DONE bit (0x02 --> 0000_00010)
				}

				// Read the control and status register
				uint8_t temp[4];
				read_addr(XPAR_YOLO_ENGINE_IP_0_BASEADDR + 0x00, temp, 4);
				//layer_done = (temp[0] & 0x02);	//
				if(is_dummy)
					layer_done = 1;
			}
			// }}}
			// 3. Send response
			uart_send(cEngine_done, 16);
		}
		else if(RecvBuffer[0] == MODE_PAUSE){	//Pause and resume
			//send response 1
			uart_send(cPause, 16);

			int x;
			x = 0;
			for(int i = 0; i < 200000000; i = i + 1) {
				x = x + 2;
			}
			uart_send(cResume, 16);
		}
	}
	return 0;
}

int init_uart(u16 DeviceID){
	int status;
	status = XUartLite_Initialize(&UartLite, DeviceID);
	if(status =! XST_SUCCESS){
		return XST_FAILURE;
	}

	status = XUartLite_SelfTest(&UartLite);
	if (status = !XST_SUCCESS){
		return XST_FAILURE;
	}

	XUartLite_ResetFifos(&UartLite);

	return XST_SUCCESS;
}


void uart_recv(u8 num_bytes){
	int received_count = 0;
	while (1) {
		received_count += XUartLite_Recv(&UartLite, RecvBuffer + received_count, num_bytes - received_count);
		if (received_count == num_bytes) {
			break;
		}
	}
	return;
}


void uart_send(u8* data, u32 num_bytes) {

	int sent_bytes = 0;
	while(1){
		sent_bytes += XUartLite_Send(&UartLite, data + sent_bytes, num_bytes - sent_bytes);
		if(sent_bytes == num_bytes){
			break;
		}
	}
	return;
}

void write_addr(u32 addr, u8* data, u32 num_bytes){
	for(int i = 0; i < num_bytes; i++){
		Xil_Out8(addr + i, data[i]);
	}
	return;
}

void read_addr(u32 addr, u8* readbuffer, u32 num_bytes){
	for(int i = 0; i < num_bytes; i++){
		readbuffer[i] = Xil_In8(addr + i);
	}
	return;
}


#else


#include <stdio.h>
#include "xparameters.h"
#include "xil_types.h"
#include "xstatus.h"
#include "xil_testmem.h"

#include "platform.h"
#include "memory_config.h"
#include "xil_printf.h"

/*
 * memory_test.c: Test memory ranges present in the Hardware Design.
 *
 * This application runs with D-Caches disabled. As a result cacheline requests
 * will not be generated.
 *
 * For MicroBlaze/PowerPC, the BSP doesn't enable caches and this application
 * enables only I-Caches. For ARM, the BSP enables caches by default, so this
 * application disables D-Caches before running memory tests.
 */

void putnum(unsigned int num);

void test_memory_range(struct memory_range_s *range) {
    XStatus status;

    /* This application uses print statements instead of xil_printf/printf
     * to reduce the text size.
     *
     * The default linker script generated for this application does not have
     * heap memory allocated. This implies that this program cannot use any
     * routines that allocate memory on heap (printf is one such function).
     * If you'd like to add such functions, then please generate a linker script
     * that does allocate sufficient heap memory.
     */

    print("Testing memory region: "); print(range->name);  print("\n\r");
    print("    Memory Controller: "); print(range->ip);  print("\n\r");
    #if defined(__MICROBLAZE__) && !defined(__arch64__)
        #if (XPAR_MICROBLAZE_ADDR_SIZE > 32)
            print("         Base Address: 0x"); putnum((range->base & UPPER_4BYTES_MASK) >> 32); putnum(range->base & LOWER_4BYTES_MASK);print("\n\r");
        #else
            print("         Base Address: 0x"); putnum(range->base); print("\n\r");
        #endif
        print("                 Size: 0x"); putnum(range->size); print (" bytes \n\r");
    #else
        xil_printf("         Base Address: 0x%lx \n\r",range->base);
        xil_printf("                 Size: 0x%lx bytes \n\r",range->size);
    #endif

#if defined(__MICROBLAZE__) && !defined(__arch64__) && (XPAR_MICROBLAZE_ADDR_SIZE > 32)
    status = Xil_TestMem32((range->base & LOWER_4BYTES_MASK), ((range->base & UPPER_4BYTES_MASK) >> 32), 1024, 0xAAAA5555, XIL_TESTMEM_ALLMEMTESTS);
    print("          32-bit test: "); print(status == XST_SUCCESS? "PASSED!":"FAILED!"); print("\n\r");

    status = Xil_TestMem16((range->base & LOWER_4BYTES_MASK), ((range->base & UPPER_4BYTES_MASK) >> 32), 2048, 0xAA55, XIL_TESTMEM_ALLMEMTESTS);
    print("          16-bit test: "); print(status == XST_SUCCESS? "PASSED!":"FAILED!"); print("\n\r");

    status = Xil_TestMem8((range->base & LOWER_4BYTES_MASK), ((range->base & UPPER_4BYTES_MASK) >> 32), 4096, 0xA5, XIL_TESTMEM_ALLMEMTESTS);
    print("           8-bit test: "); print(status == XST_SUCCESS? "PASSED!":"FAILED!"); print("\n\r");
#else
    status = Xil_TestMem32((u32*)range->base, 1024, 0xAAAA5555, XIL_TESTMEM_ALLMEMTESTS);
    print("          32-bit test: "); print(status == XST_SUCCESS? "PASSED!":"FAILED!"); print("\n\r");

    status = Xil_TestMem16((u16*)range->base, 2048, 0xAA55, XIL_TESTMEM_ALLMEMTESTS);
    print("          16-bit test: "); print(status == XST_SUCCESS? "PASSED!":"FAILED!"); print("\n\r");

    status = Xil_TestMem8((u8*)range->base, 4096, 0xA5, XIL_TESTMEM_ALLMEMTESTS);
    print("           8-bit test: "); print(status == XST_SUCCESS? "PASSED!":"FAILED!"); print("\n\r");
#endif

}

int main()
{
    sint32 i;

    init_platform();

    print("--Starting Memory Test Application--\n\r");
    print("NOTE: This application runs with D-Cache disabled.");
    print("As a result, cacheline requests will not be generated\n\r");

    for (i = 0; i < n_memory_ranges; i++) {
        test_memory_range(&memory_ranges[i]);
    }

    print("--Memory Test Application Complete--\n\r");
    print("Successfully ran Memory Test Application");
    cleanup_platform();
    return 0;
}

#endif
