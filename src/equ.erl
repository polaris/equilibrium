-module(equ).

-export([start/0, stop/0]).

-define(DEFAULT_CONFIG, 'equ.config').
-define(DEFAULT_PORT, 2307).
-define(NUM_ACCEPTORS, 4).

start() ->
  case application:start(?MODULE) of
    ok -> 
      event_logger:add_handler(),
      Config = equ_config:new(?DEFAULT_CONFIG),
      configure_backend(Config),
      Port = equ_config:get_value(port, Config, ?DEFAULT_PORT),
      NumAcceptors = equ_config:get_value(num_acceptors, Config, ?NUM_ACCEPTORS),
      listen(Port, NumAcceptors);
    {error, Reason} -> 
      io:format("Failed to start equ: ~p~n", [Reason])
  end.

stop() ->
  application:stop(?MODULE).

configure_backend(Config) ->
  List = equ_config:get_value(backend_servers, Config, []),
  add_backend_server(List).

add_backend_server([]) ->
  ok;
add_backend_server([H|T]) ->
  backend_server:add(element(1, H), element(2, H)),
  add_backend_server(T).

listen(Port, NumAcceptors) ->
  Options = [binary, {packet, raw}, {active, true}, {reuseaddr, true}],
  case gen_tcp:listen(Port, Options) of
    {ok, ListenSocket} ->
      start_acceptors(NumAcceptors, ListenSocket);
    {error, Reason} ->
      io:format("Failed to listen on port ~p: ~p~n", [Port, Reason])
  end.

start_acceptors(NumAcceptors, _ListenSocket) when NumAcceptors =< 0 ->
  ok;
start_acceptors(NumAcceptors, ListenSocket) ->
  acceptor_server:start(ListenSocket),
  start_acceptors(NumAcceptors-1, ListenSocket).
