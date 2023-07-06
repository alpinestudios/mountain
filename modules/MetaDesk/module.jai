//
// Jai Bindings for MetaDesk.
// Not all bindings have been created, copy across new ones as needed
//

/*
// this was used to generate the libs
#import "BuildCpp";
#import "Basic";
#run {
	print("Building dynamic library:\n");
	build_cpp_dynamic_lib("md", "md.c");

	print("Building static library:\n");
	build_cpp_static_lib("md", "md.c");

	//set_build_options_dc(.{do_output = false});
};
*/

//~ Arena

MD_ArenaAlloc :: () -> *MD_Arena #foreign metadesk;
MD_ArenaRelease :: (arena : *MD_Arena) #foreign metadesk;

// MD_FUNCTION void*        MD_ArenaPush(MD_Arena *arena, MD_u64 size);
// MD_FUNCTION void         MD_ArenaPutBack(MD_Arena *arena, MD_u64 size);
// MD_FUNCTION void         MD_ArenaSetAlign(MD_Arena *arena, MD_u64 boundary);
// MD_FUNCTION void         MD_ArenaPushAlign(MD_Arena *arena, MD_u64 boundary);
// MD_FUNCTION void         MD_ArenaClear(MD_Arena *arena);

//~ Numeric Strings

// MD_FUNCTION MD_b32     MD_StringIsU64(MD_String8 string, MD_u32 radix);
// MD_FUNCTION MD_b32     MD_StringIsCStyleInt(MD_String8 string);

MD_U64FromString :: (str : MD_String8, radix : u32) -> u64 #foreign metadesk;
MD_CStyleIntFromString :: (str : MD_String8) -> s64 #foreign metadesk;
MD_F64FromString :: (str : MD_String8) -> float64 #foreign metadesk;

// MD_FUNCTION MD_String8 MD_CStyleHexStringFromU64(MD_Arena *arena, MD_u64 x, MD_b32 caps);

//~ Parsing

// MD_FUNCTION MD_Token       MD_TokenFromString(MD_String8 string);
// MD_FUNCTION MD_u64         MD_LexAdvanceFromSkips(MD_String8 string, MD_TokenKind skip_kinds);
// MD_FUNCTION MD_ParseResult MD_ParseResultZero(void);
// MD_FUNCTION MD_ParseResult MD_ParseNodeSet(MD_Arena *arena, MD_String8 string, MD_u64 offset, MD_Node *parent,
//                                            MD_ParseSetRule rule);
// MD_FUNCTION MD_ParseResult MD_ParseOneNode(MD_Arena *arena, MD_String8 string, MD_u64 offset);
// MD_FUNCTION MD_ParseResult MD_ParseWholeString(MD_Arena *arena, MD_String8 filename, MD_String8 contents);
MD_ParseWholeFile :: (arena : *MD_Arena, filename : MD_String8) -> MD_ParseResult #foreign metadesk;

//~ Location Conversion

// MD_FUNCTION MD_CodeLoc MD_CodeLocFromFileOffset(MD_String8 filename, MD_u8 *base, MD_u64 offset);
MD_CodeLocFromNode :: (node: *MD_Node) -> MD_CodeLoc #foreign metadesk;

//~ Tree/List Building
MD_NodeIsNil :: (node : *MD_Node) -> bool #foreign metadesk;
// MD_FUNCTION MD_b32   MD_NodeIsNil(MD_Node *node);
MD_NilNode :: () -> *MD_Node #foreign metadesk;
// MD_FUNCTION MD_Node *MD_MakeNode(MD_Arena *arena, MD_NodeKind kind, MD_String8 string,
//                                  MD_String8 raw_string, MD_u64 offset);
// MD_FUNCTION void     MD_PushChild(MD_Node *parent, MD_Node *new_child);
// MD_FUNCTION void     MD_PushTag(MD_Node *node, MD_Node *tag);

// MD_FUNCTION MD_Node *MD_MakeList(MD_Arena *arena);
// MD_FUNCTION void     MD_ListConcatInPlace(MD_Node *list, MD_Node *to_push);
// MD_FUNCTION MD_Node *MD_PushNewReference(MD_Arena *arena, MD_Node *list, MD_Node *target);

//~ Introspection Helpers

// These calls are for getting info from nodes, and introspecting
// on trees that are returned to you by the parser.

MD_FirstNodeWithString :: (first : *MD_Node, string : MD_String8, flags : MD_MatchFlags) -> *MD_Node #foreign metadesk;
// MD_FUNCTION MD_Node *  MD_NodeAtIndex(MD_Node *first, int n);
// MD_FUNCTION MD_Node *  MD_FirstNodeWithFlags(MD_Node *first, MD_NodeFlags flags);
// MD_FUNCTION int        MD_IndexFromNode(MD_Node *node);
// MD_FUNCTION MD_Node *  MD_RootFromNode(MD_Node *node);
// MD_FUNCTION MD_Node *  MD_ChildFromString(MD_Node *node, MD_String8 child_string, MD_MatchFlags flags);
// MD_FUNCTION MD_Node *  MD_TagFromString(MD_Node *node, MD_String8 tag_string, MD_MatchFlags flags);
MD_ChildFromIndex :: (node: *MD_Node, n: int) -> *MD_Node #foreign metadesk;
// MD_FUNCTION MD_Node *  MD_TagFromIndex(MD_Node *node, int n);
// MD_FUNCTION MD_Node *  MD_TagArgFromIndex(MD_Node *node, MD_String8 tag_string, MD_MatchFlags flags, int n);
// MD_FUNCTION MD_Node *  MD_TagArgFromString(MD_Node *node, MD_String8 tag_string, MD_MatchFlags tag_str_flags, MD_String8 arg_string, MD_MatchFlags arg_str_flags);
// MD_FUNCTION MD_b32     MD_NodeHasChild(MD_Node *node, MD_String8 string, MD_MatchFlags flags);
MD_NodeHasTag :: (node: *MD_Node, str: MD_String8, flags: MD_MatchFlags) -> bool #foreign metadesk;
MD_ChildCountFromNode :: (node : *MD_Node) -> s64 #foreign metadesk;
// MD_FUNCTION MD_i64     MD_TagCountFromNode(MD_Node *node);
// MD_FUNCTION MD_Node *  MD_ResolveNodeFromReference(MD_Node *node);
// MD_FUNCTION MD_Node*   MD_NodeNextWithLimit(MD_Node *node, MD_Node *opl);

