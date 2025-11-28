`timescale 1ns / 1ps

// ============================================================================
// Testbench para uart_rx
// ============================================================================

module uart_rx_tb;

    // ========================================================================
    // Señales del testbench
    // ========================================================================
    reg         clk;
    reg         rx_raw;
    reg         rst;
    wire [7:0]  data_out;
    wire        data_valid;
    wire        frame_error;
	 wire [2:0]  state;
    
    // ========================================================================
    // Parámetros
    // ========================================================================
    localparam CLK_PERIOD = 20;           // 50 MHz → 20 ns
    localparam BAUD_RATE = 115200;
    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // ~8680 ns
    
    // ========================================================================
    // Instancia del módulo a probar (DUT)
    // ========================================================================
    uart_rx dut (
        .clk        (clk),
        .rx_raw     (rx_raw),
        .rst        (rst),
        .data_out   (data_out),
        .data_valid (data_valid),
        .frame_error(frame_error),
		  .state      (state)
    );
    
    // ========================================================================
    // Generador de reloj 50 MHz
    // ========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // ========================================================================
    // Task para enviar un byte válido por UART
    // ========================================================================
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            $display("[%0d] ns Enviando byte: 0x%02h (%d)", $time, data, data);
            
            // Start bit (0)
            rx_raw = 0;
            #BIT_PERIOD;
            
            // 8 bits de datos (LSB primero)
            for (i = 0; i < 8; i = i + 1) begin
                rx_raw = data[i];
                #BIT_PERIOD;
            end
            
            // Stop bit 1 (1)
            rx_raw = 1;
            #BIT_PERIOD;
            
            // Stop bit 2 (1)
            rx_raw = 1;
            #BIT_PERIOD;
            
            // Pequeña pausa entre bytes
            // #(BIT_PERIOD * 2);
        end
    endtask
    
    // ========================================================================
    // Task para enviar un byte CON ERROR (stop bit incorrecto)
    // ========================================================================
    task send_byte_error;
        input [7:0] data;
        integer i;
        begin
            $display("[%0d] ns Enviando byte con ERROR: 0x%02h", $time, data);
            
            // Start bit
            rx_raw = 0;
            #BIT_PERIOD;
            
            // 8 bits de datos
            for (i = 0; i < 8; i = i + 1) begin
                rx_raw = data[i];
                #BIT_PERIOD;
            end
            
            // Stop bit 1 INCORRECTO (0 en lugar de 1)
            rx_raw = 0;  // ← ERROR INTENCIONAL
            #BIT_PERIOD;
            
            // Stop bit 2
            rx_raw = 1;
            #BIT_PERIOD;
            
            #(BIT_PERIOD * 2);
        end
    endtask
    
    // ========================================================================
    // Monitor de eventos - detecta cuando llega un byte
    // ========================================================================
    always @(posedge clk) begin
        if (data_valid) begin
            $display("[%0d] ns BYTE RECIBIDO: 0x%02h (%d) - CORRECTO", 
                     $time, data_out, data_out);
        end
        
        if (frame_error) begin
            $display("[%0d] FRAME ERROR detectado", $time);
        end
    end
    
    // ========================================================================
    // Estímulos de prueba
    // ========================================================================
    initial begin
        // Inicialización
        rx_raw = 1;  // Línea idle (alta)
        
        $display("========================================");
        $display("INICIO DE SIMULACIoN - UART RX");
        $display("Baudrate: %0d", BAUD_RATE);
        $display("Periodo de bit: %0d ns", BIT_PERIOD);
        $display("========================================\n");
        
        // Inicializar y liberar reset síncrono del DUT
        // (evita enviar datos mientras `rst` == 1 y producir frame_error)
        rst = 1;                              // mantener en reset
        @(posedge clk);
        @(posedge clk);
        rst = 0;                              // liberar reset
        @(posedge clk);                       // margen adicional
        @(posedge clk);
        
        // ====================================================================
        // PRUEBA 1: Enviar bytes válidos (0-7, escala de grises)
        // ====================================================================
        $display("\n--- PRUEBA 1: Bytes validos (0-7) ---");
        send_byte(8'h00);  // Negro
        send_byte(8'h01);  
        send_byte(8'h02);
        send_byte(8'h03);
        send_byte(8'h04);
        send_byte(8'h05);
        send_byte(8'h06);
        send_byte(8'h07);  // Blanco
        
        // ====================================================================
        // PRUEBA 2: Bytes con patrones específicos
        // ====================================================================
        $display("\n--- PRUEBA 2: Patrones de prueba ---");
        send_byte(8'hAA);  // 10101010
        send_byte(8'h55);  // 01010101
        send_byte(8'hFF);  // 11111111
        send_byte(8'h00);  // 00000000
        
        // ====================================================================
        // PRUEBA 3: Byte con ERROR en stop bit
        // ====================================================================
        $display("\n--- PRUEBA 3: Byte con error de frame ---");
        send_byte_error(8'hBD);  // Este debe generar frame_error
        
        // ====================================================================
        // PRUEBA 4: Bytes consecutivos rápidos
        // ====================================================================
        $display("\n--- PRUEBA 4: Bytes consecutivos rapidos ---");
        send_byte(8'h12);
        send_byte(8'h34);
        send_byte(8'h56);
        send_byte(8'h78);
        
        // ====================================================================
        // PRUEBA 5: Simular glitch en start bit
        // ====================================================================
        $display("\n--- PRUEBA 5: Glitch corto (falso inicio) ---");
        rx_raw = 0;
        #(BIT_PERIOD / 4);  // Pulso muy corto (1/4 de bit)
        rx_raw = 1;
        #(BIT_PERIOD * 3);  // Esperar
        
        // Ahora enviar byte real
        send_byte(8'h99);
        
        // Esperar un poco más
        #10000;
        
        // ====================================================================
        // Resumen final
        // ====================================================================
        $display("\n========================================");
        $display("SIMULACIoN COMPLETADA");
        $display("========================================");
        
        $finish;
    end
    
    // ========================================================================
    // Timeout de seguridad (por si se cuelga)
    // ========================================================================
    initial begin
        #5_000_000;  // 5 ms timeout
        $display("\n TIMEOUT - Simulacion detenida por seguridad");
        $finish;
    end
    
    // ========================================================================
    // Generar archivo VCD para GTKWave (opcional)
    // ========================================================================
    initial begin
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_tb);
    end

endmodule