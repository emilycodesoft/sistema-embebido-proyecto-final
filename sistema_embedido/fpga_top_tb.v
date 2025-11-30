`timescale 1ns / 1ps

module fpga_top_tb;

    // ========================================
    // Señales del DUT (Device Under Test)
    // ========================================
    reg         CLOCK_50;
    reg         UART_RXD;
    wire        UART_TXD;
    wire [9:0]  LEDR;
	 
	 // ========================================
    // Señales para DEBUG (comentar despues)
    // ======================================== 
	 wire       uart_valid;          // pulso cuando llega byte
	 wire       frame_error;         // Error en stop bits
	 wire [2:0] state;               // Estado RX
    
    // ========================================
    // Parámetros UART
    // ========================================
    localparam CLK_PERIOD = 20;        // 50 MHz → 20 ns
    localparam BAUD_RATE = 115200;
    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // ~8680 ns
    
    // ========================================
    // Instancia del módulo a probar
    // ========================================
    fpga_top dut (
        .CLOCK_50   (CLOCK_50),
        .UART_RXD   (UART_RXD),
        .UART_TXD   (UART_TXD),
        .LEDR       (LEDR),
		.uart_valid (uart_valid),
		.frame_error (frame_error),
		.state       (state)
    );
    
    // ========================================
    // Generador de reloj 50 MHz
    // ========================================
    initial begin
        CLOCK_50 = 0;
        forever #(CLK_PERIOD/2) CLOCK_50 = ~CLOCK_50;
    end
    
    // ========================================
    // Task para enviar un byte por UART
    // ========================================
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            UART_RXD = 0;
            #BIT_PERIOD;
            
            // 8 bits de datos (LSB primero)
            for (i = 0; i < 8; i = i + 1) begin
                UART_RXD = data[i];
                #BIT_PERIOD;
            end
            
            // Stop bit 1
            UART_RXD = 1;
            #BIT_PERIOD;
            
            // Stop bit 2
            UART_RXD = 1;
            #BIT_PERIOD;
        end
    endtask
    
    // ========================================
    // Estímulos de prueba
    // ========================================
    initial begin
        // Inicialización
        UART_RXD = 1;  // línea idle
        
        // Esperar estabilización y a que el POR interno libere el reset
        // (evita enviar datos mientras `reset` == 1 y producir frame_error)
        @(posedge CLOCK_50);              // alinearse con el reloj
        @(negedge dut.reset);             // esperar a que reset pase a 0
        @(posedge CLOCK_50);              // margen adicional
        @(posedge CLOCK_50);
        
        $display("========================================");
        $display("Inicio de simulación");
        $display("========================================");
        
        // Enviar 20 bytes de prueba (simulando imagen)
        $display("\nEnviando bytes de prueba...");
        
        send_uart_byte(8'h00);  // Negro
        #1000;
        send_uart_byte(8'h01);  
        #1000;
        send_uart_byte(8'h02);
        #1000;
        send_uart_byte(8'h03);
        #1000;
        send_uart_byte(8'h04);
        #1000;
        send_uart_byte(8'h05);
        #1000;
        send_uart_byte(8'h06);
        #1000;
        send_uart_byte(8'h07);  // Blanco
        #1000;
        
        // Repetir patrón
        send_uart_byte(8'h00);
        #1000;
        send_uart_byte(8'h01);
        #1000;
        send_uart_byte(8'h02);
        #1000;
        send_uart_byte(8'h03);
        #1000;
        send_uart_byte(8'h04);
        #1000;
        send_uart_byte(8'h05);
        #1000;
        send_uart_byte(8'h06);
        #1000;
        send_uart_byte(8'h07);
        #1000;
        
        // Bytes adicionales
        send_uart_byte(8'hAA);
        #1000;
        send_uart_byte(8'h55);
        #1000;
        send_uart_byte(8'hFF);
        #1000;
        send_uart_byte(8'h00);
        #1000;
        
        $display("\n========================================");
        $display("Bytes enviados correctamente");
        $display("========================================");
        
        // Observar resultados
        #10000;
        
        $display("\nValor final de write_addr: %d", dut.write_addr);
        $display("Último byte en LEDs: 0x%02h", LEDR[7:0]);
        
        $display("\n========================================");
        $display("Simulación completada");
        $display("========================================");
        
        $finish;
    end
    
    // ========================================
    // Monitor de eventos
    // ========================================
    initial begin
        $monitor("Tiempo=%0d ns | UART_valid=%b | write_addr=%d | uart_data=0x%02h | LEDR=%b", 
                 $time, dut.uart_valid, dut.write_addr, dut.uart_data, LEDR);
    end
    
    // ========================================
    // Generar archivo de formas de onda
    // ========================================
    initial begin
        $dumpfile("fpga_top_tb.vcd");
        $dumpvars(0, fpga_top_tb);
    end

endmodule