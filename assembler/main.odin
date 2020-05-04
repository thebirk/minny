package assembler

import "core:fmt"

Operand :: struct {
    loc:       Location,
    is_memory: bool,
    value: union {
        Register,
        LabelOperand,
        Identifier,
        String,
        Number,
        Binary,
    }
}

Number     :: distinct int;
Identifier :: distinct string;
String     :: distinct string;
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
}
LabelOperand :: struct {
    name:  string,
    local: string,
}
Binary :: struct {
    op: TokenType,
    lhs, rhs: ^Operand, // where do we store these? Could always allocate them all.
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

// Instruction wishlist:
// PUSH/POP   - word/registers
// PUSHB/POPB - pushb byte/popb reg/mem
// PUSHA/POPA - push all registers, excluding SP and PC
// JE/JNE     - these should compile to JZ/JNZ
// Two register option for jump instructions jz r1, r2. Here we would jump to r1 if the zero flag was set, r2 otherwise
// MOVB       - move src as 8bit to dst memory
// DB/DW      - emit bytes/words

Instruction :: struct {
    label:       string,
    local_label: bool,
    directive:   bool,
    op:          string,
    operands:    []^Operand,
}

Directive :: struct {
    name: string,
    args: [dynamic]string, // We need something fancy here, maybe something like Directive_Operand, which supports strings etc.
}

LocalLabel :: struct {
    name:   string,
    offset: int,
}

Label :: struct {
    offset: int,
    name:   string,
    locals: [dynamic]LocalLabel,
}

Value :: struct {
    loc: Location,
    kind: union {
        int,
        string,
    },
}

Scope :: struct {
    parent: ^Scope, // For eventual macros
    symbols: map[string]Value,
}

eval_operand :: proc(scope: ^Scope, operand: ^Operand, ignore_errors: bool) -> ^Operand {
    switch op in operand.value {
    case Register:
        return operand;
    case LabelOperand:

    case Identifier:
        //fmt.printf("\neval_operand(Identifier): %v\n", op);

        switch op {
        case "r0", "R0":             o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .R0; return o;
        case "r1", "R1":             o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .R1; return o;
        case "r2", "R2":             o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .R2; return o;
        case "r3", "R3":             o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .R3; return o;
        case "r4", "R4":             o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .R4; return o;
        case "r5", "R5":             o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .R5; return o;
        case "r6", "R6":             o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .R6; return o;
        case "r7", "R7":             o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .R7; return o;
        case "sp", "sP", "Sp", "SP": o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .SP; return o;
        case "pc", "pC", "Pc", "PC": o := new(Operand); o.loc = operand.loc; o.is_memory = operand.is_memory; o.value = .PC; return o;
        }

        //TODO: lookup in scope

        return operand;
    case String:

    case Number:

    case Binary:
        lhs := eval_operand(scope, op.lhs, ignore_errors);
        rhs := eval_operand(scope, op.rhs, ignore_errors);

        lhs_int, lhs_valid := lhs.value.(Number);
        rhs_int, rhs_valid := rhs.value.(Number);

        if !lhs_valid {
            panic("TODO");
        }
        if !rhs_valid {
            panic("TODO");
        }

        res := new(Operand);
        res.loc = operand.loc;
        res.is_memory = operand.is_memory;

        #partial
        switch op.op {
        case .Plus:     res.value = Number(lhs_int + rhs_int);
        case .Minus:    res.value = Number(lhs_int - rhs_int);
        case .Asterisk: res.value = Number(lhs_int * rhs_int);
        case .Slash:    res.value = Number(lhs_int / rhs_int);
        case:
            panic("Invalid op");
        }

        return res;
    }

    //unreachable();
    return operand;
}

validate_instruction :: proc(instr: Instruction) -> (bool, string) {
    assert(instr.op != "");
    ops := get_valid_ops_from_name(instr.op);
    if len(ops) == 0 {
        fmt.printf("####: unknown op %s\n", instr.op);
    }

    fmt.printf("%s: %#v\n", instr.op, ops);

    return false, "";
}

calculate_instruction_size :: proc(instr: Instruction) -> int {
    assert(instr.op != "");



    return 0;
}

size_pass :: proc(instrs: []Instruction) {
    labels: [dynamic]Label;

    offset := 0;
    for instr in instrs {
        if instr.label != "" {
            if instr.local_label {
                append(&labels[len(labels)-1].locals, LocalLabel{instr.label, offset});
            } else {
                label: Label;
                label.name = instr.label;
                label.offset = offset;
                append(&labels, label);
            }
        }

        if instr.op != "" {
            if instr.directive {

            } else {
                offset += 2;
                validate_instruction(instr);
            }
        }
    }

    for l in labels {
        fmt.printf("%s: %d\n", l.name, l.offset);
        for local in l.locals {
            fmt.printf("%s.%s: %d\n", l.name, local.name, local.offset);
        }
    }
    fmt.println("offset:", offset);
}

main :: proc() {
    validate_valid_ops_table();
    
    //instrs: [dynamic]Instruction;
    //labels: [dynamic]struct{name: string, offset: int};
    //append(&instrs, {.MOV, 2, {false, .R0}, {false, Immediate{0xFF}}});

    // Pretty-much-it-as-far-as-syntax-goes
    // [[`.`]label `:`] (`%`directive-name | instruction) [operand (`,` operand)*]

    //TODO: We would probably want bitwise binary operators as well

    // If we get to emitting a label before its resolved
    // emit a zero, and add it to a list
    // then at the end resolve all possible labels
    // If there are any remaining, throw errors

    instrs := parse_file("test.masm");
    print_instructions(instrs[:]);


    for instr in instrs {
        if instr.label != "" {

        }
    }
    size_pass(instrs);
    
    
}

print_operand :: proc(op: ^Operand) {
        if op.is_memory do fmt.printf("[");
        switch kind in op.value {
        case Register:
            fmt.printf("%s", kind);
        case LabelOperand:
            assert(kind.name != "" || kind.local != "");
            if kind.name != "" do fmt.printf("%s", kind.name);
            if kind.local != "" {
                fmt.printf(".%s", kind);
            }
        case Identifier:
            fmt.printf("%s", kind);
        case String:
            fmt.printf("%s", kind);
        case Number:
            fmt.printf("%v", kind);
        case Binary:
            print_operand(kind.lhs);
            #partial switch kind.op {
            case .Plus:     fmt.printf("+");
            case .Minus:    fmt.printf("-");
            case .Asterisk: fmt.printf("*");
            case .Slash:    fmt.printf("/");
            case: unreachable("invalid op");
            }
            print_operand(kind.rhs);
        }
        if op.is_memory do fmt.printf("]");
    }

    print_instructions :: proc(instrs: []Instruction) {
        for instr in instrs {
            //fmt.printf("%#v\n", instr);

            when true {
                if instr.local_label do fmt.printf(".");
                if instr.label != "" do fmt.printf("%s: ", instr.label);

                if instr.label == "" && !instr.directive do fmt.printf("    ");
                if instr.directive do fmt.printf("%%");
                if instr.op != "" do fmt.printf("%s ", instr.op);

                for op, i in instr.operands {
                    //print_operand(op);
                    print_operand(eval_operand(nil, op, false));

                    if !instr.directive && i < len(instr.operands)-1 do fmt.printf(",");
                    fmt.printf(" ");
                }

                fmt.printf("\n");
            }
        }
    }

