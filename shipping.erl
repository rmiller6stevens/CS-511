%% Robert Miller
%% I pledge my honor that I have abided by the Stevens Honor System
%% this is for me to access this file from terminal /mnt/c/Users/robmi/OneDrive/Desktop/hw3
-module(shipping).
-compile(export_all).
-include_lib("./shipping.hrl").

lsize([]) -> 
    0;
lsize([_H|T]) ->
    1 + lsize(T).

get_ship(Shipping_State, Ship_ID) ->
    F = lists:keyfind (Ship_ID, #ship.id, Shipping_State#shipping_state.ships),
    if F == false -> %% Ship DNE
        error;
        true -> F
    end.

get_container(Shipping_State, Container_ID) ->
    F = lists:keyfind(Container_ID, #container.id, Shipping_State#shipping_state.containers),
    if F == false -> %% Container DNE
        error;
        true -> F
    end.

get_port(Shipping_State, Port_ID) ->
    F = lists:keyfind(Port_ID, #port.id, Shipping_State#shipping_state.ports),
    if F == false -> %% Port DNE
        error;
        true -> F
    end.

get_occupied_docks(Shipping_State, Port_ID) ->
    F = lists:keyfind(Port_ID, #port.id, Shipping_State#shipping_state.ports),
    if F == false -> %% Port DNE
        [];
        true -> 
            Ports = lists:filter(fun({P, _D, _S}) -> P == Port_ID end, Shipping_State#shipping_state.ship_locations),
            lists:map(fun({_P, D, _S}) -> D end, Ports)
    end.

get_ship_location(Shipping_State, Ship_ID) ->
    F = lists:keyfind (Ship_ID, #ship.id, Shipping_State#shipping_state.ships),
    if F == false -> %% Ship DNE
        error;
        true ->
        Ships = lists:filter(fun({_P, _D, S}) -> S == Ship_ID end, Shipping_State#shipping_state.ship_locations),
        [{P, D}] = lists:map(fun({P,D,_S}) -> {P, D} end, Ships),
        {P,D}
    end.

get_container_weight(Shipping_State, Container_IDs) ->
    Check = lists:map(fun(X) -> get_container(Shipping_State, X) end, Container_IDs),
    Size = lsize(lists:filter(fun(T) -> T == error end, Check)),
    if Size > 0 -> %% 1(+) Containers DNE
        error;
    true -> lists:foldl(fun(T, Sum) -> T#container.weight + Sum end, 0, Check)
    end.   

get_ship_weight(Shipping_State, Ship_ID) ->
    F = get_ship(Shipping_State, Ship_ID),
    if F == error -> %%Ship DNE
        error;
    true ->
        {ok, D} = maps:find(Ship_ID, Shipping_State#shipping_state.ship_inventory),
        get_container_weight(Shipping_State, D)
    end.

load_ship(Shipping_State, Ship_ID, Container_IDs) ->
    Ship = get_ship(Shipping_State, Ship_ID),
    if Ship == error -> %% Ship DNE
        error;
    true ->
        {ok, Current} = maps:find(Ship_ID, Shipping_State#shipping_state.ship_inventory),
            SizeOfCurrent = lsize(Current),
            Total = lsize(Container_IDs) + SizeOfCurrent,
                if  Total > Ship#ship.container_cap -> %%Ship Container Cap
                    error;
                true ->
                    {Port, _dock} = get_ship_location(Shipping_State, Ship_ID), %%Get the current port of the ship
                    {ok, PInv} = maps:find(Port, Shipping_State#shipping_state.port_inventory), %%Gets the list of cargo at that port
                    Check = is_sublist(PInv, Container_IDs),
                        if Check == false -> %% if there is cargo not at that port in the list of IDs return error
                            error;
                            true ->
                            Shipping_State#shipping_state{ship_inventory = maps:update(Ship_ID, Current ++ Container_IDs, Shipping_State#shipping_state.ship_inventory), port_inventory = maps:update(Port, PInv -- Container_IDs, Shipping_State#shipping_state.port_inventory)}
                        end
                 end
        end.

unload_ship_all(Shipping_State, Ship_ID) ->
    Ship = get_ship(Shipping_State, Ship_ID), %%check if ship exists
    if Ship == error -> %% Ship DNE
       error;
    true ->
        {Port, _dock} = get_ship_location(Shipping_State, Ship_ID), %% Gets the Port
        {ok, PInv} = maps:find(Port, Shipping_State#shipping_state.port_inventory), %%Gets the list of cargo at that port
        SPInv = lsize(PInv), %% amount of containers at port
        {ok, SInv} = maps:find(Ship_ID, Shipping_State#shipping_state.ship_inventory), %%Gets the list of cargo on that Ship
        SSInv = lsize(SInv), %% amount of containers on ship
        TC = SPInv + SSInv, %%Total amount of containers
        if TC > Port#port.container_cap -> %% all this for error checking, oh god
            error;
        true -> 
            Shipping_State#shipping_state{port_inventory = maps:update(Port, PInv ++ SInv, Shipping_State#shipping_state.port_inventory), ship_inventory = maps:update(Ship_ID, [], Shipping_State#shipping_state.ship_inventory)}
        end
    end.
        
unload_ship(Shipping_State, Ship_ID, Container_IDs) ->
    Ship = get_ship(Shipping_State, Ship_ID), %%check if ship exists
    if Ship == error -> %% Ship DNE
       error;
    true ->
        {Port, _dock} = get_ship_location(Shipping_State, Ship_ID), %% Gets the Port
        {ok, PInv} = maps:find(Port, Shipping_State#shipping_state.port_inventory), %%Gets the list of cargo at that port
        SPInv = lsize(PInv), %% amount of containers at port
        {ok, SInv} = maps:find(Ship_ID, Shipping_State#shipping_state.ship_inventory), %%Gets the list of cargo on that Ship
        TC = SPInv + lsize(Container_IDs), %%Total amount of containers
        if TC > Port#port.container_cap -> 
            error;
        true -> 
           Check = is_sublist(SInv, Container_IDs), %% Check that containers are on the ship
           if Check == false ->
                error;
            true -> 
                % maps:update(Port, PInv ++ Container_IDs, Shipping_State#shipping_state.port_inventory),
                NewCargo = SInv -- Container_IDs, %% List of containers no longer on ship
                % maps:update(Ship_ID, NewCargo, Shipping_State#shipping_state.ship_inventory),
                print_state(Shipping_State#shipping_state{port_inventory = maps:update(Port, PInv ++ Container_IDs, Shipping_State#shipping_state.port_inventory), ship_inventory = maps:update(Ship_ID, NewCargo, Shipping_State#shipping_state.ship_inventory)})
            end
        end
    end.

set_sail(Shipping_State, Ship_ID, {Port_ID, Dock}) ->
    Ship = get_ship(Shipping_State, Ship_ID), %%check if ship exists
    if Ship == error -> %% Ship DNE
       error;
    true ->
        DCheck = get_occupied_docks(Shipping_State, Port_ID),
        Check = is_sublist(DCheck, [Dock]),
        if Check == true ->
            error;
        true ->
            {OldPort, OldDock} = get_ship_location(Shipping_State, Ship_ID),
            OldPorts = Shipping_State#shipping_state.ship_locations -- [{OldPort, OldDock, Ship_ID}],
            NewPorts = OldPorts ++ {Port_ID, Dock, Ship_ID},
            Shipping_State#shipping_state{ship_locations = NewPorts}
        end 
    end.



%% Determines whether all of the elements of Sub_List are also elements of Target_List
%% @returns true is all elements of Sub_List are members of Target_List; false otherwise
is_sublist(Target_List, Sub_List) ->
    lists:all(fun (Elem) -> lists:member(Elem, Target_List) end, Sub_List).

%% Prints out the current shipping state in a more friendly format
print_state(Shipping_State) ->
    io:format("--Ships--~n"),
    _ = print_ships(Shipping_State#shipping_state.ships, Shipping_State#shipping_state.ship_locations, Shipping_State#shipping_state.ship_inventory, Shipping_State#shipping_state.ports),
    io:format("--Ports--~n"),
    _ = print_ports(Shipping_State#shipping_state.ports, Shipping_State#shipping_state.port_inventory).


%% helper function for print_ships
get_port_helper([], _Port_ID) -> error;
get_port_helper([ Port = #port{id = Port_ID} | _ ], Port_ID) -> Port;
get_port_helper( [_ | Other_Ports ], Port_ID) -> get_port_helper(Other_Ports, Port_ID).


print_ships(Ships, Locations, Inventory, Ports) ->
    case Ships of
        [] ->
            ok;
        [Ship | Other_Ships] ->
            {Port_ID, Dock_ID, _} = lists:keyfind(Ship#ship.id, 3, Locations),
            Port = get_port_helper(Ports, Port_ID),
            {ok, Ship_Inventory} = maps:find(Ship#ship.id, Inventory),
            io:format("Name: ~s(#~w)    Location: Port ~s, Dock ~s    Inventory: ~w~n", [Ship#ship.name, Ship#ship.id, Port#port.name, Dock_ID, Ship_Inventory]),
            print_ships(Other_Ships, Locations, Inventory, Ports)
    end.

print_containers(Containers) ->
    io:format("~w~n", [Containers]).

print_ports(Ports, Inventory) ->
    case Ports of
        [] ->
            ok;
        [Port | Other_Ports] ->
            {ok, Port_Inventory} = maps:find(Port#port.id, Inventory),
            io:format("Name: ~s(#~w)    Docks: ~w    Inventory: ~w~n", [Port#port.name, Port#port.id, Port#port.docks, Port_Inventory]),
            print_ports(Other_Ports, Inventory)
    end.
%% This functions sets up an initial state for this shipping simulation. You can add, remove, or modidfy any of this content. This is provided to you to save some time.
%% @returns {ok, shipping_state} where shipping_state is a shipping_state record with all the initial content.
shipco() ->
    Ships = [#ship{id=1,name="Santa Maria",container_cap=20},
              #ship{id=2,name="Nina",container_cap=20},
              #ship{id=3,name="Pinta",container_cap=20},
              #ship{id=4,name="SS Minnow",container_cap=20},
              #ship{id=5,name="Sir Leaks-A-Lot",container_cap=20}
             ],
    Containers = [
                  #container{id=1,weight=200},
                  #container{id=2,weight=215},
                  #container{id=3,weight=131},
                  #container{id=4,weight=62},
                  #container{id=5,weight=112},
                  #container{id=6,weight=217},
                  #container{id=7,weight=61},
                  #container{id=8,weight=99},
                  #container{id=9,weight=82},
                  #container{id=10,weight=185},
                  #container{id=11,weight=282},
                  #container{id=12,weight=312},
                  #container{id=13,weight=283},
                  #container{id=14,weight=331},
                  #container{id=15,weight=136},
                  #container{id=16,weight=200},
                  #container{id=17,weight=215},
                  #container{id=18,weight=131},
                  #container{id=19,weight=62},
                  #container{id=20,weight=112},
                  #container{id=21,weight=217},
                  #container{id=22,weight=61},
                  #container{id=23,weight=99},
                  #container{id=24,weight=82},
                  #container{id=25,weight=185},
                  #container{id=26,weight=282},
                  #container{id=27,weight=312},
                  #container{id=28,weight=283},
                  #container{id=29,weight=331},
                  #container{id=30,weight=136}
                 ],
    Ports = [
             #port{
                id=1,
                name="New York",
                docks=['A','B','C','D'],
                container_cap=200
               },
             #port{
                id=2,
                name="San Francisco",
                docks=['A','B','C','D'],
                container_cap=200
               },
             #port{
                id=3,
                name="Miami",
                docks=['A','B','C','D'],
                container_cap=200
               }
            ],
    %% {port, dock, ship}
    Locations = [
                 {1,'B',1},
                 {1, 'A', 3},
                 {3, 'C', 2},
                 {2, 'D', 4},
                 {2, 'B', 5}
                ],
    Ship_Inventory = #{
      1=>[14,15,9,2,6],
      2=>[1,3,4,13],
      3=>[],
      4=>[2,8,11,7],
      5=>[5,10,12]},
    Port_Inventory = #{
      1=>[16,17,18,19,20],
      2=>[21,22,23,24,25],
      3=>[26,27,28,29,30]
     },
    #shipping_state{ships = Ships, containers = Containers, ports = Ports, ship_locations = Locations, ship_inventory = Ship_Inventory, port_inventory = Port_Inventory}.
