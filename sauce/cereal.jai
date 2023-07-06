//
// Very basic helpers for reading and writing binary.
// Dumps out the name + size of the variable to help catch mismatch bugs when reading back in.
// Ideally this is only done in debug mode.
// TODO:
// - option for bypassing in release
// - string / flat array support 
//

cereal_write :: (file : *File, src : $T, match_name : string)
{
 #assert T != string;

 // write debug name for matching when reading back in
 success := file_write(file, match_name);
 assert(success);

 // write debug size for type match
 size : int = size_of(T);
 success = file_write(file, *size, size_of(int));
 assert(success);

 // write actual data
 success = file_write(file, *src, size);
 assert(success);
}

cereal_read :: (file : *File, dest : *$T, match_name : string)
{
 #assert T != string;

 // ensure name matches
 in_name := tprint(match_name);
 memset(in_name.data, 0, in_name.count);
 success, bytes_read := file_read(file, in_name.data, in_name.count);
 assert(success && bytes_read == in_name.count);
 assert(in_name == match_name); // todo - proper assert msg

 // ensure size matches
 var_size : int = -1;
 success, bytes_read = file_read(file, *var_size, size_of(int));
 assert(success && bytes_read == size_of(int));
 assert(var_size == size_of(T));

 // read in actual data :)
 success, bytes_read = file_read(file, dest, var_size);
 assert(success && bytes_read == var_size);
}

// This is pretty lazy lol, but it does tidy up the caller a lot.
// wonder if there's a better way to do this than a code-gen macro?
/*
cereal_write :: (file : *File, var_name : string) #expand
{
 #insert -> string
 {
  return tprint("cereal_write(file, `%1, \"%1\");\n", var_name);
 }
}

cereal_read :: (file : *File, var_name : string) #expand
{
 #insert -> string
 {
  return tprint("cereal_read(file, *`%1, \"%1\");\n", var_name);
 }
}
*/