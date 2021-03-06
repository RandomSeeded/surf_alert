-module(surfline_api).
-behavior(gen_server).

% -export([check_forecast_good/0]).

-compile(export_all).

init([]) ->
  {ok, []}.

start_link() ->
  gen_server:start_link(?MODULE, [], []).


% handle-call: for SYNC
% handle-cast: for ASYNC
% Fundamentally get_forecast is for now a synchronous operation

handle_call({check_forecast_good, SpotId}, _From, []) ->
  Body = get_forecast(SpotId),
  ThreeDayForecast = decode_JSON(Body),
  io:format("ThreeDayForecast ~p ~p~n", [ThreeDayForecast, SpotId]),
  Response = case ThreeDayForecast of
    "fair" ->
      true;
    "good" ->
      true;
    "fair to good" ->
      true;
    _ ->
      false
  end,
  {reply, Response, []};
handle_call(test, _From, []) ->
  {reply, "Test", []}.

% This should probably be a gen_server

test(Pid) ->
  gen_server:call(Pid, test).

% OK THIS IS COOL AND ALL BUT IT'S NOT AN EXPOSED FUNCTION. (nuke it)
% get_forecast(Pid) ->
%   gen_server:call(Pid, get_forecast).
get_forecast(SpotId) ->
  inets:start(),
  SpotId_Str = integer_to_list(SpotId),
  Url = "http://api.surfline.com/v1/forecasts/" ++ SpotId_Str ++ "?resources=analysis&days=4",
  {ok, {{_Version, 200, _ReasonPhrase}, _Headers, Body}} = httpc:request(Url),
  Body.

% Helper methods
decode_JSON(Body) ->
  Struct = mochijson:decode(Body),
  {struct, JSONData} = Struct,
  % This needs to actually look it up (lists:keyfind)
  {"Analysis", {struct, Analysis}} = lists:nth(5, JSONData),
  {"generalCondition", {array, RegionalForecasts}} = lists:nth(9, Analysis),
  ThreeDayForecast = lists:nth(4, RegionalForecasts), % Get the forecast for three days out
  ThreeDayForecast.

% Would be expanded for more criteria n stuff
% Additionally, this should be made somehow fault tolerant.
% Right now if the api call fails this thing just keels over and dies

% Client methods (currently broken pending gen_server revamp)
check_forecast_good(Pid, SpotId) ->
  gen_server:call(Pid, {check_forecast_good, SpotId}).

