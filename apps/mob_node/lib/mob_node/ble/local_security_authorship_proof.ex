defmodule Mob.Node.BLE.LocalSecurityAuthorshipProof do
  @moduledoc """
  Pure authorship proof boundary for full `MessageEnvelope` values.

  This module defines the deterministic bytes that a future security layer
  signs for a full envelope and verifies an Ed25519 detached signature when
  the caller supplies public key material. It does not manage keys, store
  trust, decide peer trust, authenticate beacon refs by themselves, provide
  replay protection, fetch, route, persist, ACK, retry, encrypt, or run
  background work.
  """

  alias Mob.Node.BLE.MessageEnvelope

  defmodule Proof do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :proof_version,
               :algorithm,
               :key_id,
               :signer_peer_id,
               :signature
             ]}
    @enforce_keys [:proof_version, :algorithm, :key_id, :signer_peer_id, :signature]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            proof_version: 1,
            algorithm: :ed25519,
            key_id: binary(),
            signer_peer_id: binary(),
            signature: binary()
          }
  end

  @domain_separator "MeshX local BLE MessageEnvelope authorship proof v1\0"
  @proof_version 1
  @algorithm :ed25519
  @signature_size 64
  @ed25519_key_size 32

  @type verify_error ::
          :invalid_envelope
          | :invalid_proof_version
          | :unsupported_algorithm
          | :invalid_key_id
          | :invalid_signer_peer_id
          | :signer_peer_mismatch
          | :invalid_signature
          | :invalid_private_key
          | :invalid_public_key
          | :signature_mismatch

  @spec domain_separator() :: binary()
  def domain_separator, do: @domain_separator

  @spec derive_key_id(binary()) :: binary()
  def derive_key_id(public_key) when is_binary(public_key) do
    :crypto.hash(:sha256, "mob-ed25519:" <> public_key)
  end

  @spec signing_payload(MessageEnvelope.t()) :: {:ok, binary()} | {:error, :invalid_envelope}
  def signing_payload(%MessageEnvelope{} = envelope) do
    with :ok <- validate_envelope(envelope) do
      {:ok, @domain_separator <> MessageEnvelope.encode(envelope)}
    end
  end

  def signing_payload(_), do: {:error, :invalid_envelope}

  @spec sign(MessageEnvelope.t(), binary(), binary()) ::
          {:ok, Proof.t()} | {:error, verify_error()}
  def sign(%MessageEnvelope{} = envelope, private_key, key_id)
      when is_binary(private_key) and is_binary(key_id) do
    with {:ok, seed} <- normalize_private_key(private_key),
         :ok <- validate_key_id(key_id),
         {:ok, payload} <- signing_payload(envelope) do
      proof = %Proof{
        proof_version: @proof_version,
        algorithm: @algorithm,
        key_id: key_id,
        signer_peer_id: envelope.sender_peer_id,
        signature: :crypto.sign(:eddsa, :none, payload, [seed, :ed25519])
      }

      {:ok, proof}
    end
  end

  def sign(_, _, _), do: {:error, :invalid_envelope}

  @spec verify(MessageEnvelope.t(), Proof.t(), binary()) ::
          {:ok, map()} | {:error, verify_error()}
  def verify(%MessageEnvelope{} = envelope, %Proof{} = proof, public_key)
      when is_binary(public_key) do
    with :ok <- validate_public_key(public_key),
         :ok <- validate_proof(proof),
         :ok <- validate_signer(envelope, proof),
         {:ok, payload} <- signing_payload(envelope),
         true <- :crypto.verify(:eddsa, :none, payload, proof.signature, [public_key, :ed25519]) do
      {:ok,
       %{
         authorship_proof?: true,
         proof_version: proof.proof_version,
         algorithm: proof.algorithm,
         key_id: proof.key_id,
         signer_peer_id: proof.signer_peer_id,
         message_id: envelope.message_id,
         envelope_version: envelope.envelope_version
       }}
    else
      false -> {:error, :signature_mismatch}
      {:error, _} = error -> error
    end
  end

  def verify(_, _, _), do: {:error, :invalid_envelope}

  defp validate_envelope(%MessageEnvelope{} = envelope) do
    envelope
    |> MessageEnvelope.encode()
    |> MessageEnvelope.parse()
    |> case do
      {:ok, ^envelope} -> :ok
      {:ok, _} -> {:error, :invalid_envelope}
      {:error, _} -> {:error, :invalid_envelope}
    end
  end

  defp validate_proof(%Proof{proof_version: version}) when version != @proof_version,
    do: {:error, :invalid_proof_version}

  defp validate_proof(%Proof{algorithm: algorithm}) when algorithm != @algorithm,
    do: {:error, :unsupported_algorithm}

  defp validate_proof(%Proof{key_id: key_id})
       when not is_binary(key_id) or byte_size(key_id) == 0,
       do: {:error, :invalid_key_id}

  defp validate_proof(%Proof{signer_peer_id: signer_peer_id})
       when not is_binary(signer_peer_id) or byte_size(signer_peer_id) == 0,
       do: {:error, :invalid_signer_peer_id}

  defp validate_proof(%Proof{signature: signature})
       when not is_binary(signature) or byte_size(signature) != @signature_size,
       do: {:error, :invalid_signature}

  defp validate_proof(%Proof{}), do: :ok

  defp validate_signer(%MessageEnvelope{sender_peer_id: sender}, %Proof{signer_peer_id: sender}),
    do: :ok

  defp validate_signer(%MessageEnvelope{}, %Proof{}), do: {:error, :signer_peer_mismatch}

  defp validate_public_key(public_key) when byte_size(public_key) == @ed25519_key_size, do: :ok
  defp validate_public_key(_), do: {:error, :invalid_public_key}

  # OTP 27+ `:crypto.generate_key(:eddsa, :ed25519)` may return a 64-byte
  # private key (seed || public) on device; signing uses the 32-byte seed.
  defp normalize_private_key(private_key) when byte_size(private_key) == @ed25519_key_size,
    do: {:ok, private_key}

  defp normalize_private_key(private_key) when byte_size(private_key) == @ed25519_key_size * 2,
    do: {:ok, binary_part(private_key, 0, @ed25519_key_size)}

  defp normalize_private_key(_), do: {:error, :invalid_private_key}

  defp validate_key_id(key_id) when is_binary(key_id) and byte_size(key_id) > 0, do: :ok
  defp validate_key_id(_), do: {:error, :invalid_key_id}
end
