%%%-------------------------------------------------------------------
%%% @copyright (C) 2016, 2600Hz
%%% @doc
%%% Utils for backends
%%% @end
%%% @contributors
%%%    SIPLABS, LLC (Vorontsov Nikita) <info@siplabs.ru>
%%%-------------------------------------------------------------------
-module(edr_utils).

-include("edr.hrl").

-export([distribute_event/1
        ,registred_backends/0
        ,register_backend/5
        ,delete_backend/1
        ,enable_backend/1
        ,disable_backend/1
        ,event_from_kapi/1
        ]).

-spec register_backend(ne_binary(), ne_binary(), kz_json:object(), kz_json:object(), boolean())-> 'ok' | {'error', 'already_registred'}.
register_backend(Name, Type, Tags, Opts, IsEnable)->
    JBackends = kapps_config:get(<<"edr">>, <<"backends">>, kz_json:new()),
    case kz_json:get_value(Name, JBackends) of
        'undefined' ->
            Backend = kz_json:from_list([{<<"Name">>, Name}
                                        ,{<<"Options">>, Opts}
                                        ,{<<"Tags">>, Tags}
                                        ,{<<"Type">>, Type}
                                        ,{<<"Enabled">>, IsEnable}
                                        ]),
            NewBackends = kz_json:set_value(Name, Backend, JBackends),
            {'ok', _} = kapps_config:set(<<"edr">>, <<"backends">>, NewBackends),
            'ok';
        _V -> {'error', 'already_registred'}
    end.

-spec delete_backend(ne_binary())-> 'ok'.
delete_backend(Name)->
    Backends = kapps_config:get(<<"edr">>, <<"backends">>, kz_json:new()),
    NewBackends = kz_json:delete_key(Name, Backends),
    {'ok', _} = kapps_config:set(<<"edr">>, <<"backends">>, NewBackends),
    'ok'.

-spec enable_backend(ne_binary())-> 'ok' | {'error', 'not_registred'}.
enable_backend(Name)->
    Backends = kapps_config:get(<<"edr">>, <<"backends">>, kz_json:new()),
    case kz_json:get_value(Name, Backends) of
        'undefined' -> {'error', 'not_registred'};
        Backend ->
            NewBackend = kz_json:set_value(<<"Enabled">>, 'true', Backend),
            NewBackends = kz_json:set_value(Name, NewBackend, Backends),
            {'ok', _} = kapps_config:set(<<"edr">>, <<"backends">>, NewBackends),
            'ok'
    end.

-spec disable_backend(ne_binary())-> 'ok'.
disable_backend(Name)->
    Backends = kapps_config:get(<<"edr">>, <<"backends">>, kz_json:new()),
    case kz_json:get_value(Name, Backends) of
        'undefined' -> {'error', 'not_registred'};
        Backend ->
            NewBackend = kz_json:set_value(<<"Enabled">>, 'false', Backend),
            NewBackends = kz_json:set_value(Name, NewBackend, Backends),
            {'ok', _} = kapps_config:set(<<"edr">>, <<"backends">>, NewBackends),
            'ok'
    end.


-spec registred_backends()-> kz_json:object().
registred_backends()->
    kapps_config:get(<<"edr">>, <<"backends">>, kz_json:new()).


-spec distribute_event(event())-> 'ok'.
distribute_event(Event)->
    lists:foreach(fun ({_,Pid,_})->
                          gen_backend:push(Pid, Event)
                  end, edr_backend_sup:get_running_backends()).

-spec event_from_kapi(kz_json:object()) -> event().
event_from_kapi(JObj) ->
    AccountId = kz_json:get_value(<<"Account-Id">>, JObj),
    GregorianTime = kz_json:get_value(<<"Timestamp">>, JObj),
    #event{account_id=AccountId
          ,account_tree=account_tree(AccountId)
          ,app_name=kz_json:get_value(<<"App-Name">>, JObj)
          ,app_version=kz_json:get_value(<<"App-Version">>, JObj)
          ,level=kz_util:to_atom(kz_json:get_value(<<"Level">>, JObj))
          ,body=kz_json:get_value(<<"Body">>, JObj)
          ,timestamp=kz_time:iso_8601(GregorianTime)
          ,gregorian_time=GregorianTime
          }.

-spec account_tree(api_ne_binary()) -> api_ne_binaries().
account_tree('undefined') ->
    'undefined';
account_tree(AccountId) ->
    case kz_account:fetch(AccountId) of
        {'ok', Doc} -> kz_account:tree(Doc);
        _ -> 'undefined'
    end.
