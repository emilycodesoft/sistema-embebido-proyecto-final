module fpga_top (
    input  wire clk_50,         // reloj principal
    input  wire clk_vga,        // pixel clock para VGA
    input  wire rx,             // entrada UART
    output wire [2:0] vga_r,
    output wire [2:0] vga_g,
    output wire [2:0] vga_b,
    output wire hsync,
    output wire vsync
);

    // ================
    // UART FSM
    // ================
    wire [7:0] uart_byte;
    wire       data_valid;

    uart_fsm uart (
        .clk      (clk_50),
        .rx       (rx),
        .data_out (uart_byte),
        .data_valid (data_valid)
    );

    // Contador para escritura en BRAM
    reg [18:0] addr_uart = 0;

    always @(posedge clk_50) begin
        if (data_valid) begin
            addr_uart <= addr_uart + 1;
        end
    end

    // ================
    // VGA controller
    // ================
    wire [18:0] vga_addr;
    wire [7:0]  vga_pixel;

	 /*
    vga_controller vga (
        .clk       (clk_vga),
        .pixel_data(vga_pixel),
        .pixel_addr(vga_addr),
        .hsync     (hsync),
        .vsync     (vsync),
        .r         (vga_r),
        .g         (vga_g),
        .b         (vga_b)
    );
	 */

    // ================
    // BRAM (IP Core)
    // ================
    onchip_memory2_0 bram_image (
        // PORT A — UART (escritura)
        .clk_a      (clk_50),
        .address_a  (addr_uart),
        .wren_a     (data_valid),
        .data_a     (uart_byte),
        .q_a        (),           // no lo usamos

        // PORT B — VGA (lectura)
        .clk_b      (clk_vga),
        .address_b  (vga_addr),
        .wren_b     (1'b0),       // solo lectura
        .data_b     (8'd0),
        .q_b        (vga_pixel)
    );

endmodule
