g++ -fPIC -shared -lcurl -Wl,-rpath=. -Wl,-whole-archive -L./linux -l:GameAnalytics.a -Wl,-no-whole-archive ga.cpp -o libga.so
