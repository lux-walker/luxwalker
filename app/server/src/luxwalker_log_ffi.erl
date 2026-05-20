-module(luxwalker_log_ffi).

-export([
    configure/0,
    log_info/2,
    log_warn/2,
    log_error/2,
    log_debug/2,
    format/2
]).

configure() ->
    _ = logger:update_handler_config(default, formatter, {?MODULE, #{}}),
    _ = logger:set_primary_config(level, info),
    nil.

log_info(Event, Fields) -> do_log(info, Event, Fields).
log_warn(Event, Fields) -> do_log(warning, Event, Fields).
log_error(Event, Fields) -> do_log(error, Event, Fields).
log_debug(Event, Fields) -> do_log(debug, Event, Fields).

do_log(Level, Event, Fields) ->
    Report = build_report(Event, Fields),
    logger:log(Level, Report),
    nil.

build_report(Event, Fields) ->
    Base = lists:foldl(
        fun({K, V}, Acc) -> Acc#{to_bin(K) => to_bin(V)} end,
        #{},
        Fields
    ),
    Base#{<<"event">> => to_bin(Event)}.

format(#{level := Level, msg := Msg, meta := Meta}, _Config) ->
    Ts = format_ts(Meta),
    Base = #{
        <<"ts">> => Ts,
        <<"level">> => atom_to_binary(Level)
    },
    Body = body_for(Msg),
    Map = maps:merge(Body, Base),
    Sanitised = maps:fold(
        fun(K, V, Acc) -> Acc#{to_bin(K) => to_json_value(V)} end,
        #{},
        Map
    ),
    try json:encode(Sanitised) of
        Encoded -> [Encoded, $\n]
    catch
        _:_ ->
            Fallback = #{
                <<"ts">> => Ts,
                <<"level">> => atom_to_binary(Level),
                <<"event">> => <<"log_encode_failed">>,
                <<"raw">> => list_to_binary(io_lib:format("~p", [Sanitised]))
            },
            [json:encode(Fallback), $\n]
    end.

body_for({report, R}) when is_map(R) -> R;
body_for({report, R}) when is_list(R) -> maps:from_list(R);
body_for({string, S}) -> #{<<"msg">> => to_bin(S)};
body_for({Fmt, Args}) when is_list(Fmt) ->
    #{<<"msg">> => to_bin(io_lib:format(Fmt, Args))};
body_for(Bin) when is_binary(Bin) -> #{<<"msg">> => Bin};
body_for(Other) -> #{<<"msg">> => to_bin(io_lib:format("~p", [Other]))}.

format_ts(#{time := T}) when is_integer(T) ->
    list_to_binary(
        calendar:system_time_to_rfc3339(T, [{unit, microsecond}, {offset, "Z"}])
    );
format_ts(_) ->
    list_to_binary(
        calendar:system_time_to_rfc3339(
            erlang:system_time(microsecond),
            [{unit, microsecond}, {offset, "Z"}]
        )
    ).

to_json_value(V) when is_binary(V) -> V;
to_json_value(V) when is_integer(V) -> V;
to_json_value(V) when is_float(V) -> V;
to_json_value(V) when is_boolean(V) -> V;
to_json_value(V) when is_atom(V) -> atom_to_binary(V);
to_json_value(V) when is_map(V) ->
    maps:fold(
        fun(K, Val, Acc) -> Acc#{to_bin(K) => to_json_value(Val)} end,
        #{},
        V
    );
to_json_value(V) when is_list(V) ->
    case unicode:characters_to_binary(V) of
        Bin when is_binary(Bin) -> Bin;
        _ -> list_to_binary(io_lib:format("~p", [V]))
    end;
to_json_value(V) ->
    list_to_binary(io_lib:format("~p", [V])).

to_bin(V) when is_binary(V) -> V;
to_bin(V) when is_atom(V) -> atom_to_binary(V);
to_bin(V) when is_integer(V) -> integer_to_binary(V);
to_bin(V) when is_float(V) -> float_to_binary(V, [short]);
to_bin(V) when is_list(V) ->
    case unicode:characters_to_binary(V) of
        Bin when is_binary(Bin) -> Bin;
        _ -> list_to_binary(io_lib:format("~p", [V]))
    end;
to_bin(V) -> list_to_binary(io_lib:format("~p", [V])).
