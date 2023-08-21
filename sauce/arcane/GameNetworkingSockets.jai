//
// Game Networking Sockets is a cleaned-up version of steam's networking library.
// This is a simplified and un-steamify binding so intended to be easy to use.
//

#import "Basic"; // print

// GameNetworkingSockets
GameNetworkingSockets :: struct
{
    Initialize :: (pIdentity : *Identity = null) -> success : bool
    {
        hasFailed : bool = false;
        
        err : *s8;
        // Initialize the library.  Optionally, you can set an initial identity
        // for the default interface that is returned by SteamNetworkingSockets().
        // On failure, false is returned, and a non-localized diagnostic message is returned.
        GameNetworkingSockets_Init :: (pIdentity: *Identity, errMsg: *NetworkingErrMsg) -> bool #foreign lib "GameNetworkingSockets_Init";
        hasFailed |= (GameNetworkingSockets_Init(pIdentity, *err) == false);

        if hasFailed
        {
            errMsg : string;
            errMsg.data = xx err;
            errMsg.count = c_style_strlen(xx err);
            print("GameNetworkingSocket_Init() failed! ErrMsg: %\n", errMsg);
        } 

        g_sockets_interface = GetISockets();
        hasFailed |= (g_sockets_interface == null);
        if hasFailed then print("GetISockets() failed!\n");

        g_utils_interface = GetIUtils();
        hasFailed |= (g_utils_interface == null);
        if hasFailed then print("GetIUtils() failed!\n");

        return !hasFailed;
    }

    Finalize :: ()
    {
        // Close all connections and listen sockets and free all resources
        GameNetworkingSockets_Kill :: () #c_call #foreign lib "GameNetworkingSockets_Kill";
        GameNetworkingSockets_Kill();
    }

    GetISockets :: () -> *ISockets #foreign lib "SteamAPI_SteamNetworkingSockets_v009";
    GetIUtils   :: () -> *IUtils   #foreign lib "SteamAPI_SteamNetworkingUtils_v003";

    // Custom memory allocation methods.  If you call this, you MUST call it exactly once,
    // before calling any other API function.  *Most* allocations will pass through these,
    // especially all allocations that are per-connection.  A few allocations
    // might still go to the default CRT malloc and operator new.
    // To use this, you must compile the library with STEAMNETWORKINGSOCKETS_ENABLE_MEM_OVERRIDE
    //
    // The included binaries in gns-jai DO NOT compile with STEAMNETWORKINGSOCKETS_ENABLE_MEM_OVERRIDE
    // so you MUST make your own binaries to use this feature.
    //
    // @randy - commented this out since it's unresolved.
    // SetCustomMemoryAllocator :: (
    //     pfn_malloc: Malloc,
    //     pfn_free: Free,
    //     pfn_realloc: Realloc) #foreign lib "SteamNetworkingSockets_SetCustomMemoryAllocator";

    // Malloc  :: #type (s: u64) -> *void;
    // Free    :: #type (p: *void);
    // Realloc :: #type (p: *void, s: u64) -> *void;
}

