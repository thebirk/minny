package assembler

import "core:fmt"
import "core:strings"

Instruction_Template_Operand :: struct {
    is_memory: bool,
    type: enum {
        Register,
        Immediate,
    },
}

Instruction_Template :: struct {
    name:          string,
    operand_count: int,
    operands:      []Instruction_Template_Operand,
}

//NOTE: All instrucions with the samne opcode has to be grouped together
//      so that they can be sliced as one group.
valid_ops := []Instruction_Template{
    {"nop", 0, {}},

    {"mov", 2, {{false, .Register},{false, .Register }}}, // mov r0, r0
    {"mov", 2, {{false, .Register},{true , .Register }}}, // mov r0, [r0]
    {"mov", 2, {{true , .Register},{false, .Register }}}, // mov [r0], r0
    {"mov", 2, {{true , .Register},{true , .Register }}}, // mov [r0], [r0]

    {"mov", 2, {{false, .Register},{false, .Immediate}}}, // mov r0, imm
    {"mov", 2, {{false, .Register},{true , .Immediate}}}, // mov r0, [imm]
    {"mov", 2, {{true , .Register},{false, .Immediate}}}, // mov [r0], imm
    {"mov", 2, {{true , .Register},{true , .Immediate}}}, // mov [r0], [imm]

    {"add", 2, {{false, .Register},{false, .Register }}}, // add r0, r0
    {"add", 2, {{false, .Register},{true , .Register }}}, // add r0, [r0]
    {"add", 2, {{false, .Register},{false, .Immediate}}}, // add [r0], r0
    {"add", 2, {{false, .Register},{true , .Immediate}}}, // add [r0], [r0]

    {"add", 2, {{true , .Register},{false, .Register }}}, // add r0, imm
    {"add", 2, {{true , .Register},{true , .Register }}}, // add r0, [imm]
    {"add", 2, {{true , .Register},{false, .Immediate}}}, // add [r0], imm
    {"add", 2, {{true , .Register},{true , .Immediate}}}, // add [r0], [imm]

    {"sub", 2, {{false, .Register},{false, .Register }}}, // sub r0, r0
    {"sub", 2, {{false, .Register},{true , .Register }}}, // sub r0, [r0]
    {"sub", 2, {{false, .Register},{false, .Immediate}}}, // sub [r0], r0
    {"sub", 2, {{false, .Register},{true , .Immediate}}}, // sub [r0], [r0]

    {"sub", 2, {{true , .Register},{false, .Register }}}, // sub r0, imm
    {"sub", 2, {{true , .Register},{true , .Register }}}, // sub r0, [imm]
    {"sub", 2, {{true , .Register},{false, .Immediate}}}, // sub [r0], imm
    {"sub", 2, {{true , .Register},{true , .Immediate}}}, // sub [r0], [imm]

    {"shl", 2, {{false, .Register},{false, .Register }}}, // shl r0, r0
    {"shl", 2, {{false, .Register},{true , .Register }}}, // shl r0, [r0]
    {"shl", 2, {{false, .Register},{false, .Immediate}}}, // shl [r0], r0
    {"shl", 2, {{false, .Register},{true , .Immediate}}}, // shl [r0], [r0]

    {"shl", 2, {{true , .Register},{false, .Register }}}, // shl r0, imm
    {"shl", 2, {{true , .Register},{true , .Register }}}, // shl r0, [imm]
    {"shl", 2, {{true , .Register},{false, .Immediate}}}, // shl [r0], imm
    {"shl", 2, {{true , .Register},{true , .Immediate}}}, // shl [r0], [imm]

    {"shr", 2, {{false, .Register},{false, .Register }}}, // shr r0, r0
    {"shr", 2, {{false, .Register},{true , .Register }}}, // shr r0, [r0]
    {"shr", 2, {{false, .Register},{false, .Immediate}}}, // shr [r0], r0
    {"shr", 2, {{false, .Register},{true , .Immediate}}}, // shr [r0], [r0]

    {"shr", 2, {{true , .Register},{false, .Register }}}, // shr r0, imm
    {"shr", 2, {{true , .Register},{true , .Register }}}, // shr r0, [imm]
    {"shr", 2, {{true , .Register},{false, .Immediate}}}, // shr [r0], imm
    {"shr", 2, {{true , .Register},{true , .Immediate}}}, // shr [r0], [imm]

    {"and", 2, {{false, .Register},{false, .Register }}}, // and r0, r0
    {"and", 2, {{false, .Register},{true , .Register }}}, // and r0, [r0]
    {"and", 2, {{false, .Register},{false, .Immediate}}}, // and [r0], r0
    {"and", 2, {{false, .Register},{true , .Immediate}}}, // and [r0], [r0]

    {"and", 2, {{true , .Register},{false, .Register }}}, // and r0, imm
    {"and", 2, {{true , .Register},{true , .Register }}}, // and r0, [imm]
    {"and", 2, {{true , .Register},{false, .Immediate}}}, // and [r0], imm
    {"and", 2, {{true , .Register},{true , .Immediate}}}, // and [r0], [imm]

    {"or" , 2, {{false, .Register},{false, .Register }}}, // or  r0, r0
    {"or" , 2, {{false, .Register},{true , .Register }}}, // or  r0, [r0]
    {"or" , 2, {{false, .Register},{false, .Immediate}}}, // or  [r0], r0
    {"or" , 2, {{false, .Register},{true , .Immediate}}}, // or  [r0], [r0]

    {"or" , 2, {{true , .Register},{false, .Register }}}, // or  r0, imm
    {"or" , 2, {{true , .Register},{true , .Register }}}, // or  r0, [imm]
    {"or" , 2, {{true , .Register},{false, .Immediate}}}, // or  [r0], imm
    {"or" , 2, {{true , .Register},{true , .Immediate}}}, // or  [r0], [imm]

    {"xor", 2, {{false, .Register},{false, .Register }}}, // xor r0, r0
    {"xor", 2, {{false, .Register},{true , .Register }}}, // xor r0, [r0]
    {"xor", 2, {{false, .Register},{false, .Immediate}}}, // xor [r0], r0
    {"xor", 2, {{false, .Register},{true , .Immediate}}}, // xor [r0], [r0]

    {"xor", 2, {{true , .Register},{false, .Register }}}, // xor r0, imm
    {"xor", 2, {{true , .Register},{true , .Register }}}, // xor r0, [imm]
    {"xor", 2, {{true , .Register},{false, .Immediate}}}, // xor [r0], imm
    {"xor", 2, {{true , .Register},{true , .Immediate}}}, // xor [r0], [imm]

    {"not", 1, {{false, .Register }}}, // not r0
    {"not", 1, {{true , .Register }}}, // not [r0]
    {"not", 1, {{true , .Immediate}}}, // not [imm]

    {"jmp", 1, {{false, .Register }}}, // jmp r0
    {"jmp", 1, {{true , .Register }}}, // jmp [r0]
    {"jmp", 1, {{false, .Immediate}}}, // jmp imm
    {"jmp", 1, {{true , .Immediate}}}, // jmp [imm]

    {"jsr", 1, {{false, .Register }}}, // jsr r0
    {"jsr", 1, {{true , .Register }}}, // jsr [r0]
    {"jsr", 1, {{false, .Immediate}}}, // jsr imm
    {"jsr", 1, {{true , .Immediate}}}, // jsr [imm]

    {"ret", 0, {}}, // ret

    {"jz" , 1, {{false, .Register }}}, // jz r0
    {"jz" , 1, {{true , .Register }}}, // jz [r0]
    {"jz" , 1, {{false, .Immediate}}}, // jz imm
    {"jz" , 1, {{true , .Immediate}}}, // jz [imm]

    {"jnz", 1, {{false, .Register }}}, // jnz r0
    {"jnz", 1, {{true , .Register }}}, // jnz [r0]
    {"jnz", 1, {{false, .Immediate}}}, // jnz imm
    {"jnz", 1, {{true , .Immediate}}}, // jnz [imm]

    {"jc" , 1, {{false, .Register }}}, // jc r0
    {"jc" , 1, {{true , .Register }}}, // jc [r0]
    {"jc" , 1, {{false, .Immediate}}}, // jc imm
    {"jc" , 1, {{true , .Immediate}}}, // jc [imm]

    {"jnc", 1, {{false, .Register }}}, // jnc r0
    {"jnc", 1, {{true , .Register }}}, // jnc [r0]
    {"jnc", 1, {{false, .Immediate}}}, // jnc imm
    {"jnc", 1, {{true , .Immediate}}}, // jnc [imm]

    {"int", 1, {{false, .Register }}}, // int r0
    {"int", 1, {{true , .Register }}}, // int [r0]
    {"int", 1, {{false, .Immediate}}}, // int imm
    {"int", 1, {{true , .Immediate}}}, // int [imm]

    {"reti", 0, {}}, // reti
    {"hlt", 0, {}}, // hlt

    {"inc", 1, {{false, .Register }}}, // inc r0
    {"inc", 1, {{true , .Register }}}, // inc [r0]
    {"inc", 1, {{true , .Immediate}}}, // inc [imm]

    {"dec", 1, {{false, .Register }}}, // dec r0
    {"dec", 1, {{true , .Register }}}, // dec [r0]
    {"dec", 1, {{true , .Immediate}}}, // dec [imm]

    {"cmp", 2, {{false, .Register},{false, .Register }}}, // cmp r0, r0
    {"cmp", 2, {{false, .Register},{true , .Register }}}, // cmp r0, [r0]
    {"cmp", 2, {{true , .Register},{false, .Register }}}, // cmp [r0], r0
    {"cmp", 2, {{true , .Register},{true , .Register }}}, // cmp [r0], [r0]

    {"cmp", 2, {{false, .Register},{false, .Immediate}}}, // cmp r0, imm
    {"cmp", 2, {{false, .Register},{true , .Immediate}}}, // cmp r0, [imm]
    {"cmp", 2, {{true , .Register},{false, .Immediate}}}, // cmp [r0], imm
    {"cmp", 2, {{true , .Register},{true , .Immediate}}}, // cmp [r0], [imm]

    /* JE/JNE */
};

