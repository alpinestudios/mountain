md_parse_file :: (path: string) -> MD_ParseResult #expand
{
	arena := MD_ArenaAlloc();
	`defer MD_ArenaRelease(arena);
	
	parse := MD_ParseWholeFile(arena, md_string(path));
	next := parse.errors.first;
	while next
	{
		defer next = next.next;
		msg := MD_FormatMessage(arena, MD_CodeLocFromNode(next.node), next.kind, next.str);
		log(md_string(msg));
	}
	assert(parse.errors.max_message_kind < MD_MessageKind.Warning, tprint("Failed to parse %", path));
	return parse;
}

is_nil :: (node: *MD_Node) -> bool
{
	return MD_NodeIsNil(node);
}

md_string :: (str: string) -> MD_String8
{
	return .{str.data, xx str.count};
}
md_string :: (str: MD_String8) -> string
{
	result: string = ---;
 result.count = xx str.size;
 result.data  = str.str;
	return result;
}

// for_expansion :: (node: *MD_Node, body: Code, flags: For_Flags) #expand
// {
// 	#assert(!(flags & .REVERSE));
// 	index: int;
// 	next := node;
// 	while !MD_NodeIsNil(next)
// 	{
// 		next_cached := next.next;
// 		defer next = next_cached;
// 		defer index += 1;
		
// 		`it := next;
// 		`it_index := index;
		
// 		#insert body;
// 	}
// }

// for_expansion :: (list: *MD_MessageList, body: Code, flags: For_Flags) #expand
// {
// 	#assert(!(flags & .REVERSE));
// 	index: int;
// 	next := list.first;
// 	while next
// 	{
// 		next_cached := next.next;
// 		defer next = next_cached;
// 		defer index += 1;
		
// 		`it := next;
// 		`it_index := index;
		
// 		#insert body;
// 	}
// }

md_find_all_nodes_with_tag :: (root: *MD_Node, tag: string, container: *[..]*MD_Node)
{
	if MD_NodeHasTag(root, md_string(tag), 0) then array_add(container, root);
	next := root.first_child;
	while !MD_NodeIsNil(next)
	{
		defer next = next.next;
		md_find_all_nodes_with_tag(next, tag, container);
	}
}
md_find_all_nodes_with_tag :: (root: *MD_Node, tag: string) -> [..]*MD_Node
{
	container : [..]*MD_Node;
	container.allocator = temp;
	md_find_all_nodes_with_tag(root, tag, *container);
	return container;
}

md_find_node_with_string :: (node: *MD_Node, str: string, assert_existence := false) -> *MD_Node
{
	if md_string(node.str) == str then return node;
	next := node.first_child;
	while !MD_NodeIsNil(next)
	{
		defer next = next.next;
		found_child := md_find_node_with_string(next, str);
		if !MD_NodeIsNil(found_child) then return found_child;
	}
	assert(!assert_existence, tprint("Failed to find node %", str));
	return MD_NilNode();
}

md_has_key :: (root_node: *MD_Node, key: string) -> bool
{
	return !MD_NodeIsNil(md_find_node_with_string(root_node, key));
}

md_u64_from_key :: (root_node: *MD_Node, key: string, assert_existence := false) -> u64
{
	value := md_find_node_with_string(root_node, key);
	if assert_existence && MD_NodeIsNil(value) then assert(false, tprint("Node % not found", key));
	
	if !MD_NodeIsNil(value) then assert(MD_ChildCountFromNode(value) == 1, tprint("Node % is not a u64", key));
	return MD_U64FromString(value.first_child.str, 10);
}

md_float_from_key :: (root_node: *MD_Node, key: string, assert_existence := false) -> float
{
	value := md_find_node_with_string(root_node, key, assert_existence);
	
	element_count: int;
	element: float;
	node := value.first_child;
	while !MD_NodeIsNil(node)
	{
		defer node = node.next;
		is_numeric: bool = xx (node.flags & .Numeric);
		if is_numeric then element_count += 1;
		if element_count > 1 then continue;
		
		if is_numeric
		{
			element = xx MD_F64FromString(node.str) * sign_from_bit(element);
		}
		else
		{
			element *= -1; // this gives the float a sign bit
		}
	}
	if !MD_NodeIsNil(value) then assert(element_count == 1, tprint("Node % doesn't have 1 element", key));
	return element;
}

md_vector2_from_key :: (root_node: *MD_Node, key: string, assert_existence := false) -> Vector2
{
	value := md_find_node_with_string(root_node, key);
	if assert_existence && MD_NodeIsNil(value) then assert(false, tprint("Node % not found", key));
	
	EXPECTED_COUNT :: 2;
	element_count: int;
	elements: [EXPECTED_COUNT]float;
	node := value.first_child;
	while !MD_NodeIsNil(node)
	{
		defer node = node.next;
		is_numeric: bool = xx (node.flags & .Numeric);
		if is_numeric then element_count += 1;
		if element_count > EXPECTED_COUNT then continue;
		
		if is_numeric
		{
			elements[element_count-1] = xx MD_F64FromString(node.str) * sign_from_bit(elements[element_count-1]);
		}
		else
		{
			elements[element_count] *= -1; // this gives the float a sign bit
		}
	}
	if !MD_NodeIsNil(value) then assert(element_count == EXPECTED_COUNT, tprint("Node % doesn't have 2 elements", key));
	return .{elements[0], elements[1]};
}

md_col_from_key :: (root_node: *MD_Node, key: string, assert_existence := false) -> Vector4
{
	value := md_find_node_with_string(root_node, key);
	if assert_existence && MD_NodeIsNil(value) then assert(false, tprint("Node % not found", key));
	if !MD_NodeIsNil(value) then assert(MD_ChildCountFromNode(value) == 1, tprint("Node % is not hex", key));
	
	hex := MD_CStyleIntFromString(value.first_child.str);
	return hex_to_rgba(hex);
}

md_string_from_key :: (root_node: *MD_Node, key: string, assert_existence := false) -> string
{
	value := md_find_node_with_string(root_node, key);
	if assert_existence && MD_NodeIsNil(value) then assert(false, tprint("Node % not found", key));
	if !MD_NodeIsNil(value) then assert(MD_ChildCountFromNode(value) == 1, tprint("% has more than 1 child. Can't read string", key));
	return md_string(value.first_child.str);
}


md_transform_from_node :: (node: *MD_Node, assert_existence := false) -> Transform2
{
	if assert_existence then assert(md_string(node.str) == "trs");
	vec := md_vector2_from_key(node, "v2");
	rot := md_float_from_key(node, "f");
	trs := make_transform(vec, rot);
	return trs;
}