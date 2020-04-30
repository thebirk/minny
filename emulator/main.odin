package emulator

import "core:os"
import "core:fmt"
import "core:time"
import "core:math/rand"

when ODIN_OS == "windows" do foreign import libc "system:libcmt.lib";
when ODIN_OS == "linux"   do foreign import libc "system:c";
when ODIN_OS == "darwin"  do foreign import libc "system:c";
foreign libc {
	getchar :: proc"c"() -> i32 ---;
}

READ_BIT  :u16: 0b01 << 8;
WRITE_BIT :u16: 0b10 << 8;

FLAG_C :u16: 0b00000001;
FLAG_Z :u16: 0b00000010;
FLAG_H :u16: 0b00000100;
FLAG_S :u16: 0b00001000;

CPU :: struct {
	mem: []u16,
	reg: [8]u16,
	sp: u16,
	pc: u16,
	hlt: bool,
}

REG_SP :u16: 0b1000;
REG_PC :u16: 0b1001;

OP_MASK :u16: 0b1111100000000000;
X_MASK  :u16: 0b0000011100000000;
R_MASK  :u16: 0b0000000011110000;
T_MASK  :u16: 0b0000000000001111;

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

OpcodeInformation :: struct {
	operands: int,
}

Opcodes := map[u16]OpcodeInformation {
	cast(u16) Opcode.NOP  = {0},
	cast(u16) Opcode.MOV  = {2},
	cast(u16) Opcode.ADD  = {2},
	cast(u16) Opcode.SUB  = {2},
	cast(u16) Opcode.SHL  = {2},
	cast(u16) Opcode.SHR  = {2},
	cast(u16) Opcode.AND  = {2},
	cast(u16) Opcode.OR   = {2},
	cast(u16) Opcode.XOR  = {2},
	cast(u16) Opcode.NOT  = {1},
	cast(u16) Opcode.JMP  = {1},
	cast(u16) Opcode.JSR  = {1},
	cast(u16) Opcode.RET  = {0},
	cast(u16) Opcode.JZ   = {1},
	cast(u16) Opcode.JNZ  = {1},
	cast(u16) Opcode.JC   = {1},
	cast(u16) Opcode.JNC  = {1},
	cast(u16) Opcode.INT  = {1},
	cast(u16) Opcode.RETI = {0},
	cast(u16) Opcode.HLT  = {0},
	cast(u16) Opcode.INC  = {1},
	cast(u16) Opcode.DEC  = {1},
	cast(u16) Opcode.JE   = {1},
	cast(u16) Opcode.JNE  = {1},
	cast(u16) Opcode.CMP  = {2},
};

init_cpu :: proc(using cpu: ^CPU) {
	cpu.mem = make([]u16, int(max(u16)) + 1);

	// Set memory access bits and fill data with "noise"
	for i in 0..len(cpu.mem)-1 {
		cpu.mem[i] = (READ_BIT|WRITE_BIT) | u16(rand.uint32() & 0xFF);
	}
	reg[0] = 0;
	reg[1] = 0;
	reg[2] = 0;
	reg[3] = 0;
	reg[4] = 0;
	reg[5] = 0;
	reg[6] = 0;
	reg[7] = 0;

	sp = 0;
	pc = 0; // Find a better starting address
}

cpu_sub :: proc(using cpu: ^CPU, a, b: u16, write_flags: bool) -> u16{
	result := a - b;
	
	if write_flags {
		zero  := false;
		sign  := false;
		carry := false;
		
		// Do we want a overflow flag?
		
		if result == 0 {
			zero = true;
		}
		
		if result & (1<<15) > 0 {
			sign = true;
		}
		
		//TODO: Check that this is right
		if (a - b) > a {
			carry = true;
		}
		
		cpu.reg[7] &~= (FLAG_Z | FLAG_S | FLAG_C);
		cpu.reg[7] |= (zero ? FLAG_Z : 0) | (sign ? FLAG_S : 0) | (carry ? FLAG_C : 0);
	}
	
	return result;
}

write_byte :: inline proc(using cpu: ^CPU, addr: u16, v: u8) {
	if mem[addr] & WRITE_BIT > 0 {
		mem[addr] &~= 0xFF;
		mem[addr] |= u16(v);
	}
}

write_word :: inline proc(using cpu: ^CPU, addr: u16, v: u16) {
	//mem[addr]   |= u16(v >> 8)   & 0xFF;
	//mem[addr+1] |= u16(v & 0xFF) & 0xFF;
	write_byte(cpu, addr    , u8(v >> 8));
	write_byte(cpu, addr + 1, u8(v &  0xFF));
}

