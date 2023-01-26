-module(server).

-export([start_server/0]).

-include_lib("./defs.hrl").

-spec start_server() -> _.
-spec loop(_State) -> _.
-spec do_join(_ChatName, _ClientPID, _Ref, _State) -> _.
-spec do_leave(_ChatName, _ClientPID, _Ref, _State) -> _.
-spec do_new_nick(_State, _Ref, _ClientPID, _NewNick) -> _.
-spec do_client_quit(_State, _Ref, _ClientPID) -> _NewState.

start_server() ->
    catch(unregister(server)),
    register(server, self()),
    case whereis(testsuite) of
	undefined -> ok;
	TestSuitePID -> TestSuitePID!{server_up, self()}
    end,
    loop(
      #serv_st{
	 nicks = maps:new(), %% nickname map. client_pid => "nickname"
	 registrations = maps:new(), %% registration map. "chat_name" => [client_pids]
	 chatrooms = maps:new() %% chatroom map. "chat_name" => chat_pid
	}
     ).

loop(State) ->
    receive 
	%% initial connection
	{ClientPID, connect, ClientNick} ->
	    NewState =
		#serv_st{
		   nicks = maps:put(ClientPID, ClientNick, State#serv_st.nicks),
		   registrations = State#serv_st.registrations,
		   chatrooms = State#serv_st.chatrooms
		  },
	    loop(NewState);
	%% client requests to join a chat
	{ClientPID, Ref, join, ChatName} ->
	    NewState = do_join(ChatName, ClientPID, Ref, State),
	    loop(NewState);
	%% client requests to leave a chat
	{ClientPID, Ref, leave, ChatName} ->
	    NewState = do_leave(ChatName, ClientPID, Ref, State),
	    loop(NewState);
	%% client requests to register a new nickname
	{ClientPID, Ref, nick, NewNick} ->
	    NewState = do_new_nick(State, Ref, ClientPID, NewNick),
	    loop(NewState);
	%% client requests to quit
	{ClientPID, Ref, quit} ->
	    NewState = do_client_quit(State, Ref, ClientPID),
	    loop(NewState);
	{TEST_PID, get_state} ->
	    TEST_PID!{get_state, State},
	    loop(State)
    end.

%% executes join protocol from server perspective
do_join(ChatName, ClientPID, Ref, State) ->
    IsIn = maps:find(ChatName, State#serv_st.chatrooms),
	if IsIn == error ->
			ChatPID = spawn(chatroom, start_chatroom, [ChatName]),
			maps:put(ChatName, ChatPID, State#serv_st.chatrooms),
			{ok, CliNick} = maps:find(ClientPID, State#serv_st.nicks),
			ChatPID!{self(), Ref, register, ClientPID, CliNick},
			{ok, CurrReg} = maps:find(ChatName, State#serv_st.registrations),
			maps:update(ChatName, CurrReg ++ [ClientPID], State#serv_st.registrations);
		true ->
			{ok, ChatPId} = maps:find(ChatName, State#serv_st.chatrooms),
			{ok, CliNick} = maps:find(ClientPID, State#serv_st.nicks),
			ChatPId!{self(), Ref, register, ClientPID, CliNick},
			{ok, CurrReg} = maps:find(ChatName, State#serv_st.registrations),
			maps:update(ChatName, CurrReg ++ [ClientPID], State#serv_st.registrations)
	end.

%% executes leave protocol from server perspective
do_leave(ChatName, ClientPID, Ref, State) ->
    {ok, ChatPID} = maps:find(ChatName, State#serv_st.chatrooms),
	{ok, ClientList} = maps:find(ChatName, State#serv_st.registrations),
	Pred = fun(X) -> X =/= ClientPID end,
	NewList = lists:filter(Pred, ClientList),
	maps:update(ChatName, NewList, State#serv_st.registrations),
	ChatPID!{self(), Ref, unregister, ClientPID},
	ClientPID!{self(), Ref, ack_leave}.


%% executes new nickname protocol from server perspective
do_new_nick(State, Ref, ClientPID, NewNick) ->
	Pred = fun(_K, V) -> V == NewNick end,
    IsIn = maps:filter(Pred, State#serv_st.nicks),
	IsInTwo = size(IsIn),
	if IsInTwo =/= 0 ->
		ClientPID!{self(), Ref, err_nick_used};
		true ->
			maps:update(ClientPID, NewNick, State#serv_st.nicks),
			Update = fun(K, V) -> 
				Check = lists:member(ClientPID, V),
					if Check ->
				{ok, ChatPID} = maps:find(K, State#serv_st.chatrooms),
				ChatPID!{self(), Ref, update_nick, ClientPID, NewNick} end end,
				maps:map(Update, State#serv_st.registrations)
	end.

%% executes client quit protocol from server perspective
do_client_quit(State, Ref, ClientPID) ->
	State#serv_st{nicks = maps:remove(ClientPID, State#serv_st.nicks)},
	Update = fun(K, V) -> 
				Check = lists:member(ClientPID, V),
					if Check ->
				{ok, ChatPID} = maps:find(K, State#serv_st.chatrooms),
				ChatPID!{self(), Ref, unregister, ClientPID},
				{ok, OldList} = maps:find(ChatPID, State#serv_st.registrations),
				NewList = OldList -- [ClientPID],
				maps:update(ChatPID, NewList, State#serv_st.registrations)
				end end,
				State#serv_st{registrations = maps:map(Update, State#serv_st.registrations)},
				ClientPID!{self(), Ref, ack_quit}.