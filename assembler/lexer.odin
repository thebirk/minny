package assembler

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "utf8proc"

TokenTypes :: distinct bit_set[TokenType];
TokenType :: enum {
    End_Of_File,

    Identifier,
    Number,
    String,
    End_Of_Line,

    Percent,
    Dot,
    Comma,
    Colon,
    LeftBracket,
    RightBracket,

    /* For potential assemble time arithmetics*/
    Plus, Minus,
    Asterisk, Slash,
}

Location :: struct {
    file: string,
    line: int,
    character: int,
}

Token :: struct {
    kind:   TokenType,
    lexeme: string,
    loc:    Location,
    value:  union{int},
}

print_location :: proc(loc: Location) {
    fmt.printf("%s(%d:%d):", loc.file, loc.line, loc.character);
}

next_rune :: proc(parser: ^Parser) -> rune {
    parser.current_rune_offset = parser.offset;

    r, length := utf8.decode_rune(parser.data[parser.offset:]);
    // Differenatiate betwee utf8.RUNE_ERROR and EOF
    parser.offset += length;
    parser.current_rune = r;
    parser.current_character += 1;

    return r;
}

is_alpha :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z');
}

is_alnum :: proc(r: rune) -> bool {
    return is_alpha(r) || (r >= '0' && r <= '9');
}

is_letter :: proc(r: rune) -> bool {
    cat := utf8proc.category(r);
    // TODO: Can be optimized into range comparison
    return
        (cat == utf8proc.Category.LU ||
         cat == utf8proc.Category.LL ||
         cat == utf8proc.Category.LT ||
         cat == utf8proc.Category.LM ||
         cat == utf8proc.Category.LO
        );
}

is_ident :: proc(r: rune) -> bool {
    cat := utf8proc.category(r);
    // TODO: Can be optimized into range comparisons
    return 
        (cat == utf8proc.Category.LU ||
         cat == utf8proc.Category.LL ||
         cat == utf8proc.Category.LT ||
         cat == utf8proc.Category.LM ||
         cat == utf8proc.Category.LO
        )
        || (cat == utf8proc.Category.ND ||
            cat == utf8proc.Category.NL ||
            cat == utf8proc.Category.NO
            )
        || r == '_';
}

unescape_string :: proc(parser: ^Parser, loc: Location, str: string) -> string {
    // Should probably return a bool telling whether or not we allocated a new string

    found := false;
    for i := 0; i < len(str); i += 1 {
        // We could get the correct size here
        if str[i] == '\\' {
            found = true;
            break;
        }
    }

    if !found do return str;

    buffer: [dynamic]u8;
    reserve(&buffer, len(str));

    for i := 0; i < len(str); i += 1 {
        if str[i] == '\\' {
            i += 1;
            switch str[i] {
            case '\\': append(&buffer, '\\');
            case 'n': append(&buffer, 0x0A);
            case 'r': append(&buffer, 0x0D);
            case 'e': append(&buffer, 0x1b);
            case 't': append(&buffer, 0x09);
            case '0': append(&buffer, 0);
            case '"': append(&buffer, '"');
            case 'x': panic("TODO: Implement byte escape");
            case:
                parser_error(parser, loc, "unknown escape sequence '\\%r'", str[i]);
            }
        } else {
            append(&buffer, str[i]);
        }
    }

    return string(buffer[:]);
}

