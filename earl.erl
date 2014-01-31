-module(earl).
-export([main/0, connect/0, buffer/0]).

main() ->
	register(bufferPid, spawn(earl, buffer, [])),
	register(connectPid, spawn(earl, connect, [])).

connect({ok, Socket}) ->
	receive_data(Socket);
connect({error, Reason}) ->
	io:format("ERROR - Could not connect: ~s~n", [Reason]).
connect() ->
	connect(gen_tcp:connect("irc.cs.kent.ac.uk", 6667, [], 1000)).
	
receive_data(Socket) ->
	receive
		{tcp, Socket, ":irc.cs.ukc.ac.uk NOTICE AUTH :*** No Ident response\r\n"} ->
			ok = gen_tcp:send(Socket, "USER jfp6 jfp6 jfp6 jfp6\n\rNICK Earl\n\rJOIN #bottesting");
		{tcp, Socket, Bin} -> 
			bufferPid ! Bin;
		{tcp_closed, Socket} ->
			io:format("Connection closed.~n",[]),
			exit(self(), normal);
		{send, A} ->
			gen_tcp:send(Socket, A)
	end,
	receive_data(Socket).

buffer() ->
	buffer([]).
buffer(Buffer)->
	receive
		Tmp1 -> Tmp1
	end,

	Tmp2 = Buffer ++ [Tmp1],
	io:format("BUGGER: ~p~n", [Tmp2]),
	buffer(Tmp2).
