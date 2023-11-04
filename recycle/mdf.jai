/* 
* MDF Parser
* Author: Filip Homolka / @fhomolka
* License: zlib
*
* Clean-room implementation of Mars Data Format
*
* Original spec by Nick London
* https://wiki.ironworksgames.com/doku.php?id=mdf_file_format
*
* Basic Usage:
* Get a  *Document with
* doc, ok := load_from_file("name_of_your_mdf_file.mdf")
* When you're done using it, just call
* destroy(doc)
*
* TODO:
* - Writing
*
*/


TokenType :: enum
{
	NONE;
	LABEL;
	VALUE;
	CHUNK_OPEN;
	CHUNK_CLOSE;
	ARRAY_OPEN;
	ARRAY_CLOSE;

	EQUALS;
}

Token :: struct
{
	type: TokenType;
	value: string;
	line: u32;
}

MDFError :: enum #specified
{
	NONE :: 0;
	COULD_NOT_READ :: 1;
	INVALID :: 2;
	FAIL :: 3;
}

ElementType :: enum
{
	CHUNK;
	ARRAY;
	VALUE;
}

Element :: struct
{
	name: string;
	type: ElementType;
	chunk_props: *Table(string, Element);
	#place chunk_props; arr_props: [..]Element;
	#place chunk_props; val: string;
}

Document :: struct
{
	tokens: [..]Token;
	elements: [..]Element;
}

process_array :: (array: *Element, slice: []Token)
{
	if slice.count < 1
	{
		return;
	}

	if slice[0].type != .VALUE &&
	   slice[0].type != .CHUNK_OPEN &&
	   slice[0].type != .ARRAY_OPEN &&
	   slice[0].type != .LABEL
	{
		return;
	}

	for * slice
	{
		if it.type ==
		{
			case .LABEL;
			{
				if slice[it_index + 1].type != .EQUALS
				{
					print("Line % : Found label %, but it has no assignment\n", slice[it_index].line, slice[it_index].value);
					return;
				}

				if slice[it_index + 2].type != .VALUE &&
				   slice[it_index + 2].type != .CHUNK_OPEN &&
				   slice[it_index + 2].type != .ARRAY_OPEN
				{
				
					print("Line % : Attempting to store invalid data into field %\n", slice[it_index].line, slice[it_index].value);
					return;
				}

				e_it_index := it_index + 2;

				if slice[e_it_index].type ==
				{
					case .VALUE;
					{
						new_val: Element;
						new_val.name = slice[it_index].value;
						new_val.val = slice[e_it_index].value;
						new_val.type = .VALUE;
						array_add(*array.arr_props, new_val);
						it_index = e_it_index;
					}
					case .CHUNK_OPEN;
					{
						nesting := 1;
						closing_index := e_it_index + 1;
						for n : e_it_index + 1..slice.count - 1
						{
							if slice[n].type == .CHUNK_OPEN
							{
								nesting += 1;
							}

							if slice[n].type == .CHUNK_CLOSE
							{
								nesting -= 1;
							}

							if nesting < 1
							{
								closing_index = n;
								break;
							}
						}

						new_chunk: Element;
						new_chunk.name = slice[it_index].value;
						new_chunk.type = .CHUNK;
						sub_slice: []Token = slice;
						sub_slice.data += e_it_index + 1;
						sub_slice.count = closing_index - e_it_index - 1;
						new_chunk.chunk_props = New(Table(string, Element));
						init(new_chunk.chunk_props);
						process_chunk(*new_chunk, sub_slice);
						array_add(*array.arr_props, new_chunk);
						it_index = closing_index;
					}
					case .ARRAY_OPEN;
					{
						nesting := 1;
						closing_index := e_it_index + 1;
						for n : e_it_index + 1..slice.count - 1
						{
							if slice[n].type == .ARRAY_OPEN
							{
								nesting += 1;
							}

							if slice[n].type == .ARRAY_CLOSE
							{
								nesting -= 1;
							}

							if nesting < 1
							{
								closing_index = n;
								break;
							}
						}
						new_array: Element;
						new_array.name = slice[it_index].value;
						new_array.type = .ARRAY;

						sub_slice: []Token = slice;
						sub_slice.data += e_it_index + 1;
						sub_slice.count = closing_index - e_it_index - 1;
						process_array(*new_array, sub_slice);
						array_add(*array.arr_props, new_array);
						it_index = closing_index;
					}
				}
			}
			case .VALUE; //Anon value
			{
				new_val: Element;
				new_val.val = it.value;
				new_val.type = .VALUE;
				array_add(*array.arr_props, new_val);
			}
			case .CHUNK_OPEN; //Anon Chunk
			{
				nesting := 1;
				closing_index := it_index + 1;
				for n : it_index + 1..slice.count - 1
				{
					if slice[n].type == .CHUNK_OPEN
					{
						nesting += 1;
					}

					if slice[n].type == .CHUNK_CLOSE
					{
						nesting -= 1;
					}

					if nesting < 1
					{
						closing_index = n;
						break;
					}
				}

				new_chunk: Element;
				new_chunk.type = .CHUNK;
				sub_slice: []Token = slice;
				sub_slice.data += it_index + 1;
				sub_slice.count = closing_index - it_index - 1;
				new_chunk.chunk_props = New(Table(string, Element));
				init(new_chunk.chunk_props);
				process_chunk(*new_chunk, sub_slice);
				array_add(*array.arr_props, new_chunk);
				it_index = closing_index;
			}
			case .ARRAY_OPEN; //Anon Array
			{
				nesting := 1;
				closing_index := it_index + 1;
				for n : it_index + 1..slice.count - 1
				{
					if slice[n].type == .ARRAY_OPEN
					{
						nesting += 1;
					}

					if slice[n].type == .ARRAY_CLOSE
					{
						nesting -= 1;
					}

					if nesting < 1
					{
						closing_index = n;
						break;
					}
				}
				new_array: Element;
				new_array.type = .ARRAY;
				sub_slice: []Token = slice;
				sub_slice.data += it_index + 1;
				sub_slice.count = closing_index - it_index - 1;
				process_array(*new_array, sub_slice);
				array_add(*array.arr_props, new_array);
				it_index = closing_index;
			}
		}
	}
}

