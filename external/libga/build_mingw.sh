g++ -fPIC -shared -lcurl -Wl,-rpath=. -Wl,-whole-archive -L./windows -l:GameAnalytics.lib -Wl,-no-whole-archive ga.cpp -o libga.so
