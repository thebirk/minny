package assembler

import "core:os"
import "core:fmt"

Parser :: struct {
    filepath: string,
    data: []u8,
    offset: int,
    current_line: int,
    current_character: int,
    current_rune: rune,
    current_rune_offset: int,
    current_token: Token,

    allocated_strings: [dynamic]string,
}

parser_error_at :: proc(using parser: ^Parser, loc: Location, fmt_string: string, args: ..any) -> ! {
    print_location(loc);
    fmt.printf("\e[91m parser error: \e[0m");
    fmt.printf(fmt_string, ..args);
    fmt.printf("\n");

    //TODO: Print the line, with the line above and below as well
    //      try using an arrow as well
    //      Easiest solution would be to tag tokens with the start offset

    os.exit(1);
}

parser_error_current :: proc(using parser: ^Parser, fmt_string: string, args: ..any) -> ! {
    parser_error_at(parser, current_token.loc, fmt_string, ..args);
}

parser_error :: proc{
    parser_error_at,
    parser_error_current,
};

parse_operand :: proc(using parser: ^Parser) -> ^Operand {
    t := current_token;
    #partial
    switch t.kind {
    case .Identifier:
        next_token(parser);
        op := new(Operand);
        op.is_memory = false;
        op.value = Identifier(t.lexeme);
        return op;
    case .Number:
        next_token(parser);
        op := new(Operand);
        op.is_memory = false;
        //op.value = ;
        op.value = Number(t.value.(int));
        return op;
    case .String:
        next_token(parser);
        op := new(Operand);
        op.is_memory = false;
        op.value = String(t.lexeme);
        return op;
    case .Dot:
        next_token(parser);
        if current_token.kind != .Identifier {
            parser_error(parser, "unexpected '%v', expected identifier after '.'", current_token.lexeme);
        }
        ident := current_token;
        next_token(parser);

        op := new(Operand);
        op.is_memory = false;
        //TODO: mark as local when we get a label like value
        op.value = Identifier(ident.lexeme);

        return op;
    case:
        parser_error(parser, "unexpected token '%v'", t.lexeme);    
    }

    unreachable();
    return nil;
}

parse_operand_expr_mul :: proc(using parser: ^Parser) -> ^Operand {
    lhs := parse_operand(parser);

    for (current_token.kind in TokenTypes{.Plus, .Minus}) {
        op := current_token;
        next_token(parser);

        rhs := parse_operand(parser);
        
        new_lhs := new(Operand);
        new_lhs.is_memory = false;
        new_lhs.value = Binary{
            op.kind,
            lhs,
            rhs
        };

        lhs = new_lhs;
    }

    return lhs;
}

parse_operand_expr_add :: proc(using parser: ^Parser) -> ^Operand {
    lhs := parse_operand_expr_mul(parser);

    for (current_token.kind in TokenTypes{.Plus, .Minus}) {
        op := current_token;
        next_token(parser);

        rhs := parse_operand_expr_mul(parser);
        
        new_lhs := new(Operand);
        new_lhs.is_memory = false;
        new_lhs.value = Binary{
            op.kind,
            lhs,
            rhs 
        };

        lhs = new_lhs;
    }

    return lhs;
}

parse_operand_expr :: proc(using parser: ^Parser) -> ^Operand {
    is_memory := false;
    if current_token.kind == .LeftBracket {
        is_memory = true;
        next_token(parser);
    }
    op := parse_operand_expr_add(parser);

    if is_memory {
        op.is_memory = true;

        if current_token.kind != .RightBracket {
            parser_error(parser, "unexpected '%v', expected ']'", current_token.kind);
        }
        next_token(parser);
    }

    return op;
}