validate_valid_ops_table :: proc() {
    names: map[string][dynamic]int;
    defer delete(names);

    prev := "";
    for op, i in valid_ops {
        if prev != op.name {
            if _, ok := names[op.name]; !ok {
                prev = op.name;
                locs: [dynamic]int;
                append(&locs, i);
                names[op.name] = locs;
                continue;
            }

            // we found something which wasnt prev but already exists
            // somewhere else in the table

            builder := strings.make_builder();
            strings.write_string(&builder, fmt.aprintf(
                "index %d of valid_ops table with op '%s', is out of order with %d other declaration(s) of the same name at indices:\n",
                i, op.name, len(names[op.name])
            ));

            locs := names[op.name];
            for l in locs {
                //strings.write_string(&builder, fmt.aprintf("- valid_ops[%d]: %#v\n", l, valid_ops[l]));
                strings.write_string(
                    &builder,
                    fmt.aprintf("    - %d\n", l)
                );
            }

            panic(strings.to_string(builder));
        } else {
            append(&names[op.name], i);
        }
    }

    for k, v in names {
        delete(v);
    }
}

get_valid_ops_from_name :: proc(name: string) -> []Instruction_Template {
    start := -1;

    for op, i in valid_ops {
        if op.name == name {
            if start == -1 {
                start = i;
                continue;
            }
        } else {
            if start != -1 {
                return valid_ops[start:i];
            }
        }
    }

    return nil;
}