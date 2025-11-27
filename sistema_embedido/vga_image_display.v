// ============================================================================
// Módulo: vga_image_display (VERSIÓN RGB111 - COLOR)
// Descripción: Lee imagen RGB111 de BRAM y genera señales RGB
// ============================================================================

module vga_image_display (
    input  wire clk_25mhz,
    input  wire reset,
    
    // Desde VGA controller
    input  wire display_enable,
    input  wire [9:0] hcount,
    input  wire [9:0] vcount,
    
    // Hacia BRAM (puerto de lectura)
    output wire [18:0] bram_addr,
    input  wire [7:0] bram_data,
    
    // Salidas RGB
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);

    // ========================================================================
    // Cálculo de dirección BRAM (igual que antes)
    // ========================================================================
    wire [9:0] x_pos = hcount;
    wire [9:0] y_pos = vcount;
    
    wire [18:0] addr_calc = (y_pos << 9) + (y_pos << 7) + x_pos;
    
    reg [18:0] addr_reg = 0;
    
    always @(posedge clk_25mhz) begin
        if (display_enable)
            addr_reg <= addr_calc;
        else
            addr_reg <= 0;
    end
    
    assign bram_addr = addr_reg;
    
    // ========================================================================
    // Extracción de bits RGB111 (NUEVO)
    // ========================================================================
    // Formato: byte = 00000RGB
    //                      │││
    //                      ││└─ B (bit 0)
    //                      │└── G (bit 1)
    //                      └─── R (bit 2)
    
    wire bit_r = bram_data[2];  // Bit rojo
    wire bit_g = bram_data[1];  // Bit verde
    wire bit_b = bram_data[0];  // Bit azul
    
    // ========================================================================
    // Expandir 1 bit → 8 bits por canal
    // ========================================================================
    // Opción A: 0 → 00000000, 1 → 11111111 (máximo contraste)
    wire [7:0] red_value   = bit_r ? 8'b11111111 : 8'b00000000;
    wire [7:0] green_value = bit_g ? 8'b11111111 : 8'b00000000;
    wire [7:0] blue_value  = bit_b ? 8'b11111111 : 8'b00000000;
    
    // ========================================================================
    // Salidas RGB (con display_enable)
    // ========================================================================
    assign vga_r = display_enable ? red_value   : 8'b00000000;
    assign vga_g = display_enable ? green_value : 8'b00000000;
    assign vga_b = display_enable ? blue_value  : 8'b00000000;

endmodule