read_byte :: inline proc(using cpu: ^CPU, addr: u16) -> u8 {
	if mem[addr] & READ_BIT > 0 {
		return u8(mem[addr] & 0xFF);
	} else {
		return 0;
	}
}

read_word :: inline proc(using cpu: ^CPU, addr: u16) -> u16 {
	v := u16(read_byte(cpu, addr)) << 8;
	v |= u16(read_byte(cpu, addr+1));
	return v;
}

read_register :: inline proc(using cpu: ^CPU, r: u16) -> u16 {
	switch r {
	case 0..7:   return reg[r];
	case REG_SP: return sp;
	case REG_PC: return pc;
	case: panic("unknown reg");			
	}

	return 0xABCD;
}

write_register :: inline proc(using cpu: ^CPU, r: u16, value: u16) {
	switch r {
	case 0..7:   reg[r] = value;
	case REG_SP: sp     = value;
	case REG_PC: pc     = value;
	case: panic("unknown reg");				
	}
}

pop :: inline proc(using cpu: ^CPU) -> u16 {
	v := read_word(cpu, sp);
	sp += 2;
	return v;
}

push_register :: inline proc(using cpu: ^CPU, r: u16) {
	sp -= 2;
	write_word(cpu, sp, read_register(cpu, r));
}

cpu_step :: proc(using cpu: ^CPU) {
	instr := read_word(cpu, pc);
	pc += 2;

	op := (instr & OP_MASK) >> 11;
	using Opcode;

	#partial
	switch Opcode(op) {
	case:
		panic("INVALID OP");
	case NOP:
		return;
	case HLT:
		hlt = true;
		return;
	case MOV:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch addr & 0b100 {
		case 0b000:
			t := (instr & T_MASK);

			switch addr {
				case 0b000:
					//reg[r] = reg[t];
					write_register(cpu, r, read_register(cpu, t));
				case 0b001:
					//reg[r] = read_word(cpu, reg[t]);
					write_register(cpu, r, read_word(cpu, read_register(cpu, t)));
				case 0b010:
					//write_word(cpu, reg[r], reg[t]);
					write_word(cpu, read_register(cpu, r), read_register(cpu, t));
				case 0b011:	
					//write_word(cpu, reg[r], read_word(cpu, reg[t]));
					write_word(cpu, read_register(cpu, r), read_word(cpu, read_register(cpu, t)));
			}
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
				case 0b100:
					//reg[r] = i;
					write_register(cpu, r, i);
				case 0b101:
					//reg[r] = read_word(cpu, i);
					write_register(cpu, r, read_word(cpu, i));
				case 0b110:
					//write_word(cpu, reg[r], i);
					write_word(cpu, read_register(cpu, r), i);
				case 0b111:
					//write_word(cpu, reg[r], read_word(cpu, i));
					write_word(cpu, read_register(cpu, r), read_word(cpu, i));
			}
		}
	case ADD:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch addr & 0b100 {
		case 0b000:
			t := (instr & T_MASK);

			switch addr {
				case 0b000:
					reg[r] = reg[r] + reg[t];
				case 0b001:
					reg[r] = reg[r] + read_word(cpu, reg[t]);
				case 0b010:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv + reg[t]);
				case 0b011:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv + read_word(cpu, reg[t]));
			}	
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
				case 0b100:
					reg[r] = reg[r] + i;
				case 0b101:
					reg[r] = reg[r] + read_word(cpu, i);
				case 0b110:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv + i);
				case 0b111:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv + read_word(cpu, i));
			}
		}
	case SUB:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch addr & 0b100 {
		case 0b000:
			t := (instr & T_MASK);

			switch addr {
				case 0b000:
					reg[r] = reg[r] - reg[t];
				case 0b001:
					reg[r] = reg[r] - read_word(cpu, reg[t]);
				case 0b010:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv - reg[t]);
				case 0b011:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv - read_word(cpu, reg[t]));
			}
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
				case 0b100:
					reg[r] = reg[r] - i;
				case 0b101:
					reg[r] = reg[r] - read_word(cpu, i);
				case 0b110:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv - i);
				case 0b111:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv - read_word(cpu, i));
			}
		}
	case INC:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch (addr & 0b100) >> 2 {
		case 0:
			switch addr {
			case 0b000:
				// register
				reg[r] += 1;
			case 0b001:
				panic("Invalid OPCODE");
			case 0b010:
				// memory offset
				v := read_word(cpu, reg[r]);
				v += 1;
				//TODO: Flags
				write_word(cpu, reg[r], v);
			case 0b011:
				panic("Invalid OPCODE");
			}
		case 1:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
			case 0b100:
				panic("Invalid OPCODE");
			case 0b101:
				panic("Invalid OPCODE");
			case 0b110:
				v := read_word(cpu, i);
				v += 1;
				write_word(cpu, i, v);
			case 0b111:
				panic("Invalid OPCODE");
			}
		}
	case DEC:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch (addr & 0b100) >> 2 {
		case 0:
			switch addr {
			case 0b000:
				// register
				reg[r] -= 1;
			case 0b001:
				panic("Invalid OPCODE");
			case 0b010:
				// memory offset
				v := read_word(cpu, reg[r]);
				v -= 1;
				//TODO: Flags
				write_word(cpu, reg[r], v);
			case 0b011:
				panic("Invalid OPCODE");
			}
		case 1:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
			case 0b100:
				panic("Invalid OPCODE");
			case 0b101:
				panic("Invalid OPCODE");
			case 0b110:
				v := read_word(cpu, i);
				v -= 1;
				write_word(cpu, i, v);
			case 0b111:
				panic("Invalid OPCODE");
			}
		}
	case AND:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch addr & 0b100 {
		case 0b000:
			t := (instr & T_MASK);

			switch addr {
				case 0b000:
					reg[r] = reg[r] & reg[t];
				case 0b001:
					reg[r] = reg[r] & read_word(cpu, reg[t]);
				case 0b010:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv & reg[t]);
				case 0b011:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv & read_word(cpu, reg[t]));
			}	
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
				case 0b100:
					reg[r] = reg[r] & i;
				case 0b101:
					reg[r] = reg[r] & read_word(cpu, i);
				case 0b110:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv & i);
				case 0b111:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv & read_word(cpu, i));
			}
		}
	case OR:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch addr & 0b100 {
		case 0b000:
			t := (instr & T_MASK);

			switch addr {
				case 0b000:
					reg[r] = reg[r] | reg[t];
				case 0b001:
					reg[r] = reg[r] | read_word(cpu, reg[t]);
				case 0b010:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv | reg[t]);
				case 0b011:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv | read_word(cpu, reg[t]));
			}	
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
				case 0b100:
					reg[r] = reg[r] | i;
				case 0b101:
					reg[r] = reg[r] | read_word(cpu, i);
				case 0b110:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv | i);
				case 0b111:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv | read_word(cpu, i));
			}
		}
	case XOR:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch addr & 0b100 {
		case 0b000:
			t := (instr & T_MASK);

			switch addr {
				case 0b000:
					reg[r] = reg[r] ~ reg[t];
				case 0b001:
					reg[r] = reg[r] ~ read_word(cpu, reg[t]);
				case 0b010:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv ~ reg[t]);
				case 0b011:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv ~ read_word(cpu, reg[t]));
			}	
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
				case 0b100:
					reg[r] = reg[r] ~ i;
				case 0b101:
					reg[r] = reg[r] ~ read_word(cpu, i);
				case 0b110:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv ~ i);
				case 0b111:
					rv := read_word(cpu, reg[r]);
					write_word(cpu, reg[r], rv ~ read_word(cpu, i));
			}
		}
	case JMP:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch addr & 0b100 {
		case 0b000:
			switch addr {
			case 0b000:
				// r
				pc = reg[r];
			case 0b010:
				// (r)
				pc = read_word(cpu, reg[r]);
			case 0b001, 0b011:
				panic("Illegal opcode");	
			}
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
			case 0b100:
				// imm
				pc = i;
			case 0b110:
				// (imm)
				pc = read_word(cpu, i);
			case 0b101, 0b111:
				panic("Illegal opcode");
			}
		}
	case JSR:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		switch addr & 0b100 {
		case 0b000:
			switch addr {
			case 0b000:
				// r
				//pc = reg[r];
				push_register(cpu, REG_PC);
				pc = read_register(cpu, r);
			case 0b010:
				// (r)
				//pc = read_word(cpu, reg[r]);
				push_register(cpu, REG_PC);
				pc = read_word(cpu, read_register(cpu, r));
			case 0b001, 0b011:
				panic("Illegal opcode");	
			}
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
			case 0b100:
				// imm
				push_register(cpu, REG_PC);
				pc = i;
			case 0b110:
				// (imm)
				push_register(cpu, REG_PC);
				pc = read_word(cpu, i);
			case 0b101, 0b111:
				panic("Illegal opcode");
			}
		}
	case RET:
		pc = pop(cpu);
	case CMP:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;
		a, b: u16;

		switch addr & 0b100 {
		case 0b000:
			t := instr & T_MASK;

			switch addr {
			case 0b000:
				a = read_register(cpu, r);
				b = read_register(cpu, t);
			case 0b010:
				a = read_word(cpu, read_register(cpu, r));
				b = read_register(cpu, t);
			case 0b001:
				a = read_register(cpu, r);
				b = read_word(cpu, read_register(cpu, t));
			case 0b011:
				a = read_word(cpu, read_register(cpu, r));
				b = read_word(cpu, read_register(cpu, t));
			}
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
			case 0b100:
				a = read_register(cpu, r);
				b = i;
			case 0b110:
				a = read_word(cpu, read_register(cpu, r));
				b = i;
			case 0b101:
				a = read_register(cpu, r);
				b = read_word(cpu, i);
			case 0b111:
				a = read_word(cpu, read_register(cpu, r));
				b = read_word(cpu, i);
			}
		}

		cpu_sub(cpu, a, b, true);
	case JE:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		new_pc := u16(0);
		
		switch addr & 0b100 {
		case 0b000:
			switch addr {
			case 0b000:
				new_pc = read_register(cpu, r);
			case 0b010:
				new_pc = read_word(cpu, read_register(cpu, r));
			case 0b001, 0b011:
				panic("Illegal opcode");	
			}
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
			case 0b100:
				new_pc = i;
			case 0b110:
				new_pc = read_word(cpu, i);
			case 0b101, 0b111:
				panic("Illegal opcode");
			}
		}
		
		if reg[7] & FLAG_Z > 0 {
			pc = new_pc;
		}
	case JNE:
		addr := (instr & X_MASK) >> 8;
		r := (instr & R_MASK) >> 4;

		new_pc := u16(0);
		
		switch addr & 0b100 {
		case 0b000:
			switch addr {
			case 0b000:
				new_pc = read_register(cpu, r);
			case 0b010:
				new_pc = read_word(cpu, read_register(cpu, r));
			case 0b001, 0b011:
				panic("Illegal opcode");	
			}
		case 0b100:
			i := read_word(cpu, pc);
			pc += 2;

			switch addr {
			case 0b100:
				new_pc = i;
			case 0b110:
				new_pc = read_word(cpu, i);
			case 0b101, 0b111:
				panic("Illegal opcode");
			}
		}
		
		if !(reg[7] & FLAG_Z > 0) {
			pc = new_pc;
		}
	}
}