read_token :: proc(parser: ^Parser) -> Token {
    loc := Location{parser.filepath, parser.current_line, parser.current_character};

    start := parser.current_rune_offset;
    r := parser.current_rune;
    if r == utf8.RUNE_ERROR do return Token{.End_Of_File, "end of file", loc, nil};

    if r == '\n' {
        next_rune(parser);
        parser.current_line += 1;
        parser.current_character = 1;
        return Token{.End_Of_Line, "end of line", loc, nil};
    }

    if r == ' ' || r == '\t' || r == '\r' {
        next_rune(parser);
        return read_token(parser); //WARNING Recursion
    }

    switch r {
        case '%': next_rune(parser); return Token{.Percent,      "%", loc, nil};
        case '.': next_rune(parser); return Token{.Dot,          ".", loc, nil};
        case ':': next_rune(parser); return Token{.Colon,        ":", loc, nil};
        case ',': next_rune(parser); return Token{.Comma,        ",", loc, nil};
        case '[': next_rune(parser); return Token{.LeftBracket,  "[", loc, nil};
        case ']': next_rune(parser); return Token{.RightBracket, "]", loc, nil};

        case '+': next_rune(parser); return Token{.Plus,     "+", loc, nil};
        case '-': next_rune(parser); return Token{.Minus,    "-", loc, nil};
        case '*': next_rune(parser); return Token{.Asterisk, "*", loc, nil};
        case '/': next_rune(parser); return Token{.Slash,    "&", loc, nil};

        case ';': {
            next_rune(parser);

            for parser.current_rune != '\n' && parser.current_rune != utf8.RUNE_ERROR {
                next_rune(parser);
            }

            return read_token(parser);
        }

        case '"': {
            r = next_rune(parser);
            start = parser.current_rune_offset;

            //TODO: Handle escapes
            for {
                if r == '"' do break;

                r = next_rune(parser);
                if r == utf8.RUNE_ERROR do parser_error(parser, loc, "unexpected end of file while parsing string");
            }

            lexeme := string(parser.data[start:parser.current_rune_offset]);
            next_rune(parser);
            return Token{.String, lexeme, loc, nil};
        }

        case '\'': {
            r = next_rune(parser);
            start = parser.current_rune_offset;

            //TODO: Handle escapes
            for {
                if r == '\'' do break;

                r = next_rune(parser);
                if r == utf8.RUNE_ERROR do parser_error(parser, loc, "unexpected end of file while parsing character literal");
            }

            lexeme := string(parser.data[start:parser.current_rune_offset]);
            next_rune(parser);

            if utf8.rune_count(transmute([]u8)lexeme[:]) > 1 {
                parser_error(parser, loc, "invalid character literal, '%s'", lexeme);
            }

            r, len := utf8.decode_rune_in_string(lexeme);
            val := int(r);

            number_lexeme := fmt.aprintf("%d", r);
            append(&parser.allocated_strings, number_lexeme);

            return Token{.Number, number_lexeme, loc, val};
        }

        case '0'..'9': {
            base := 10;

            // Store in union value in Token, or if Number is the only special case Token, just stuff a `value: int` in there

            if parser.current_rune == '0' {
                r = next_rune(parser); // eat 0

                switch parser.current_rune {
                case 'x': base = 16; r = next_rune(parser); start := parser.current_rune_offset;
                case 'b': base = 2;  r = next_rune(parser); start := parser.current_rune_offset;
                }
            }

            value := 0;

            number_scan:
            for {
                if r >= 'A' && r <= 'F' {
                    r += 'a'-'A';
                }

                for ch, i in NUMBER_CHARS[:base] {
                    if ch == r {
                        value *= base;
                        value += i;
                        r = next_rune(parser);
                        continue number_scan;
                    }
                }

                break;
            }


            lexeme := string(parser.data[start:parser.current_rune_offset]);
            fmt.println(lexeme, ":", value);
            return Token{TokenType.Number, lexeme, loc, value};
        }

        case: {
            if is_letter(r) || r == '_' {
                for {
                    r = next_rune(parser);

                    if !is_ident(r) do break;
                }

                lexeme := string(parser.data[start:parser.current_rune_offset]);
                token_type := TokenType.Identifier;
                switch lexeme {
                    // Check for any keywords here if they are needed ex.
                    // > case "continue" : token_type = TokenType.Continue;
                }

                return Token{token_type, lexeme, loc, nil};
            }
        }
    }

    //TODO: if we fall here from a failed multi char we report the character after the failed char!
    fmt.printf("%s(%d:%d): Invalid character '%r'/%d!\n", loc.file, loc.line, loc.character, r, r);
    panic("");
    return Token{TokenType.End_Of_File, "end of file", loc, nil};
}

@(private="file")
NUMBER_CHARS := "0123456789abcdef";
