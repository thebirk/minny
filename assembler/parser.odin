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
