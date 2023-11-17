@echo off
pushd "proj/arcane/"
jai ../../build.jai -x64 -import_dir external - prof && arcane.exe
popd
