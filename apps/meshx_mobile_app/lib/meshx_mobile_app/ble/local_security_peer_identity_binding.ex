defmodule MeshxMobileApp.BLE.LocalSecurityPeerIdentityBinding do
  @moduledoc """
  Pure peer identity binding for local BLE security proofs.

  A binding records that a `peer_id` is associated with supplied Ed25519
  public key material and the derived key id used by authorship proofs. It
  can validate a full `MessageEnvelope` authorship proof against that
  binding. It does not discover keys, persist trust, rotate keys, revoke
  peers, authenticate beacon refs by themselves, provide replay protection,
  fetch, route, ACK, retry, encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.{LocalSecurityAuthorshipProof, MessageEnvelope}
  alias MeshxMobileApp.BLE.LocalSecurityAuthorshipProof.Proof

  defmodule Binding do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :binding_version,
               :source,
               :peer_id,
               :key_id,
               :public_key
             ]}
    @enforce_keys [:binding_version, :source, :peer_id, :key_id, :public_key]
    defstruct @enforce_keys

    @type source :: :ed25519_public_key

    @type t :: %__MODULE__{
            binding_version: 1,
            source: source(),
            peer_id: binary(),
            key_id: binary(),
            public_key: binary()
          }
  end

  @binding_version 1
  @source :ed25519_public_key
  @ed25519_key_size 32

  @type error ::
          :invalid_peer_id
          | :invalid_public_key
          | :invalid_binding_version
          | :unsupported_binding_source
          | :binding_peer_mismatch
          | :binding_key_mismatch
          | LocalSecurityAuthorshipProof.verify_error()

  @spec bind(binary(), binary()) :: {:ok, Binding.t()} | {:error, error()}
  def bind(peer_id, public_key) when is_binary(peer_id) and is_binary(public_key) do
    with :ok <- validate_peer_id(peer_id),
         :ok <- validate_public_key(public_key) do
      {:ok,
       %Binding{
         binding_version: @binding_version,
         source: @source,
         peer_id: peer_id,
         key_id: LocalSecurityAuthorshipProof.derive_key_id(public_key),
         public_key: public_key
       }}
    end
  end

  def bind(_, _), do: {:error, :invalid_peer_id}

  @spec verify(MessageEnvelope.t(), Proof.t(), Binding.t()) ::
          {:ok, map()} | {:error, error()}
  def verify(%MessageEnvelope{} = envelope, %Proof{} = proof, %Binding{} = binding) do
    with :ok <- validate_binding(binding),
         :ok <- validate_binding_peer(envelope, binding),
         :ok <- validate_binding_key(proof, binding),
         {:ok, result} <- LocalSecurityAuthorshipProof.verify(envelope, proof, binding.public_key) do
      {:ok,
       Map.merge(result, %{
         authenticated_peer_identity?: true,
         binding_source: binding.source,
         binding_key_id: binding.key_id
       })}
    end
  end

  def verify(_, _, _), do: {:error, :invalid_peer_id}

  defp validate_binding(%Binding{binding_version: version}) when version != @binding_version,
    do: {:error, :invalid_binding_version}

  defp validate_binding(%Binding{source: source}) when source != @source,
    do: {:error, :unsupported_binding_source}

  defp validate_binding(%Binding{peer_id: peer_id, public_key: public_key}) do
    with :ok <- validate_peer_id(peer_id),
         :ok <- validate_public_key(public_key) do
      :ok
    end
  end

  defp validate_binding_peer(
         %MessageEnvelope{sender_peer_id: peer_id},
         %Binding{peer_id: peer_id}
       ),
       do: :ok

  defp validate_binding_peer(%MessageEnvelope{}, %Binding{}), do: {:error, :binding_peer_mismatch}

  defp validate_binding_key(%Proof{key_id: key_id}, %Binding{key_id: key_id}), do: :ok
  defp validate_binding_key(%Proof{}, %Binding{}), do: {:error, :binding_key_mismatch}

  defp validate_peer_id(peer_id)
       when is_binary(peer_id) and byte_size(peer_id) > 0 and
              byte_size(peer_id) <= 32,
       do: :ok

  defp validate_peer_id(_), do: {:error, :invalid_peer_id}

  defp validate_public_key(public_key) when byte_size(public_key) == @ed25519_key_size, do: :ok
  defp validate_public_key(_), do: {:error, :invalid_public_key}
end