process_chunk :: (chunk: *Element, slice: []Token)
{
	for * slice
	{
		if it.type ==
		{
			case .LABEL;
			{
				if slice[it_index + 1].type != .EQUALS
				{
					print("Line % : Found label %, but it has no assignment\n", slice[it_index].line, slice[it_index].value);
					return;
				}

				if slice[it_index + 2].type != .VALUE &&
				   slice[it_index + 2].type != .CHUNK_OPEN &&
				   slice[it_index + 2].type != .ARRAY_OPEN
				{
					print("Line % : Attempting to store invalid data into field %\n", slice[it_index].line, slice[it_index].value);
					return;
				}

				e_it_index := it_index + 2;

				if slice[e_it_index].type ==
				{
					case .VALUE;
					{
						new_val: Element;
						new_val.type = .VALUE;
						new_val.name = slice[it_index].value;
						new_val.val = slice[e_it_index].value;
						table_add(chunk.chunk_props, new_val.name, new_val);
					}
					case .ARRAY_OPEN;
					{
						nesting := 1;
						closing_index := e_it_index + 1;
						for n : e_it_index + 1..slice.count - 1
						{
							if slice[n].type == .ARRAY_OPEN
							{
								nesting += 1;
							}

							if slice[n].type == .ARRAY_CLOSE
							{
								nesting -= 1;
							}

							if nesting < 1
							{
								closing_index = n;
								break;
							}
						}
						new_array: Element;
						new_array.name = slice[it_index].value;
						new_array.type = .ARRAY;

						sub_slice: []Token = slice;
						sub_slice.data += e_it_index + 1;
						sub_slice.count = closing_index - e_it_index - 1;
						process_array(*new_array, sub_slice);
						table_add(chunk.chunk_props, new_array.name,new_array);
						it_index = closing_index;
					}
					case .CHUNK_OPEN;
					{
						nesting := 1;
						closing_index := e_it_index + 1;
						for n : e_it_index + 1..slice.count - 1
						{
							if slice[n].type == .CHUNK_OPEN
							{
								nesting += 1;
							}

							if slice[n].type == .CHUNK_CLOSE
							{
								nesting -= 1;
							}

							if nesting < 1
							{
								closing_index = n;
								break;
							}
						}

						new_chunk: Element;
						new_chunk.name = slice[it_index].value;
						new_chunk.type = .CHUNK;
						sub_slice: []Token = slice;
						sub_slice.data += e_it_index + 1;
						sub_slice.count = closing_index - e_it_index - 1;
						new_chunk.chunk_props = New(Table(string, Element));
						init(new_chunk.chunk_props);
						process_chunk(*new_chunk, sub_slice);
						table_add(chunk.chunk_props, new_chunk.name , new_chunk);
						it_index = closing_index;
					}
				}
			}
			case;
		}
	}
}

