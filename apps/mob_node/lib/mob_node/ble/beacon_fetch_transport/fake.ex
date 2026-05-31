defmodule Mob.Node.BLE.BeaconFetchTransport.Fake do
  @moduledoc """
  Pure in-memory simulation of a constrained beacon fetch exchange.

  Requester sends a fetch request, responder looks in an `EnvelopeCache`,
  responder emits a fetch response. No transport is opened.
  """

  alias Mob.Node.BLE.{BeaconFetchProtocol, EnvelopeCache}
  alias BeaconFetchProtocol.{Request, Response}

  @spec exchange(Request.t(), EnvelopeCache.t(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def exchange(%Request{} = request, %EnvelopeCache{} = cache, opts) do
    responder_peer_id = Keyword.fetch!(opts, :responder_peer_id)
    now = Keyword.fetch!(opts, :now)

    case EnvelopeCache.get(cache, request.message_id_hash, now: now) do
      {:ok, envelope} ->
        BeaconFetchProtocol.response(
          request_id: request.request_id,
          message_id_hash: request.message_id_hash,
          responder_peer_id: responder_peer_id,
          status: :ok,
          envelope: envelope
        )

      :miss ->
        BeaconFetchProtocol.response(
          request_id: request.request_id,
          message_id_hash: request.message_id_hash,
          responder_peer_id: responder_peer_id,
          status: :not_found,
          reason: :not_found
        )

      :expired ->
        BeaconFetchProtocol.response(
          request_id: request.request_id,
          message_id_hash: request.message_id_hash,
          responder_peer_id: responder_peer_id,
          status: :not_found,
          reason: :expired
        )
    end
  end
end