//-----------------------------------------------------------------------------
// Lower level networking API.
//
// - Connection-oriented API (like TCP, not UDP).  When sending and receiving
//   messages, a connection handle is used.  In this TCP-style interface, the
//   "server" will "listen" on a "listen socket."  A "client" will "connect"
//   to the server, and the server will "accept" the connection.
// - But unlike TCP, it's message-oriented, not stream-oriented.
// - Mix of reliable and unreliable messages
// - Fragmentation and reassembly
// - Supports connectivity over plain UDP
//
// These bindings do not support:
// - gns-jai is simplified and does NOT provide the bindings for supports SDR ("Steam Datagram Relay"). The
//   "P2P" (peer to peer) custom signaling for "ICE" (Interactive Connectivity Establishment) using a STUN
//   and TURN servers are also NOT included since the GNS 1.2.0 doesn't provide a C-friendly interface.
//
// Note that neither of the terms "connection" nor "socket" necessarily correspond
// one-to-one with an underlying UDP socket.  An attempt has been made to
// keep the semantics as similar to the standard socket model when appropriate,
// but some deviations do exist.
//
Sockets :: WrapISockets(#bake_arguments GlobalInterfaceWrapper(pp = *g_sockets_interface));

//-----------------------------------------------------------------------------
// Misc networking utilities for checking the local networking environment
// and estimating pings.
Utils :: WrapIUtils(#bake_arguments GlobalInterfaceWrapper(pp = *g_utils_interface));

// Wrapper around ISockets to enable Sockets.functionName to pass the interface pointer
WrapISockets :: struct(s : () -> *ISockets)
{
    // Creates a "server" socket that listens for clients to connect to by 
    // calling ConnectByIPAddress, over ordinary UDP (IPv4 or IPv6)
    //
    // You must select a specific local port to listen on and set it
    // the port field of the local address.
    //
    // Usually you will set the IP portion of the address to zero (IPAddr.Clear()).
    // This means that you will not bind to any particular local interface (i.e. the same
    // as INADDR_ANY in plain socket code).  Furthermore, if possible the socket will be bound
    // in "dual stack" mode, which means that it can accept both IPv4 and IPv6 client connections.
    // If you really do wish to bind a particular interface, then set the local address to the
    // appropriate IPv4 or IPv6 IP.
    //
    // If you need to set any initial config options, pass them here.  See ConfigValue for more
    // about why this is preferable to setting the options "immediately" after creation.
    //
    // When a client attempts to connect, a ConnectionStatusChanged
    // will be posted.  The connection will be in the connecting state.
    CreateListenSocketIP :: (localAddress: *IPAddr, nOptions: s32, pOptions: *ConfigValue) -> ListenSocket { return s().CreateListenSocketIP(s(), localAddress, nOptions, pOptions); }

    // Creates a connection and begins talking to a "server" over UDP at the
    // given IPv4 or IPv6 address.  The remote host must be listening with a
    // matching call to CreateListenSocketIP on the specified port.
    //
    // A ConnectionStatusChanged callback will be triggered when we start
    // connecting, and then another one on either timeout or successful connection.
    //
    // If the server does not have any identity configured, then their network address
    // will be the only identity in use.  Or, the network host may provide a platform-specific
    // identity with or without a valid certificate to authenticate that identity.  (These
    // details will be contained in the ConnectionStatusChanged.)  It's up to your application
    // to decide whether to allow the connection.
    //
    // By default, all connections will get basic encryption sufficient to prevent
    // casual eavesdropping.  But note that without certificates (or a shared secret
    // distributed through some other out-of-band mechanism), you don't have any
    // way of knowing who is actually on the other end, and thus are vulnerable to
    // man-in-the-middle attacks.
    //
    // If you need to set any initial config options, pass them here.  See
    // ConfigValue for more about why this is preferable to
    // setting the options "immediately" after creation.
    ConnectByIPAddress :: (address: *IPAddr, nOptions: s32, pOptions: *ConfigValue) -> NetConnection { return s().ConnectByIPAddress(s(), address, nOptions, pOptions); }

    // Accept an incoming connection that has been received on a listen socket.
    //
    // When a connection attempt is received (perhaps after a few basic handshake
    // packets have been exchanged to prevent trivial spoofing), a connection interface
    // object is created in the ConnectionState.Connecting state
    // and a ConnectionStatusChanged is posted.  At this point, your
    // application MUST either accept or close the connection.  (It may not ignore it.)
    // Accepting the connection will transition it either into the connected state,
    // or the finding route state, depending on the connection type.
    //
    // You should take action within a second or two, because accepting the connection is
    // what actually sends the reply notifying the client that they are connected.  If you
    // delay taking action, from the client's perspective it is the same as the network
    // being unresponsive, and the client may timeout the connection attempt.  In other
    // words, the client cannot distinguish between a delay caused by network problems
    // and a delay caused by the application.
    //
    // This means that if your application goes for more than a few seconds without
    // processing callbacks (for example, while loading a map), then there is a chance
    // that a client may attempt to connect in that interval and fail due to timeout.
    //
    // If the application does not respond to the connection attempt in a timely manner,
    // and we stop receiving communication from the client, the connection attempt will
    // be timed out locally, transitioning the connection to the
    // ConnectionState.ProblemDetectedLocally state.  The client may also
    // close the connection before it is accepted, and a transition to the
    // ConnectionState.ClosedByPeer is also possible  on the exact
    // sequence of events.
    //
    // Returns Result.InvalidParam if the handle is invalid.
    // Returns Result.InvalidState if the connection is not in the appropriate state.
    // (Remember that the connection state could change in between the time that the
    // notification being posted to the queue and when it is received by the application.)
    //
    // A note about connection configuration options.  If you need to set any configuration
    // options that are common to all connections accepted through a particular listen
    // socket, consider setting the options on the listen socket, since such options are
    // inherited automatically.  If you really do need to set options that are connection
    // specific, it is safe to set them on the connection before accepting the connection.
    AcceptConnection :: (conn: NetConnection) -> Result { return s().AcceptConnection(s(), conn); }

    // Disconnects from the remote host and invalidates the connection handle.
    // Any unread data on the connection is discarded.
    //
    // reason: ConnectionEnd is an application-defined code that will be received on the other
    // end and recorded (when possible) in backend analytics.  The value should come from
    // a restricted range.  (See ConnectionEnd)  If you don't need to communicate any
    // information to the remote host, and do not want analytics to be able to distinguish
    // "normal" connection terminations from "exceptional" ones, You may pass zero, in
    // which case the generic value of ConnectionEnd.App_Generic will be used.
    //
    // debugMessage: *s8 is an optional human-readable diagnostic string that will be received
    // by the remote host and recorded (when possible) in backend analytics.
    //
    // If you wish to put the socket into a "linger" state, where an attempt is made to
    // flush any remaining sent data, use bEnableLinger=true.  Otherwise reliable data
    // is not flushed.
    //
    // If the connection has already ended and you are just freeing up the connection
    // interface, the reason code, debug string, and linger flag are ignored.
    CloseConnection :: (peer: NetConnection, reason: ConnectionEnd, debugMessage: *s8, bEnableLinger: bool) -> bool { return s().CloseConnection(s(), peer, reason, debugMessage, bEnableLinger); }

    // Destroy a listen socket.  All the connections that were accepting on the listen
    // socket are closed ungracefully.
    CloseListenSocket :: (socket: ListenSocket) -> bool { return s().CloseListenSocket(s(), socket); }

    // Set connection user data.  the data is returned in the following places
    // - You can query it using GetConnectionUserData.
    // - The NetworkingMessage structure.
    // - The ConnectionInfo structure.  (Which is a member of ConnectionStatusChanged.)
    //   (Which is a member of ConnectionStatusChangedFunctionType -- but see WARNINGS below!!!!)
	//
	// Do you need to set this atomically when the connection is created?
	// See ConfigValueLabel.ConnectionUserData.
	//
	// WARNING: Be *very careful* when using the value provided in callbacks structs.
	// Callbacks are queued, and the value that you will receive in your
	// callback is the userdata that was effective at the time the callback
	// was queued.  There are subtle race conditions that can hapen if you
	// don't understand this!
	//
	// If any incoming messages for this connection are queued, the userdata
	// field is updated, so that when when you receive messages (e.g. with
	// ReceiveMessagesOnConnection), they will always have the very latest
	// userdata.  So the tricky race conditions that can happen with callbacks
	// do not apply to retrieving messages.
    //
    // Returns false if the handle is invalid.
    SetConnectionUserData :: (peer: NetConnection, nUserData: s64) -> bool { return s().SetConnectionUserData(s(), peer, nUserData); }

    // Fetch connection user data.  Returns -1 if handle is invalid
    // or if you haven't set any userdata on the connection.
    GetConnectionUserData :: (peer: NetConnection) -> s64 { return s().GetConnectionUserData(s(), peer); };

    // Set a name for the connection, used mostly for debugging
    SetConnectionName :: (peer: NetConnection, name: *s8) { s().SetConnectionName(s(), peer, name); }

    // Fetch connection name.  Returns false if handle is invalid
    GetConnectionName :: (peer: NetConnection, name: *s8, maxLen: s32) -> bool { return s().GetConnectionName(s(), peer, name, maxLen); }

    // Send a message to the remote host on the specified connection.
    //
    // sendFlags: NetworkingSend determines the delivery guarantees that will be
    // provided, when data should be buffered, etc. (E.g. NetworkingSend.Unreliable)
    //
    // Note that the semantics we use for messages are not precisely
    // the same as the semantics of a standard "stream" socket.
    // (SOCK_STREAM)  For an ordinary stream socket, the boundaries
    // between chunks are not considered relevant, and the sizes of
    // the chunks of data written will not necessarily match up to
    // the sizes of the chunks that are returned by the reads on
    // the other end.  The remote host might read a partial chunk,
    // or chunks might be coalesced.  For the message semantics 
    // used here, however, the sizes WILL match.  Each send call 
    // will match a successful read call on the remote host 
    // one-for-one.  If you are porting existing stream-oriented 
    // code to the semantics of reliable messages, your code should 
    // work the same, since reliable message semantics are more 
    // strict than stream semantics.  The only caveat is related to 
    // performance: there is per-message overhead to retain the 
    // message sizes, and so if your code sends many small chunks 
    // of data, performance will suffer. Any code based on stream 
    // sockets that does not write excessively small chunks will 
    // work without any changes. 
    //
    // The pOutMessageNumber is an optional pointer to receive the
    // message number assigned to the message, if sending was successful.
    //
    // Returns:
    // - ResultInvalidParam: invalid connection handle, or the individual message is too big.
    //   (See MaxNetworkingMessageSendSize)
    // - Result.InvalidState: connection is in an invalid state
    // - Result.NoConnection: connection has ended
    // - Result.Ignored: You used NetworkingSend.NoDelay, and the message was dropped because
    //   we were not ready to send it.
    // - Result.LimitExceeded: there was already too much data queued to be sent.
    //   (See ConfigValueLabel.SendBufferSize)
    SendMessageToConnection :: (conn: NetConnection, data: *void, cbData: u32, sendFlags: NetworkingSend, pOutMessageNumber: *s64) -> Result { return s().SendMessageToConnection(s(), conn, data,        cbData,    sendFlags, pOutMessageNumber); }
    SendStringToConnection  :: (conn: NetConnection, str: string, sendFlags: NetworkingSend, pOutMessageNumber: *s64) -> Result              { return s().SendMessageToConnection(s(), conn, str.data, xx str.count, sendFlags, pOutMessageNumber); }

    // Send one or more messages without copying the message payload.
    // This is the most efficient way to send messages. To use this
    // function, you must first allocate a message object using
    // IUtils.AllocateMessage.  (Do not declare one
    // on the stack or allocate your own.)
    //
    // You should fill in the message payload.  You can either let
    // it allocate the buffer for you and then fill in the payload,
    // or if you already have a buffer allocated, you can just point
    // m_pData at your buffer and set the callback to the appropriate function
    // to free it.  Note that if you use your own buffer, it MUST remain valid
    // until the callback is executed.  And also note that your callback can be
    // invoked at any time from any thread (perhaps even before SendMessages
    // returns!), so it MUST be fast and threadsafe.
    //
    // You MUST also fill in:
    // - m_conn - the handle of the connection to send the message to
    // - m_nFlags - bitmask of NetworkingSend.xxx flags.
    //
    // All other fields are currently reserved and should not be modified.
    //
    // The library will take ownership of the message structures.  They may
    // be modified or become invalid at any time, so you must not read them
    // after passing them to this function.
    //
    // pOutMessageNumberOrResult is an optional array that will receive,
    // for each message, the message number that was assigned to the message
    // if sending was successful.  If sending failed, then a negative EResult
    // value is placed into the array.  For example, the array will hold
    // -Result.InvalidState if the connection was in an invalid state.
    // See ISockets.SendMessageToConnection for possible
    // failure codes.
    SendMessages :: (nMessages: s32, pMessages: **NetworkingMessage, pOutMessageNumberOrResult: *s64) { s().SendMessages(s(), nMessages, pMessages, pOutMessageNumberOrResult); }

    // Flush any messages waiting on the Nagle timer and send them
    // at the next transmission opportunity (often that means right now).
    //
    // If Nagle is enabled (it's on by default) then when calling 
    // SendMessageToConnection the message will be buffered, up to the Nagle time
    // before being sent, to merge small messages into the same packet.
    // (See ConfigValueLabel.NagleTime)
    //
    // Returns:
    // Result.InvalidParam: invalid connection handle
    // Result.InvalidState: connection is in an invalid state
    // Result.NoConnection: connection has ended
    // Result.Ignored: We weren't (yet) connected, so this operation has no effect.
    FlushMessagesOnConnection :: (conn: NetConnection) -> Result { return s().FlushMessagesOnConnection(s(), conn); }

    // Fetch the next available message(s) from the connection, if any.
    // Returns the number of messages returned into your array, up to nMaxMessages.
    // If the connection handle is invalid, -1 is returned.
    //
    // The order of the messages returned in the array is relevant.
    // Reliable messages will be received in the order they were sent (and with the
    // same sizes --- see SendMessageToConnection for on this subtle difference from a stream socket).
    //
    // Unreliable messages may be dropped, or delivered out of order with respect to
    // each other or with respect to reliable messages.  The same unreliable message
    // may be received multiple times.
    //
    // If any messages are returned, you MUST call NetworkingMessage.Release() on each
    // of them free up resources after you are done.  It is safe to keep the object alive for
    // a little while (put it into some queue, etc), and you may call Release() from any thread.
    ReceiveMessagesOnConnection :: (conn: NetConnection, ppOutMessages: **NetworkingMessage, nMaxMessages: s32) -> s32 { return s().ReceiveMessagesOnConnection(s(), conn, ppOutMessages, nMaxMessages); }

    // Returns basic information about the high-level state of the connection.
    GetConnectionInfo :: (conn: NetConnection, info: *ConnectionInfo) -> bool { return s().GetConnectionInfo(s(), conn, info); }

    // Returns a small set of information about the real-time state of the connection
    // Returns false if the connection handle is invalid, or the connection has ended.
    GetQuickConnectionStatus :: (conn: NetConnection, stats: *QuickConnectionStatus) -> bool { return s().GetQuickConnectionStatus(s(), conn, stats); }

    // Returns detailed connection stats in text format.  Useful for dumping to a log, etc.
    //
    // Returns:
    // -1 failure (bad connection handle)
    // 0 OK, your buffer was filled in and '\0'-terminated
    // >0 Your buffer was either nullptr, or it was too small and the text got truncated.
    //    Try again with a buffer of at least N bytes.
    GetDetailedConnectionStatus :: (conn: NetConnection, buf: *s8, cbBuf: s32) -> s32 { return s().GetDetailedConnectionStatus(s(), conn, buf, cbBuf); }

    // Returns local IP and port that a listen socket created using CreateListenSocketIP is bound to.
    //
    // An IPv6 address of ::0 means "any IPv4 or IPv6"
    // An IPv6 address of ::ffff:0000:0000 means "any IPv4"
    GetListenSocketAddress :: (socket: ListenSocket, address: *IPAddr) -> bool { return s().GetListenSocketAddress(s(), socket, address); }

    // Create a pair of connections that are talking to each other, e.g. a loopback connection.
    // This is very useful for testing, or so that your client/server code can work the same
    // even when you are running a local "server".
    //
    // The two connections will immediately be placed into the connected state, and no callbacks
    // will be posted immediately.  After this, if you close either connection, the other connection
    // will receive a callback, exactly as if they were communicating over the network.  You must
    // close *both* sides in order to fully clean up the resources!
    //
    // By default, internal buffers are used, completely bypassing the network, the chopping up of
    // messages into packets, encryption, copying the payload, etc.  This means that loopback
    // packets, by default, will not simulate lag or loss.  Passing true for bUseNetworkLoopback will
    // cause the socket pair to send packets through the local network loopback device (127.0.0.1)
    // on ephemeral ports.  Fake lag and loss are supported in this case, and CPU time is expended
    // to encrypt and decrypt.
    //
    // If you wish to assign a specific identity to either connection, you may pass a particular
    // identity.  Otherwise, if you pass nullptr, the respective connection will assume a generic
    // "localhost" identity.  If you use real network loopback, this might be translated to the
    // actual bound loopback port.  Otherwise, the port will be zero.
    CreateSocketPair :: (pOutConnection1: *NetConnection, pOutConnection2: *NetConnection, bUseNetworkLoopback: bool, pIdentity1: *Identity, pIdentity2: *Identity) -> bool { return s().CreateSocketPair(s(), pOutConnection1, pOutConnection2, bUseNetworkLoopback, pIdentity1, pIdentity2); }

    // Get the identity assigned to this interface.
    // E.g. on Steam, this is the user's SteamID, or for the gameserver interface, the SteamID assigned
    // to the gameserver.  Returns false and sets the result to an invalid identity if we don't know
    // our identity yet.  (E.g. GameServer has not logged in.  On Steam, the user will know their SteamID
    // even if they are not signed into Steam.)
    GetIdentity :: (pIdentity: *Identity) -> bool { return s().GetIdentity(s(), pIdentity); }

    // Indicate our desire to be ready participate in authenticated communications.
    // If we are currently not ready, then steps will be taken to obtain the necessary
    // certificates.   (This includes a certificate for us, as well as any CA certificates
    // needed to authenticate peers.)
    //
    // You can call this at program init time if you know that you are going to
    // be making authenticated connections, so that we will be ready immediately when
    // those connections are attempted.  (Note that essentially all connections require
    // authentication, with the exception of ordinary UDP connections with authentication
    // disabled using ConfigValueLabel.IP_AllowWithoutAuth.)  If you don't call
    // this function, we will wait until a feature is utilized that that necessitates
    // these resources.
    //
    // You can also call this function to force a retry, if failure has occurred.
    // Once we make an attempt and fail, we will not automatically retry.
    // In this respect, the behavior of the system after trying and failing is the same
    // as before the first attempt: attempting authenticated communication or calling
    // this function will call the system to attempt to acquire the necessary resources.
    //
    // You can use GetAuthenticationStatus or listen for AuthenticationStatus
    // to monitor the status.
    //
    // Returns the current value that would be returned from GetAuthenticationStatus.
    InitAuthentication :: () -> NetworkAvailability { return s().InitAuthentication(s()); }

    // Query our readiness to participate in authenticated communications.  A
    // AuthenticationStatus callback is posted any time this status changes,
    // but you can use this function to query it at any time.
    //
    // The value of AuthenticationStatus.m_eAvail is returned.  If you only
    // want this high level status, you can pass NULL for pDetails.  If you want further
    // details, pass non-NULL to receive them.
    GetAuthenticationStatus :: (details: *AuthenticationStatus) -> NetworkAvailability { return s().GetAuthenticationStatus(s(), details); }

    //
    // Poll groups.  A poll group is a set of connections that can be polled efficiently.
    // (In our API, to "poll" a connection means to retrieve all pending messages.  We
    // actually don't have an API to "poll" the connection *state*, like BSD sockets.)
    //

    // Create a new poll group.
    //
    // You should destroy the poll group when you are done using DestroyPollGroup
    CreatePollGroup :: () -> PollGroup { return s().CreatePollGroup(s()); }

    // Destroy a poll group created with CreatePollGroup().
    //
    // If there are any connections in the poll group, they are removed from the group,
    // and left in a state where they are not part of any poll group.
    // Returns false if passed an invalid poll group handle.
    DestroyPollGroup :: (pollGroup: PollGroup) -> bool{ return s().DestroyPollGroup(s(), pollGroup); }

    // Assign a connection to a poll group.  Note that a connection may only belong to a
    // single poll group.  Adding a connection to a poll group implicitly removes it from
    // any other poll group it is in.
    //
    // You can pass PollGroup.Invalid to remove a connection from its current
    // poll group without adding it to a new poll group.
    //
    // If there are received messages currently pending on the connection, an attempt
    // is made to add them to the queue of messages for the poll group in approximately
    // the order that would have applied if the connection was already part of the poll
    // group at the time that the messages were received.
    //
    // Returns false if the connection handle is invalid, or if the poll group handle
    // is invalid (and not PollGroup.Invalid).
    SetConnectionPollGroup :: (conn: NetConnection, pollGroup: PollGroup) -> bool { return s().SetConnectionPollGroup(s(), conn, pollGroup); }

    // Same as ReceiveMessagesOnConnection, but will return the next messages available
    // on any connection in the poll group.  Examine NetworkingMessage.m_conn
    // to know which connection.  (NetworkingMessage.m_nConnUserData might also
    // be useful.)
    //
    // Delivery order of messages among different connections will usually match the
    // order that the last packet was received which completed the message.  But this
    // is not a strong guarantee, especially for packets received right as a connection
    // is being assigned to poll group.
    //
    // Delivery order of messages on the same connection is well defined and the
    // same guarantees are present as mentioned in ReceiveMessagesOnConnection.
    // (But the messages are not grouped by connection, so they will not necessarily
    // appear consecutively in the list; they may be interleaved with messages for
    // other connections.)
    ReceiveMessagesOnPollGroup :: (pollGroup: PollGroup, ppOutMessages: **NetworkingMessage, nMaxMessages: s32) -> s32{ return s().ReceiveMessagesOnPollGroup(s(), pollGroup, ppOutMessages, nMaxMessages); }

    //
    // Certificate provision by the application.  On Steam, we normally handle all this automatically
    // and you will not need to use these advanced functions.
    //

    // Get blob that describes a certificate request.  You can send this to your game coordinator.
    // Upon entry, *pcbBlob should contain the size of the buffer.  On successful exit, it will
    // return the number of bytes that were populated.  You can pass pBlob=NULL to query for the required
    // size.  (256 bytes is a very conservative estimate.)
    //
    // Pass this blob to your game coordinator and call SteamDatagram_CreateCert.
    GetCertificateRequest :: (pcbBlob: *s32, pBlob: *void, errMsg: *NetworkingErrMsg) -> bool { return s().GetCertificateRequest(s(), pcbBlob, pBlob, errMsg); }

    // Set the certificate.  The certificate blob should be the output of SteamDatagram_CreateCert.
    SetCertificate  :: (pCertificate: *void, cbCertificate: s32, errMsg: *NetworkingErrMsg) -> bool  { return s().SetCertificate(s(), pCertificate, cbCertificate, errMsg); }

    // Invoke all callback functions queued for this interface.
    // See ConfigValueLabel.Callback_ConnectionStatusChanged, etc
    RunCallbacks :: () {  s().RunCallbacks(s()); }
}

// Wrapper around IUtils to enable Utils.functionName to pass the interface pointer
WrapIUtils :: struct(s : () -> *IUtils)
{
    // Allocate and initialize a message object.  Usually the reason
    // you call this is to pass it to ISockets.SendMessages.
    // The returned object will have all of the relevant fields cleared to zero.
    //
    // Optionally you can also request that this system allocate space to
    // hold the payload itself.  If size is nonzero, the system
    // will allocate memory to hold a payload of at least size bytes.
    // m_pData will point to the allocated buffer, m_cbSize will be set to the
    // size, and m_pfnFreeData will be set to the proper function to free up
    // the buffer.
    //
    // If size=0, then no buffer is allocated.  m_pData will be NULL,
    // m_cbSize will be zero, and m_pfnFreeData will be NULL.  You will need to
    // set each of these.
    AllocateMessage :: (size: s32) -> *NetworkingMessage { return s().AllocateMessage (s(), size);}

    // Fetch current timestamp.  This timer has the following properties:
    //
    // - Monotonicity is guaranteed.
    // - The initial value will be at least 24*3600*30*1e6, i.e. about
    //   30 days worth of microseconds.  In this way, the timestamp value of
    //   0 will always be at least "30 days ago".  Also, negative numbers
    //   will never be returned.
    // - Wraparound / overflow is not a practical concern.
    //
    // If you are running under the debugger and stop the process, the clock
    // might not advance the full wall clock time that has elapsed between
    // calls.  If the process is not blocked from normal operation, the
    // timestamp values will track wall clock time, even if you don't call
    // the function frequently.
    //
    // The value is only meaningful for this run of the process.  Don't compare
    // it to values obtained on another computer, or other runs of the same process.
    GetLocalTimestamp  :: () -> Microseconds { return s().GetLocalTimestamp(s()); }

    // Set a function to receive network-related information that is useful for debugging.
    // This can be very useful during development, but it can also be useful for troubleshooting
    // problems with tech savvy end users.  If you have a console or other log that customers
    // can examine, these log messages can often be helpful to troubleshoot network issues.
    // (Especially any warning/error messages.)
    //
    // The detail level indicates what message to invoke your callback on.  Lower numeric
    // value means more important, and the value you pass is the lowest priority (highest
    // numeric value) you wish to receive callbacks for.
    //
    // The value here controls the detail level for most messages.  You can control the
    // detail level for various subsystems (perhaps only for certain connections) by
    // adjusting the configuration values ConfigValueLabel.LogLevel_Xxxxx.
    //
    // Except when debugging, you should only use DebugOutputLevel.Msg or DebugOutputLevel.Warning.
    // For best performance, do NOT request a high detail level and then filter out messages in
    // your callback.  This incurs all of the expense of formatting the messages, which are then
    // discarded.  Setting a high priority value (low numeric value) here allows the library to
    // avoid doing this work.
    //
    // IMPORTANT: This may be called from a service thread, while we own a mutex, etc.
    // Your output function must be threadsafe and fast!  Do not make any other
    // Steamworks calls from within the handler.
    SetDebugOutputFunction :: (detailLevel: DebugOutputLevel, pfnFunc: DebugOutputFunctionType) { s().SetDebugOutputFunction(s(), detailLevel, pfnFunc); }
    
    //
    // Set and get configuration values, see ESteamNetworkingConfigValue for individual descriptions.
    //

    // Shortcuts for common cases.  (Implemented as inline functions below)
    SetGlobalConfigValueInt32  :: (valueLabel: ConfigValueLabel, val: s32)     -> bool { return s().SetGlobalConfigValueInt32 (s(), valueLabel, val); }
    SetGlobalConfigValueFloat  :: (valueLabel: ConfigValueLabel, val: float32) -> bool { return s().SetGlobalConfigValueFloat (s(), valueLabel, val); }
    SetGlobalConfigValueString :: (valueLabel: ConfigValueLabel, val: *s8)     -> bool { return s().SetGlobalConfigValueString(s(), valueLabel, val); }
    SetGlobalConfigValuePtr    :: (valueLabel: ConfigValueLabel, val: *void)   -> bool { return s().SetGlobalConfigValuePtr   (s(), valueLabel, val); };
    SetConnectionConfigValueInt32  :: (conn: NetConnection, valueLabel: ConfigValueLabel, val: s32)     -> bool { return s().SetConnectionConfigValueInt32 (s(), conn, valueLabel, val); }
    SetConnectionConfigValueFloat  :: (conn: NetConnection, valueLabel: ConfigValueLabel, val: float32) -> bool { return s().SetConnectionConfigValueFloat (s(), conn, valueLabel, val); }
    SetConnectionConfigValueString :: (conn: NetConnection, valueLabel: ConfigValueLabel, val: *s8)     -> bool { return s().SetConnectionConfigValueString(s(), conn, valueLabel, val); }

    //
    // Set global callbacks. ISockets.RunCallbacks() will invoke these methods.
    //
    SetGlobalCallbackConnectionStatusChanged     :: (fnCallback: ConnectionStatusChangedFunctionType) -> bool { return s().SetGlobalCallbackConnectionStatusChanged(s(), fnCallback); }
    SetGlobalCallbackAuthenticationStatusChanged :: (fnCallback: AuthenticationStatusChangedFunctionType) -> bool { return s().SetGlobalCallbackAuthenticationStatusChanged(s(), fnCallback); }

    // Set a configuration value.
    // - valueLabel: which value is being set
    // - scope: Onto what type of object are you applying the setting?
    // - scopeObj: Which object you want to change?  (Ignored for global scope).  E.g. connection handle, listen socket handle, interface pointer, etc.
    // - eDataType: What type of data is in the buffer at pValue?  This must match the type of the variable exactly!
    // - pArg: Value to set it to.  You can pass NULL to remove a non-global setting at this scope,
    //   causing the value for that object to use global defaults.  Or at global scope, passing NULL
    //   will reset any custom value and restore it to the system default.
    //   NOTE: When setting pointers (e.g. callback functions), do not pass the function pointer directly.
    //   Your argument should be a pointer to a function pointer.
    SetConfigValue :: (valueLabel: ConfigValueLabel, scope: ConfigScope, scopeObj: intptr, eDataType: ConfigDataType, pArg: *void) -> bool { return s().SetConfigValue(s(), valueLabel, scope, scopeObj, eDataType, pArg); }

    // Set a configuration value, using a struct to pass the value.
    // (This is just a convenience shortcut; see below for the implementation and
    // a little insight into how ConfigValue is used when
    // setting config options during listen socket and connection creation.)
    SetConfigValueStruct :: (opt: *ConfigValue, scope: ConfigScope, scopeObj: intptr) -> bool { return s().SetConfigValueStruct(s(), opt, scope, scopeObj); }

    // Get a configuration value.
    // - valueLabel: which value to fetch
    // - scope: query setting on what type of object
    // - scopeObj: the object to query the setting for
    // - pOutDataType: If non-NULL, the data type of the value is returned.
    // - pResult: Where to put the result.  Pass NULL to query the required buffer size.  (GetConfigValueResult.BufferTooSmall will be returned.)
    // - cbResult: IN: the size of your buffer.  OUT: the number of bytes filled in or required.
    GetConfigValue :: (valueLabel: ConfigValueLabel, scope: ConfigScope, scopeObj: intptr,  pOutDataType: *ConfigDataType, pResult: *void, cbResult: *u64) -> IUtils.GetConfigValueResult { return s().GetConfigValue(s(), valueLabel, scope, scopeObj, pOutDataType, pResult, cbResult); } 

    // Returns info about a configuration value.  Returns false if the value does not exist.
    // pOutNextValue can be used to iterate through all of the known configuration values.
    // (Use GetFirstConfigValue() to begin the iteration, will be ConfigValueLabel.Invalid on the last value)
    // Any of the output parameters can be NULL if you do not need that information.
    //
    // See ConfigValueLabel.EnumerateDevVars for some more info about "dev" variables,
    // which are usually excluded from the set of variables enumerated using this function.
    GetConfigValueInfo :: (valueLabel: ConfigValueLabel, pOutName: **s8, pOutDataType: *ConfigDataType, pOutScope: *ConfigScope, pOutNextValue: *ConfigValueLabel) -> bool { return s().GetConfigValueInfo  (s(), valueLabel, pOutName, pOutDataType, pOutScope, pOutNextValue); }

    // Return the lowest numbered configuration value available in the current environment.
    GetFirstConfigValue :: () -> ConfigValueLabel { return s().GetFirstConfigValue (s()); }
}

//
// Network message
//
NetworkingMessage :: struct
{ 
    // You MUST call this when you're done with the object, to free up memory, etc.
    Release :: (self: *NetworkingMessage) -> void #foreign lib "SteamAPI_SteamNetworkingMessage_t_Release";

    // Message payload
    m_pData: *void;

    // Size of the payload.
    m_cbSize: s32;

    // Max size of a single message that we can SEND.
    // Note: We might be wiling to receive larger messages, and our peer might, too.
    MaxNetworkingMessageSendSize :s32: 524288; // in bytes

    // For messages received on connections: what connection did this come from?
    // For outgoing messages: what connection to send it to?
    m_conn: NetConnection;

    // For inbound messages: Who sent this to us?
    // For outbound messages on connections: not used.
    m_identityPeer: Identity;

    // For messages received on connections, this is the user data
    // associated with the connection.
    //
    // This is *usually* the same as calling GetConnection() and then
    // fetching the user data associated with that connection, but for
    // the following subtle differences:
    //
    // - This user data will match the connection's user data at the time
    //   is captured at the time the message is returned by the API.
    //   If you subsequently change the userdata on the connection,
    //   this won't be updated.
    // - This is an inline call, so it's *much* faster.
    // - You might have closed the connection, so fetching the user data
    //   would not be possible.
    //
    // Not used when sending messages, 
    m_nConnUserData: s64;

    // Local timestamp when the message was received
    // Not used for outbound messages.
    m_usecTimeReceived: Microseconds;

    // Message number assigned by the sender.
    // This is not used for outbound messages
    m_nMessageNumber: s64;

    // Function used to free up m_pData.  This mechanism exists so that
    // apps can create messages with buffers allocated from their own
    // heap, and pass them into the library.  This function will
    // usually be something like:
    //
    // free( pMsg->m_pData );
    m_pfnFreeData: #type (a0: *NetworkingMessage) -> void #c_call;

    // Function to used to decrement the internal reference count and, if
    // it's zero, release the message.  You should not set this function pointer,
    // or need to access this directly!  Use the Release() function instead!
    m_pfnRelease: #type (a0: *NetworkingMessage) -> void #c_call;

    // When using ISteamNetworkingMessages, the channel number the message was received on
    // (Not used for messages sent or received on "connections")
    m_nChannel: s32;

    // Bitmask of NetworkingSend.xxx flags.
    // For received messages, only the NetworkingSend.Reliable bit is valid.
    // For outbound messages, all bits are relevant
    m_nFlags: s32;

    // Arbitrary user data that you can use when sending messages using
    // IUtils.AllocateMessage and ISockets.SendMessage.
    // (The callback you set in m_pfnFreeData might use this field.)
    //
    // Not used for received messages.
    m_nUserData: s64;
}

//
// Flags used to set options for message sending
//
NetworkingSend :: enum s32 
{
    // Send the message unreliably. Can be lost.  Messages *can* be larger than a
    // single MTU (UDP packet), but there is no retransmission, so if any piece
    // of the message is lost, the entire message will be dropped.
    //
    // The sending API does have some knowledge of the underlying connection, so
    // if there is no NAT-traversal accomplished or there is a recognized adjustment
    // happening on the connection, the packet will be batched until the connection
    // is open again.
    //
    // Migration note: This is not exactly the same as k_EP2PSendUnreliable!  You
    // probably want UnreliableNoNagle
    Unreliable :: 0;

    // Disable Nagle's algorithm.
    // By default, Nagle's algorithm is applied to all outbound messages.  This means
    // that the message will NOT be sent immediately, in case further messages are
    // sent soon after you send this, which can be grouped together.  Any time there
    // is enough buffered data to fill a packet, the packets will be pushed out immediately,
    // but partially-full packets not be sent until the Nagle timer expires.  See
    // ISockets.FlushMessagesOnConnection
    //
    // NOTE: Don't just send every message without Nagle because you want packets to get there
    // quicker.  Make sure you understand the problem that Nagle is solving before disabling it.
    // If you are sending small messages, often many at the same time, then it is very likely that
    // it will be more efficient to leave Nagle enabled.  A typical proper use of this flag is
    // when you are sending what you know will be the last message sent for a while (e.g. the last
    // in the server simulation tick to a particular client), and you use this flag to flush all
    // messages.
    NoNagle :: 1;

    // Send a message unreliably, bypassing Nagle's algorithm for this message and any messages
    // currently pending on the Nagle timer.  This is equivalent to using Unreliable
    // and then immediately flushing the messages using ISockets.FlushMessagesOnConnection.
    // (But using this flag is more efficient since you only make one API call.)
    UnreliableNoNagle :: Unreliable | NoNagle;

    // If the message cannot be sent very soon (because the connection is still doing some initial
    // handshaking, route negotiations, etc), then just drop it.  This is only applicable for unreliable
    // messages.  Using this flag on reliable messages is invalid.
    NoDelay :: 4;

    // Send an unreliable message, but if it cannot be sent relatively quickly, just drop it instead of queuing it.
    // This is useful for messages that are not useful if they are excessively delayed, such as voice data.
    // NOTE: The Nagle algorithm is not used, and if the message is not dropped, any messages waiting on the
    // Nagle timer are immediately flushed.
    //
    // A message will be dropped under the following circumstances:
    // - the connection is not fully connected.  (E.g. the "Connecting" or "FindingRoute" states)
    // - there is a sufficiently large number of messages queued up already such that the current message
    //   will not be placed on the wire in the next ~200ms or so.
    //
    // If a message is dropped for these reasons, Result.Ignored will be returned.
    UnreliableNoDelay :: Unreliable | NoDelay | NoNagle;

    // Reliable message send. Can send up to NetworkingMessage.MaxNetworkingMessageSendSize bytes in a single message. 
    // Does fragmentation/re-assembly of messages under the hood, as well as a sliding window for
    // efficient sends of large chunks of data.
    //
    // The Nagle algorithm is used.  See notes on NetworkingSend.Unreliable for more details.
    // See ReliableNoNagle, ISockets.FlushMessagesOnConnection
    //
    // Migration note: This is NOT the same as k_EP2PSendReliable, it's more like k_EP2PSendReliableWithBuffering
    Reliable :: 8;

    // Send a message reliably, but bypass Nagle's algorithm.
    //
    // Migration note: This is equivalent to k_EP2PSendReliabl
    ReliableNoNagle :: Reliable | NoNagle;

    // By default, message sending is queued, and the work of encryption and talking to
    // the operating system sockets, etc is done on a service thread.  This is usually a
    // a performance win when messages are sent from the "main thread".  However, if this
    // flag is set, and data is ready to be sent immediately (either from this message
    // or earlier queued data), then that work will be done in the current thread, before
    // the current call returns.  If data is not ready to be sent (due to rate limiting
    // or Nagle), then this flag has no effect.
    //
    // This is an advanced flag used to control performance at a very low level.  For
    // most applications running on modern hardware with more than one CPU core, doing
    // the work of sending on a service thread will yield the best performance.  Only
    // use this flag if you have a really good reason and understand what you are doing.
    // Otherwise you will probably just make performance worse.
    UseCurrentThread :: 16;
}

//
// General result codes
//
Result :: enum s32 
{
    OK  :: 1;                           // success
    Fail :: 2;                          // generic failure 
    NoConnection :: 3;                  // no/failed network connection
  //NoConnectionRetry :: 4;             // OBSOLETE - removed
    InvalidPassword :: 5;               // password/ticket is invalid
    LoggedInElsewhere :: 6;             // same user logged in elsewhere
    InvalidProtocolVer :: 7;            // protocol version is incorrect
    InvalidParam :: 8;                  // a parameter is incorrect
    FileNotFound :: 9;                  // file was not found
    Busy :: 10;                         // called method busy - action not taken
    InvalidState :: 11;                 // called object was in an invalid state
    InvalidName :: 12;                  // name is invalid
    InvalidEmail :: 13;                 // email is invalid
    DuplicateName :: 14;                // name is not unique
    AccessDenied :: 15;                 // access is denied
    Timeout :: 16;                      // operation timed out
    Banned :: 17;                       // VAC2 banned
    AccountNotFound :: 18;              // account not found
    InvalidSteamID :: 19;               // steamID is invalid
    ServiceUnavailable :: 20;           // The requested service is currently unavailable
    NotLoggedOn :: 21;                  // The user is not logged on
    Pending :: 22;                      // Request is pending (may be in process, or waiting on third party)
    EncryptionFailure :: 23;            // Encryption or Decryption failed
    InsufficientPrivilege :: 24;        // Insufficient privilege
    LimitExceeded :: 25;                // Too much of a good thing
    Revoked :: 26;                      // Access has been revoked (used for revoked guest passes)
    Expired :: 27;                      // License/Guest pass the user is trying to access is expired
    AlreadyRedeemed :: 28;              // Guest pass has already been redeemed by account, cannot be acked again
    DuplicateRequest :: 29;             // The request is a duplicate and the action has already occurred in the past, ignored this time
    AlreadyOwned :: 30;                 // All the games in this guest pass redemption request are already owned by the user
    IPNotFound :: 31;                   // IP address not found
    PersistFailed :: 32;                // failed to write change to the data store
    LockingFailed :: 33;                // failed to acquire access lock for this operation
    LogonSessionReplaced :: 34;
    ConnectFailed :: 35;
    HandshakeFailed :: 36;
    IOFailure :: 37;
    RemoteDisconnect :: 38;
    ShoppingCartNotFound :: 39;         // failed to find the shopping cart requested
    Blocked :: 40;                      // a user didn't allow it
    Ignored :: 41;                      // target is ignoring sender
    NoMatch :: 42;                      // nothing matching the request found
    AccountDisabled :: 43;
    ServiceReadOnly :: 44;              // this service is not accepting content changes right now
    AccountNotFeatured :: 45;           // account doesn't have value, so this feature isn't available
    AdministratorOK :: 46;              // allowed to take this action, but only because requester is admin
    ContentVersion :: 47;               // A Version mismatch in content transmitted within the Steam protocol.
    TryAnotherCM :: 48;                 // The current CM can't service the user making a request, user should try another.
    PasswordRequiredToKickSession :: 49;// You are already logged in elsewhere this cached credential login has failed.
    AlreadyLoggedInElsewhere :: 50;     // You are already logged in elsewhere, you must wait
    Suspended :: 51;                    // Long running operation (content download) suspended/paused
    Cancelled :: 52;                    // Operation canceled (typically by user: content download)
    DataCorruption :: 53;               // Operation canceled because data is ill formed or unrecoverable
    DiskFull :: 54;                     // Operation canceled - not enough disk space.
    RemoteCallFailed :: 55;             // an remote call or IPC call failed
    PasswordUnset :: 56;                // Password could not be verified as it's unset server side
    ExternalAccountUnlinked :: 57;      // External account (PSN, Facebook...) is not linked to a Steam account
    PSNTicketInvalid :: 58;             // PSN ticket was invalid
    ExternalAccountAlreadyLinked :: 59; // External account (PSN, Facebook...) is already linked to some other account, must explicitly request to replace/delete the link first
    RemoteFileConflict :: 60;           // The sync cannot resume due to a conflict between the local and remote files
    IllegalPassword :: 61;              // The requested new password is not legal
    SameAsPreviousValue :: 62;          // new value is the same as the old one ( secret question and answer )
    AccountLogonDenied :: 63;           // account login denied due to 2nd factor authentication failure
    CannotUseOldPassword :: 64;         // The requested new password is not legal
    InvalidLoginAuthCode :: 65;         // account login denied due to auth code invalid
    AccountLogonDeniedNoMail :: 66;     // account login denied due to 2nd factor auth failure - and no mail has been sent
    HardwareNotCapableOfIPT :: 67;      // 
    IPTInitError :: 68;                 // 
    ParentalControlRestricted :: 69;    // operation failed due to parental control restrictions for current user
    FacebookQueryError :: 70;           // Facebook query returned an error
    ExpiredLoginAuthCode :: 71;         // account login denied due to auth code expired
    IPLoginRestrictionFailed :: 72;
    AccountLockedDown :: 73;
    AccountLogonDeniedVerifiedEmailRequired :: 74;
    NoMatchingURL :: 75;
    BadResponse :: 76;                  // parse failure, missing field, etc.
    RequirePasswordReEntry :: 77;       // The user cannot complete the action until they re-enter their password
    ValueOutOfRange :: 78;              // the value entered is outside the acceptable range
    UnexpectedError :: 79;              // something happened that we didn't expect to ever happen
    Disabled :: 80;                     // The requested service has been configured to be unavailable
    InvalidCEGSubmission :: 81;         // The set of files submitted to the CEG server are not valid !
    RestrictedDevice :: 82;             // The device being used is not allowed to perform this action
    RegionLocked :: 83;                 // The action could not be complete because it is region restricted
    RateLimitExceeded :: 84;            // Temporary rate limit exceeded, try again later, different from Result.LimitExceeded which may be permanent
    AccountLoginDeniedNeedTwoFactor :: 85;  // Need two-factor code to login
    ItemDeleted :: 86;                  // The thing we're trying to access has been deleted
    AccountLoginDeniedThrottle :: 87;   // login attempt failed, try to throttle response to possible attacker
    TwoFactorCodeMismatch :: 88;        // two factor code mismatch
    TwoFactorActivationCodeMismatch :: 89;  // activation code for two-factor didn't match
    AccountAssociatedToMultiplePartners :: 90;  // account has been associated with multiple partners
    NotModified :: 91;                  // data not modified
    NoMobileDevice :: 92;               // the account does not have a mobile device associated with it
    TimeNotSynced :: 93;                // the time presented is out of range or tolerance
    SmsCodeFailed :: 94;                // SMS code failure (no match, none pending, etc.)
    AccountLimitExceeded :: 95;         // Too many accounts access this resource
    AccountActivityLimitExceeded :: 96; // Too many changes to this account
    PhoneActivityLimitExceeded :: 97;   // Too many changes to this phone
    RefundToWallet :: 98;               // Cannot refund to payment method, must use wallet
    EmailSendFailure :: 99;             // Cannot send an email
    NotSettled :: 100;                  // Can't perform operation till payment has settled
    NeedCaptcha :: 101;                 // Needs to provide a valid captcha
    GSLTDenied :: 102;                  // a game server login token owned by this token's owner has been banned
    GSOwnerDenied :: 103;               // game server owner is denied for other reason (account lock, community ban, vac ban, missing phone)
    InvalidItemType :: 104;             // the type of thing we were requested to act on is invalid
    IPBanned :: 105;                    // the ip address has been banned from taking this action
    GSLTExpired :: 106;                 // this token has expired from disuse, can be reset for use
    InsufficientFunds :: 107;           // user doesn't have enough wallet funds to complete the action
    TooManyPending :: 108;              // There are too many of this thing pending already
    NoSiteLicensesFound :: 109;         // No site licenses found
    WGNetworkSendExceeded :: 110;       // the WG couldn't send a response because we exceeded max network send size
}

// Handle used to identify a connection to a remote host.
NetConnection :: enum u32
{
    Invalid :: 0; // value of an invalid NetConnection
};

// Handle used to identify a "listen socket".  Unlike traditional
// Berkeley sockets, a listen socket and a connection are two
// different abstractions.
ListenSocket :: enum u32
{
    Invalid :: 0; // value of an invalid ListenSocket
}

// Handle used to identify a poll group, used to query many
// connections at once efficiently.
PollGroup  :: enum u32
{
    Invalid :: 0; // value of an invalid PollGroup
}

// Used to return English-language diagnostic error messages to caller.
// (For debugging or spewing to a console, etc.  Not intended for UI.)
NetworkingErrMsg :: *s8;
// Max length of diagnostic error message
MaxNetworkingErrMsgSize  :: 1024;

// Identifier used for a network location point of presence.  (E.g. a Valve data center.)
// Typically you won't need to directly manipulate these.
SteamNetworkingPOPID :: u32;

// A local timestamp.  You can subtract two timestamps to get the number of elapsed
// microseconds.  This is guaranteed to increase over time during the lifetime
// of a process, but not globally across runs.  You don't need to worry about
// the value wrapping around.  Note that the underlying clock might not actually have
// microsecond resolution.
Microseconds :: s64;

// Describe the status of a particular network resource
NetworkAvailability :: enum s32 
{
    // Negative values indicate a problem.
    //
    // In general, we will not automatically retry unless you take some action that
    // depends on of requests this resource, such as querying the status, attempting
    // to initiate a connection, receive a connection, etc.  If you do not take any
    // action at all, we do not automatically retry in the background.

    CannotTry  :: -102; // A dependent resource is missing, so this service is unavailable.  (E.g. we cannot talk to routers because the Internet is down or we don't have the network config.)
    Failed     :: -101; // We have tried for enough time that we would expect to have been successful by now.  We have never been successful
    Previously :: -100; // We tried and were successful at one time, but now it looks like we have a problem

    Retrying   :: -10;  // We previously failed and are currently retrying

    // Not a problem, but not ready either
    NeverTried :: 1;    // We don't know because we haven't ever checked/tried
    Waiting    :: 2;    // We're waiting on a dependent resource to be acquired.  (E.g. we cannot obtain a cert until we are logged into Steam.  We cannot measure latency to relays until we have the network config.)
    Attempting :: 3;    // We're actively trying now, but are not yet successful.
    Current    :: 100;  // Resource is online/available
    Unknown    :: 0;    // Internal dummy/sentinel, or value is not applicable in this context
}

//
// Store an IP and port.  IPv6 is always used; IPv4 is represented using
// "IPv4-mapped" addresses: IPv4 aa.bb.cc.dd => IPv6 ::ffff:aabb:ccdd
// (RFC 4291 section 2.5.5.2.)
//
IPAddr :: struct
{
    // Constants
    // Max length of the buffer needed to hold IP formatted using ToString, including '\0'
    // ([0123:4567:89ab:cdef:0123:4567:89ab:cdef]:12345)
    MaxStringIPAddrSize :: 48;

    // Types
    IPv6 :: [16] u8;
    IPv4 :: [16] u8;

    //
    // @TODO @COMPILER BUG, Jai compiler version 0.66
    // Using IPv4 gives the struct the incorrect size.
    //
    // IPv4 :: struct // IPv4 "mapped address" (rfc4038 section 4.2) 
    // {
    //     m_8zeros : u64;
    //     m_0000   : u16;
    //     m_ffff   : u16;
    //     m_ip     : [4] u8; // NOTE: As bytes, i.e. network byte order
    // };

    // Data
    union
    {
        m_ipv4 : IPv4 = ---;
        m_ipv6 : IPv6;
    }
    m_port     : u16;

    // Functions

    // Set everything to zero.  E.g. [::]:0
    Clear            :: (self: *IPAddr) -> void                         #foreign lib "SteamAPI_SteamNetworkingIPAddr_Clear";

    // Return true if the IP is ::0.  (Doesn't check port.)
    IsIPv6AllZeros   :: (self: *IPAddr) -> bool                         #foreign lib "SteamAPI_SteamNetworkingIPAddr_IsIPv6AllZeros";

    // Set IPv6 address.  IP is interpreted as bytes, so there are no endian issues.  (Same as inaddr_in6.)  The IP can be a mapped IPv4 address
    SetIPv6          :: (self: *IPAddr, ipv6: *u8, nPort: u16) -> void  #foreign lib "SteamAPI_SteamNetworkingIPAddr_SetIPv6";

    // Sets to IPv4 mapped address.  IP and port are in host byte order.
    SetIPv4          :: (self: *IPAddr, nIP: u32, nPort: u16) -> void   #foreign lib "SteamAPI_SteamNetworkingIPAddr_SetIPv4";

    // Return true if IP is mapped IPv4
    IsIPv4           :: (self: *IPAddr) -> bool                         #foreign lib "SteamAPI_SteamNetworkingIPAddr_IsIPv4";

    // Returns IP in host byte order (e.g. aa.bb.cc.dd as 0xaabbccdd).  Returns 0 if IP is not mapped IPv4.
    GetIPv4          :: (self: *IPAddr) -> u32                          #foreign lib "SteamAPI_SteamNetworkingIPAddr_GetIPv4";

    // Set to the IPv6 localhost address ::1, and the specified port.
    SetIPv6LocalHost :: (self: *IPAddr, nPort: u16) -> void             #foreign lib "SteamAPI_SteamNetworkingIPAddr_SetIPv6LocalHost";

    // Return true if this identity is localhost.  (Either IPv6 ::1, or IPv4 127.0.0.1)
    IsLocalHost      :: (self: *IPAddr) -> bool                         #foreign lib "SteamAPI_SteamNetworkingIPAddr_IsLocalHost";

    // See if two addresses are identical
    IsEqualTo        :: (self: *IPAddr, x: *IPAddr) -> bool             #foreign lib "SteamAPI_SteamNetworkingIPAddr_IsEqualTo";

    // Print to a string, with or without the port.  Mapped IPv4 addresses are printed
    // as dotted decimal (12.34.56.78), otherwise this will print the canonical
    // form according to RFC5952.  If you include the port, IPv6 will be surrounded by
    // brackets, e.g. [::1:2]:80.  Your buffer should be at least MaxStringIPAddrSize bytes
    // to avoid truncation
    ToString         :: (self: *IPAddr, buf: *s8, cbBuf: u64, bWithPort: bool) -> void #foreign lib "SteamAPI_SteamNetworkingIPAddr_ToString";

    // Parse an IP address and optional port.  If a port is not present, it is set to 0.
    // (This means that you cannot tell if a zero port was explicitly specified.)
    ParseString      :: (self: *IPAddr, pszStr: *s8) -> bool                           #foreign lib "SteamAPI_SteamNetworkingIPAddr_ParseString";
}

//
// An abstract way to represent the identity of a network host.  All identities can
// be represented as a simple string.  Furthermore, this string representation is actually
// used on the wire in several places, even though it is less efficient, in order to
// facilitate forward compatibility.  (Old client code can handle an identity type that
// it doesn't understand.)
//
Identity :: struct
{
    // Constants
    MaxStringIdentitySize        :: 128;
    MaxGenericStringIdentitySize :: 32;
    MaxGenericBytesIdentitySize  :: 32;

    // Types
    //
    // Different methods of describing the identity of a network host
    //
    IdentityType :: enum s32 
    {
        // Dummy/empty/invalid.
        // Please note that if we parse a string that we don't recognize
        // but that appears reasonable, we will NOT use this type.  Instead
        // we'll use IdentityType.UnknownType.
        Invalid :: 0;

        // Basic platform-specific identifiers.
        SteamID :: 16;

        //
        // Special identifiers.
        //

        // Use their IP address (and port) as their "identity".
        // These types of identities are always unauthenticated.
        // They are useful for porting plain sockets code, and other
        // situations where you don't care about authentication.  In this
        // case, the local identity will be "localhost",
        // and the remote address will be their network address.
        //
        // We use the same type for either IPv4 or IPv6, and the address is
        // always store as IPv6.  We use IPv4 mapped addresses to handle IPv4.
        IPAddress :: 1;

        // Generic string/binary blobs.  It's up to your app to interpret this.
        // This library can tell you if the remote host presented a certificate
        // signed by somebody you have chosen to trust, with this identity on it.
        // It's up to you to ultimately decide what this identity means.
        GenericString :: 2;
        GenericBytes :: 3;

        // This identity type is used when we parse a string that looks like is a
        // valid identity, just of a kind that we don't recognize.  In this case, we
        // can often still communicate with the peer!  Allowing such identities
        // for types we do not recognize useful is very useful for forward
        // compatibility.
        UnknownType :: 4;
    }

    // Data
    m_eType: IdentityType; // Type of identity.

    //
    // Internal representation. Don't access this directly, use the accessors!
    //
    // Number of bytes that are relevant below.  This MUST ALWAYS be set.
    // This is important to enable old code to work with new identity types.
    m_cbSize: s32;
    union 
    {
        m_steamID64: u64;
        m_szGenericString   : [MaxGenericStringIdentitySize] s8;
        m_genericBytes      : [MaxGenericBytesIdentitySize] u8;
        m_szUnknownRawString: [MaxStringIdentitySize] s8;
        m_ip: IPAddr;
        m_reserved: [32] u32;
    }

    // Functions
    Clear            :: (self: *Identity) -> void                          #foreign lib "SteamAPI_SteamNetworkingIdentity_Clear";
    IsInvalid        :: (self: *Identity) -> bool                          #foreign lib "SteamAPI_SteamNetworkingIdentity_IsInvalid";
    SetSteamID       :: (self: *Identity, steamID: uint64_steamid) -> void #foreign lib "SteamAPI_SteamNetworkingIdentity_SetSteamID";
    GetSteamID       :: (self: *Identity) -> uint64_steamid                #foreign lib "SteamAPI_SteamNetworkingIdentity_GetSteamID";
    SetSteamID64     :: (self: *Identity, steamID: u64) -> void            #foreign lib "SteamAPI_SteamNetworkingIdentity_SetSteamID64";
    GetSteamID64     :: (self: *Identity) -> u64                           #foreign lib "SteamAPI_SteamNetworkingIdentity_GetSteamID64";
    SetIPAddr        :: (self: *Identity, addr: *IPAddr) -> void           #foreign lib "SteamAPI_SteamNetworkingIdentity_SetIPAddr";
    GetIPAddr        :: (self: *Identity) -> *IPAddr                       #foreign lib "SteamAPI_SteamNetworkingIdentity_GetIPAddr";

    SetIPv4Addr      :: inline (self: *Identity, nIPv4: u32, nPort: u16)
    {
        self.m_eType = .IPAddress;
        self.m_cbSize = size_of(type_of(m_ip));
        IPAddr.SetIPv4(*self.m_ip, nIPv4, nPort );
    }
    GetIPv4          :: inline (self: *Identity) -> u32
    {
        return ifx self.m_eType == .IPAddress then IPAddr.GetIPv4(*self.m_ip) else 0;
    }
    
    SetLocalHost     :: (self: *Identity) -> void                          #foreign lib "SteamAPI_SteamNetworkingIdentity_SetLocalHost";
    IsLocalHost      :: (self: *Identity) -> bool                          #foreign lib "SteamAPI_SteamNetworkingIdentity_IsLocalHost";
    SetGenericString :: (self: *Identity, pszString: *s8) -> bool          #foreign lib "SteamAPI_SteamNetworkingIdentity_SetGenericString";
    GetGenericString :: (self: *Identity) -> *s8                           #foreign lib "SteamAPI_SteamNetworkingIdentity_GetGenericString";
    SetGenericBytes  :: (self: *Identity, data: *void, cbLen: u32) -> bool #foreign lib "SteamAPI_SteamNetworkingIdentity_SetGenericBytes";
    GetGenericBytes  :: (self: *Identity, cbLen: *s32) -> *u8              #foreign lib "SteamAPI_SteamNetworkingIdentity_GetGenericBytes";
    IsEqualTo        :: (self: *Identity, x: *Identity) -> bool            #foreign lib "SteamAPI_SteamNetworkingIdentity_IsEqualTo";

    // Print to a human-readable string.  This is suitable for debug messages or any other
    // time you need to encode the identity as a string.  It has a URL-like format (type:<type-data>).
    // Your buffer should be at least MaxStringIdentitySize bytes big to avoid truncation.
    ToString         :: (self: *Identity, buf: *s8, cbBuf: u64) -> void    #foreign lib "SteamAPI_SteamNetworkingIdentity_ToString";

    // Parse back a string that was generated using ToString.  If we don't understand the
    // string, but it looks "reasonable" (it matches the pattern type:<type-data> and doesn't
    // have any funky characters, etc), then we will return true, and the type is set to
    // IdentityType.UnknownType.  false will only be returned if the string
    // looks invalid.
    ParseString      :: (self: *Identity, sizeofIdentity: u64, pszStr: *s8) -> bool #foreign lib "SteamAPI_SteamNetworkingIdentity_ParseString";
}

//
// Connection status: High level connection status
//
ConnectionState :: enum s32 
{
    // Dummy value used to indicate an error condition in the API.
    // Specified connection doesn't exist or has already been closed.
    None :: 0;

    // We are trying to establish whether peers can talk to each other,
    // whether they WANT to talk to each other, perform basic auth,
    // and exchange crypt keys.
    //
    // - For connections on the "client" side (initiated locally):
    //   We're in the process of trying to establish a connection.
    //   Depending on the connection type, we might not know who they are.
    //   Note that it is not possible to tell if we are waiting on the
    //   network to complete handshake packets, or for the application layer
    //   to accept the connection.
    //
    // - For connections on the "server" side (accepted through listen socket):
    //   We have completed some basic handshake and the client has presented
    //   some proof of identity.  The connection is ready to be accepted
    //   using AcceptConnection().
    //
    // In either case, any unreliable packets sent now are almost certain
    // to be dropped.  Attempts to receive packets are guaranteed to fail.
    // You may send messages if the send mode allows for them to be queued.
    // but if you close the connection before the connection is actually
    // established, any queued messages will be discarded immediately.
    // (We will not attempt to flush the queue and confirm delivery to the
    // remote host, which ordinarily happens when a connection is closed.)
    Connecting :: 1;
    
    // Some connection types use a back channel or trusted 3rd party
    // for earliest communication.  If the server accepts the connection,
    // then these connections switch into the rendezvous state.  During this
    // state, we still have not yet established an end-to-end route (through
    // the relay network), and so if you send any messages unreliable, they
    // are going to be discarded.
    FindingRoute :: 2;

    // We've received communications from our peer (and we know
    // who they are) and are all good.  If you close the connection now,
    // we will make our best effort to flush out any reliable sent data that
    // has not been acknowledged by the peer.  (But note that this happens
    // from within the application process, so unlike a TCP connection, you are
    // not totally handing it off to the operating system to deal with it.)
    Connected :: 3;

    // Connection has been closed by our peer, but not closed locally.
    // The connection still exists from an API perspective.  You must close the
    // handle to free up resources.  If there are any messages in the inbound queue,
    // you may retrieve them.  Otherwise, nothing may be done with the connection
    // except to close it.
    //
    // This status is similar to CLOSE_WAIT in the TCP state machine.
    ClosedByPeer :: 4;

    // A disruption in the connection has been detected locally.  (E.g. timeout,
    // local internet connection disrupted, etc.)
    //
    // The connection still exists from an API perspective.  You must close the
    // handle to free up resources.
    //
    // Attempts to send further messages will fail.  Any remaining received messages
    // in the queue are available.
    ProblemDetectedLocally :: 5;
}

//
// Enumerate various causes of connection termination.  These are designed to work similar
// to HTTP error codes: the numeric range gives you a rough classification as to the source
// of the problem.
//
ConnectionEnd :: enum s32
{
    // Invalid/sentinel value
    Invalid :: 0;

    //
    // Application codes.  These are the values you will pass to
    // ISockets.CloseConnection.  You can use these codes if
    // you want to plumb through application-specific reason codes.  If you don't
    // need this facility, feel free to always pass .App_Generic
    //
    // The distinction between "normal" and "exceptional" termination is
    // one you may use if you find useful, but it's not necessary for you
    // to do so.  The only place where we distinguish between normal and
    // exceptional is in connection analytics.  If a significant
    // proportion of connections terminates in an exceptional manner,
    // this can trigger an alert.
    //

    // 1xxx: Application ended the connection in a "usual" manner.
    //       E.g.: user intentionally disconnected from the server,
    //             gameplay ended normally, etc
    App_Min :: 1000;
        App_Generic  :: App_Min;
        // Use codes in this range for "normal" disconnection
    App_Max :: 1999;

    // 2xxx: Application ended the connection in some sort of exceptional
    //       or unusual manner that might indicate a bug or configuration
    //       issue.
    // 
    AppException_Min :: 2000;
        AppException_Generic  :: AppException_Min;
        // Use codes in this range for "unusual" disconnection
    AppException_Max :: 2999;

    // 3xxx: Connection failed or ended because of problem with the
    //       local host or their connection to the Internet.
    Local_Min :: 3000; // gns-jai UNUSED
        // gns-jai UNUSED
    Local_Max :: 3999; // gns-jai UNUSED

    // 4xxx: Connection failed or ended, and it appears that the
    //       cause does NOT have to do with the local host or their
    //       connection to the Internet.  It could be caused by the
    //       remote host, or it could be somewhere in between.
    Remote_Min :: 4000;

        // The connection was lost, and as far as we can tell our connection
        // to relevant services (relays) has not been disrupted.  This doesn't
        // mean that the problem is "their fault", it just means that it doesn't
        // appear that we are having network issues on our end.
        Remote_Timeout :: 4001;

        // Something was invalid with the cert or crypt handshake
        // info you gave me, I don't understand or like your key types,
        // etc.
        Remote_BadCrypt :: 4002;

        // You presented me with a cert that was I was able to parse
        // and *technically* we could use encrypted communication.
        // But there was a problem that prevents me from checking your identity
        // or ensuring that somebody int he middle can't observe our communication.
        // E.g.: - the CA key was missing (and I don't accept unsigned certs)
        // - The CA key isn't one that I trust,
        // - The cert doesn't was appropriately restricted by app, user, time, data center, etc.
        // - The cert wasn't issued to you.
        // - etc
        Remote_BadCert :: 4003;

        // These will never be returned
        // Remote_NotLoggedIn   :: 4004;
        // Remote_NotRunningApp :: 4005;

        // Something wrong with the protocol version you are using.
        // (Probably the code you are running is too old.)
        Remote_BadProtocolVersion :: 4006;


    Remote_Max :: 4999;

    // 5xxx: Connection failed for some other reason.
    Misc_Min :: 5000;

        // A failure that isn't necessarily the result of a software bug,
        // but that should happen rarely enough that it isn't worth specifically
        // writing UI or making a localized message for.
        // The debug string should contain further details.
        Misc_Generic :: 5001;

        // Generic failure that is most likely a software bug.
        Misc_InternalError :: 5002;

        // The connection to the remote host timed out, but we
        // don't know if the problem is on our end, in the middle,
        // or on their end.
        Misc_Timeout :: 5003;

        // Our peer replied that it has no record of the connection.
        // This should not happen ordinarily, but can happen in a few
        // exception cases:
        //
        // - This is an old connection, and the peer has already cleaned
        //   up and forgotten about it.  (Perhaps it timed out and they
        //   closed it and were not able to communicate this to us.)
        // - A bug or internal protocol error has caused us to try to
        //   talk to the peer about the connection before we received
        //   confirmation that the peer has accepted the connection.
        // - The peer thinks that we have closed the connection for some
        //   reason (perhaps a bug), and believes that is it is
        //   acknowledging our closure.
        Misc_PeerSentNoConnection :: 5010;

    Misc_Max :: 5999;
}

//
// Enumerate different kinds of transport that can be used
//
ConnectionInfoFlags :: enum_flags s32 
{
    Unauthenticated :: 1;  // We don't have a certificate for the remote host.
    Unencrypted :: 2;      // Information is being sent out over a wire unencrypted (by this library)
    LoopbackBuffers :: 4;  // Internal loopback buffers.  Won't be true for localhost.  (You can check the address to determine that.)  This implies ConnectionInfoFlags.Fast
    Fast :: 8;             // The connection is "fast" and "reliable".  Either internal/localhost (check the address to find out), or the peer is on the same LAN.  (Probably.  It's based on the address and the ping time, this is actually hard to determine unambiguously).
    Relayed :: 16;         // The connection is relayed somehow (SDR or TURN).
    DualWifi :: 32;        // We're taking advantage of dual-wifi multi-path
}

//
// Describe the state of a connection.
//
ConnectionInfo :: struct
{
    // Who is on the other end?  Depending on the connection type and phase of the connection, we might not know
    m_identityRemote: Identity;

    // Arbitrary user data set by the local application code
    m_nUserData: s64;
    
    // Handle to listen socket this was connected on, or ListenSocket.Invalid if we initiated the connection
    m_hListenSocket: ListenSocket;

    // Remote address.  Might be all 0's if we don't know it, or if this is N/A.
    // (E.g. Basically everything except direct UDP connection.)
    m_addrRemote: IPAddr;
    m__pad1     : u16;
    
    // What data center is the remote host in?  (0 if we don't know.)
    m_idPOPRemote: SteamNetworkingPOPID; // gns-jai UNUSED

    // What relay are we using to communicate with the remote host?
    // (0 if not applicable.)
    m_idPOPRelay: SteamNetworkingPOPID; // gns-jai UNUSED

    // High level state of the connection
    m_eState: ConnectionState;

    // Basic cause of the connection termination or problem.
    // See ConnectionEnd for the values used
    m_eEndReason: ConnectionEnd;

    // Human-readable, but non-localized explanation for connection termination or
    // problem.  This is intended for debugging / diagnostic purposes only, not to
    // display to users.  It might have some details specific to the issue.
    m_szEndDebug: [MaxConnectionCloseReasonSize] s8;
    // Max length, in bytes (including null terminator) of the reason string when a connection is closed.
    MaxConnectionCloseReasonSize :: 128;

    // Debug description.  This includes the internal connection ID, connection type
    // (and peer information), and any name given to the connection by the app.
    //  This string is used in various internal logging messages.
    m_szConnectionDescription: [MaxConnectionDescriptionSize] s8;
    // Max length, in bytes (include null terminator) of debug description of a connection.
    MaxConnectionDescriptionSize :: 128;

    /// Misc flags.  Bitmask of ConnectionInfoFlags.Xxxx
    m_nFlags: ConnectionInfoFlags;

    // Internal stuff, room to change API easily
    reserved: [63] u32;
}

//
// Quick connection state, pared down to something you could call
// more frequently without it being too big of a perf hit.
//
QuickConnectionStatus :: struct
{
    // High level state of the connection
    m_eState: ConnectionState;

    // Current ping (ms)
    m_nPing: s32;

    // Connection quality measured locally, 0-1, (Percentage of packets delivered end-to-end in order).
    m_flConnectionQualityLocal: float32;

    // Packet delivery success rate as observed from remote host
    m_flConnectionQualityRemote: float32;

    // Current data rates from recent history.
    m_flOutPacketsPerSec : float32;
    m_flOutBytesPerSec   : float32;
    m_flInPacketsPerSec  : float32;
    m_flInBytesPerSec    : float32;

    // Estimate rate that we believe that we can send data to our peer.
    // Note that this could be significantly higher than m_flOutBytesPerSec,
    // meaning the capacity of the channel is higher than you are sending data.
    m_nSendRateBytesPerSecond: s32;

    // Number of bytes pending to be sent.  This is data that you have recently
    // requested to be sent but has not yet actually been put on the wire.  The
    // reliable number ALSO includes data that was previously placed on the wire,
    // but has now been scheduled for re-transmission.  Thus, it's possible to
    // observe m_cbPendingReliable increasing between two checks, even if no
    // calls were made to send reliable data between the checks.  Data that is
    // awaiting the Nagle delay will appear in these numbers.
    m_cbPendingUnreliable: s32;
    m_cbPendingReliable: s32;

    // Number of bytes of reliable data that has been placed on the wire, but
    // for which we have not yet received an acknowledgment, and thus we may
    // have to re-transmit.
    m_cbSentUnackedReliable: s32;

    // If you asked us to send a message right now, how long would that message
    // sit in the queue before we actually started putting packets on the wire?
    // (And assuming Nagle does not cause any packets to be delayed.)
    //
    // In general, data that is sent by the application is limited by the
    // bandwidth of the channel.  If you send data faster than this, it must
    // be queued and put on the wire at a metered rate.  Even sending a small amount
    // of data (e.g. a few MTU, say ~3k) will require some of the data to be delayed
    // a bit.
    //
    // In general, the estimated delay will be approximately equal to
    //
    //     ( m_cbPendingUnreliable+m_cbPendingReliable ) / m_nSendRateBytesPerSecond
    //
    // plus or minus one MTU.  It depends on how much time has elapsed since the last
    // packet was put on the wire.  For example, the queue might have *just* been emptied,
    // and the last packet placed on the wire, and we are exactly up against the send
    // rate limit.  In that case, we might need to wait for one packet's worth of time to
    // elapse before we can send again.  On the other extreme, the queue might have data
    // in it waiting for Nagle.  (This will always be less than one packet, because as soon
    // as we have a complete packet we would send it.)  In that case, we might be ready
    // to send data now, and this value will be 0.
    m_usecQueueTime: Microseconds;

    // Internal stuff, room to change API easily.
    reserved: [16] u32;
}

//
// Configuration Scope
//
ConfigScope :: enum s32 
{
    // Get/set global option, or defaults.  Even options that apply to more specific scopes
    // have global scope, and you may be able to just change the global defaults.  If you
    // need different settings per connection (for example), then you will need to set those
    // options at the more specific scope.
    Global :: 1;

    // Some options are specific to a particular interface.  Note that all connection
    // and listen socket settings can also be set at the interface level, and they will
    // apply to objects created through those interfaces.
    SocketsInterface :: 2;

    // Options for a listen socket.  Listen socket options can be set at the interface layer,
    // if you have multiple listen sockets and they all use the same options.
    // You can also set connection options on a listen socket, and they set the defaults
    // for all connections accepted through this listen socket.  (They will be used if you don't
    // set a connection option.)
    ListenSocket :: 3;

    // Options for a specific connection.
    Connection :: 4;
}

//
// Different configuration values have different data types
//
ConfigDataType :: enum s32 
{
    _s32      :: 1;
    _s64      :: 2;
    _float32  :: 3;
    _c_string :: 4; // null terminated
    _ptr      :: 5;
}

//
// Configuration option lebels
// Rename: ESteamNetworkingConfigValue -> ConfigValueLabel
//
ConfigValueLabel :: enum s32 
{
    Invalid :: 0;

    //
    // Connection options
    //

    // [connection int32] Timeout value (in ms) to use when first connecting
    TimeoutInitial :: 24;

    // [connection int32] Timeout value (in ms) to use after connection is established
    TimeoutConnected :: 25;

    // [connection int32] Upper limit of buffered pending bytes to be sent,
    // if this is reached SendMessage will return Result.LimitExceeded
    // Default is 512k (524288 bytes)
    SendBufferSize :: 9;

	/// [connection int64] Get/set userdata as a configuration option.
	/// The default value is -1.   You may want to set the user data as
	/// a config value, instead of using ISteamNetworkingSockets::SetConnectionUserData
	/// in two specific instances:
	///
	/// - You wish to set the userdata atomically when creating
	///   an outbound connection, so that the userdata is filled in properly
	///   for any callbacks that happen.  However, note that this trick
	///   only works for connections initiated locally!  For incoming
	///   connections, multiple state transitions may happen and
	///   callbacks be queued, before you are able to service the first
	///   callback!  Be careful!
	///
	/// - You can set the default userdata for all newly created connections
	///   by setting this value at a higher level (e.g. on the listen
	///   socket or at the global level.)  Then this default
	///   value will be inherited when the connection is created.
	///   This is useful in case -1 is a valid userdata value, and you
	///   wish to use something else as the default value so you can
	///   tell if it has been set or not.
	///
	///   HOWEVER: once a connection is created, the effective value is
	///   then bound to the connection.  Unlike other connection options,
	///   if you change it again at a higher level, the new value will not
	///   be inherited by connections.
	///
	/// Using the userdata field in callback structs is not advised because
	/// of tricky race conditions.  Instead, you might try one of these methods:
	///
	/// - Use a separate map with the HSteamNetConnection as the key.
	/// - Fetch the userdata from the connection in your callback
	///   using ISockets::GetConnectionUserData, to
	//    ensure you have the current value.
	ConnectionUserData :: 40;

    // [connection int32] Minimum/maximum send rate clamp, 0 is no limit.
    // This value will control the min/max allowed sending rate that 
    // bandwidth estimation is allowed to reach.  Default is 0 (no-limit)
    SendRateMin :: 10;
    SendRateMax :: 11;

    // [connection int32] Nagle time, in microseconds.  When SendMessage is called, if
    // the outgoing message is less than the size of the MTU, it will be
    // queued for a delay equal to the Nagle timer value.  This is to ensure
    // that if the application sends several small messages rapidly, they are
    // coalesced into a single packet.
    // See historical RFC 896.  Value is in microseconds. 
    // Default is 5000us (5ms).
    NagleTime :: 12;

    // [connection int32] Don't automatically fail IP connections that don't have
    // strong auth.  On clients, this means we will attempt the connection even if
    // we don't know our identity or can't get a cert.  On the server, it means that
    // we won't automatically reject a connection due to a failure to authenticate.
    // (You can examine the incoming connection and decide whether to accept it.)
    //
    // This is a dev configuration value, and you should not let users modify it in
    // production.
    IP_AllowWithoutAuth :: 23;

    // [connection int32] Do not send UDP packets with a payload of
    // larger than N bytes.  If you set this, ConfigValueLabel.MTU_DataSize
    // is automatically adjusted
    MTU_PacketSize :: 32;

    // [connection int32] (read only) Maximum message size you can send that
    // will not fragment, based on ConfigValueLabel.MTU_PacketSize
    MTU_DataSize :: 33;

    // [connection int32] Allow unencrypted (and unauthenticated) communication.
    // 0: Not allowed (the default)
    // 1: Allowed, but prefer encrypted
    // 2: Allowed, and preferred
    // 3: Required.  (Fail the connection if the peer requires encryption.)
    //
    // This is a dev configuration value, since its purpose is to disable encryption.
    // You should not let users modify it in production.  (But note that it requires
    // the peer to also modify their value in order for encryption to be disabled.)
    Unencrypted :: 34;

    // [connection int32] Set this to 1 on outbound connections and listen sockets,
    // to enable "symmetric connect mode", which is useful in the following
    // common peer-to-peer use case:
    //
    // - The two peers are "equal" to each other.  (Neither is clearly the "client"
    //   or "server".)
    // - Either peer may initiate the connection, and indeed they may do this
    //   at the same time
    // - The peers only desire a single connection to each other, and if both
    //   peers initiate connections simultaneously, a protocol is needed for them
    //   to resolve the conflict, so that we end up with a single connection.
    //
    // This use case is both common, and involves subtle race conditions and tricky
    // pitfalls, which is why the API has support for dealing with it.
    //
    // If an incoming connection arrives on a listen socket or via custom signaling,
    // and the application has not attempted to make a matching outbound connection
    // in symmetric mode, then the incoming connection can be accepted as usual.
    // A "matching" connection means that the relevant endpoint information matches.
    // (At the time this comment is being written, this is only supported for P2P
    // connections, which means that the peer identities must match, and the virtual
    // port must match.  At a later time, symmetric mode may be supported for other
    // connection types.)
    //
    // If connections are initiated by both peers simultaneously, race conditions
    // can arise, but fortunately, most of them are handled internally and do not
    // require any special awareness from the application.  However, there
    // is one important case that application code must be aware of:
    // If application code attempts an outbound connection using a ConnectXxx
    // function in symmetric mode, and a matching incoming connection is already
    // waiting on a listen socket, then instead of forming a new connection,
    // the ConnectXxx call will accept the existing incoming connection, and return
    // a connection handle to this accepted connection.
    // IMPORTANT: in this case, a ConnectionStatusChanged
    // has probably *already* been posted to the queue for the incoming connection!
    // (Once callbacks are posted to the queue, they are not modified.)  It doesn't
    // matter if the callback has not been consumed by the app.  Thus, application
    // code that makes use of symmetric connections must be aware that, when processing a
    // ConnectionStatusChanged for an incoming connection, the
    // m_conn may refer to a new connection that the app has has not
    // seen before (the usual case), but it may also refer to a connection that
    // has already been accepted implicitly through a call to Connect()!  In this
    // case, AcceptConnection() will return Result.DuplicateRequest.
    //
    // Only one symmetric connection to a given peer (on a given virtual port)
    // may exist at any given time.  If client code attempts to create a connection,
    // and a (live) connection already exists on the local host, then either the
    // existing connection will be accepted as described above, or the attempt
    // to create a new connection will fail.  Furthermore, linger mode functionality
    // is not supported on symmetric connections.
    //
    // A more complicated race condition can arise if both peers initiate a connection
    // at roughly the same time.  In this situation, each peer will receive an incoming
    // connection from the other peer, when the application code has already initiated
    // an outgoing connection to that peer.  The peers must resolve this conflict and
    // decide who is going to act as the "server" and who will act as the "client".
    // Typically the application does not need to be aware of this case as it is handled
    // internally.  On both sides, the will observe their outbound connection being
    // "accepted", although one of them one have been converted internally to act
    // as the "server".
    //
    // In general, symmetric mode should be all-or-nothing: do not mix symmetric
    // connections with a non-symmetric connection that it might possible "match"
    // with.  If you use symmetric mode on any connections, then both peers should
    // use it on all connections, and the corresponding listen socket, if any.  The
    // behaviour when symmetric and ordinary connections are mixed is not defined by
    // this API, and you should not rely on it.  (This advice only applies when connections
    // might possibly "match".  For example, it's OK to use all symmetric mode
    // connections on one virtual port, and all ordinary, non-symmetric connections
    // on a different virtual port, as there is no potential for ambiguity.)
    //
    // When using the feature, you should set it in the following situations on
    // applicable objects:
    //
    // - When creating an outbound connection using ConnectXxx function
    // - When creating a listen socket.  (Note that this will automatically cause
    //   any accepted connections to inherit the flag.)
    // - When using custom signaling, before accepting an incoming connection.
    //
    // Setting the flag on listen socket and accepted connections will enable the
    // API to automatically deal with duplicate incoming connections, even if the
    // local host has not made any outbound requests.  (In general, such duplicate
    // requests from a peer are ignored internally and will not be visible to the
    // application code.  The previous connection must be closed or resolved first.)
    SymmetricConnect :: 37;

    // [connection int32] For connection types that use "virtual ports", this can be used
    // to assign a local virtual port.  For incoming connections, this will always be the
    // virtual port of the listen socket (or the port requested by the remote host if custom
    // signaling is used and the connection is accepted), and cannot be changed.  For
    // connections initiated locally, the local virtual port will default to the same as the
    // requested remote virtual port, if you do not specify a different option when creating
    // the connection.  The local port is only relevant for symmetric connections, when
    // determining if two connections "match."  In this case, if you need the local and remote
    // port to differ, you can set this value.
    //
    // You can also read back this value on listen sockets.
    //
    // This value should not be read or written in any other context.
    LocalVirtualPort :: 38;

    //
    // Simulating network conditions
    //
    // These are global (not per-connection) because they apply at
    // a relatively low UDP layer.
    //

	/// [global float, 0--100] Randomly discard N pct of packets instead of sending/recv
	/// This is a global option only, since it is applied at a low level
	/// where we don't have much context
	FakePacketLoss_Send :: 2;
	FakePacketLoss_Recv :: 3;

	/// [global int32].  Delay all outbound/inbound packets by N ms
	FakePacketLag_Send :: 4;
	FakePacketLag_Recv :: 5;

	/// [global float] 0-100 Percentage of packets we will add additional delay
	/// to (causing them to be reordered)
	FakePacketReorder_Send :: 6;
	FakePacketReorder_Recv :: 7;

	/// [global int32] Extra delay, in ms, to apply to reordered packets.
	FakePacketReorder_Time :: 8;

	/// [global float 0--100] Globally duplicate some percentage of packets we send
	FakePacketDup_Send :: 26;
	FakePacketDup_Recv :: 27;

	/// [global int32] Amount of delay, in ms, to delay duplicated packets.
	/// (We chose a random delay between 0 and this value)
	FakePacketDup_TimeMax :: 28;

	/// [global int32] Trace every UDP packet, similar to Wireshark or tcpdump.
	/// Value is max number of bytes to dump.  -1 disables tracing.
	// 0 only traces the info but no actual data bytes
	PacketTraceMaxBytes :: 41;


	// [global int32] Global UDP token bucket rate limits.
	// "Rate" refers to the steady state rate. (Bytes/sec, the
	// rate that tokens are put into the bucket.)  "Burst"
	// refers to the max amount that could be sent in a single
	// burst.  (In bytes, the max capacity of the bucket.)
	// Rate=0 disables the limiter entirely, which is the default.
	// Burst=0 disables burst.  (This is not realistic.  A
	// burst of at least 4K is recommended; the default is higher.)
	FakeRateLimit_Send_Rate :: 42;
	FakeRateLimit_Send_Burst :: 43;
	FakeRateLimit_Recv_Rate :: 44;
	FakeRateLimit_Recv_Burst :: 45;

    //
    // Callbacks
    //

    // On Steam, you may use the default Steam callback dispatch mechanism.  If you prefer
    // to not use this dispatch mechanism (or you are not running with Steam), or you want
    // to associate specific functions with specific listen sockets or connections, you can
    // register them as configuration values.
    //
    // Note also that IUtils has some helpers to set these globally.

    // [connection ConnectionStatusChangedFunctionType] Callback that will be invoked
    // when the state of a connection changes.
    //
    // IMPORTANT: callbacks are dispatched to the handler that is in effect at the time
    // the event occurs, which might be in another thread.  For example, immediately after
    // creating a listen socket, you may receive an incoming connection.  And then immediately
    // after this, the remote host may close the connection.  All of this could happen
    // before the function to create the listen socket has returned.  For this reason,
    // callbacks usually must be in effect at the time of object creation.  This means
    // you should set them when you are creating the listen socket or connection, or have
    // them in effect so they will be inherited at the time of object creation.
    //
    // For example:
    // 
    // MyConnectionStatusChangedHandler :: ConnectionStatusChangedFunctionType;
    //
    // options : [1] ConfigValue;
    // ConfigValue.SetPtr(*options[0], .Callback_ConnectionStatusChanged, xx MyConnectionStatusChangedHandler);
    // serverLocalAddr : IPAddr;
    // IPAddr.Clear(*serverLocalAddr);
    // serverLocalAddr.m_port = 6789; // Port to listen on
    // listen_socket = Sockets.CreateListenSocketIP(*serverLocalAddr, options.count, options.data);
    //
    // When accepting an incoming connection, there is no atomic way to switch the
    // callback.  However, if the connection is DOA, AcceptConnection() will fail, and
    // you can fetch the state of the connection at that time.
    //
    // If all connections and listen sockets can use the same callback, the simplest
    // method is to set it globally before you create any listen sockets or connections.
    Callback_ConnectionStatusChanged :: 201;

    // [global AuthenticationStatusChangedFunctionType] Callback that will be invoked
    // when our auth state changes.  If you use this, install the callback before creating
    // any connections or listen sockets, and don't change it.
    // See: IUtils.SetGlobalCallbackAuthenticationStatusChanged
    Callback_AuthStatusChanged :: 202;

    //
    // Misc / debugging
    //

	// [global int32] 0 or 1.  Some variables are "dev" variables.  They are useful
	// for debugging, but should not be adjusted in production.  When this flag is false (the default),
	// such variables will not be enumerated by the ISteamnetworkingUtils::GetFirstConfigValue
	// ISteamNetworkingUtils::GetConfigValueInfo functions.  The idea here is that you
	// can use those functions to provide a generic mechanism to set any configuration
	// value from a console or configuration file, looking up the variable by name.  Depending
	// on your game, modifying other configuration values may also have negative effects, and
	// you may wish to further lock down which variables are allowed to be modified by the user.
	// (Maybe no variables!)  Or maybe you use a whitelist or blacklist approach.
	//
	// (This flag is itself a dev variable.)
	EnumerateDevVars :: 35;

    //
    // Log levels for debugging information of various subsystems.
    // Higher numeric values will cause more stuff to be printed.
    // See IUtils.SetDebugOutputFunction for more
    // information
    //
    // The default for all values is DebugOutputLevel.Warning.
    //
    LogLevel_AckRTT        :: 13; // [connection int32] RTT calculations for inline pings and replies
    LogLevel_PacketDecode  :: 14; // [connection int32] log SNP packets send/recv
    LogLevel_Message       :: 15; // [connection int32] log each message send/recv
    LogLevel_PacketGaps    :: 16; // [connection int32] dropped packets
}

//
// In a few places we need to set configuration options on listen sockets and connections, and
// have them take effect *before* the listen socket or connection really starts doing anything.
// Creating the object and then setting the options "immediately" after creation doesn't work
// completely, because network packets could be received between the time the object is created and
// when the options are applied.  To set options at creation time in a reliable way, they must be
// passed to the creation function.  This structure is used to pass those options.
//
// For the meaning of these fields, see IUtils.SetConfigValue.  Basically
// when the object is created, we just iterate over the list of options and call
// IUtils.SetConfigValueStruct, where the scope arguments are supplied by the
// object being created.
//
ConfigValue :: struct
{
    m_eValueLabel : ConfigValueLabel;  // Which option is being set
    m_eDataType   : ConfigDataType;    // Which field below did you fill in?
    
    m_val : union                      // Option value
    {
        m_s32: s32;
        m_s64: s64;
        m_float32: float32;
        m_c_string: *s8;               // Points to your '\0'-terminated buffer
        m_ptr: *void;
    };

    // Shortcut helpers to set the type and value in a single call
    SetInt32 :: (config : *ConfigValue, eVal : ConfigValueLabel, data : s32)
    {
        config.m_eValueLabel = eVal;
        config.m_eDataType = ._s32;
        config.m_val.m_s32 = data;
    }
    SetInt64 :: (config : *ConfigValue, eVal : ConfigValueLabel, data : s64)
    {
        config.m_eValueLabel = eVal;
        config.m_eDataType = ._s64;
        config.m_val.m_s64 = data;
    }
    SetFloat :: (config : *ConfigValue, eVal : ConfigValueLabel, data : float )
    {
        config.m_eValueLabel = eVal;
        config.m_eDataType = ._float32;
        config.m_val.m_float32 = data;
    }
    SetPtr :: (config : *ConfigValue, eVal : ConfigValueLabel, data : *void)
    {
        config.m_eValueLabel = eVal;
        config.m_eDataType = ._ptr;
        config.m_val.m_ptr = data;
    }
    SetString :: (config : *ConfigValue, eVal : ConfigValueLabel, data : *s8) // WARNING - Just saves your pointer.  Does NOT make a copy of the string
    {
        config.m_eValueLabel = eVal;
        config.m_eDataType = ._ptr;
        config.m_val.m_c_string = data;
    }
}

//
// Debug output
//

// Detail level for diagnostic output callback.
// See IUtils.SetDebugOutputFunction
DebugOutputLevel :: enum s32 
{
    None       :: 0;
    Bug        :: 1; // You used the API incorrectly, or an internal error happened
    Error      :: 2; // Run-time error condition that isn't the result of a bug.  (E.g. we are offline, cannot bind a port, etc)
    Important  :: 3; // Nothing is wrong, but this is an important notification
    Warning    :: 4;
    Msg        :: 5; // Recommended amount
    Verbose    :: 6; // Quite a bit
    Debug      :: 7; // Practically everything
    Everything :: 8; // Wall of text, detailed packet contents breakdown, etc
}

// Setup callback for debug output, and the desired verbosity you want.
DebugOutputFunctionType :: #type (a0: DebugOutputLevel, a1: *s8) -> void #c_call;

// This callback is posted whenever a connection is created, destroyed, or changes state.
// The m_info field will contain a complete description of the connection at the time the
// change occurred and the callback was posted.  In particular, m_eState will have the
// new connection state.
//
// You will usually need to listen for this callback to know when:
// - A new connection arrives on a listen socket.
//   m_info.m_hListenSocket will be set, m_eOldState = ConnectionState.None,
//   and m_info.m_eState = ConnectionState.Connecting.
//   See ISockets.AcceptConnection.
//
// - A connection you initiated has been accepted by the remote host.
//   m_eOldState = ConnectionState.Connecting, and
//   m_info.m_eState = ConnectionState.Connected.
//   Some connections might transition to ConnectionState.FindingRoute first.
//
// - A connection has been actively rejected or closed by the remote host.
//   m_eOldState = ConnectionState.Connecting or ConnectionState.Connected,
//   and m_info.m_eState = ConnectionState.ClosedByPeer.  m_info.m_eEndReason
//   and m_info.m_szEndDebug will have for more details.
//   NOTE: upon receiving this callback, you must still destroy the connection using
//   ISockets.CloseConnection to free up local resources.  (The details
//   passed to the function are not used in this case, since the connection is already closed.)
//
// - A problem was detected with the connection, and it has been closed by the local host.
//   The most common failure is timeout, but other configuration or authentication failures
//   can cause this.  m_eOldState = ConnectionState.Connecting or
//   ConnectionState.Connected, and m_info.m_eState = ConnectionState.ProblemDetectedLocally.
//   m_info.m_eEndReason and m_info.m_szEndDebug will have for more details.
//   NOTE: upon receiving this callback, you must still destroy the connection using
//   ISockets.CloseConnection to free up local resources.  (The details
//   passed to the function are not used in this case, since the connection is already closed.)
//
// Remember that callbacks are posted to a queue, and networking connections can
// change at any time.  It is possible that the connection has already changed
// state by the time you process this callback.
//
// Also note that callbacks will be posted when connections are created and destroyed by your own API calls.
ConnectionStatusChanged :: struct
{
    m_conn: NetConnection;        // Connection handle
    m_info: ConnectionInfo;       // Full connection info
    m_eOldState: ConnectionState; // Previous state.  (Current state is in m_info.m_eState)
}

// A struct used to describe our readiness to participate in authenticated,
// encrypted communication.  To do this we need:
//
// - The list of trusted CA certificates that might be relevant for this
//   app.
// - A valid certificate issued by a CA.
//
// This callback is posted whenever the state of our readiness changes.
AuthenticationStatus :: struct
{
    m_eAvail: NetworkAvailability; // Status
    m_debugMsg: [256] s8;          // Non-localized English language status. For diagnostic/debugging purposes only.
}

uint64_steamid :: u64; // Used when passing or returning CSteamID
intptr         :: u64; // Used for scopeObj

ConnectionStatusChangedFunctionType     :: #type (a0: *ConnectionStatusChanged) -> void #c_call;
AuthenticationStatusChangedFunctionType :: #type (a0: *AuthenticationStatus)    -> void #c_call;

ISteamNetworkingConnectionSignaling :: void;
//
// Custom signaling functions
//
FSteamNetworkingSocketsCustomSignaling_SendSignal :: #type (ctx: *void, hConn: NetConnection, info: *ConnectionInfo, pMsg: *void, cbMsg: s32) -> bool #c_call;
FSteamNetworkingSocketsCustomSignaling_Release    :: #type (ctx: *void) #c_call;
SteamAPI_ISteamNetworkingSockets_CreateCustomSignaling :: (
    ctx: *void,                                                      //< pointer to something useful you understand.  Will be passed to your callbacks.
	fnSendSignal: FSteamNetworkingSocketsCustomSignaling_SendSignal, //< Callback to send a signal.   See ISteamNetworkingConnectionSignaling::SendSignal
	fnRelease: FSteamNetworkingSocketsCustomSignaling_Release        //< callback to do any cleanup.  See ISteamNetworkingConnectionSignaling::Release.  You can pass NULL if you don't need to do any cleanup.
) -> *ISteamNetworkingConnectionSignaling #foreign lib "SteamAPI_ISteamNetworkingSockets_CreateCustomSignaling";

FSteamNetworkingCustomSignalingRecvContext_OnConnectRequest    :: #type (ctx: *void, hConn: NetConnection, identityPeer: *Identity, nLocalVirtualPort: s32) -> *ISteamNetworkingConnectionSignaling #c_call;
FSteamNetworkingCustomSignalingRecvContext_SendRejectionSignal :: #type (ctx: *void, identityPeer: *Identity, pMsg: *void, cbMsg: s32) #c_call;
SteamAPI_ISteamNetworkingSockets_ReceivedP2PCustomSignal2 :: (                            //  Same as SteamAPI_ISteamNetworkingSockets_ReceivedP2PCustomSignal, but using plain C primitives.
	self: *ISockets, pMsg: *void, cbMsg: s32,                                             //< Same as SteamAPI_ISteamNetworkingSockets_ReceivedP2PCustomSignal
	ctx: *void,                                                                           //< pointer to something useful you understand.  Will be passed to your callbacks.
	fnOnConnectRequest: FSteamNetworkingCustomSignalingRecvContext_OnConnectRequest,      //< callback for sending a signal.  Required.  See ISteamNetworkingSignalingRecvContext::OnConnectRequest
	fnSendRejectionSignal: FSteamNetworkingCustomSignalingRecvContext_SendRejectionSignal //< callback when we wish to actively reject the connection.  Optional, pass NULL if you don't need this.  See ISteamNetworkingSignalingRecvContext::SendRejectionSignal
) -> bool #foreign lib "SteamAPI_ISteamNetworkingSockets_ReceivedP2PCustomSignal2";


#scope_file

// See WrapISockets for API comments
ISockets :: struct
{   
    CreateListenSocketIP        :: (self: *ISockets, localAddress: *IPAddr, nOptions: s32, pOptions: *ConfigValue) -> ListenSocket                #foreign lib "SteamAPI_ISteamNetworkingSockets_CreateListenSocketIP";
    ConnectByIPAddress          :: (self: *ISockets, address: *IPAddr, nOptions: s32, pOptions: *ConfigValue) -> NetConnection                    #foreign lib "SteamAPI_ISteamNetworkingSockets_ConnectByIPAddress";
    AcceptConnection            :: (self: *ISockets, conn: NetConnection) -> Result                                                               #foreign lib "SteamAPI_ISteamNetworkingSockets_AcceptConnection";
    CloseConnection             :: (self: *ISockets, peer: NetConnection, reason: ConnectionEnd, debugMessage: *s8, bEnableLinger: bool) -> bool  #foreign lib "SteamAPI_ISteamNetworkingSockets_CloseConnection";
    CloseListenSocket           :: (self: *ISockets, socket: ListenSocket) -> bool                                                                #foreign lib "SteamAPI_ISteamNetworkingSockets_CloseListenSocket";
    SetConnectionUserData       :: (self: *ISockets, peer: NetConnection, nUserData: s64) -> bool                                                 #foreign lib "SteamAPI_ISteamNetworkingSockets_SetConnectionUserData";
    GetConnectionUserData       :: (self: *ISockets, peer: NetConnection) -> s64                                                                  #foreign lib "SteamAPI_ISteamNetworkingSockets_GetConnectionUserData";
    SetConnectionName           :: (self: *ISockets, peer: NetConnection, name: *s8) -> void                                                      #foreign lib "SteamAPI_ISteamNetworkingSockets_SetConnectionName";
    GetConnectionName           :: (self: *ISockets, peer: NetConnection, name: *s8, maxLen: s32) -> bool                                         #foreign lib "SteamAPI_ISteamNetworkingSockets_GetConnectionName";
    SendMessageToConnection     :: (self: *ISockets, conn: NetConnection, data: *void, cbData: u32, sendFlags: NetworkingSend, pOutMessageNumber: *s64) -> Result #foreign lib "SteamAPI_ISteamNetworkingSockets_SendMessageToConnection";
    SendMessages                :: (self: *ISockets, nMessages: s32, pMessages: **NetworkingMessage, pOutMessageNumberOrResult: *s64) -> void     #foreign lib "SteamAPI_ISteamNetworkingSockets_SendMessages";
    FlushMessagesOnConnection   :: (self: *ISockets, conn: NetConnection) -> Result                                                               #foreign lib "SteamAPI_ISteamNetworkingSockets_FlushMessagesOnConnection";
    ReceiveMessagesOnConnection :: (self: *ISockets, conn: NetConnection, ppOutMessages: **NetworkingMessage, nMaxMessages: s32) -> s32           #foreign lib "SteamAPI_ISteamNetworkingSockets_ReceiveMessagesOnConnection";
    GetConnectionInfo           :: (self: *ISockets, conn: NetConnection, info: *ConnectionInfo) -> bool                                          #foreign lib "SteamAPI_ISteamNetworkingSockets_GetConnectionInfo";
    GetQuickConnectionStatus    :: (self: *ISockets, conn: NetConnection, stats: *QuickConnectionStatus) -> bool                                  #foreign lib "SteamAPI_ISteamNetworkingSockets_GetQuickConnectionStatus";
    GetDetailedConnectionStatus :: (self: *ISockets, conn: NetConnection, buf: *s8, cbBuf: s32) -> s32                                            #foreign lib "SteamAPI_ISteamNetworkingSockets_GetDetailedConnectionStatus";
    GetListenSocketAddress      :: (self: *ISockets, socket: ListenSocket, address: *IPAddr) -> bool                                              #foreign lib "SteamAPI_ISteamNetworkingSockets_GetListenSocketAddress";
    CreateSocketPair            :: (self: *ISockets, pOutConnection1: *NetConnection, pOutConnection2: *NetConnection, bUseNetworkLoopback: bool, pIdentity1: *Identity, pIdentity2: *Identity) -> bool #foreign lib "SteamAPI_ISteamNetworkingSockets_CreateSocketPair";
    GetIdentity                 :: (self: *ISockets, pIdentity: *Identity) -> bool                                                                #foreign lib "SteamAPI_ISteamNetworkingSockets_GetIdentity";
    InitAuthentication          :: (self: *ISockets) -> NetworkAvailability                                                                       #foreign lib "SteamAPI_ISteamNetworkingSockets_InitAuthentication";
    GetAuthenticationStatus     :: (self: *ISockets, details: *AuthenticationStatus) -> NetworkAvailability                                       #foreign lib "SteamAPI_ISteamNetworkingSockets_GetAuthenticationStatus";
    CreatePollGroup             :: (self: *ISockets) -> PollGroup                                                                                 #foreign lib "SteamAPI_ISteamNetworkingSockets_CreatePollGroup";
    DestroyPollGroup            :: (self: *ISockets, pollGroup: PollGroup) -> bool                                                                #foreign lib "SteamAPI_ISteamNetworkingSockets_DestroyPollGroup";
    SetConnectionPollGroup      :: (self: *ISockets, conn: NetConnection, pollGroup: PollGroup) -> bool                                           #foreign lib "SteamAPI_ISteamNetworkingSockets_SetConnectionPollGroup";
    ReceiveMessagesOnPollGroup  :: (self: *ISockets, pollGroup: PollGroup, ppOutMessages: **NetworkingMessage, nMaxMessages: s32) -> s32          #foreign lib "SteamAPI_ISteamNetworkingSockets_ReceiveMessagesOnPollGroup";
    GetCertificateRequest       :: (self: *ISockets, pcbBlob: *s32, pBlob: *void, errMsg: *NetworkingErrMsg) -> bool                              #foreign lib "SteamAPI_ISteamNetworkingSockets_GetCertificateRequest";
    SetCertificate              :: (self: *ISockets, pCertificate: *void, cbCertificate: s32, errMsg: *NetworkingErrMsg) -> bool                  #foreign lib "SteamAPI_ISteamNetworkingSockets_SetCertificate";
    RunCallbacks                :: (self: *ISockets) -> void                                                                                      #foreign lib "SteamAPI_ISteamNetworkingSockets_RunCallbacks";
}
#assert(size_of(ISockets) == 0);
// See WrapIUtils for API comments
IUtils :: struct
{
    //
    // Return value of IUtils.GetConfigValue
    //
    GetConfigValueResult :: enum s32 
    {
        BadLabel       :: -1; // No such configuration label
        BadScopeObj    :: -2; // Bad connection handle, etc
        BufferTooSmall :: -3; // Couldn't fit the result in your buffer
        OK             :: 1;
        OKInherited    :: 2;  // A value was not set at this level, but the effective (inherited) value was returned.
    }

    // Functions
    AllocateMessage                :: (self: *IUtils, size: s32) -> *NetworkingMessage                                           #foreign lib "SteamAPI_ISteamNetworkingUtils_AllocateMessage";
    GetLocalTimestamp              :: (self: *IUtils) -> Microseconds                                                            #foreign lib "SteamAPI_ISteamNetworkingUtils_GetLocalTimestamp";
    SetDebugOutputFunction         :: (self: *IUtils, detailLevel: DebugOutputLevel, pfnFunc: DebugOutputFunctionType) -> void   #foreign lib "SteamAPI_ISteamNetworkingUtils_SetDebugOutputFunction";
    SetGlobalConfigValueInt32      :: (self: *IUtils, valueLabel: ConfigValueLabel, val: s32) -> bool                            #foreign lib "SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueInt32";
    SetGlobalConfigValueFloat      :: (self: *IUtils, valueLabel: ConfigValueLabel, val: float32) -> bool                        #foreign lib "SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueFloat";
    SetGlobalConfigValueString     :: (self: *IUtils, valueLabel: ConfigValueLabel, val: *s8) -> bool                            #foreign lib "SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueString";
    SetGlobalConfigValuePtr        :: (self: *IUtils, valueLabel: ConfigValueLabel, val: *void) -> bool                          #foreign lib "SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValuePtr";
    SetConnectionConfigValueInt32  :: (self: *IUtils, conn: NetConnection, valueLabel: ConfigValueLabel, val: s32) -> bool       #foreign lib "SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueInt32";
    SetConnectionConfigValueFloat  :: (self: *IUtils, conn: NetConnection, valueLabel: ConfigValueLabel, val: float32) -> bool   #foreign lib "SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueFloat";
    SetConnectionConfigValueString :: (self: *IUtils, conn: NetConnection, valueLabel: ConfigValueLabel, val: *s8) -> bool       #foreign lib "SteamAPI_ISteamNetworkingUtils_SetConnectionConfigValueString";
    SetConfigValue                 :: (self: *IUtils, valueLabel: ConfigValueLabel, scope: ConfigScope, scopeObj: intptr, eDataType: ConfigDataType, pArg: *void) -> bool #foreign lib "SteamAPI_ISteamNetworkingUtils_SetConfigValue";
    SetConfigValueStruct           :: (self: *IUtils,        opt: *ConfigValue,     scope: ConfigScope, scopeObj: intptr) -> bool #foreign lib "SteamAPI_ISteamNetworkingUtils_SetConfigValueStruct";
    GetConfigValue                 :: (self: *IUtils, valueLabel: ConfigValueLabel, scope: ConfigScope, scopeObj: intptr, pOutDataType: *ConfigDataType, pResult: *void, cbResult: *u64) -> IUtils.GetConfigValueResult #foreign lib "SteamAPI_ISteamNetworkingUtils_GetConfigValue"; 
    GetConfigValueInfo             :: (self: *IUtils, valueLabel: ConfigValueLabel, pOutName: **s8, pOutDataType: *ConfigDataType, pOutScope: *ConfigScope, pOutNextValue: *ConfigValueLabel) -> bool #foreign lib "SteamAPI_ISteamNetworkingUtils_GetConfigValueInfo";
    GetFirstConfigValue            :: (self: *IUtils) -> ConfigValueLabel                                                        #foreign lib "SteamAPI_ISteamNetworkingUtils_GetFirstConfigValue";
    SetGlobalCallbackConnectionStatusChanged     :: (self: *IUtils, fnCallback: ConnectionStatusChangedFunctionType) -> bool     #foreign lib "SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_SteamNetConnectionStatusChanged";
    SetGlobalCallbackAuthenticationStatusChanged :: (self: *IUtils, fnCallback: AuthenticationStatusChangedFunctionType) -> bool #foreign lib "SteamAPI_ISteamNetworkingUtils_SetGlobalCallback_SteamNetAuthenticationStatusChanged";
}
#assert(size_of(IUtils) == 0);
g_sockets_interface : *ISockets;
g_utils_interface : *IUtils;

GlobalInterfaceWrapper :: inline ($pp : **$T) -> *T
{
    return << pp;
}

#if      OS == .WINDOWS lib :: #library 							"GameNetworkingSockets";
else #if OS == .LINUX   lib :: #library        "linux/libGameNetworkingSockets"; // UNTESTED
else #if OS == .MACOS   lib :: #library        "mac/GameNetworkingSockets";      // UNTESTED
