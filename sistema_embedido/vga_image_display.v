// ============================================================================
// Módulo: vga_image_display (VERSIÓN MEJORADA CON PIPELINE)
// Descripción: Lee imagen RGB111 de BRAM y genera señales RGB con cursor
// Incluye pipeline de 2 ciclos para compensar latencia de BRAM
// ============================================================================

module vga_image_display (
    input  wire clk_50mhz,           // Clock principal (50 MHz)
    input  wire clk_enable_25mhz,    // Enable de 25 MHz
    input  wire reset,
    
    // Desde VGA controller
    input  wire display_enable,
    input  wire [9:0] hcount,
    input  wire [9:0] vcount,
    
    // Posición del cursor
    input  wire [9:0] cursor_x,
    input  wire [9:0] cursor_y,
    
    // Hacia BRAM (puerto de lectura)
    output wire [18:0] bram_addr,
    input  wire [7:0] bram_data,
    
    // Salidas RGB
    output reg [7:0] vga_r,
    output reg [7:0] vga_g,
    output reg [7:0] vga_b
);

    // ========================================================================
    // Generador de parpadeo del cursor (~2 Hz)
    // ========================================================================
    localparam BLINK_PERIOD = 25_000_000 / 2;  // 0.5 segundos @ 50MHz
    
    reg [24:0] blink_counter = 0;
    reg        cursor_visible = 0;
    
    always @(posedge clk_50mhz) begin
        if (reset) begin
            blink_counter  <= 25'd0;
            cursor_visible <= 1'b0;
        end else begin
            if (blink_counter == BLINK_PERIOD - 1) begin
                blink_counter  <= 25'd0;
                cursor_visible <= ~cursor_visible;  // Toggle cada 0.5s
            end else begin
                blink_counter <= blink_counter + 25'd1;
            end
        end
    end
    
    // ========================================================================
    // PIPELINE STAGE 1: Calcular dirección y registrar señales
    // ========================================================================
    wire [9:0] x_pos = hcount;
    wire [9:0] y_pos = vcount;
    
    // Optimización: 640 = 512 + 128 = 2^9 + 2^7
    // addr = y * 640 + x = (y << 9) + (y << 7) + x
    wire [18:0] addr_calc = (y_pos << 9) + (y_pos << 7) + x_pos;
    
    reg [18:0] addr_reg = 0;
    reg        display_enable_d1 = 0;
    reg [9:0]  hcount_d1 = 0;
    reg [9:0]  vcount_d1 = 0;
    
    always @(posedge clk_50mhz) begin
        if (reset) begin
            addr_reg <= 19'd0;
            display_enable_d1 <= 1'b0;
            hcount_d1 <= 10'd0;
            vcount_d1 <= 10'd0;
        end else if (clk_enable_25mhz) begin
            addr_reg <= display_enable ? addr_calc : 19'd0;
            display_enable_d1 <= display_enable;
            hcount_d1 <= hcount;
            vcount_d1 <= vcount;
        end
    end
    
    assign bram_addr = addr_reg;
    
    // Nota: BRAM tiene 1 ciclo de latencia adicional por registro de salida
    // Por lo tanto, necesitamos 1 ciclo más de pipeline
    
    // ========================================================================
    // PIPELINE STAGE 2: Registrar datos de BRAM y señales de control
    // ========================================================================
    reg [7:0]  bram_data_d1 = 0;
    reg        display_enable_d2 = 0;
    reg [9:0]  hcount_d2 = 0;
    reg [9:0]  vcount_d2 = 0;
    
    always @(posedge clk_50mhz) begin
        if (reset) begin
            bram_data_d1 <= 8'd0;
            display_enable_d2 <= 1'b0;
            hcount_d2 <= 10'd0;
            vcount_d2 <= 10'd0;
        end else if (clk_enable_25mhz) begin
            bram_data_d1 <= bram_data;
            display_enable_d2 <= display_enable_d1;
            hcount_d2 <= hcount_d1;
            vcount_d2 <= vcount_d1;
        end
    end
    
    // ========================================================================
    // Detección de posición del cursor (usando señales retrasadas)
    // ========================================================================
    wire at_cursor = (hcount_d2 == cursor_x) && (vcount_d2 == cursor_y);
    wire show_cursor = at_cursor && cursor_visible && display_enable_d2;

    // ========================================================================
    // Extracción de bits RGB111
    // ========================================================================
    // Formato BRAM: byte = 00000RGB
    //                          │││
    //                          ││└─ B (bit 0)
    //                          │└── G (bit 1)
    //                          └─── R (bit 2)
    
    wire bit_r = bram_data_d1[2];  // Bit rojo
    wire bit_g = bram_data_d1[1];  // Bit verde
    wire bit_b = bram_data_d1[0];  // Bit azul
    
    // ========================================================================
    // Expandir 1 bit → 8 bits por canal (máximo contraste)
    // ========================================================================
    wire [7:0] red_value   = bit_r ? 8'hFF : 8'h00;
    wire [7:0] green_value = bit_g ? 8'hFF : 8'h00;
    wire [7:0] blue_value  = bit_b ? 8'hFF : 8'h00;
    
    // ========================================================================
    // Invertir color cuando el cursor está visible (efecto de resaltado)
    // ========================================================================
    wire [7:0] red_final   = show_cursor ? ~red_value   : red_value;
    wire [7:0] green_final = show_cursor ? ~green_value : green_value;
    wire [7:0] blue_final  = show_cursor ? ~blue_value  : blue_value;
    
    // ========================================================================
    // PIPELINE STAGE 3: Salidas RGB registradas
    // ========================================================================
    always @(posedge clk_50mhz) begin
        if (reset) begin
            vga_r <= 8'd0;
            vga_g <= 8'd0;
            vga_b <= 8'd0;
        end else if (clk_enable_25mhz) begin
            vga_r <= display_enable_d2 ? red_final   : 8'h00;
            vga_g <= display_enable_d2 ? green_final : 8'h00;
            vga_b <= display_enable_d2 ? blue_final  : 8'h00;
        end
    end
    
endmodule