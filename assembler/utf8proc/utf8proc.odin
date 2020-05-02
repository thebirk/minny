package utf8proc

import "core:c"
import "core:mem"

VERSION_MAJOR :: 2;
VERSION_MINOR :: 1;
VERSION_PATCH :: 0;

ERROR_NOMEM       :: -1; /** Memory could not be allocated. */
ERROR_OVERFLOW    :: -2; /** The given string is too long to be processed. */
ERROR_INVALIDUTF8 :: -3; /** The given string is not a legal UTF-8 string. */
ERROR_NOTASSIGNED :: -4; /** The @ref UTF8PROC_REJECTNA flag was set and an unassigned codepoint was found. */
ERROR_INVALIDOPTS :: -5; /** Invalid options have been used. */

Option :: enum i32 {
	UTF8PROC_NULLTERM  = (1<<0), /** The given UTF-8 input is NULL terminated. */
	UTF8PROC_STABLE    = (1<<1), /** Unicode Versioning Stability has to be respected. */
	UTF8PROC_COMPAT    = (1<<2), /** Compatibility decomposition (i.e. formatting information is lost). */
	UTF8PROC_COMPOSE   = (1<<3), /** Return a result with decomposed characters. */
	UTF8PROC_DECOMPOSE = (1<<4), /** Return a result with decomposed characters. */
	UTF8PROC_IGNORE    = (1<<5), /** Strip "default ignorable characters" such as SOFT-HYPHEN or ZERO-WIDTH-SPACE. */
	UTF8PROC_REJECTNA  = (1<<6), /** Return an error, if the input contains unassigned codepoints. */
	/**
	* Indicating that NLF-sequences (LF, CRLF, CR, NEL) are representing a
	* line break, and should be converted to the codepoint for line
	* separation (LS).
	*/
	UTF8PROC_NLF2LS    = (1<<7),
	/**
	* Indicating that NLF-sequences are representing a paragraph break, and
	* should be converted to the codepoint for paragraph separation
	* (PS).
	*/
	UTF8PROC_NLF2PS    = (1<<8),
	UTF8PROC_NLF2LF    = (UTF8PROC_NLF2LS | UTF8PROC_NLF2PS), /** Indicating that the meaning of NLF-sequences is unknown. */
	/** Strips and/or convers control characters.
	*
	* NLF-sequences are transformed into space, except if one of the
	* NLF2LS/PS/LF options is given. HorizontalTab (HT) and FormFeed (FF)
	* are treated as a NLF-sequence in this case.  All other control
	* characters are simply removed.
	*/
	UTF8PROC_STRIPCC   = (1<<9),
	/**
	* Performs unicode case folding, to be able to do a case-insensitive
	* string comparison.
	*/
	UTF8PROC_CASEFOLD  = (1<<10),
	/**
	* Inserts 0xFF bytes at the beginning of each sequence which is
	* representing a single grapheme cluster (see UAX#29).
	*/
	UTF8PROC_CHARBOUND = (1<<11),
	/** Lumps certain characters together.
	*
	* E.g. HYPHEN U+2010 and MINUS U+2212 to ASCII "-". See lump.md for details.
	*
	* If NLF2LF is set, this includes a transformation of paragraph and
	* line separators to ASCII line-feed (LF).
	*/
	UTF8PROC_LUMP      = (1<<12),
	/** Strips all character markings.
	*
	* This includes non-spacing, spacing and enclosing (i.e. accents).
	* @note This option works only with @ref UTF8PROC_COMPOSE or
	*       @ref UTF8PROC_DECOMPOSE
	*/
	UTF8PROC_STRIPMARK = (1<<13),
}