//~ Error/Warning Helpers

// MD_FUNCTION MD_String8 MD_StringFromMessageKind(MD_MessageKind kind);
MD_FormatMessage :: (arena: *MD_Arena, loc: MD_CodeLoc, kind: MD_MessageKind, str: MD_String8) -> MD_String8 #foreign metadesk;

metadesk :: #library "md";

MD_CodeLoc :: struct
{
	filename : MD_String8;
	line : u32;
	column : u32;
}

MD_MatchFlags :: enum
{
 MD_MatchFlag_FindLast :: (1<<0);
}
MD_StringMatchFlags :: enum
{
 MD_StringMatchFlag_CaseInsensitive  :: (1<<4);
 MD_StringMatchFlag_RightSideSloppy  :: (1<<5);
 MD_StringMatchFlag_SlashInsensitive :: (1<<6);
}
MD_NodeMatchFlags :: enum
{
	MD_NodeMatchFlag_Tags             :: (1<<16);
	MD_NodeMatchFlag_TagArguments     :: (1<<17);
	MD_NodeMatchFlag_NodeFlags        :: (1<<18);
}

MD_Arena :: struct
{
	prev : *MD_Arena;
	current : *MD_Arena;
	base_pos : u64;
 pos : u64;
 cmt : u64;
 cap : u64;
 align : u64;
}

MD_String8 :: struct
{
	str : *u8;
	size : u64;
}

MD_NodeKind :: enum
{
	// NOTE(rjf): @maintenance Must be kept in sync with MD_StringFromNodeKind.
	
	Nil;
	
	// NOTE(rjf): Generated by parser
	File;
	ErrorMarker;
	
	// NOTE(rjf): Parsed from user Metadesk code
	Main;
	Tag;
	
	// NOTE(rjf): User-created data structures
	List;
	Reference;
	
	COUNT;
}

MD_NodeFlags :: enum
{
	HasParenLeft               :: (1<<0);
	HasParenRight              :: (1<<1);
	HasBracketLeft             :: (1<<2);
	HasBracketRight            :: (1<<3);
	HasBraceLeft               :: (1<<4);
	HasBraceRight              :: (1<<5);
	
	MaskSetDelimiters          :: (0x3F<<0);
	
	IsBeforeSemicolon          :: (1<<6);
	IsAfterSemicolon           :: (1<<7);
	IsBeforeComma              :: (1<<8);
	IsAfterComma               :: (1<<9);
	
	MaskSeperators             :: (0xF<<6);
	
	StringSingleQuote       :: (1<<10);
	StringDoubleQuote       :: (1<<11);
	StringTick              :: (1<<12);
	StringTriplet           :: (1<<13);
	
	MaskStringDelimiters    :: (0xF<<10);
	
	Numeric                 :: (1<<14);
	Identifier              :: (1<<15);
	StringLiteral           :: (1<<16);
	Symbol                  :: (1<<17);
	
	MaskLabelKind           :: (0xF<<14);
}

MD_Node :: struct
{
	// Tree relationship data.
	next : *MD_Node;
	prev : *MD_Node;
	parent : *MD_Node;
	first_child : *MD_Node;
	last_child : *MD_Node;

	// Tag list.
	first_tag : *MD_Node;
	last_tag : *MD_Node;

	// Node info.
	kind : MD_NodeKind;
	flags : MD_NodeFlags;
	str : MD_String8;
	raw_string : MD_String8;

	// Source code location information.
	offset : u64;

	// Reference.
	ref_target : *MD_Node;

	// Comments.
	// @usage prev_comment/next_comment should be considered "hidden". Rely on
	// the functions MD_PrevCommentFromNode/MD_NextCommentFromNode to access
	// these. Directly access to these is likely to break in a future version.
	prev_comment : MD_String8;
	next_comment : MD_String8;
};

MD_ParseResult :: struct
{
	node : *MD_Node;
	string_advance : u64;
	errors : MD_MessageList;
}

MD_MessageKind :: enum
{
	Null;
	Note;
	Warning;
	Error;
	FatalError;
}

MD_Message :: struct
{
	next : *MD_Message;
	node : *MD_Node;
	kind : MD_MessageKind;
	str : MD_String8;
	user_ptr : *void;
}

MD_MessageList :: struct
{
	max_message_kind : MD_MessageKind;
	node_count : u64;
	first : *MD_Message;
	last : *MD_Message;
}