-module(ircParser).
-export([start/1, parse/1, lineParse/1]).
-import(optimusPrime, [optimusPrime/1]).
-import(time, [time/1]).
-import(telnet, [telnet/1]).
-include_lib("eunit/include/eunit.hrl").

-define(NICK, "Earl3").
-define(USER, "Simon Sir_Earl Sir_Earl Sir_Earl").

%Contains the record definitions
-include("ircParser.hrl").


start(SendPid) ->
	register(primePid, spawn(optimusPrime, optimusPrime, [SendPid])),
	register(timePid, spawn(time, time, [SendPid])),
	register(telnetPid, spawn(telnet, telnet, [SendPid])),
	parse(SendPid).


% Starts passing the message around to the different handlers.
parse(SendPid) ->
    receive
		die ->
			io:format("parserPid :: EXIT~n"),
			primePid ! die,
			timePid ! die,
			telnetPid ! die,
			exit(self(), normal);
		T->
			Line = lineParse(T),

			% Commands which don't need admin
			case Line of
				% Join (#j)
				#privmsg{message="#j " ++ K} ->
					io:format("~p~n", [K]),
					SendPid ! {command, {"JOIN", K}};
				


				% Is Prime Number (#isPrime <num>)
				#privmsg{message="#isPrime" ++ _K} ->
					primePid ! Line;

				% List the primes to a given number (#primesTo <num>)
				#privmsg{message="#primesTo " ++ _K} ->
					primePid ! Line;

				% Time (#t)
				#privmsg{message="#t" ++ _} ->
					timePid ! Line;

				% Ping
				#ping{nonce=K} ->
					SendPid ! {command, {"PONG", K}};

				_Default -> false % We don't know about everything - let's not deal with it.
			end,
		checkIndentResponce(re:run(T, "NOTICE AUTH :... Got Ident response"), SendPid)
    end,
    parse(SendPid).


% Connects to the server after indent response [[ NEEDS REDOING ]]
checkIndentResponce({match, [_]}, SendPid) ->
	SendPid ! {command, {"USER", ?USER}},
	SendPid ! {command, {"NICK", ?NICK}},
	true;
checkIndentResponce(_,_) ->
	false.


% Get the command part of a line
getPrefix(":" ++ Str) ->
	SpaceIndex = string:str(Str, " "),
	Prefix = string:substr(Str, 1, SpaceIndex-1),
	Rest = string:strip(string:substr(Str, SpaceIndex), left),
	{true, Prefix, Rest};
getPrefix(Str) -> {false, "", Str}.


% Get the tail of a given string (the message part)
getTrail(Str) ->
	Index = string:str(Str, " :"),
	case Index of
		0 -> {false, "", Str};
		_ ->
			% io:format("Index: ~p~n", [Index]),
			Rest = string:strip(string:substr(Str, 1, Index)),
			Trail = string:strip(string:strip(string:substr(Str, Index + 2), both, $\n), both, $\r),
			{true, Trail, Rest}
	end.


% Get the command from a given string
getCommand(Str) ->
	Tokens = string:tokens(Str, " "),
	[Command|Params] = Tokens,
	{Command, Params}.


% Get the nick part of a user!host string
getNick(Str) ->
	%Admins = ["graymalkin", "Mex", "Tatskaari"].	
	%Nick = string:sub_word(Str, 1, $!), 
	%IsAdmin = isAdmin(Nick, Admins),
	%{Nick, IsAdmin}.
	string:sub_word(Str, 1, $!).


% Parse a line
lineParse(Str) ->
	{_HasPrefix, Prefix, Rest} = getPrefix(Str),
	{_HasTrail, Trail, CommandsAndParams} = getTrail(Rest),
	{Command, Params} = getCommand(CommandsAndParams),
	case Command of
		"PRIVMSG" -> #privmsg{target=lists:nth(1, Params), from=getNick(Prefix), message=Trail};
		"PING" -> #ping{nonce=Trail};
		_ -> false		% We don't know about everything - let's not deal with it.
	end.


% Checks that a list contains a given string
isAdmin(_, []) -> false;
isAdmin(Str, List) ->
	[Head|Tail] = List,
	if
		Head == Str ->
			true;
		true ->
			isAdmin(Str, Tail)
	end.
	

% =============================================================================
%
%                                UNIT TESTING
%
% =============================================================================

% Test parsing of PRIVMSG lines
lineParse_privmsg_test() ->
	?assertEqual(#privmsg{message="Hello everyone!", from="CalebDelnay", target="#mychannel"} ,lineParse(":CalebDelnay!calebd@localhost PRIVMSG #mychannel :Hello everyone!")),
	?assertEqual(#privmsg{message=":", from="Mex", target="#bottesting"}, lineParse(":Mex!~a@a.kent.ac.uk PRIVMSG #bottesting ::")).

% Test parsing of PING requests
lineParse_ping_test() ->
	?assertEqual(#ping{nonce="irc.localhost.localdomain"} ,lineParse("PING :irc.localhost.localdomain")).

% Test getting the command from a given string
getCommand_test() ->
	?assertEqual({"PRIVMSG", ["#bottesting"]}, getCommand("PRIVMSG #bottesting")).

% Test getting the message from a given string
getTrail_test() ->
	{true, _, Rest} = getPrefix(":Mex!~a@a.kent.ac.uk PRIVMSG #bottesting : :"),
	?assertEqual({true, " :", "PRIVMSG #bottesting"}, getTrail(Rest)),
	{true, _, Rest} = getPrefix(":Mex!~a@a.kent.ac.uk PRIVMSG #bottesting : :"),
	?assertEqual({true, " :", "PRIVMSG #bottesting"}, getTrail(Rest)).

% Fuck knows
getPrefix_test() ->
	?assertEqual({true, "a", "b"}, getPrefix(":a b")),
	?assertEqual({true, "a", "b"}, getPrefix(":a     b")),
	?assertEqual({false, "", "b"}, getPrefix("b")).

% Test getting the nick from a nick!host string
getNick_test() ->
	?assertEqual("graymalkin", getNick("graymalkin!sjc80@kestrel.kent.ac.uk")),
	?assertEqual("graymalkin", getNick("graymalkin!/supporter/pdc/freenode")).

% Tests isAdmin funciton
isAdmin_test() ->
	?assertEqual(false, isAdmin("graymalkin", [])),
	?assertEqual(false, isAdmin("graymalkin", ["Tatskaari", "Mex"])),
	?assertEqual(true, isAdmin("graymalkin", ["Tatskaari", "Mex", "graymalkin"])).