Category :: enum i16 {
	CN  = 0, /**< Other, not assigned */
	LU  = 1, /**< Letter, uppercase */
	LL  = 2, /**< Letter, lowercase */
	LT  = 3, /**< Letter, titlecase */
	LM  = 4, /**< Letter, modifier */
	LO  = 5, /**< Letter, other */
	MN  = 6, /**< Mark, nonspacing */
	MC  = 7, /**< Mark, spacing combining */
	ME  = 8, /**< Mark, enclosing */
	ND  = 9, /**< Number, decimal digit */
	NL = 10, /**< Number, letter */
	NO = 11, /**< Number, other */
	PC = 12, /**< Punctuation, connector */
	PD = 13, /**< Punctuation, dash */
	PS = 14, /**< Punctuation, open */
	PE = 15, /**< Punctuation, close */
	PI = 16, /**< Punctuation, initial quote */
	PF = 17, /**< Punctuation, final quote */
	PO = 18, /**< Punctuation, other */
	SM = 19, /**< Symbol, math */
	SC = 20, /**< Symbol, currency */
	SK = 21, /**< Symbol, modifier */
	SO = 22, /**< Symbol, other */
	ZS = 23, /**< Separator, space */
	ZL = 24, /**< Separator, line */
	ZP = 25, /**< Separator, paragraph */
	CC = 26, /**< Other, control */
	CF = 27, /**< Other, format */
	CS = 28, /**< Other, surrogate */
	CO = 29, /**< Other, private use */
}

BidiClass :: enum i16 {
	L     = 1, /**< Left-to-Right */
	LRE   = 2, /**< Left-to-Right Embedding */
	LRO   = 3, /**< Left-to-Right Override */
	R     = 4, /**< Right-to-Left */
	AL    = 5, /**< Right-to-Left Arabic */
	RLE   = 6, /**< Right-to-Left Embedding */
	RLO   = 7, /**< Right-to-Left Override */
	PDF   = 8, /**< Pop Directional Format */
	EN    = 9, /**< European Number */
	ES   = 10, /**< European Separator */
	ET   = 11, /**< European Number Terminator */
	AN   = 12, /**< Arabic Number */
	CS   = 13, /**< Common Number Separator */
	NSM  = 14, /**< Nonspacing Mark */
	BN   = 15, /**< Boundary Neutral */
	B    = 16, /**< Paragraph Separator */
	S    = 17, /**< Segment Separator */
	WS   = 18, /**< Whitespace */
	ON   = 19, /**< Other Neutrals */
	LRI  = 20, /**< Left-to-Right Isolate */
	RLI  = 21, /**< Right-to-Left Isolate */
	FSI  = 22, /**< First Strong Isolate */
	PDI  = 23, /**< Pop Directional Isolate */
}

Decomp :: enum i16 {
	FONT      = 1, /**< Font */
	NOBREAK   = 2, /**< Nobreak */
	INITIAL   = 3, /**< Initial */
	MEDIAL    = 4, /**< Medial */
	FINAL     = 5, /**< Final */
	ISOLATED  = 6, /**< Isolated */
	CIRCLE    = 7, /**< Circle */
	SUPER     = 8, /**< Super */
	SUB       = 9, /**< Sub */
	VERTICAL = 10, /**< Vertical */
	WIDE     = 11, /**< Wide */
	NARROW   = 12, /**< Narrow */
	SMALL    = 13, /**< Small */
	SQUARE   = 14, /**< Square */
	FRACTION = 15, /**< Fraction */
	COMPAT   = 16, /**< Compat */
}

Boundclass :: enum u8 {
	START              =  0, /**< Start */
	OTHER              =  1, /**< Other */
	CR                 =  2, /**< Cr */
	LF                 =  3, /**< Lf */
	CONTROL            =  4, /**< Control */
	EXTEND             =  5, /**< Extend */
	L                  =  6, /**< L */
	V                  =  7, /**< V */
	T                  =  8, /**< T */
	LV                 =  9, /**< Lv */
	LVT                = 10, /**< Lvt */
	REGIONAL_INDICATOR = 11, /**< Regional indicator */
	SPACINGMARK        = 12, /**< Spacingmark */
	PREPEND            = 13, /**< Prepend */
	ZWJ                = 14, /**< Zero Width Joiner */
	E_BASE             = 15, /**< Emoji Base */
	E_MODIFIER         = 16, /**< Emoji Modifier */
	GLUE_AFTER_ZWJ     = 17, /**< Glue_After_ZWJ */
	E_BASE_GAZ         = 18, /**< E_BASE + GLUE_AFTER_ZJW */
}

