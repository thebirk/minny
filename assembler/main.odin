package assembler

import "core:fmt"

Operand :: struct {
    is_memory: bool,
    value: union {
        Register,
        Immediate,
        Label,
    }
}

Immediate :: distinct u16;
Register :: enum u16 {
    R0 = 0b0000,
    R1 = 0b0001,
    R2 = 0b0010,
    R3 = 0b0011,
    R4 = 0b0100,
    R5 = 0b0101,
    R6 = 0b0110,
    R7 = 0b0111,

    SP = 0b1000,
    PC = 0b1001,
};
Label :: struct {
    parent: string,
    local:  string,
}

Opcode :: enum u16 {
    NOP  = 0b00000,
    MOV  = 0b00001,
    ADD  = 0b00010,
    SUB  = 0b00011,
    SHL  = 0b00100,
    SHR  = 0b00101,
    AND  = 0b00110,
    OR   = 0b00111,
    XOR  = 0b01000,
    NOT  = 0b01001,
    JMP  = 0b01010,
    JSR  = 0b01011,
    RET  = 0b01100,
    JZ   = 0b01101,
    JNZ  = 0b01110,
    JC   = 0b01111,
    JNC  = 0b10000,
    INT  = 0b10001,
    RETI = 0b10010,
    HLT  = 0b10011,
    INC  = 0b10100,
    DEC  = 0b10101,
    JE   = 0b10110,
    JNE  = 0b10111,
    CMP  = 0b11000,
}

Instruction :: struct {
    op:       Opcode,
    operands: int,
    a, b:     Operand,
}

Directive :: struct {
    name: string,
    args: [dynamic]string,
}

main :: proc() {
    //instrs: [dynamic]Instruction;
    //labels: [dynamic]struct{name: string, offset: int};
    //append(&instrs, {.MOV, 2, {false, .R0}, {false, Immediate{0xFF}}});

    // If we get to emitting a label before its resolved
    // emit a zero, and add it to a list
    // then at the end resolve all possible labels
    // If there are any remaining, throw errors


    // IDEA: Allow encoding tiny immediates in the first word.
    //  Us the top-most T bit to check if its short-form, if so the immediate is
    //  the first three bits of T. If  the top bit is set, the immedate uses the next word
    // ex. the instruction below would in short-form become:
    // shl r3, 1
    //  oooooxxxrrrrtttt
    //  0010010000110001
    //
    // instead of the usual
    //
    //  oooooxxxrrrrtttt iiiiiiiiiiiiiiii
    //  0010010000110000 0000000000000001
    //
    // If we wanted the long form, the new result would be:
    //
    //              notice the top T bit set here
    //              v
    //  oooooxxxrrrrtttt iiiiiiiiiiiiiiii
    //  0010010000111000 0000000000000001
    fmt.println("shl r3, 1");
    instr := Instruction{.SHL, 1, {false, .R3}, {false, Immediate(1)}};
    print_instr(instr);
    fmt.println();

    fmt.println("shl r3, 8");
    instr = Instruction{.SHL, 1, {false, .R3}, {false, Immediate(8)}};
    print_instr(instr);
    fmt.println();

    fmt.println("mov r5, 0");
    instr = Instruction{.MOV, 2, {false, .R5}, {true, Immediate(0)}};
    print_instr(instr);
    fmt.println();

    fmt.println("mov r5, 0x74");
    instr = Instruction{.MOV, 2, {false, .R5}, {true, Immediate(0x74)}};
    print_instr(instr);
    fmt.println();

    print_instr :: proc(instr: Instruction) {
        // bit 0 - b.is_memory
        // bit 1 - a.is_memory
        // bit 2 - b.value.(Immediate)
        _, b_is_imm := instr.b.value.(Immediate);
        addr := u16(
            (instr.b.is_memory ? 1<<0 : 0) |
            (instr.a.is_memory ? 1<<1 : 0) |
            (b_is_imm          ? 1<<2 : 0)
        );

        R := instr.a.value.(Register);
        T := u16(0);
        if !b_is_imm {
            T = u16(instr.b.value.(Register));
        } else {
            imm := u16(instr.b.value.(Immediate));
            if imm > 0b111 {
                T = 0b1000;
            } else {
                T = imm;
            }
        }
        fmt.printf("oooooxxxrrrrtttt\n");
        fmt.printf("%05b%03b%04b%04b", u16(instr.op), addr, u16(R), T);

        if b_is_imm {
            imm := u16(instr.b.value.(Immediate));
            if imm > 0b111 {
                fmt.printf(" %016b", imm);
            }
        }

        fmt.println();
    }
}


