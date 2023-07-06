//
// LINKED LIST HELPERS
//

stack_push :: (first : *$T, node : T)
{
 element := <<first;
 <<first = node;
 node.next = element;
}

stack_pop :: (first : *$T)
{
 element := <<first;
 if element != null
 {
  <<first = element.next;
  element.next = null;
 }
}

dll_push_back :: (first : *T, last : *T, node : $T,
                  $next : string = "next", $prev : string = "prev", $nil : string = "null") #expand
{
 first_element := <<first;
 last_element := <<last;
 <<last = node;
 
str :: #string END_STRING
 if last_element != %3
 {
  last_element.%1 = node;
  node.%2 = last_element;
 }
 
 if first_element == %3
 {
  <<first = node;
 }
END_STRING;
 #insert #run tprint(str, next, prev, nil);
 
 // this is the default code, maybe we should provide it as a fast-path?
 // ehh then we've gotta maintain it in two places (bc I'm sure there'll be bugs that I fix in this lol)
 // I'm sure the #insert directive is fast enough not to really matter?
 /* 
 first_element := <<first;
 last_element := <<last;
 
 <<last = node;
 if last_element == null
 {
  last_element.next = node;
  node.prev = last_element;
 }
 
 if first_element == null then <<first = node;
 */
}

dll_remove :: (first : *T, last : *T, node : $T,
               $next : string = "next", $prev : string = "prev", $nil : string = "null")
{
 first_element := <<first;
 last_element := <<last;
 
str :: #string END_STRING
 if node == first_element
 {
  assert(node.%2 == %3);
  <<first = node.%1;
 }
 else
 {
  node.%2.%1 = node.%1; 
 }
 
 if node == last_element
 {
  assert(node.%1 == %3);
  <<last = node.%2;
 }
 else
 {
  node.%1.%2 = node.%2;
 }
 
 node.%1 = %3;
 node.%2 = %3;
END_STRING;
 #insert #run tprint(str, next, prev, nil);
}

// TODO - give this guy same #insert treatment
dll_push_front :: (first : *T, last : *T, node : $T)
{
 first_element := <<first;
 last_element := <<last;
 <<first = node;
 if first_element
 {
  first_element.prev = node;
  node.next = first_element;
 }
 
 if last_element == null then <<last = node;
}

print_dll :: (first : $T, last : T)
{
 get_id :: (node : T) -> string
 {
  return ifx node then tprint("%", node.id) else "null";
 }
 
 print_node :: (prefix : string, node : T)
 {
  print("%:% ", prefix, get_id(node));
  if node
  {
   print("-> n:% p:%", get_id(node.next), get_id(node.prev));
  }
  print("\n");
 }
 
 print_node("first", first);
 
 count := 0;
 next := first;
 while count < 20 && next
 {
  print_node(tprint("%_it", count), next);
  next = next.next;
 }  
 
 print_node("last", last);
 print("\n");
}



//
// GENERIC LINKED LIST
//

LinkedList :: struct(type : Type, allocator : Allocator)
{
	first : *type;
	last : *type;
	count : int;
	
	// we're just gonna assume that the type passed in has the right pointers?
	/*
	Node :: struct
	{
		next : *Node;
		using payload : type;
	}
	*/
}

for_expansion :: (list : LinkedList, body : Code, flags : For_Flags) #expand
{
	#assert(!(flags & .REVERSE));
	
	index : int;
	next := list.first;
	while next
	{
		next_cached := next.next;
		defer next = next_cached;
		defer index += 1;
		
		`it := next;
		`it_index := index;
		
		#insert body;
	}
}

reset :: (list : *LinkedList)
{
	list.first = null;
	list.last = null;
	list.count = 0;
}

push_front :: (list : *LinkedList) -> *list.type
{
	new_node : *list.Node = alloc(size_of(list.Node), list.allocator);
	old_first : *list.Node = list.first;
	list.first = new_node;
	new_node.next = old_first;
	
	if list.last == null then list.last = new_node;
	
	list.count += 1;
	return *new_node.payload;
}

push_back :: (list : *LinkedList) -> *list.type
{
	link : *list.type = alloc(size_of(list.type), list.allocator);
	old_last : *list.type = list.last;
	list.last = link;
	if old_last
	{
		old_last.next = link;
	}
	
	if list.first == null then list.first = link;
	
	list.count += 1;
	return link;
}