instr_rt :: proc(op: Opcode, addr: u16, r: u16, t: u16) -> u16 {
	return u16(op) << 11 | addr << 8 | r << 4 | t;
}

disassemble_instr :: proc(instr: u16, next_word: u16) {
	op   := (instr & OP_MASK) >> 11;
	addr := (instr &  X_MASK) >>  8;
	r    := (instr &  R_MASK) >>  4;

	opinfo := Opcodes[op];

	fmt.printf("%v ", Opcode(op));

	switch opinfo.operands {
	case 0:
		// do nothing
	case 1:
		switch addr & 0b100 {
		case 0b000:
			switch addr {
			case 0b000:
				print_reg(r);
			case 0b010:
				fmt.printf("(");
				print_reg(r);
				fmt.printf(")");
			case 0b001, 0b011:
				fmt.printf("INVALID");	
			}
		case 0b100:
			i := next_word;

			switch addr {
			case 0b100:
				fmt.printf("0x%X", i);
			case 0b110:
				fmt.printf("(0x%X)", i);
			case 0b101, 0b111:
				fmt.printf("INVALID");
			}
		}
	case 2:
		switch addr & 0b100 {
		case 0b000:
			t := (instr & T_MASK);

			switch addr {
				case 0b000:
					print_reg(r);
					fmt.printf(", ");
					print_reg(t);
				case 0b001:
					print_reg(r);
					fmt.printf(", (");
					print_reg(t);
					fmt.printf(")");
				case 0b010:
					fmt.printf("(");
					print_reg(r);
					fmt.printf(")");

					fmt.printf(", ");
					print_reg(t);
				case 0b011:
					fmt.printf("(");
					print_reg(r);
					fmt.printf(")");

					fmt.printf(", (");
					print_reg(t);
					fmt.printf(")");
			}	
		case 0b100:
			i := next_word;

			switch addr {
				case 0b100:
					print_reg(r);
					fmt.printf(", 0x%X", i);
				case 0b101:
					print_reg(r);
					fmt.printf(", (0x%X)", i);
				case 0b110:
					fmt.printf("(");
					print_reg(r);
					fmt.printf(")");

					fmt.printf(", 0x%X", i);
				case 0b111:
					fmt.printf("(");
					print_reg(r);
					fmt.printf(")");

					fmt.printf(", (0x%X)", i);
			}
		}
	case: panic("Opinfo is fucked");
	}

	

	fmt.printf("\n");
}

