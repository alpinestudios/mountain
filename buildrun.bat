@echo off
pushd "proj/arcane/"
"../d3dshader/d3d_compiler.exe" res/shaders/shader.hlsl && jai ../../build.jai -x64 -import_dir external && arcane.exe
popd
