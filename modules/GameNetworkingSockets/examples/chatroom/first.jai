//
// A simple chatroom application using gns-jai
//

// Help message for when parameters fail to parse
cmd_line_prompt_help_message :: #string DONE
Please enter a valid command line argument:
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
DONE

#import "Basic";
#import "Random";
#import "String";

#load "../../module.jai"; // gns-jai
//#import "gns-jai";

// The chat window
#load "chat_window.jai";

DefaultPort :: 27020;
g_isServer : bool;
g_isClient : bool;
g_server : ServerData;
g_client : ClientData;
g_chat : ChatWindowData;

ClientData :: struct
{
    // Input Data
    endpoint : IPAddr;

    // GNS Working Data
    connection : NetConnection;

    // General
    is_quitting : bool;
}

ServerData :: struct
{
    // Input Data
    port : u16 = DefaultPort;
    
    // GNS Working Data
    listen_socket : ListenSocket;
    poll_group    : PollGroup;
    clients       : [..] Client;
    Client :: struct
    {
        connection : NetConnection;
        nickname   : string;
    }

    // General
    is_quitting : bool;    
}

InitializeClient :: (client : *ClientData) -> sucess: bool
{
    // Start connecting
    connectionAddr : [ IPAddr.MaxStringIPAddrSize ] s8;
    IPAddr.ToString(*client.endpoint, connectionAddr.data, connectionAddr.count, true);
    connectionAddrView := view_of_c_string(connectionAddr.data);
    print("Connecting to chat server at %\n", connectionAddrView);

    options : [1] ConfigValue;
    ConfigValue.SetPtr(*options[0], .Callback_ConnectionStatusChanged, xx ClientNetConnectionStatusChanged);

    client.connection = Sockets.ConnectByIPAddress(*client.endpoint, options.count, options.data);

    if client.connection == .Invalid 
    {
        print("Client: ConnectByIPAddress() failed!\n");
        return false;
    }

    return true;
}

