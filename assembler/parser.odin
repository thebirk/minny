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
        op.value = Number(420);
        return op;
    case .String:
        next_token(parser);
        op := new(Operand);
        op.is_memory = false;
        op.value = String(t.lexeme);
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
    #partial
    switch current_token.kind {
    case .Percent:    fmt.println("Percent");
    case .Dot:        fmt.println("Dot");
    case .Identifier:
        ident := current_token;
        next_token(parser);
        fmt.printf("%#v\n", ident);

        operands: [dynamic]^Operand;
        op := parse_operand_expr(parser);
        append(&operands, op);

        for current_token.kind == .Comma {
            next_token(parser);

            op := parse_operand_expr(parser);
            append(&operands, op);
        }

        return Instruction{ident.lexeme, operands[:]}, true;
    case .End_Of_File: return {}, false;
    case:
        parser_error(parser, "unexpected token '%v'", current_token.lexeme);
    }

    unreachable();
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

next_token :: proc(using parser: ^Parser) -> Token {
    t := read_token(parser);
    current_token = t;
    return t;
}