// test_gen :: proc() {
//     // IDEA: Allow encoding tiny immediates in the first word.
//     //  Us the top-most T bit to check if its short-form, if so the immediate is
//     //  the first three bits of T. If  the top bit is set, the immedate uses the next word
//     // ex. the instruction below would in short-form become:
//     // shl r3, 1
//     //  oooooxxxrrrrtttt
//     //  0010010000110001
//     //
//     // instead of the usual
//     //
//     //  oooooxxxrrrrtttt iiiiiiiiiiiiiiii
//     //  0010010000110000 0000000000000001
//     //
//     // If we wanted the long form, the new result would be:
//     //
//     //              notice the top T bit set here
//     //              v
//     //  oooooxxxrrrrtttt iiiiiiiiiiiiiiii
//     //  0010010000111000 0000000000000001
//     fmt.println("shl r3, 1");
//     instr := Instruction{.SHL, 1, {false, .R3}, {false, Immediate(1)}};
//     print_instr(instr);
//     fmt.println();

//     fmt.println("shl r3, 8");
//     instr = Instruction{.SHL, 1, {false, .R3}, {false, Immediate(8)}};
//     print_instr(instr);
//     fmt.println();

//     fmt.println("mov r5, 0");
//     instr = Instruction{.MOV, 2, {false, .R5}, {true, Immediate(0)}};
//     print_instr(instr);
//     fmt.println();

//     fmt.println("mov r5, 0x74");
//     instr = Instruction{.MOV, 2, {false, .R5}, {true, Immediate(0x74)}};
//     print_instr(instr);
//     fmt.println();

//     print_instr :: proc(instr: Instruction) {
//         // bit 0 - b.is_memory
//         // bit 1 - a.is_memory
//         // bit 2 - b.value.(Immediate)
//         _, b_is_imm := instr.b.value.(Immediate);
//         addr := u16(
//             (instr.b.is_memory ? 1<<0 : 0) |
//             (instr.a.is_memory ? 1<<1 : 0) |
//             (b_is_imm          ? 1<<2 : 0)
//         );

//         R := instr.a.value.(Register);
//         T := u16(0);
//         if !b_is_imm {
//             T = u16(instr.b.value.(Register));
//         } else {
//             imm := u16(instr.b.value.(Immediate));
//             if imm > 0b111 {
//                 T = 0b1000;
//             } else {
//                 T = imm;
//             }
//         }
//         fmt.printf("oooooxxxrrrrtttt\n");
//         fmt.printf("%05b%03b%04b%04b", u16(instr.op), addr, u16(R), T);

//         if b_is_imm {
//             imm := u16(instr.b.value.(Immediate));
//             if imm > 0b111 {
//                 fmt.printf(" %016b", imm);
//             }
//         }

//         fmt.println();
//     }
// }