parse_line :: proc(using parser: ^Parser) -> (Instruction, bool) {
    for {
        if current_token.kind == .End_Of_File {
            return {}, false;
        }
        if current_token.kind == .End_Of_Line {
            next_token(parser);
            continue;
        }

        if current_token.kind == .Dot {
            next_token(parser);

            if current_token.kind != .Identifier {
                parser_error(parser, "unexpected '%v', expected identifier", current_token.lexeme);
            }
            label_name := current_token;
            next_token(parser);

            if current_token.kind != .Colon {
                parser_error(parser, "unexpected '%v', expected ':' after label", current_token.lexeme);
            }
            next_token(parser);

            if current_token.kind == .End_Of_Line || current_token.kind == .End_Of_File {
                next_token(parser);
                return Instruction{label_name.lexeme, true, false, "", nil}, true;
            }

            directive := false;
            if current_token.kind == .Percent {
                directive = true;
                next_token(parser);
            }

            if current_token.kind != .Identifier {
                parser_error(parser, "unexpected '%v', expected instruction or directive");
            }
            ident := current_token;
            next_token(parser);

            return parse_instruction(parser, ident, label_name.lexeme, true, directive), true;
        } else {
            if current_token.kind != .Identifier && current_token.kind != .Percent {
                parser_error(parser, "unexpected '%v', expected identifier or '%%'", current_token.lexeme);
            }
            ident_label_or_percent := current_token;
            next_token(parser);

            if current_token.kind == .Colon {
                next_token(parser);

                if ident_label_or_percent.kind != .Identifier {
                    parser_error_at(parser, ident_label_or_percent.loc, "unexpected '%v', expected identifier before ':'", ident_label_or_percent.lexeme);
                }

                if current_token.kind == .End_Of_Line || current_token.kind == .End_Of_File {
                    next_token(parser);
                    return Instruction{ident_label_or_percent.lexeme, false, false, "", nil}, true;
                }

                directive := false;
                if current_token.kind == .Percent {
                    directive = true;
                    next_token(parser);
                }

                if current_token.kind != .Identifier {
                    parser_error(parser, "unexpected '%v', expected instruction", current_token.lexeme);
                }
                ident := current_token;
                next_token(parser);

                return parse_instruction(parser, ident, ident_label_or_percent.lexeme, false, directive), true;
            } else {
                if ident_label_or_percent.kind == .Percent {
                    if current_token.kind != .Identifier {
                        parser_error(parser, "unexpected '%v', expected directive name", current_token.lexeme);
                    }
                    ident := current_token;
                    next_token(parser);

                    return parse_instruction(parser, ident, "", false, true), true;
                } else {
                    return parse_instruction(parser, ident_label_or_percent, "", false, false), true;
                }
            }
        }

        parse_instruction :: proc(using parser: ^Parser, ident: Token, label: string, local_label: bool, directive: bool) -> Instruction {
            fmt.printf("%#v\n", ident);

            operands: [dynamic]^Operand;

            if current_token.kind == .End_Of_Line || current_token.kind == .End_Of_File {
                return Instruction{
                    label = label,
                    local_label = local_label,
                    directive = directive,
                    op = ident.lexeme,
                    operands = operands[:]
                };
            }

            op := parse_operand_expr(parser);
            append(&operands, op);

            for directive ? current_token.kind != .End_Of_Line : current_token.kind == .Comma {
                if !directive do next_token(parser);

                op := parse_operand_expr(parser);
                append(&operands, op);
            }

            if current_token.kind != .End_Of_Line  && current_token.kind != .End_Of_File {
                parser_error(parser, "unexpected '%v'", current_token.lexeme);
            }
            next_token(parser);

            return Instruction{
                label = label,
                local_label = local_label,
                directive = directive,
                op = ident.lexeme,
                operands = operands[:]
            };
        }

        fmt.println(current_token);
        unreachable();
    }
    return {}, false;
}

parse :: proc(using parser: ^Parser) -> []Instruction {
    instrs: [dynamic]Instruction;

    for {
        instr, ok := parse_line(parser);
        if !ok do break;
        append(&instrs, instr);
    }

    return instrs[:];
}

parse_file :: proc(path: string) -> []Instruction {
    parser: Parser;
    parser.filepath = path;

    data, ok := os.read_entire_file(path);
    if !ok {
        panic("failed to read file");
    }

    parser.data = data[:];
    parser.current_line = 1;
    parser.current_character = 0;
    next_rune(&parser);
    next_token(&parser);

    return parse(&parser);
}

next_token :: proc(using parser: ^Parser) -> Token {
    t := read_token(parser);
    current_token = t;
    return t;
}