print_reg :: proc(r: u16) {
	if r < 8 {
		fmt.printf("r%d", r);
	} else {
		switch r {
		case REG_SP: fmt.printf("sp");
		case REG_PC: fmt.printf("pc");
		case: panic("unknown reg");				
		}
	}
}


main :: proc() {
	cpu: CPU;
	init_cpu(&cpu);

	write_word_offs :: proc(cpu: ^CPU, pos: ^u16, v: u16) {
		write_word(cpu, pos^, v);
		pos^ += 2;
	}

	using Opcode;
	offset := u16(0);
	// write_word_offs(&cpu, &offset, instr_rt(SUB, 0b100, REG_SP, 0)); // sub sp, 2
	// write_word_offs(&cpu, &offset, 2);

	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b100, 0, 0)); // mov r0, 0x40
	write_word_offs(&cpu, &offset, 0x40);
	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b100, 4, 0)); // mov r4, 0x41
	write_word_offs(&cpu, &offset, 0x40);
	write_word_offs(&cpu, &offset, instr_rt(CMP, 0b000, 0, 4)); // cmp r0, r4
	
	write_word_offs(&cpu, &offset, instr_rt(JNE, 0b100, 0, 0)); // je 0x100
	write_word_offs(&cpu, &offset, 0x100);

	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b100, 1, 0)); // mov r1, 0x0010
	write_word_offs(&cpu, &offset, 0x0010);

	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b000, 0, 1)); // mov r0, r1

	write_word_offs(&cpu, &offset, instr_rt(ADD, 0b000, 0, 1)); // add r0, r1

	write_word_offs(&cpu, &offset, instr_rt(ADD, 0b100, 0, 1)); // add r0, 1
	write_word_offs(&cpu, &offset, 0x0001);

	write_word_offs(&cpu, &offset, instr_rt(ADD, 0b101, 4, 0)); // add r4, (2)
	write_word_offs(&cpu, &offset, 2);

	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b101, 5, 0)); // mov r5, (2)
	write_word_offs(&cpu, &offset, 2);

	write_word_offs(&cpu, &offset, instr_rt(SUB, 0b100, 0, 0)); // sub r0, 1
	write_word_offs(&cpu, &offset, 0x0001);

	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 0, 0)); // inc r0

	write_word(&cpu, 126, 0x45);
	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b101, 6, 0)); // mov r6, (126)
	write_word_offs(&cpu, &offset, 126);
	write_word_offs(&cpu, &offset, instr_rt(INC, 0b110, 0, 0)); // inc (126)
	write_word_offs(&cpu, &offset, 126);
