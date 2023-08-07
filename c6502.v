module c6502
(
    input               clock,
    input               ce,
    input               reset_n,
    output      [15:0]  address,
    input       [ 7:0]  in,
    output reg  [ 7:0]  out,
    output reg          rd,
    output reg          we
);

assign address = cp ? ab : pc;

localparam

    LDC = 0,
    ZP  = 1,    ZPX = 2,    ZPY = 3,
    ABS = 4,    ABX = 5,    ABY = 6,    ABZ = 7,
    IX  = 8,    IX2 = 9,    IX3 = 10,
    IY  = 11,   IY2 = 12,   IY3 = 13,
    RUN = 14,   BRA = 15,
    JP1 = 16,   JP2 = 17,
    JI1 = 18,   JI2 = 19,   JI3 = 20,   JI4 = 21;

// Регистры
// ------------------------------------------------------
reg [ 7:0]  a, x, y, s;
reg [ 7:0]  p = 8'b00000000;
//                 NV    ZC

// Управление процессором
// ------------------------------------------------------
reg         cp;
reg [ 5:0]  t;          // Состояние процессора
reg [15:0]  ab, pc;
reg [ 7:0]  op;
reg [ 7:0]  w;          // Временный регистр

// Вычисления
// ------------------------------------------------------
wire [8:0] zpx = in + x;
wire [8:0] zpy = in + y;
wire [3:0] bra = {p[1], p[0], p[6], p[7]}; // 3=Z,C,V,0=N

// Исполнение инструкции
// ------------------------------------------------------
always @(posedge clock)
// Состояние сброса процессора
if (reset_n == 1'b0) begin

    t  <= 1'b0;
    cp <= 1'b0;
    pc <= 16'h0000;
    a  <= 8'h00;
    x  <= 8'hFE;
    y  <= 8'h01;
    s  <= 8'h00;
    p  <= 8'h00;

end
// Активное состояние
else if (ce) begin

    rd <= 1'b0;
    we <= 1'b0;

    case (t)

    // Считывание опкода
    LDC: begin

        pc <= pc + 1;
        op <= in;

        casex (in)
        8'b010_011_00: t <= JP1; // 4C
        8'b011_011_00: t <= JI1; // 6C
        8'bxxx_000_x1: t <= IX;
        8'bxxx_010_x1,
        8'b1xx_000_x0: t <= RUN; // IMM
        8'bxxx_100_x1: t <= IY;
        8'bxxx_110_x1: t <= ABY;
        8'bxxx_001_xx: t <= ZP;
        8'bxxx_011_xx,
        8'b001_000_00: t <= ABS;
        8'b10x_101_1x: t <= ZPY;
        8'bxxx_101_xx: t <= ZPX;
        8'b10x_111_1x: t <= ABY;
        8'bxxx_111_xx: t <= ABX;
        8'bxxx_100_00: t <= BRA;
        default:       t <= RUN;
        endcase

    end

    // Декодирование адреса указателя на опкоды
    // -------------------------------------------------------------------------

    // Адресация по Zero Page
    ZP:  begin t <= RUN; ab <= in;       cp <= 1; rd <= 1; pc <= pc + 1; end
    ZPX: begin t <= RUN; ab <= zpx[7:0]; cp <= 1; rd <= 1; pc <= pc + 1; end
    ZPY: begin t <= RUN; ab <= zpy[7:0]; cp <= 1; rd <= 1; pc <= pc + 1; end

    // Абсолютная адресация
    ABS: begin t <= ABZ; pc <= pc + 1; ab <= in; end
    ABX: begin t <= ABZ; pc <= pc + 1; ab <= zpx; end
    ABY: begin t <= ABZ; pc <= pc + 1; ab <= zpy; end
    ABZ: begin t <= RUN; pc <= pc + 1; ab[15:8] <= ab[15:8] + in; cp <= 1; rd <= 1; end

    // Непрямая адресация
    IX:  begin t <= IX2; pc <= pc + 1; cp <= 1; ab <= zpx[7:0]; end
    IY:  begin t <= IY2; pc <= pc + 1; cp <= 1; ab <= in; end
    IX2,
    IY2: begin t <= IX3; w  <= in; ab[7:0] <= ab[7:0] + 1; end
    IX3: begin t <= RUN; rd <= 1; ab <= {in, w}; end
    IY3: begin t <= RUN; rd <= 1; ab <= {in, w} + y; end

    // Переход по условию
    BRA: begin t <= LDC; pc <= pc + 1 + ((bra[op[7:6]] == op[5]) ? {{8{in[7]}}, in[7:0]} : 0); end

    // Специальные инструкции
    // -------------------------------------------------------------------------

    // JMP ABS
    JP1: begin t <= JP2; pc <= pc + 1; w <= in; end
    JP2: begin t <= LDC; pc <= {in, w}; end

    // JMP (IND)
    JI1: begin t <= JI2; ab[ 7:0] <= in; pc <= pc + 1; end
    JI2: begin t <= JI3; ab[15:8] <= in; pc <= pc + 1; cp <= 1; end
    JI3: begin t <= JI4; pc[ 7:0] <= in; ab[7:0] <= ab[7:0] + 1; end
    JI4: begin t <= LDC; pc[15:8] <= in; cp <= 0; end

    // Выполнение инструкции
    // -------------------------------------------------------------------------

    endcase

end

endmodule
