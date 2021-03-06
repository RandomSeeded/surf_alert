-module(mongo_handler).
-compile(export_all).
-behavior(gen_server).

-include("include/surfline_definitions.hrl").

-record(db_info, {collection="emails",
  connection}).

% By our supervisor
start_link(Args) ->
  gen_server:start_link(?MODULE, Args, []).

establish_connection() ->
  application:ensure_all_started(mongodb),
  Database = <<"surf_alert">>,
  {ok, Connection} = mc_worker_api:connect([{database, Database}]),
  DB = #db_info{connection=Connection},
  {ok, DB}.

add_email_internal(DB, Email, Region, Threshold, WithinPeriod) ->
  Connection = DB#db_info.connection,
  Collection = <<"emails">>,

  ListRegion = binary_to_list(Region),
  InternalRegion = lists:keyfind(ListRegion, #spot.display_name, ?Surfline_definitions),
  RegionId = InternalRegion#spot.internal_id,
  ThresholdId = maps:get(erlang:binary_to_list(Threshold), ?Surfline_qualities),
  Uuid = erlang:list_to_binary(uuid:to_string(uuid:v4())),

  mc_worker_api:insert(Connection, Collection, [#{<<"email">> => Email, <<"region">> => RegionId, <<"_id">> => Uuid, <<"thresholdId">>  => ThresholdId, <<"withinPeriod">> => WithinPeriod}]),
  {ok, DB}.

get_emails_internal(RegionId, DB) ->
  Connection = DB#db_info.connection,
  Collection = <<"emails">>,
  BinaryRegionId = erlang:atom_to_binary(RegionId, 'latin1'),
  AllEntries = case mc_worker_api:find(Connection, Collection, #{<<"region">> => BinaryRegionId}) of
                 {ok, Cursor} ->
                   mc_cursor:rest(Cursor);
                 [] ->
                   []
               end,
  AllEntries.

remove_email_internal(DB, Email) ->
  Connection = DB#db_info.connection,
  Collection = <<"emails">>,
  mc_worker_api:delete(Connection, Collection, #{<<"email">> => Email}).
remove_alert_internal(DB, AlertId) ->
  Connection = DB#db_info.connection,
  Collection = <<"emails">>,
  mc_worker_api:delete(Connection, Collection, #{<<"_id">> => AlertId}).

% Short-lived processes (self-killing)
init({add_email, Email, Region, Threshold, WithinPeriod}) ->
  {ok, DB} = establish_connection(),
  add_email_internal(DB, Email, Region, Threshold, WithinPeriod),
  {stop, normal};
init({remove_email, Email}) ->
  {ok, DB} = establish_connection(),
  remove_email_internal(DB, Email),
  {stop, normal};
init({remove_alert, AlertId}) ->
  {ok, DB} = establish_connection(),
  remove_alert_internal(DB, AlertId),
  {stop, normal};

% Longer-lived processes
init(_DBInfo) ->
  application:ensure_all_started(mongodb),
  Database = <<"surf_alert">>,
  {ok, Connection} = mc_worker_api:connect([{database, Database}]),
  DB = #db_info{connection=Connection},
  {ok, DB}.

handle_call({get_emails, RegionId}, _From, DB) ->
  EmailsForRegion = get_emails_internal(RegionId, DB),
  {stop, normal, EmailsForRegion, DB}.

% This is triggered by m_cursor:rest; it represents no more entries in the db
handle_info({ack, _Pid, {error, normal}}, State) ->
  {noreply, State}.

add_email(Email, Region, Threshold, WithinPeriod) ->
  supervisor:start_child(mongo_handler_sup, [{add_email, Email, Region, Threshold, WithinPeriod}]).

get_emails_for_region(RegionId) ->
  {ok, Pid} = supervisor:start_child(mongo_handler_sup, [{get_emails, RegionId}]),
  gen_server:call(Pid, {get_emails, RegionId}).

remove_email(Email) ->
  supervisor:start_child(mongo_handler_sup, [{remove_email, Email}]).
remove_alert(AlertId) ->
  supervisor:start_child(mongo_handler_sup, [{remove_alert, AlertId}]).

terminate(normal, _State) ->
  ok.