parse_string :: (data: string) -> *Document, MDFError
{
	doc := New(Document);
	line_num: u32 = 1;

	while true
	{
		defer line_num += 1;
		line, found := consume_next_line(*data);
		if !found break;

		trimmed_line := trim_left(line);
		toks := split(trimmed_line, " ");

		for tok : toks
		{
			token: Token;
			token.value = tok;
			token.line = line_num;

			if tok ==
			{
				case "{";
					token.type = .CHUNK_OPEN;
				case "}";
					token.type = .CHUNK_CLOSE;
				case "[";
					token.type = .ARRAY_OPEN;
				case "]";
					token.type = .ARRAY_CLOSE;
				case "=";
					token.type = .EQUALS;
				case "";
					continue;
				case "\"\"";
				{
					token.type = .VALUE;
				}
				case;
				{
					if contains(tok, "\"")
					{
						token.type = .VALUE;

						if tok.count > 1 && tok[1] == #char "\""
						{
							break;
						}

						op := find_index_from_left(trimmed_line, "\"");
						cl := find_index_from_right(trimmed_line, "\"");

						token.value = slice(trimmed_line, op + 1, cl - op - 1);
						array_add(*doc.tokens, token);
						break;
					}

					token.type = .LABEL;
				}
			}
			array_add(*doc.tokens, token);
		}
	}


	for * doc.tokens
	{
		if it.type ==
		{
			case .LABEL;
			{
				if doc.tokens[it_index + 1].type != .EQUALS
				{
					print("Line % : Found label %, but it has no assignment\n", doc.tokens[it_index].line, doc.tokens[it_index].value);
					return doc, .INVALID;
				}

				if doc.tokens[it_index + 2].type != .VALUE &&
				   doc.tokens[it_index + 2].type != .CHUNK_OPEN &&
				   doc.tokens[it_index + 2].type != .ARRAY_OPEN
				{
					print("Line % : Attempting to store invalid data into field %\n", doc.tokens[it_index].line, doc.tokens[it_index].value);
					return doc, .INVALID;
				}

				e_it_index := it_index + 2;

				if doc.tokens[e_it_index].type ==
				{
					case .VALUE;
					{
						new_val: Element;
						new_val.name = doc.tokens[it_index].value;
						new_val.val = doc.tokens[e_it_index].value;
						new_val.type = .VALUE;

						array_add(*doc.elements, new_val);
						it_index = e_it_index;
					}
					case .CHUNK_OPEN;
					{
						nesting := 1;
						closing_index := e_it_index + 1;
						for n : e_it_index + 1..doc.tokens.count
						{
							if doc.tokens[n].type == .CHUNK_OPEN
							{
								nesting += 1;
							}

							if doc.tokens[n].type == .CHUNK_CLOSE
							{
								nesting -= 1;
							}

							if nesting < 1
							{
								closing_index = n;
								break;
							}
						}

						new_chunk: Element;
						new_chunk.name = doc.tokens[it_index].value;
						new_chunk.type = .CHUNK;
						slice: []Token = doc.tokens;
						slice.data += e_it_index + 1;
						slice.count = closing_index - e_it_index - 1;
						new_chunk.chunk_props = New(Table(string, Element));
						init(new_chunk.chunk_props);
						process_chunk(*new_chunk, slice);
						array_add(*doc.elements, new_chunk);
						it_index = closing_index;
					}
					case .ARRAY_OPEN;
					{
						nesting := 1;
						closing_index := e_it_index + 1;
						for n : e_it_index + 1..doc.tokens.count
						{
							if doc.tokens[n].type == .ARRAY_OPEN
							{
								nesting += 1;
							}

							if doc.tokens[n].type == .ARRAY_CLOSE
							{
								nesting -= 1;
							}

							if nesting < 1
							{
								closing_index = n;
								break;
							}
						}
						new_array: Element;
						new_array.name = doc.tokens[it_index].value;
						new_array.type = .ARRAY;

						array_add(*doc.elements, new_array);
						it_index = closing_index;
					}
				}
			}
		}	
	}

	return doc, .NONE;
}

load_from_file :: (filename: string) -> *Document, MDFError
{
	context.allocator = Allocator.{__default_allocator_proc, null};
	data, ok := read_entire_file(filename);
	if !ok then return null, .COULD_NOT_READ;
	doc, err := parse_string(data);
	return doc, err;
}

destroy_element :: (element: *Element)
{
	if element.type == 
	{
		case .VALUE;
		{}
		case .ARRAY;
		{
			for * element.arr_props
			{
				destroy_element(it);
			}
			array_free(element.arr_props);
		}
		case .CHUNK;
		{
			for value, key : <<element.chunk_props
			{
				destroy_element(*value);
			}
			table_reset(element.chunk_props);
			deinit(element.chunk_props);
		}
	}
}

destroy :: (doc: *Document)
{
	context.allocator = Allocator.{__default_allocator_proc, null};
	if doc == null then return;
	for * doc.elements
	{
		destroy_element(it);
	}
	array_free(doc.elements);

	if doc.tokens.count > 0
	{
		free(doc.tokens[0].value);	
	}
	array_free(doc.tokens);

	free(doc);
}

#scope_module
#import "Basic";
#import "Hash_Table";
#import "File";
#import "String";
#import "Text_File_Handler"; //consume_next_line