//	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b101, 7, 0)); // mov r7, (126)
//	write_word_offs(&cpu, &offset, 126);

	write_word_offs(&cpu, &offset, instr_rt(DEC, 0b000, 0, 0)); // dec r0

	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b100, 3, 0)); // mov r3, 0x1234
	write_word_offs(&cpu, &offset, 0x1234);
	write_word_offs(&cpu, &offset, instr_rt(AND, 0b100, 3, 0)); // and r3, 0x00FF
	write_word_offs(&cpu, &offset, 0xFF);

	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b100, REG_SP, 0)); // mov sp, 0xFF00
	write_word_offs(&cpu, &offset, 0xFF00);

	write_word_offs(&cpu, &offset, instr_rt(JSR, 0b100, 0, 0)); // jsr counter_loc
	counter_loc := offset;
	write_word_offs(&cpu, &offset, 0); // Stub

	write_word_offs(&cpu, &offset, instr_rt(JMP, 0b100, 0, 0)); // jmp 0
	write_word_offs(&cpu, &offset, 0);
	write_word_offs(&cpu, &offset, instr_rt(HLT, 0, 0, 0));


	// padding, becuase why not
	write_word_offs(&cpu, &offset, 0);
	write_word_offs(&cpu, &offset, 0);

	write_word(&cpu, counter_loc, offset); // Update jsr counter_loc instruction
	write_word_offs(&cpu, &offset, instr_rt(MOV, 0b100, 0, 0)); // mov, r0, 0
	write_word_offs(&cpu, &offset, 0);

	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 0, 0)); // inc r0
	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 1, 0)); // inc r1
	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 2, 0)); // inc r2
	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 3, 0)); // inc r3
	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 4, 0)); // inc r4
	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 5, 0)); // inc r5
	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 6, 0)); // inc r6
