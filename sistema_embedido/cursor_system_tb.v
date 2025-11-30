`timescale 1ns / 1ps

// ============================================================================
// Testbench para sistema completo con cursor
// Prueba: UART + BRAM + VGA + Cursor
// ============================================================================

module cursor_system_tb;

    // ========================================================================
    // Señales del DUT
    // ========================================================================
    reg         CLOCK_50;
    reg [3:0]   KEY;
    reg [3:0]   SW;
    reg         UART_RXD;
    wire        UART_TXD;
    wire [9:0]  LEDR;
    wire        VGA_HS;
    wire        VGA_VS;
    wire [3:0]  VGA_R;
    wire [3:0]  VGA_G;
    wire [3:0]  VGA_B;
    
    // Señales de debug
    wire        uart_valid;
    wire        frame_error;
    wire [2:0]  state;
    
    // ========================================================================
    // Parámetros
    // ========================================================================
    localparam CLK_PERIOD = 20;        // 50 MHz → 20 ns
    localparam BAUD_RATE = 115200;
    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // ~8680 ns
    
    // ========================================================================
    // Instancia del DUT
    // ========================================================================
    fpga_top dut (
        .CLOCK_50    (CLOCK_50),
        .KEY         (KEY),
        .SW          (SW),
        .UART_RXD    (UART_RXD),
        .UART_TXD    (UART_TXD),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .LEDR        (LEDR),
        .uart_valid  (uart_valid),
        .frame_error (frame_error),
        .state       (state)
    );
    
    // ========================================================================
    // Generador de reloj 50 MHz
    // ========================================================================
    initial begin
        CLOCK_50 = 0;
        forever #(CLK_PERIOD/2) CLOCK_50 = ~CLOCK_50;
    end
    
    // ========================================================================
    // Task para enviar un byte por UART
    // ========================================================================
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            $display("[%0t] Enviando UART byte: 0x%02h", $time, data);
            
            // Start bit
            UART_RXD = 0;
            #BIT_PERIOD;
            
            // 8 bits de datos (LSB primero)
            for (i = 0; i < 8; i = i + 1) begin
                UART_RXD = data[i];
                #BIT_PERIOD;
            end
            
            // Stop bits
            UART_RXD = 1;
            #BIT_PERIOD;
            UART_RXD = 1;
            #BIT_PERIOD;
        end
    endtask
    
    // ========================================================================
    // Task para presionar un botón (genera flanco de bajada)
    // ========================================================================
    task press_key;
        input [3:0] key_mask;  // Máscara del botón a presionar
        begin
            $display("[%0t] Presionando KEY (mask=0x%h)", $time, key_mask);
            KEY = KEY & ~key_mask;  // Poner en bajo el botón
            #1000000;               // Mantener presionado 1ms
            KEY = 4'b1111;          // Soltar botón
            #1000000;               // Esperar 1ms
        end
    endtask
    
    // ========================================================================
    // Monitor de eventos importantes
    // ========================================================================
    always @(posedge CLOCK_50) begin
        if (uart_valid)
            $display("[%0t] UART: Byte recibido = 0x%02h", $time, dut.uart_data);
        
        if (dut.cursor_ctrl.cursor_write_en)
            $display("[%0t] CURSOR: Escribiendo en BRAM addr=%0d, data=0x%02h, pos=(%0d,%0d)", 
                     $time, dut.cursor_addr, dut.cursor_data, 
                     dut.cursor_x, dut.cursor_y);
    end
    
    // ========================================================================
    // Estímulos de prueba
    // ========================================================================
    initial begin
        // Inicialización
        KEY      = 4'b1111;  // Botones no presionados (activos en bajo)
        SW       = 4'b0000;  // Switches apagados
        UART_RXD = 1;        // Línea UART idle
        
        $display("========================================");
        $display("INICIO DE SIMULACIÓN - SISTEMA CURSOR");
        $display("========================================\n");
        
        // Esperar reset interno (POR)
        $display("[%0t] Esperando reset interno...", $time);
        @(posedge CLOCK_50);
        @(negedge dut.reset);
        @(posedge CLOCK_50);
        @(posedge CLOCK_50);
        $display("[%0t] Reset completado\n", $time);
        
        // ====================================================================
        // PRUEBA 1: Cargar algunos bytes por UART (llenar BRAM)
        // ====================================================================
        $display("\n--- PRUEBA 1: Cargar datos por UART ---");
        send_uart_byte(8'b00000001);  // Azul
        #10000;
        send_uart_byte(8'b00000010);  // Verde
        #10000;
        send_uart_byte(8'b00000100);  // Rojo
        #10000;
        send_uart_byte(8'b00000111);  // Blanco
        #10000;
        
        $display("[%0t] Write_addr actual: %0d", $time, dut.write_addr);
        
        // ====================================================================
        // PRUEBA 2: Mover cursor SIN pintar (SW[0]=0)
        // ====================================================================
        $display("\n--- PRUEBA 2: Mover cursor sin pintar ---");
        $display("[%0t] Posición inicial del cursor: (%0d, %0d)", 
                 $time, dut.cursor_x, dut.cursor_y);
        
        SW = 4'b0000;  // SW[0]=0 (no pintar)
        #10000;
        
        press_key(4'b0001);  // KEY[0] = Arriba
        $display("[%0t] Cursor después de mover arriba: (%0d, %0d)", 
                 $time, dut.cursor_x, dut.cursor_y);
        
        press_key(4'b0100);  // KEY[2] = Izquierda
        $display("[%0t] Cursor después de mover izquierda: (%0d, %0d)", 
                 $time, dut.cursor_x, dut.cursor_y);
        
        // ====================================================================
        // PRUEBA 3: Mover cursor CON pintar (SW[0]=1)
        // ====================================================================
        $display("\n--- PRUEBA 3: Mover cursor pintando ---");
        SW = 4'b1110;  // SW[0]=1 (pintar), SW[3:1]=111 (blanco)
        #10000;
        
        $display("[%0t] Color seleccionado: RGB=%b", $time, SW[3:1]);
        
        press_key(4'b0010);  // KEY[1] = Abajo (debe pintar)
        press_key(4'b1000);  // KEY[3] = Derecha (debe pintar)
        press_key(4'b0001);  // KEY[0] = Arriba (debe pintar)
        
        $display("[%0t] Posición final del cursor: (%0d, %0d)", 
                 $time, dut.cursor_x, dut.cursor_y);
        
        // ====================================================================
        // PRUEBA 4: Cambiar color y pintar
        // ====================================================================
        $display("\n--- PRUEBA 4: Cambiar color de pintura ---");
        SW = 4'b1001;  // SW[0]=1, SW[3:1]=100 (solo rojo)
        #10000;
        
        $display("[%0t] Nuevo color: RGB=%b", $time, SW[3:1]);
        press_key(4'b0010);  // Abajo (debe pintar rojo)
        press_key(4'b0010);  // Abajo (debe pintar rojo)
        
        // ====================================================================
        // PRUEBA 5: Verificar prioridad UART > Cursor
        // ====================================================================
        $display("\n--- PRUEBA 5: Prioridad UART sobre cursor ---");
        
        // Intentar escribir con cursor Y UART simultáneamente
        fork
            begin
                send_uart_byte(8'b00000101);  // UART escribe
            end
            begin
                #(BIT_PERIOD * 5);  // A mitad de transmisión UART
                press_key(4'b1000);  // Intentar mover cursor
            end
        join
        
        #50000;
        
        // ====================================================================
        // PRUEBA 6: Verificar límites del cursor
        // ====================================================================
        $display("\n--- PRUEBA 6: Verificar límites ---");
        SW = 4'b0000;  // No pintar, solo mover
        
        // Mover a esquina superior izquierda
        $display("[%0t] Moviendo a esquina superior izquierda...", $time);
        repeat(250) press_key(4'b0001);  // Arriba muchas veces
        repeat(330) press_key(4'b0100);  // Izquierda muchas veces
        
        $display("[%0t] Posición en límite: (%0d, %0d) - Esperado: (0, 0)", 
                 $time, dut.cursor_x, dut.cursor_y);
        
        if (dut.cursor_x == 0 && dut.cursor_y == 0)
            $display("    ✓ Límites superiores OK");
        else
            $display("    ✗ ERROR en límites superiores");
        
        // Mover a esquina inferior derecha
        $display("[%0t] Moviendo a esquina inferior derecha...", $time);
        repeat(490) press_key(4'b0010);  // Abajo muchas veces
        repeat(650) press_key(4'b1000);  // Derecha muchas veces
        
        $display("[%0t] Posición en límite: (%0d, %0d) - Esperado: (639, 479)", 
                 $time, dut.cursor_x, dut.cursor_y);
        
        if (dut.cursor_x == 639 && dut.cursor_y == 479)
            $display("    ✓ Límites inferiores OK");
        else
            $display("    ✗ ERROR en límites inferiores");
        
        // ====================================================================
        // Resumen final
        // ====================================================================
        #100000;
        
        $display("\n========================================");
        $display("RESUMEN DE SIMULACIÓN");
        $display("========================================");
        $display("Write_addr UART final: %0d", dut.write_addr);
        $display("Posición cursor final: (%0d, %0d)", dut.cursor_x, dut.cursor_y);
        $display("Estado UART: %0d", state);
        $display("========================================");
        $display("SIMULACIÓN COMPLETADA");
        $display("========================================");
        
        $finish;
    end
    
    // ========================================================================
    // Timeout de seguridad
    // ========================================================================
    initial begin
        #500_000_000;  // 500 ms timeout
        $display("\n⚠ TIMEOUT - Simulación detenida");
        $finish;
    end
    
    // ========================================================================
    // Generar archivo VCD para visualización
    // ========================================================================
    initial begin
        $dumpfile("cursor_system_tb.vcd");
        $dumpvars(0, cursor_system_tb);
    end

endmodule