Property :: struct {
	category: Category,
	combining_class: i16,
	bidi_class: BidiClass,

	decomp_type: Decomp,
	decomp_seqindex: u16,
	casefold_seqindex: u16,
	uppercase_seqindex: u16,
	lowercase_seqindex: u16,
	titlecase_seqindex: u16,
	comb_index: u16,
	
	_bitfield: c.uint,
/*	unsigned bidi_mirrored:1;
	unsigned comp_exclusion:1;
	unsigned ignorable:1;
	unsigned control_boundary:1;
	unsigned charwidth:2;
	unsigned pad:2;
	// Boundclass enum
	unsigned boundclass:8;*/
}

Custom_Func :: #type proc"c"(cp: rune, data: rawptr);

utf8proc_ssize_t :: i64; //TODO: Is this right?

when ODIN_OS == "windows" do foreign import utf8proclib "lib/utf8proc.lib";
else when ODIN_OS == "linux" do foreign import utf8proclib "lib/utf8proc.a";
else {
	#assert("It's now your job to figure how to static link this on whatever platform you are one ;)");
}

@(default_calling_convention="c", link_prefix="utf8proc_")
foreign utf8proclib {
	version :: proc() -> cstring ---;
	errmsg  :: proc(errcode: utf8proc_ssize_t) -> cstring ---;

	iterate         :: proc(str: cstring, strlen: utf8proc_ssize_t, codepoint_ref: ^i32) -> utf8proc_ssize_t ---;
	codepoint_valid :: proc(codepoint: rune) -> b8 ---;

	encode_char  :: proc(codepoint: rune, dst: ^u8) -> utf8proc_ssize_t ---;
	get_property :: proc(codepoint: rune) -> ^Property ---;

	decompose_char   :: proc(codepoint: rune, dst: ^rune, bufsize: utf8proc_ssize_t, options: Option, last_boundclass: ^int) -> utf8proc_ssize_t ---;
	decompose        :: proc(str: cstring, strlen: utf8proc_ssize_t, buffer: ^rune, bufsize: utf8proc_ssize_t, options: Option) -> utf8proc_ssize_t ---;
	decompose_custom :: proc(str: cstring, strlen: utf8proc_ssize_t, buffer: ^rune, bufsize: utf8proc_ssize_t, options: Option, custom_func: Custom_Func, custom_data: rawptr) -> utf8proc_ssize_t ---;

	normalize_utf32   :: proc(buffer: ^rune, length: utf8proc_ssize_t, options: Option) -> utf8proc_ssize_t ---;
	reencode          :: proc(buffer: ^rune, length: utf8proc_ssize_t, options: Option) -> utf8proc_ssize_t ---;

	grapheme_break_stateful :: proc(codepoint1: rune, codepoint2: rune, state: ^i32) -> b8 ---;
	grapheme_break          :: proc(codepoint1: rune, codepoint2: rune) -> u8 ---;

	tolower :: proc(c: rune) -> rune ---;
	toupper :: proc(c: rune) -> rune ---;
	totitle :: proc(c: rune) -> rune ---;

	charwidth       :: proc(codepoint: rune) -> i32 ---;
	category        :: proc(codepoint: rune) -> Category ---;
	category_string :: proc(codepoint: rune) -> cstring ---;

	map_       :: proc(str: cstring, strlen: utf8proc_ssize_t, dstptr: ^^u8, options: Option) -> utf8proc_ssize_t ---;
	map_custom :: proc(str: cstring, strlen: utf8proc_ssize_t, dstptr: ^^u8, options: Option, custom_func: Custom_Func, custom_data: rawptr) -> utf8proc_ssize_t ---;

	NFD           :: proc(str: cstring) -> cstring ---;
	NFC           :: proc(str: cstring) -> cstring ---;
	NFKD          :: proc(str: cstring) -> cstring ---;
	NFKC          :: proc(str: cstring) -> cstring ---;
	NFKC_Casefold :: proc(str: cstring) -> cstring ---;

	utf8class_: ^i8; // Wrapped by a utf8class proc
}

utf8class :: proc() -> [/*256*/]i8 {
	return mem.slice_ptr(utf8class_, 256);
}

import "core:fmt"
main :: proc() {
	r := 'A';
	fmt.printf("tolower(%r) = %r\n", r, tolower(r));
	r = '€';
	fmt.printf("category       (%r) = %v\n", r, category(r));
	fmt.printf("category_string(%r) = %s\n", r, category_string(r));
}