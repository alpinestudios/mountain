How to build:
=============

1) Compile first.jai
2) Copy the os (win/mac/linux) binary files (\*.dll/\*.so) into the same folder as first.exe

How to run:
===========

* Run local host via .cmd files

```
run 1 time:  chatroom_localhost_server.cmd <- Starts up a chatooom server listening for clients on the default port.
run N times: chatroom_localhost_client.cmd <- Starts up a chatroom client connecting to a local host on the default port.
```

*OR*

* Enter your own command line arguments for first.exe:
```
+------------------------------------------------------------+
|  //             <ip>        <port>                         |
|  -client server 192.168.0.1:12345                          |
|  -client server 192.168.0.1      // Defaults to port 27020 |
|                                                            |
|  // local host    <port>                                   |
|  -client loopback 12345                                    |
|  -client loopback                // Defaults to port 27020 |
|                                                            |
|  //      <port>                                            |
|  -server 12345                                             |
|  -server                         // Defaults to port 27020 |
+------------------------------------------------------------+
```