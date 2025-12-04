// ============================================================================
// Módulo: fpga_top (VERSIÓN MEJORADA)
// Descripción: Sistema completo UART → BRAM → VGA
// Mejoras: Clock enable, sincronización correcta, LEDs informativos
// ============================================================================

module fpga_top (
    // Reloj
    input  wire CLOCK_50,           // Reloj 50 MHz del DE1-SoC

    // Botones e interruptores
    input  wire [3:0] KEY,          // Botones para cursor (activos en bajo)
    input  wire [3:0] SW,           // SW[0]=enable pintar, SW[3:1]=color RGB

    // UART
    input  wire UART_RXD,           // RX desde FT232
    output wire UART_TXD,           // TX hacia FT232 (eco)

    // VGA
    output wire VGA_HS,             // Hsync
    output wire VGA_VS,             // Vsync
    output wire VGA_CLK,            // Pixel clock (para DAC externo)
    output wire VGA_BLANK_N,        // Blank (activo bajo)
    output wire [7:0] VGA_R,        // Rojo
    output wire [7:0] VGA_G,        // Verde
    output wire [7:0] VGA_B,        // Azul
    
    // LEDs de debug
    output wire [9:0] LEDR          // LEDs para indicadores
);

    // ========================================
    // Power-On Reset interno
    // Mantiene reset activo durante ~1.3 ms tras encender
    // ========================================
    reg [15:0] por_cnt = 16'hFFFF;
    wire reset = (por_cnt != 16'h0000);
    
    always @(posedge CLOCK_50) begin
        if (por_cnt != 16'h0000)
            por_cnt <= por_cnt - 16'h0001;
    end

    // ========================================================================
    // Clock Enable 25 MHz para VGA
    // ========================================================================
    wire clk_enable_25mhz;
    
    clk_divider clk_div (
        .clk_50mhz        (CLOCK_50),
        .reset            (reset),
        .clk_enable_25mhz (clk_enable_25mhz)
    );
    
    // VGA_CLK: Conectar directamente a 50MHz dividido por 2 (para DAC externo)
    // Nota: Algunos monitores VGA requieren clock continuo en este pin
    reg vga_clk_reg = 1'b0;
    always @(posedge CLOCK_50) begin
        if (clk_enable_25mhz)
            vga_clk_reg <= ~vga_clk_reg;
    end
    assign VGA_CLK = vga_clk_reg;

    // ========================================================================
    // Señales UART → BRAM
    // ========================================================================
    wire [7:0] uart_data;           // Byte recibido por UART
    wire       uart_valid;          // Pulso cuando llega byte válido
    wire       frame_error;         // Error de framing
    wire [2:0] uart_state;          // Estado FSM para debug
    
    // ========================================================================
    // Señales Cursor → BRAM
    // ========================================================================
    wire [9:0]  cursor_x;
    wire [9:0]  cursor_y;
    wire        cursor_write_en;
    wire [18:0] cursor_addr;
    wire [7:0]  cursor_data;
    
    // ========================================
    // Instancia UART FSM (RX + TX con eco)
    // ========================================
    uart_fsm uart_module (
        .clk         (CLOCK_50),
        .rst         (reset),
        .rx_raw      (UART_RXD),
        .tx          (UART_TXD),
        .data_out    (uart_data),
        .data_valid  (uart_valid),
        .frame_error (frame_error),
        .rx_state    (uart_state)
    );
    
    // ========================================
    // Instancia Control de Cursor
    // ========================================
    cursor_control cursor_ctrl (
        .clk             (CLOCK_50),
        .reset           (reset),
        .KEY             (KEY),
        .SW              (SW),
        .cursor_x        (cursor_x),
        .cursor_y        (cursor_y),
        .cursor_write_en (cursor_write_en),
        .cursor_addr     (cursor_addr),
        .cursor_data     (cursor_data)
    );

    // ========================================
    // Control de escritura en BRAM (UART)
    // ========================================
    reg [18:0] write_addr = 19'd0;  // 0 a 307199 (640×480-1)
    
    always @(posedge CLOCK_50) begin
        if (reset) begin
            write_addr <= 19'd0;
        end else if (uart_valid) begin
            // Incrementar dirección con wraparound
            if (write_addr == 19'd307199)
                write_addr <= 19'd0;
            else
                write_addr <= write_addr + 19'd1;
        end
    end
    
    // ========================================
    // Multiplexor de escritura BRAM
    // Prioridad: UART > Cursor (evita conflictos)
    // ========================================
    wire [18:0] bram_wr_addr;
    wire [7:0]  bram_wr_data;
    wire        bram_wr_en;
    
    assign bram_wr_addr = uart_valid ? write_addr : cursor_addr;
    assign bram_wr_data = uart_valid ? uart_data  : cursor_data;
    assign bram_wr_en   = uart_valid | cursor_write_en;

    // ========================================================================
    // Señales VGA → BRAM
    // ========================================================================
    wire [9:0]  hcount;
    wire [9:0]  vcount;
    wire        display_enable;
    wire [18:0] read_addr;
    wire [7:0]  pixel_data;
    
    // VGA Controller
    vga_controller vga_ctrl (
        .clk_50mhz        (CLOCK_50),
        .clk_enable_25mhz (clk_enable_25mhz),
        .reset            (reset),
        .hsync            (VGA_HS),
        .vsync            (VGA_VS),
        .display_enable   (display_enable),
        .hcount           (hcount),
        .vcount           (vcount)
    );
    
    // VGA_BLANK_N debe estar activo durante el área de display
    assign VGA_BLANK_N = display_enable;
    
    // VGA Image Display
    vga_image_display vga_img (
        .clk_50mhz        (CLOCK_50),
        .clk_enable_25mhz (clk_enable_25mhz),
        .reset            (reset),
        .display_enable   (display_enable),
        .hcount           (hcount),
        .vcount           (vcount),
        .cursor_x         (cursor_x),
        .cursor_y         (cursor_y),
        .bram_addr        (read_addr),
        .bram_data        (pixel_data),
        .vga_r            (VGA_R),
        .vga_g            (VGA_G),
        .vga_b            (VGA_B)
    );
    
    // ========================================
    // Instancia BRAM Dual-Port
    // Puerto A: Escritura (UART/Cursor) @ 50MHz
    // Puerto B: Lectura (VGA) @ 25MHz efectivo
    // ========================================
    ram_2port bram_image (
        // Puerto de ESCRITURA (UART o Cursor)
        .data      (bram_wr_data),      // Dato multiplexado
        .wraddress (bram_wr_addr),      // Dirección multiplexada
        .wrclock   (CLOCK_50),          // Reloj escritura: 50 MHz
        .wren      (bram_wr_en),        // Enable multiplexado
        
        // Puerto de LECTURA (VGA)
        .rdaddress (read_addr),         // Dirección de lectura
        .rdclock   (CLOCK_50),          // Reloj lectura: 50 MHz
        .q         (pixel_data)         // Pixel leído
    );
    
    // Nota: Aunque rdclock es 50MHz, vga_image_display solo lee
    // cuando clk_enable_25mhz está activo, efectivamente leyendo a 25MHz
    
    // ========================================
    // LEDs Informativos (MEJORADO)
    // ========================================
    // LEDR[2:0] - Color seleccionado (RGB)
    // LEDR[3]   - Modo edición activo
    // LEDR[4]   - Error de framing UART
    // LEDR[5]   - Imagen cargándose (UART activo)
    // LEDR[6]   - Imagen cargada (write_addr > umbral)
    // LEDR[7]   - VGA activo (display_enable)
    // LEDR[8]   - Cursor visible (parpadeo)
    // LEDR[9]   - Sistema listo (sin reset)
    
    assign LEDR[2:0] = SW[3:1];                     // Mostrar color seleccionado
    assign LEDR[3]   = SW[0];                       // Modo edición
    assign LEDR[4]   = frame_error;                 // Error UART
    assign LEDR[5]   = uart_valid;                  // UART recibiendo
    assign LEDR[6]   = (write_addr > 19'd1000);     // Imagen parcialmente cargada
    assign LEDR[7]   = display_enable;              // VGA en área visible
    assign LEDR[8]   = cursor_write_en;             // Cursor escribiendo
    assign LEDR[9]   = ~reset;                      // Sistema operacional
    
    // ========================================
    // Guía de uso de LEDs:
    // ========================================
    // Al encender:
    //   - LEDR[9] debe encenderse después de ~1.3ms (reset completado)
    //
    // Durante carga de imagen:
    //   - LEDR[5] parpadea rápidamente (UART recibiendo bytes)
    //   - LEDR[6] se enciende después de recibir 1000 bytes
    //
    // Durante edición:
    //   - LEDR[3] encendido = modo edición activo (SW[0]=1)
    //   - LEDR[2:0] muestran color seleccionado
    //   - LEDR[8] pulsa al presionar botones
    //
    // VGA:
    //   - LEDR[7] parpadea a 60Hz (área visible)
    // ========================================

endmodule