//	write_word_offs(&cpu, &offset, instr_rt(INC, 0b000, 7, 0)); // inc r7

	write_word_offs(&cpu, &offset, instr_rt(RET, 0b000, 0, 0)); // ret

	dump_memory(&cpu);
	dump_binary(&cpu, offset);

	disassemble :: proc(cpu: ^CPU, offset: u16, pc_offset: u16) {
		used_mem := cpu.mem[:offset];
		for pc := u16(0); int(pc) < len(used_mem); {
			if pc == pc_offset {
				fmt.printf("> %2X: ", pc);
			} else {
				fmt.printf("  %2X: ", pc);
			}

			instr := read_word(cpu, pc);
			pc += 2;

			op   := (instr & OP_MASK) >> 11;
			addr := (instr & X_MASK) >> 8;
			opinfo := Opcodes[op];

			if addr & 0b100 > 0 && opinfo.operands > 0 {
				i := read_word(cpu, pc);
				pc += 2;

				fmt.printf("%4X %4X - ", instr, i);
				disassemble_instr(instr, i);
			} else {
				fmt.printf("%4X      - ", instr);
				disassemble_instr(instr, 0);
			}
		}
	}

	// cpu.hlt = true;
	last_char := 's';
	running := false;

	for !cpu.hlt {
		fmt.printf("\e[2J");   // clear screen
		fmt.printf("\e[0;0H"); // set cursor pos

		fmt.printf("R0: %4X   R1: %4X\n", cpu.reg[0], cpu.reg[1]);
		fmt.printf("R2: %4X   R3: %4X\n", cpu.reg[2], cpu.reg[3]);
		fmt.printf("R4: %4X   R5: %4X\n", cpu.reg[4], cpu.reg[5]);
		fmt.printf("R6: %4X   R7: %4X\n", cpu.reg[6], cpu.reg[7]);

		fmt.printf("\n");
		fmt.printf("PC:  %4X   SP: %4X\n", cpu.pc, cpu.sp);
		fmt.printf("FLAGS: ....SHZC\n");
		s := cpu.reg[7] & FLAG_S > 0 ? 1 : 0;
		h := cpu.reg[7] & FLAG_H > 0 ? 1 : 0;
		c := cpu.reg[7] & FLAG_C > 0 ? 1 : 0;
		z := cpu.reg[7] & FLAG_Z > 0 ? 1 : 0;
		fmt.printf("           %d%d%d%d\n", s, h, z, c);
		
		fmt.printf("-------------------\n\n");
		disassemble(&cpu, offset, cpu.pc);
		fmt.printf("\n");

		if last_char == 's' do fmt.printf("(s)");
		fmt.printf(": ");

		if !running {
			ch := rune(getchar());
			switch ch {
			case 10, 13:
				if last_char == 's' {
					cpu_step(&cpu);
					ch = 's';
				}
			case 's':
				cpu_step(&cpu);
			case 'd':
				dump_memory(&cpu);
			case 'q':
				os.exit(0);
			case 'r':
				running = true;
			case: // do nothing
			}
			last_char = ch;
		} else {
			time.sleep(time.Millisecond*100);
			cpu_step(&cpu);
		}

	}
}

dump_memory :: proc(using cpu: ^CPU) {
	out_buffer := make([]u8, len(cpu.mem));
	defer delete(out_buffer);

	for i in 0..len(cpu.mem)-1 {
		out_buffer[i] = u8(cpu.mem[i] & 0xFF);
	}
	os.write_entire_file("dump.bin", out_buffer);
}

dump_binary :: proc(using cpu: ^CPU, offset: u16) {
	out_buffer := make([]u8, offset);
	defer delete(out_buffer);

	for i in 0..<offset {
		out_buffer[i] = u8(cpu.mem[i] & 0xFF);
	}
	os.write_entire_file("prog.bin", out_buffer);
}