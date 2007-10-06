-module(amqp_direct_driver).

-include_lib("rabbitmq_server/include/rabbit.hrl").
-include("amqp_client.hrl").

-export([handshake/2, open_channel/3, close_connection/3]).
-export([acquire_lock/2, release_lock/2]).

%---------------------------------------------------------------------------
% Driver API Methods
%---------------------------------------------------------------------------

handshake(ConnectionPid, ConnectionState = #connection_state{username = User,
                                                             password = Pass,
                                                             vhostpath = VHostPath}) ->
    UserBin = amqp_util:binary(User),
    PassBin = amqp_util:binary(Pass),
    rabbit_access_control:user_pass_login(UserBin, PassBin),
    rabbit_access_control:check_vhost_access(#user{username = UserBin}, VHostPath),
    ConnectionState.

open_channel({Number,OutOfBand}, ChannelPid, State = #connection_state{username = User,
                                                                       vhostpath = VHost}) ->
    %% Why must only the username be binary?
    %% I think this is because of the binary guard on rabbit_realm:access_request/3
    UserBin = amqp_util:binary(User),
    Connection = #connection{user = #user{username = UserBin}, vhost = VHost},
    Peer = spawn_link(rabbit_direct_channel, start, [ChannelPid, Number,Connection]),
    amqp_channel:register_direct_peer(ChannelPid, Peer).

close_connection(Close, From, State) ->
    ok.

acquire_lock(AckRequired, {Tx, DeliveryTag, ConsumerTag,QName, QPid, Message}) ->
    rabbit_writer:maybe_lock_message(AckRequired,{Tx, DeliveryTag, ConsumerTag,QName, QPid, Message}).

release_lock(AckRequired, {QName, QPid, PersistentKey}) ->
    rabbit_amqqueue:notify_sent(QPid),
    ok = rabbit_writer:auto_acknowledge(AckRequired, QName, PersistentKey).
