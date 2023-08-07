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
    JI1 = 18,   JI2 = 19,   JI3 = 20,   JI4 = 21,
    TRM = 22;

localparam
    ORA = 0,    AND = 1,    EOR = 2,    ADC = 3,
    STA = 4,    LDA = 5,    CMP = 6,    SBC = 7,
    ASL = 8,    ROL = 9,    LSR = 10,   ROR = 11,
    BIT = 13,   DEC = 14,   INC = 15;

localparam
    DST_A = 0,  DST_X = 1,  DST_Y = 2,  DST_S = 3,
    SRC_D = 0,  SRC_X = 1,  SRC_Y = 2,  SRC_A = 3;

// Регистры
// ------------------------------------------------------
reg [ 7:0]  a, x, y, s, p;
//

// Управление процессором
// ------------------------------------------------------
reg         cp;
reg [ 5:0]  t;          // Состояние процессора
reg [15:0]  ab, pc;
reg [ 7:0]  op, w;      // Временный регистр
reg [ 3:0]  alu;        // Режим работы АЛУ
reg [ 1:0]  dst, src;

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

    //       NV    ZC
    p  <= 8'b00000001;
    t  <= 1'b0;
    cp <= 1'b0;
    pc <= 16'h0000;
    a  <= 8'h01;
    x  <= 8'hFE;
    y  <= 8'h01;
    s  <= 8'h00;

end
// Активное состояние
else if (ce) begin

    rd  <= 1'b0;
    we  <= 1'b0;
    dst <= DST_A;
    src <= SRC_D;

    case (t)

    // Считывание опкода
    LDC: begin

        pc <= pc + 1;
        op <= in;

        // Выбор метода адресации
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

        // Подготовка к исполнению
        casex (in)
        8'bxxx_xxx_01: alu <= in[7:5];
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
    RUN: begin

        // По умолчанию, перейти к считыванию опкода
        cp <= 0;
        t  <= LDC;

        // Immediate
        casex (op) 8'bxxx_010_x1, 8'b1xx_000_x0: pc <= pc + 1; endcase

        // Разбор операции
        casex (op)

            // STA
            8'b100_xxx_01: begin t <= TRM; out <= a; we <= 1'b1; cp <= 1'b1; end
            // CMP
            8'b110_xxx_01: begin p <= F; end
            // ORA, AND, ADC, EOR, SBC, LDA
            8'bxxx_xxx_01: begin p <= F; a <= R; end

        endcase

    end

    // Завершение цикла записи в память
    TRM: begin cp <= 0; t <= LDC; end

    endcase

end

// Арифметико-логическое устройство
// -----------------------------------------------------------------------------

// Левый операнд
wire [7:0] op1 =
    dst == DST_A ? a :
    dst == DST_X ? x :
    dst == DST_Y ? y : s;

// Правый операнд
wire [7:0] op2 =
    src == SRC_A ? a :
    src == SRC_X ? x :
    src == SRC_Y ? y : in;

// Результат
wire [8:0] R =
    // Базовые операции
    alu == ORA ? op1 | op2 :
    alu == AND ? op1 & op2 :
    alu == EOR ? op1 ^ op2 :
    alu == ADC ? op1 + op2 + cin :
    alu == STA ? op1 :
    alu == LDA ? op2 :
    alu == CMP ? op1 - op2 :
    alu == SBC ? op1 - op2 - !cin :
    // Расширенные
    alu == ASL ? {op2[6:0], 1'b0} :
    alu == ROL ? {op2[6:0], cin} :
    alu == LSR ? {1'b0, op2[7:1]} :
    alu == ROR ? {cin, op2[7:1]} :
    alu == BIT ? op1 & op2 :
    alu == DEC ? op2 - 1 :
    alu == INC ? op2 + 1 : 0;

// Вычисление флагов
wire sign  =  R[7];        // Флаг знака
wire zero  = ~|R[7:0];     // Тест на Zero
wire oadc  = (op1[7] ^ op2[7] ^ 1'b1) & (op1[7] ^ R[7]);
wire osbc  = (op1[7] ^ op2[7] ^ 1'b0) & (op2[7] ^ R[7]);
wire cin   =  p[0];
wire carry =  R[8];

// Новые флаги
wire [7:0] F =
    alu == ADC ? {sign, oadc, p[5:2], zero,  carry} :
    alu == CMP ? {sign,       p[6:2], zero, ~carry} :
    alu == SBC ? {sign, osbc, p[5:2], zero, ~carry} :
    alu == ASL || alu == ROL ? {sign, p[6:2], zero, op2[7]} :
    alu == LSR || alu == ROR ? {sign, p[6:2], zero, op2[0]} :
    alu == BIT ? {op2[7:6], p[5:2], zero, cin} :
                 {sign,     p[6:2], zero, cin};

endmodule
