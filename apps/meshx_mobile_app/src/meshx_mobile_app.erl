%% meshx_mobile_app.erl — BEAM bootstrap for MeshxMobileApp.
%% Called by the iOS/Android native launcher via -eval 'meshx_mobile_app:start().'.
%% Starts the OTP ecosystem in order, then hands off to the Elixir app module.
-module(meshx_mobile_app).
-export([start/0]).

start() ->
    step(1, fun() -> application:start(compiler) end),
    step(2, fun() -> application:start(elixir)   end),
    step(3, fun() -> application:start(logger)   end),
    step(4, fun() -> mob_nif:platform()          end),
    step(5, fun() -> 'Elixir.MeshxMobileApp.App':start() end),
    timer:sleep(infinity).

step(N, Fun) ->
    mob_nif:log("step " ++ integer_to_list(N) ++ " starting"),
    Result = (catch Fun()),
    mob_nif:log("step " ++ integer_to_list(N) ++ " => " ++
                lists:flatten(io_lib:format("~p", [Result]))).
