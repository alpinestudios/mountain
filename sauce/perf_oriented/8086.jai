#import "Basic";
#import "File";

// https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf

OP_CODE_MASK :: 0b11111100;
D_MASK :: 0b00000010;
W_MASK :: 0b00000001;
MOD_MASK :: 0b11000000;
REG_MASK :: 0b00111000;
RM_MASK :: 0b00000111;

// instructions
MOV :: 0b10001000;

get_register :: (register : u8, wide : bool) -> string
{
	if register ==
	{
		case 0b000;
		return ifx wide then "ax" else "al";
		case 0b001;
		return ifx wide then "cx" else "cl";
		case 0b010;
		return ifx wide then "dx" else "dl";
		case 0b011;
		return ifx wide then "bx" else "bl";
		case 0b100;
		return ifx wide then "sp" else "ah";
		case 0b101;
		return ifx wide then "bp" else "ch";
		case 0b110;
		return ifx wide then "si" else "dh";
		case 0b111;
		return ifx wide then "di" else "bh";

		case;
		return "!REG";
	}
}

get_instruction :: (op_code : u8) -> string
{
	if op_code ==
	{
		case 0b10001000;
		return "mov";

		case;
		return "!OP";
	}
}

main :: ()
{
	args := get_command_line_arguments();
	path := args[1];
	data, success := read_entire_file(path);
	assert(success);

	print_binary(data.data, data.count);

	builder : String_Builder;
	print_to_builder(*builder, "bits 16\n\n");

	byte : *u8 = data.data;
	while true
	{
		op_code := <<byte & OP_CODE_MASK;
		instruction := get_instruction(op_code);
		print_to_builder(*builder, "% ", instruction);
		if instruction ==
		{
			case "mov";
			dir := <<byte & D_MASK;
			wide : bool = xx <<byte & W_MASK;

			byte += 1;

			reg := <<byte & REG_MASK;
			reg = reg >> 3;
			reg_field := get_register(reg, wide);

			mod := (<<byte & MOD_MASK) >> 6;
			rm := <<byte & RM_MASK;

			if mod ==
			{
				case 0b00; // memory mode
				rm_field : string;
				if rm ==
				{
					case 0b000;
					rm_field = "bx + si";
					case 0b001;
					rm_field = "bx + di";
					case 0b010;
					rm_field = "bp + si";
					case 0b011;
					rm_field = "bp + di";
					case 0b100;
					rm_field = "si";
					case 0b101;
					rm_field = "di";
					case 0b110;
					rm_field = "DIR ADDRESS";
					case 0b111;
					rm_field = "bx";
				}

				print_to_builder(*builder, "%, ", ifx dir then reg_field else rm_field);
				print_to_builder(*builder, "%\n", ifx dir then rm_field else reg_field);

				case 0b01; // memory mode, 8bit disp
				// todo

				case 0b10; // memory mode, 16bit disp

				case 0b11; // register mode
				print_to_builder(*builder, "%, ", get_register(ifx dir then reg else rm, wide));
				print_to_builder(*builder, "%\n", get_register(ifx dir then rm else reg, wide));
			}

			case;
			print_to_builder(*builder, "\n");
		}

		byte += 1;
		if byte >= *data.data[data.count] then break;
	}
	
	//file_name := sprint("%.asm", path);
	//write_entire_file(file_name, *builder, do_reset=false);

	contents := builder_to_string(*builder);
	print("%", contents);
}

print_binary :: (a : u8, append : string = "\n")
{
	print("% ", formatInt(a, base=2, minimum_digits=8));
	print(append);
}

print_binary :: (a : *void, length : int, append : string = "\n")
{
	b := cast(*u8) a;
	for 0..length-1
	{
		print("% ", formatInt(b[it], base=2, minimum_digits=8));
	}
	print(append);
}