UpdateClient :: (client : *ClientData, chat : *ChatWindowData)
{
    // Handle incomming messages
    while !client.is_quitting
    {
        incommingMessages : [8] *NetworkingMessage;
        numMsgs := Sockets.ReceiveMessagesOnConnection(client.connection, incommingMessages.data, incommingMessages.count);

        // Finished processing received messages
        if numMsgs == 0 
            break;

        if (numMsgs < 0)
        {
            print("UpdateClient() Fatal error when receiving messages\n");
            client.is_quitting = true;
            return;
        }

        assert(numMsgs <= incommingMessages.count, "Invalid number of messages recieved\n");

        // Handle messages
        for 0..numMsgs-1
        {   
            message : *NetworkingMessage = incommingMessages[it];
            // Release at the end of the scope.
            defer NetworkingMessage.Release(message);

            // Stringview into the message buffer
            message_view : string;
            message_view.data  = message.m_pData;
            message_view.count = message.m_cbSize;

            // Empty message. Don't care.
            if message_view.count == 0
            {
                continue;
            }

            newChatLine := sprint("%", message_view);
            array_add(*chat.chat_history, newChatLine);

            // Print Message to console
            print("%\n", message_view);
        }
    }

    // Handle chat input if needed
    while chat.enter_field_should_flush
    {
        chat.enter_field_should_flush = false;
        defer array_reset_keeping_memory(*chat.enter_field_text);


        enter_field : string;
        enter_field.data = chat.enter_field_text.data;
        enter_field.count = chat.enter_field_text.count;

        // Empty string, do nothing
        if enter_field.count == 0
            break;

        // Not all commands get sent to the server
        isCommand := enter_field[0] == #char"/";
        if isCommand
        {
            cmd, args := splitInTwo(enter_field, #char" ");

            // shutdown client
            if cmd == "/quit" ||
               cmd == "/exit" || 
               cmd == "/leave"||
               cmd == "/close"
            {
                client.is_quitting = true;
                break;
            }
        }

        // Message isn't a command. Just plane text.
        Sockets.SendStringToConnection(client.connection, enter_field, .Reliable, null);
    }
    
    // Do socket callbacks
    Sockets.RunCallbacks();
}

FinalizeClient :: (client : *ClientData)
{
    {
        // Close the connection.  We use "linger mode" to ask SteamNetworkingSockets
        // to flush this out and close gracefully.
        Sockets.CloseConnection(client.connection, 0, "Server Shutdown", true);
    }
}

ClientNetConnectionStatusChanged :: (pInfo : *ConnectionStatusChanged) -> void #c_call
{
    newConext : Context;
    push_context newConext
    {
        ClientNetConnectionStatusChanged(*g_client, pInfo);
    }
}

ClientNetConnectionStatusChanged :: (client : *ClientData, pInfo : *ConnectionStatusChanged)
{
    assert(pInfo.m_conn == client.connection || client.connection == .Invalid);

    // What's the state of the connection?
    if pInfo.m_info.m_eState ==
    {
        case .None;
            // NOTE; We will get callbacks here when we destroy connections.  You can ignore these.

        case .ClosedByPeer; #through;
        case .ProblemDetectedLocally;
        {
            client.is_quitting = true;

            // @Speed: does strlen() which may not be needed...
            end_debug_view := view_of_c_string(pInfo.m_info.m_szEndDebug.data);

            // Print an appropriate message
            if pInfo.m_eOldState == .Connecting
            {
                // Note: we could distinguish between a timeout, a rejected connection,
                // or some other transport problem.
                print("We sought the remote host, yet our efforts were met with defeat. (%)\n", end_debug_view);
            }
            else if pInfo.m_info.m_eState == .ProblemDetectedLocally
            {
                print("Alas, troubles beset us; we have lost contact with the host. (%)\n", end_debug_view);
            }
            else
            {
                // NOTE: We could check the reason code for a normal disconnection
                print("The host hath bidden us farewell.  (%)\n", end_debug_view);
            }

            // Clean up the connection.  This is important!
            // The connection is "closed" in the network sense, but
            // it has not been destroyed.  We must close it on our end, too
            // to finish up.  The reason information do not matter in this case,
            // and we cannot linger because it's already closed on the other end,
            // so we just pass 0's.
            Sockets.CloseConnection(client.connection, 0, null, false);
            client.connection = .Invalid;
        }

        case .Connecting;
            // We will get this callback when we start connecting.
            // We can ignore this.

        case .Connected;
            print("Connected to server OK\n");

        case;
            // Silences -Wswitch
    }
}

InitializeServer :: (server : *ServerData) -> sucess: bool
{
    // Start listening socket
    serverLocalAddr : IPAddr;
    IPAddr.Clear(*serverLocalAddr);
    serverLocalAddr.m_port = server.port;
    
    options : [1] ConfigValue;

    // Set callback handler
    ConfigValue.SetPtr(*options[0], .Callback_ConnectionStatusChanged, xx ServerNetConnectionStatusChanged);

    // Create Listen Socket
    server.listen_socket = Sockets.CreateListenSocketIP(*serverLocalAddr, options.count, options.data);
    if server.listen_socket == .Invalid
    {
        print("FATAL ERROR: Sockets.CreateListenSocketIP() failed!\n");
        return false;
    }

    // Create Poll Group
    server.poll_group = Sockets.CreatePollGroup();
    if server.poll_group == .Invalid
    {
        Sockets.CloseListenSocket(server.listen_socket);
        print("FATAL ERROR: Sockets.CreatePollGroup() failedServer\n");
        return false;
    }

    print("Server listening on port %\n", server.port);
    return true;
}

FinalizeServer :: (server :*ServerData)
{
    server.is_quitting = true;

    // Close all the connections
    print("Closing connections...\n");

    // Send them one more goodbye message.  Note that we also have the
    // connection close reason as a place to send final data.  However,
    // that's usually best left for more diagnostic/debug text not actual
    // protocol strings.
    SendStringToClients(server.clients, "Server is shutting down.  Goodbye.");

    for * server.clients
    {
        // Close the connection.  We use "linger mode" to ask SteamNetworkingSockets
        // to flush this out and close gracefully.
        Sockets.CloseConnection(it.connection, 0, "Server Shutdown", true);

        free(it.nickname);
    }

    array_free(server.clients);

    Sockets.CloseListenSocket(server.listen_socket);
    server.listen_socket = .Invalid;

    Sockets.DestroyPollGroup(server.poll_group);
    server.poll_group = .Invalid;
}

UpdateServer :: (server : *ServerData)
{
    // Process messages while the server isn't quiting
    while (!server.is_quitting)
    {
        incommingMessages : [8] *NetworkingMessage;
        numMsgs := Sockets.ReceiveMessagesOnPollGroup(server.poll_group, incommingMessages.data, incommingMessages.count);

        // Finished processing received messages
        if numMsgs == 0 
            break;

        if (numMsgs < 0)
        {
            print("UpdateServer() Fatal error when receiving messages\n");
            server.is_quitting = true;
            return;
        }

        assert(numMsgs <= incommingMessages.count, "Invalid number of messages recieved\n");

        // Handle messages
        for 0..numMsgs-1
        {   
            message : *NetworkingMessage = incommingMessages[it];
            // Release at the end of the scope.
            defer NetworkingMessage.Release(message);

            // Stringview into the message buffer
            message_view : string;
            message_view.data  = message.m_pData;
            message_view.count = message.m_cbSize;

            // Empty message. Don't care.
            if message_view.count == 0
                continue;

            // find client associated with message
            client : *ServerData.Client;
            clientIndex := 0;
            for * server.clients
            {
                if it.connection == message.m_conn
                {
                    client = it;
                    clientIndex = it_index;
                    break;
                }
            }
            assert(client != null);

            // Check for known commands.  None of this example code is secure or robust.
            // Don't write a real server like this, please.
            isCommand := message_view[0] == #char"/";
            if isCommand
            {
                cmd, args := splitInTwo(message_view, #char" ");
                
                if (cmd == "/help")
                {
                    ServerHelpMsg :: string.[
                        "Available commands:",
                        "/nick <nick_name>      // change your name",
                        "/quit                  // quit program",
                    ];

                    for ServerHelpMsg
                    {
                        SendStringToClient(<< client, it);
                    }
                    continue;
                }

                if (cmd == "/nick")
                {
                    invalidNickName :=
                        args.count == 0      ||
                        contains(args, " "); // @Speed

                    if invalidNickName
                    {
                        invalidNickNameCommandArgsMessage := sprint("\"%\" is a truly vane name, thou must try again", args);
                        defer free(invalidNickNameCommandArgsMessage);
                        SendStringToClient(<< client, invalidNickNameCommandArgsMessage);
                        continue;
                    }

                    // Let everybody else know they changed their name
                    {
                        renameMessageAll := sprint("% shall henceforth be known as %", client.nickname, args);
                        defer free(renameMessageAll);
                        SendStringToClients(server.clients, renameMessageAll);
                    }

                    // Respond to client
                    {
                        renameMessage := sprint("Ye shall henceforth be known as %", args);
                        defer free(renameMessage);
                        SendStringToClient(<< client, renameMessage);
                    }

                    // Actually change their name
                    free (client.nickname);
                    newNickname := sprint("%", args);
                    client.nickname = newNickname;
                    continue;
                }
            }
            
            // Assume it's just a ordinary chat message, dispatch to everybody else
            messageToOthers := sprint("%: %", client.nickname, message_view);
            defer free(messageToOthers);
            SendStringToClients(server.clients, messageToOthers);
        }
    }

    // run callbacks
    Sockets.RunCallbacks();
}

ServerNetConnectionStatusChanged :: (pInfo : *ConnectionStatusChanged) -> void #c_call
{
    newConext : Context;
    push_context newConext
    {
        ServerNetConnectionStatusChanged(*g_server, pInfo);
    }
}
ServerNetConnectionStatusChanged :: (server : *ServerData, pInfo : *ConnectionStatusChanged)
{
    if pInfo.m_info.m_eState == 
    {
        case .None;
        // NOTE: We will get callbacks here when we destroy connections.  You can ignore these.

        case .ClosedByPeer; #through;
        case .ProblemDetectedLocally;
        {
            // Ignore if they were not previously connected.  (If they disconnected
            // before we accepted the connection.)
            if (pInfo.m_eOldState == .Connected)
            {

                // Locate the client.  Note that it should have been found, because this
                // is the only codepath where we remove clients (except on shutdown),
                // and connection change callbacks are dispatched in queue order.
                client : *ServerData.Client;
                clientIndex := 0;
                for * server.clients
                {
                    if it.connection == pInfo.m_conn
                    {
                        client = it;
                        clientIndex += it_index;
                        break;
                    }
                }
                assert(client != null);

                // Select appropriate log messages
                actionDescription : string;
                clientDisconnectedMessage : string;
                defer free(clientDisconnectedMessage);

                connection_description_view := view_of_c_string(pInfo.m_info.m_szConnectionDescription.data);
                end_debug_view  := view_of_c_string(pInfo.m_info.m_szEndDebug.data);

                if (pInfo.m_info.m_eState == .ProblemDetectedLocally)
                {
                    actionDescription = "problem detected locally";
                    clientDisconnectedMessage = sprint("Alas, % hath fallen into shadow.  (%)", client.nickname, end_debug_view);
                }
                else
                {
                    // Note that here we could check the reason code to see if
                    // it was a "usual" connection or an "unusual" one.
                    actionDescription = "closed by peer";
                    clientDisconnectedMessage = sprint("% hath departed", client.nickname);
                }

                // Spew something to our own log.  Note that because we put their nick
                // as the connection description, it will show up, along with their
                // transport-specific data (e.g. their IP address)
                print("Client Connection % %, reason %: %\n",
                    connection_description_view,
                    actionDescription,
                    pInfo.m_info.m_eEndReason,
                    end_debug_view
                );

                array_unordered_remove_by_index(*server.clients, clientIndex);

                // Send a message so everybody else knows what happened
                SendStringToClients(server.clients, clientDisconnectedMessage);
            }
            else
            {
                assert(pInfo.m_eOldState == .Connecting);
            }

            // Clean up the connection.  This is important!
            // The connection is "closed" in the network sense, but
            // it has not been destroyed.  We must close it on our end, too
            // to finish up.  The reason information do not matter in this case,
            // and we cannot linger because it's already closed on the other end,
            // so we just pass 0's.
            Sockets.CloseConnection(pInfo.m_conn, 0, null, false);
        }

        case .Connecting;
        {
            // This must be a new connection
            {
                for * server.clients
                {
                    if (it.connection == pInfo.m_conn)
                    {
                        assert(false, "Connecting connection already added! This shouldn't ever happen. BUG!\n");
                    }
                }
            }

            viewOfConnectionDecription := view_of_c_string(pInfo.m_info.m_szConnectionDescription.data);
            print("Connection request from %\n", viewOfConnectionDecription);

            // A client is attempting to connect
            // Try to accept the connection.
            if (Sockets.AcceptConnection(pInfo.m_conn) != .OK)
            {
                // This could fail.  If the remote host tried to connect, but
                // then disconnected, the connection may already be half closed.
                // Just destroy whatever we have on our side.
                Sockets.CloseConnection(pInfo.m_conn, 0, null, false);
                print("Can't accept connection.  (It was already closed?)\n");
                return;
            }

            // Assign the poll group
            if (!Sockets.SetConnectionPollGroup(pInfo.m_conn, server.poll_group))
            {
                Sockets.CloseConnection(pInfo.m_conn, 0, null, false);
                print("Failed to set poll group\n");
                return;
            }

            // Generate a random nick.  A random temporary nick
            // is really dumb and not how you would write a real chat server.
            // You would want them to have some sort of signon message,
            // and you would keep their client in a state of limbo (connected,
            // but not logged on) until them.  I'm trying to keep this example
            // code really simple.
            NickNames : [] string = .[ "BrakeWarrior", "GloriousGriefer", "PrettySoldier", "Pyro", "MikeTruck"];
            
            nameIndex  := random_get() % NickNames.count;
            nameNumber := 10000 + (random_get() % 100000);

            newClient : ServerData.Client;
            newClient.connection = pInfo.m_conn;
            newClient.nickname = sprint("%1%2", NickNames[nameIndex], nameNumber);
            defer array_add(*server.clients, newClient);

            // Send them a welcome message
            {
                welcomeMessage0 := sprint("Welcome, stranger. Thou art known to us for now as '%'", newClient.nickname); 
                welcomeMessage1 := sprint("upon thine command '/nick' we shall know thee otherwise."); 
                defer free(welcomeMessage0);
                defer free(welcomeMessage1);
                SendStringToClient(newClient, welcomeMessage0); 
                SendStringToClient(newClient, welcomeMessage1); 
            }

            // Also send them a list of everybody who is already connected
            if (server.clients.count == 0)
            {
                SendStringToClient(newClient, "Thou art utterly alone."); 
            }
            else
            {
                peerCountMessage := sprint("% companions greet you:", server.clients.count); 
                defer free(peerCountMessage);
                SendStringToClient(newClient, peerCountMessage);

                for * server.clients
                {
                    SendStringToClient(newClient, it.nickname); 
                }
            }

            // Let everybody else know who they are for now
            {
                newPeerMessage: = sprint("Hark! A stranger hath joined this merry host.  For now we shall call them '%'", newClient.nickname); 
                defer free(newPeerMessage);
                SendStringToClients(server.clients, newPeerMessage); 
            }
        }

        case .Connected;
            // We will get a callback immediately after accepting the connection.
            // Since we are the server, we can ignore this, it's not news to us.
        case;
            // Silences -Wswitch

    }

}

SendStringToClient :: (client : ServerData.Client, str : string)
{
    Sockets.SendStringToConnection(client.connection, str, .Reliable, null);
}
SendStringToClients :: (clients : [] ServerData.Client, str : string)
{
    for * clients
    {
        Sockets.SendStringToConnection(it.connection, str, .Reliable, null);
    }
}

g_logTimeZero : Microseconds;
DebugOutput :: (level : DebugOutputLevel, pszMsg : *s8) -> void #c_call
{
    new_context: Context;
    push_context new_context 
    {
        now := Utils.GetLocalTimestamp();
        time_since_start : float64 = xx (now - g_logTimeZero);

        // @Speed: does strlen() which may not be needed...
        msg := view_of_c_string(pszMsg);
        
        format_float := *context.print_style.default_format_float;  // Get a pointer to this so we can play with it.
        format_float.zero_removal = .ONE_ZERO_AFTER_DECIMAL;
        format_float.trailing_width = 2;
        format_float.width = 7;
        
        print("[gns]%:%\n", time_since_start * 0.000_001, msg);
        
        if (level == .Bug)
        {
            // Add level specific handling
        }
    }
}

main :: () 
{
    if handle_command_line_arguments(*g_client, *g_server) == false
    {
        print_command_line_argument_help_msg();
        return;
    }
    
    // Initialize GNS librarydefer 
    if !GameNetworkingSockets.Initialize()
    {
        print("GameNetworkingSockets.Initialize() failed!\n");
        return;
    }
    defer
    {
        GameNetworkingSockets.Finalize();
        // Give a little time for sockets to shutdown
        sleep_milliseconds(500); 
    }

    
    g_logTimeZero = Utils.GetLocalTimestamp();
    
    // Register DebugOutput callback
    Utils.SetDebugOutputFunction(.Msg, DebugOutput);

    if g_isClient
    {
        if !InitializeClient(*g_client) then return;
        defer FinalizeClient(*g_client);

        g_chat.window_title = "Chatroom";
        InitializeChatWindow(g_chat);
        
        while !g_client.is_quitting
        {
            UpdateClient(*g_client, *g_chat);
            g_client.is_quitting |= UpdateChatWindow(*g_chat);
        }
    }
    else if g_isServer
    {
        if !InitializeServer(*g_server) then return;
        defer FinalizeServer(*g_server);
        
        // setup server's local client
        loopbackIPv4 : u32 = 0x7F_00_00_01;
        IPAddr.SetIPv4(*g_client.endpoint, loopbackIPv4, g_server.port);
        if !InitializeClient(*g_client) then return;
        defer FinalizeClient(*g_client);

        // setup server's client window
        g_chat.window_title = "Chatroom (Server)";
        InitializeChatWindow(g_chat);

        while !g_server.is_quitting && !g_client.is_quitting
        {
            UpdateServer(*g_server);
            g_server.is_quitting |= UpdateChatWindow(*g_chat);
            UpdateClient(*g_client, *g_chat);
        }
    }
    else
    {
        print("ERROR: !!BUG!! Neither g_isClient nor g_isServer was set. Shouldn't get here!\n");
    }
    
}


//  Helper functions
splitInTwo :: (str : string, $exclusiveDividePoint : u8)  -> left : string,  right: string
{
    left : string;
    right : string;

    for 0..str.count-1
    {
        if str[it] == exclusiveDividePoint
        {
            left.data = str.data;
            left.count = it;
            right.data = str.data + (it + 1);
            right.count = str.count - (left.count + 1);
            return left, right;
        }
    }

    // no arguments passed
    left = str;
    return left, right;
}

print_command_line_argument_help_msg :: ()
{
    print("%", cmd_line_prompt_help_message);
}

handle_command_line_arguments :: (client : *ClientData, server : *ServerData) -> success : bool 
{
    args := get_command_line_arguments();

    
    if args.count == 1
    {
        return false;
    }

    arg_index := 1;
    while arg_index < args.count {
        arg := args[arg_index];
        print("arg[%]= %\n", arg_index, arg);
        
        arg_index += 1;
    }
    
    if args[1] ==
    {
        case "-client";
            if args.count == 2
                return false;
        
            g_isClient = true;
            if  args[2] ==
            {
                case "server";
                    if args.count == 3
                        return false;
                        
                    return IPAddr.ParseString(*client.endpoint, xx args[3].data);
                case "loopback";
                    loopbackIPv4 : u32 = 0x7F_00_00_01;
                    
                    if (args.count > 3)
                    {
                        port, valid := to_integer(args[3]);
                        if !valid 
                        {
                            print("Could not parse port number \"%\"\n", args[2]);
                            return false;
                        }
                        IPAddr.SetIPv4(*client.endpoint, loopbackIPv4, xx port);
                    }
                    else
                    {
                        port : u16 = DefaultPort;
                        IPAddr.SetIPv4(*client.endpoint, loopbackIPv4, port);
                    }
                case; return false;
            }
            
        case "-server";
            g_isServer = true;
            
            if args.count > 2
            {
                port, valid := to_integer(args[2]);
                if !valid 
                {
                    print("Could not parse port number \"%\"\n", args[2]);
                    return false;
                }
                g_server.port = xx port;
            }
            else
            {
                g_server.port = DefaultPort;
            }
        case; return false;
    }
    
    return true;
}

view_of_c_string :: (c_string : *s8) -> string
{
    ret : string;
    
    if (c_string == null)
    {
        return ret;
    }
    
    ret.data = xx c_string;
    ret.count = c_style_strlen(xx c_string);
    return ret;
}
