defmodule MeshxMobileApp.BLE.MessageEnvelope do
  @moduledoc """
  Canonical MeshX message envelope — pure-data shape for messages
  that future connection-layer code will send and receive over BLE.

  **No transport involvement.** No connections, no routing, no
  crypto, no handshake. This module only:

    * defines the envelope struct,
    * validates field shapes,
    * encodes a valid struct to bytes,
    * parses bytes back into a struct.

  A peer that needs to send a message would build/encode it here,
  and a peer that received bytes would parse them here. Whether
  those bytes ever made it across a wire is somebody else's problem.

  ## v1 wire format

  Big-endian throughout. The `"MX"` magic and version byte give a
  parser enough information to refuse anything it doesn't understand.

      "MX"                            2 bytes  magic
      envelope_version                1 byte   currently 1
      flags                           1 byte   reserved, MUST be 0 in v1
      message_id                     16 bytes  caller-provided or random
      created_at_ms                   8 bytes  uint64
      ttl                             1 byte   0..@max_ttl
      sender_peer_id_len              1 byte   1..@max_peer_id_size
      sender_peer_id        sender_len bytes
      recipient_peer_id_len           1 byte   0 (broadcast) or 1..@max_peer_id_size
      recipient_peer_id   recipient_len bytes
      payload_type_len                1 byte   1..@max_payload_type_size
      payload_type    payload_type_len bytes
      capability_requirements         1 byte   bitmap matching M13 cap flags
      payload_len                     2 bytes  uint16, 0..@max_payload_size
      payload              payload_len bytes

  Fixed overhead: 35 bytes. Plus the variable-length fields.

  ## Validation rules

  Enforced by `build/1` (struct construction) and `parse/1` (wire
  decode). Both return `{:error, reason}` tagged tuples on failure —
  this module never raises:

    * `envelope_version` must be `1` (forward versions need their
      own parser).
    * `flags` must be `0` (reserved).
    * `message_id` must be exactly 16 bytes.
    * `sender_peer_id` must be 1..32 bytes.
    * `recipient_peer_id` must be `nil` (broadcast) or 1..32 bytes.
    * `ttl` must be in `0..16` so a forwarder can never see an
      unbounded hop count.
    * `payload_type` must be 1..16 bytes.
    * `payload` must be 0..4096 bytes.
    * `capability_requirements` is a byte (no semantic validation —
      the bitmap is decoded against M13's `PeerCapabilities` flags
      by downstream consumers).

  Unknown `payload_type` values are preserved verbatim. Whether a
  receiver dispatches on it is the receiver's concern; the envelope
  layer never executes a payload.

  ## Determinism

  `build/1` accepts `:message_id` and `:created_at` opts so tests
  pin both. When omitted, `message_id` is generated via
  `:crypto.strong_rand_bytes/1` (non-deterministic in production,
  injected in tests). `created_at` has no default — callers always
  supply a clock value, consistent with the M10 `now` injection
  pattern.
  """

  @magic "MX"
  @current_envelope_version 1

  @max_ttl 16
  @max_peer_id_size 32
  @max_payload_type_size 16
  @max_payload_size 4096

  @type message_id :: <<_::128>>
  @type peer_id :: binary()
  @type payload_type :: binary()

  @type t :: %__MODULE__{
          envelope_version: pos_integer(),
          message_id: message_id(),
          sender_peer_id: peer_id(),
          recipient_peer_id: peer_id() | nil,
          created_at: non_neg_integer(),
          ttl: non_neg_integer(),
          payload_type: payload_type(),
          payload: binary(),
          capability_requirements: non_neg_integer()
        }

  @enforce_keys [:message_id, :sender_peer_id, :created_at, :payload_type]
  defstruct envelope_version: @current_envelope_version,
            message_id: nil,
            sender_peer_id: nil,
            recipient_peer_id: nil,
            created_at: 0,
            ttl: 8,
            payload_type: nil,
            payload: <<>>,
            capability_requirements: 0

  @type build_opts :: [
          message_id: binary(),
          sender_peer_id: binary(),
          recipient_peer_id: binary() | nil,
          created_at: non_neg_integer(),
          ttl: non_neg_integer(),
          payload_type: binary(),
          payload: binary(),
          capability_requirements: non_neg_integer()
        ]

  @type error ::
          :invalid_envelope_version
          | :invalid_flags
          | :invalid_message_id
          | :invalid_sender_peer_id
          | :invalid_recipient_peer_id
          | :invalid_created_at
          | :invalid_ttl
          | :invalid_payload_type
          | :invalid_capability_requirements
          | :payload_too_large
          | :truncated_envelope
          | :unsupported_envelope_version
          | :missing_magic

  # ── public constants (for tests + downstream constants) ───────────────────

  @spec current_envelope_version() :: pos_integer()
  def current_envelope_version, do: @current_envelope_version

  @spec max_ttl() :: pos_integer()
  def max_ttl, do: @max_ttl

  @spec max_payload_size() :: pos_integer()
  def max_payload_size, do: @max_payload_size

  @spec max_peer_id_size() :: pos_integer()
  def max_peer_id_size, do: @max_peer_id_size

  @spec max_payload_type_size() :: pos_integer()
  def max_payload_type_size, do: @max_payload_type_size

  # ── build ─────────────────────────────────────────────────────────────────

  @doc """
  Constructs and validates an envelope. Returns `{:ok, t()}` or
  `{:error, reason}` — never raises.

  Required opts: `:sender_peer_id`, `:created_at`, `:payload_type`.
  Optional: `:message_id` (generated when omitted), `:recipient_peer_id`
  (nil = broadcast), `:ttl` (default 8), `:payload` (default empty),
  `:capability_requirements` (default 0).
  """
  @spec build(build_opts()) :: {:ok, t()} | {:error, error()}
  def build(opts) do
    envelope = %__MODULE__{
      envelope_version: @current_envelope_version,
      message_id: Keyword.get(opts, :message_id) || generate_message_id(),
      sender_peer_id: Keyword.get(opts, :sender_peer_id),
      recipient_peer_id: Keyword.get(opts, :recipient_peer_id),
      created_at: Keyword.get(opts, :created_at, 0),
      ttl: Keyword.get(opts, :ttl, 8),
      payload_type: Keyword.get(opts, :payload_type),
      payload: Keyword.get(opts, :payload, <<>>),
      capability_requirements: Keyword.get(opts, :capability_requirements, 0)
    }

    case validate(envelope) do
      :ok -> {:ok, envelope}
      {:error, _} = err -> err
    end
  end

  # ── encode ────────────────────────────────────────────────────────────────

  @doc """
  Serializes a valid envelope to the v1 wire format. Assumes the
  caller obtained the envelope from `build/1` (i.e. it's already
  validated); structurally-invalid input may produce garbage bytes,
  but never raises on well-typed inputs.
  """
  @spec encode(t()) :: binary()
  def encode(%__MODULE__{} = e) do
    recipient = e.recipient_peer_id || <<>>
    recipient_len = byte_size(recipient)

    sender_len = byte_size(e.sender_peer_id)
    payload_type_len = byte_size(e.payload_type)
    payload_len = byte_size(e.payload)

    <<
      @magic::binary,
      e.envelope_version,
      # flags
      0,
      e.message_id::binary-size(16),
      e.created_at::64-big-unsigned,
      e.ttl,
      sender_len,
      e.sender_peer_id::binary,
      recipient_len,
      recipient::binary,
      payload_type_len,
      e.payload_type::binary,
      e.capability_requirements,
      payload_len::16-big-unsigned,
      e.payload::binary
    >>
  end

  # ── parse ─────────────────────────────────────────────────────────────────

  @doc """
  Parses v1 wire bytes into a validated envelope. Returns
  `{:ok, t()}` or `{:error, reason}`. Never raises.
  """
  @spec parse(binary()) :: {:ok, t()} | {:error, error()}
  def parse(bytes) when is_binary(bytes) do
    with {:ok, rest} <- expect_magic(bytes),
         {:ok, version, rest} <- read_byte(rest, :truncated_envelope),
         :ok <- check_version(version),
         {:ok, flags, rest} <- read_byte(rest, :truncated_envelope),
         :ok <- check_flags(flags),
         {:ok, message_id, rest} <- read_n(rest, 16, :truncated_envelope),
         {:ok, created_at, rest} <- read_uint64(rest),
         {:ok, ttl, rest} <- read_byte(rest, :truncated_envelope),
         {:ok, sender, rest} <- read_length_prefixed(rest, :invalid_sender_peer_id),
         {:ok, recipient_raw, rest} <- read_length_prefixed(rest, :invalid_recipient_peer_id),
         {:ok, payload_type, rest} <- read_length_prefixed(rest, :invalid_payload_type),
         {:ok, caps, rest} <- read_byte(rest, :truncated_envelope),
         {:ok, payload, _rest} <- read_length_prefixed_16(rest) do
      envelope = %__MODULE__{
        envelope_version: version,
        message_id: message_id,
        sender_peer_id: sender,
        recipient_peer_id: nil_if_empty(recipient_raw),
        created_at: created_at,
        ttl: ttl,
        payload_type: payload_type,
        payload: payload,
        capability_requirements: caps
      }

      case validate(envelope) do
        :ok -> {:ok, envelope}
        {:error, _} = err -> err
      end
    end
  end

  def parse(_), do: {:error, :missing_magic}

  # ── validation ────────────────────────────────────────────────────────────

  defp validate(%__MODULE__{} = e) do
    cond do
      e.envelope_version != @current_envelope_version ->
        {:error, :unsupported_envelope_version}

      not is_binary(e.message_id) or byte_size(e.message_id) != 16 ->
        {:error, :invalid_message_id}

      not is_binary(e.sender_peer_id) or
        byte_size(e.sender_peer_id) < 1 or
          byte_size(e.sender_peer_id) > @max_peer_id_size ->
        {:error, :invalid_sender_peer_id}

      e.recipient_peer_id != nil and
          (not is_binary(e.recipient_peer_id) or
             byte_size(e.recipient_peer_id) < 1 or
             byte_size(e.recipient_peer_id) > @max_peer_id_size) ->
        {:error, :invalid_recipient_peer_id}

      not is_integer(e.created_at) or e.created_at < 0 ->
        {:error, :invalid_created_at}

      not is_integer(e.ttl) or e.ttl < 0 or e.ttl > @max_ttl ->
        {:error, :invalid_ttl}

      not is_binary(e.payload_type) or
        byte_size(e.payload_type) < 1 or
          byte_size(e.payload_type) > @max_payload_type_size ->
        {:error, :invalid_payload_type}

      not is_binary(e.payload) or byte_size(e.payload) > @max_payload_size ->
        {:error, :payload_too_large}

      not is_integer(e.capability_requirements) or
        e.capability_requirements < 0 or
          e.capability_requirements > 255 ->
        {:error, :invalid_capability_requirements}

      true ->
        :ok
    end
  end

  # ── parse helpers ─────────────────────────────────────────────────────────

  defp expect_magic(<<@magic, rest::binary>>), do: {:ok, rest}
  defp expect_magic(_), do: {:error, :missing_magic}

  defp check_version(@current_envelope_version), do: :ok
  defp check_version(0), do: {:error, :invalid_envelope_version}
  defp check_version(_), do: {:error, :unsupported_envelope_version}

  defp check_flags(0), do: :ok
  defp check_flags(_), do: {:error, :invalid_flags}

  defp read_byte(<<b, rest::binary>>, _err), do: {:ok, b, rest}
  defp read_byte(_, err), do: {:error, err}

  defp read_n(bin, n, _err) when byte_size(bin) >= n do
    <<head::binary-size(n), tail::binary>> = bin
    {:ok, head, tail}
  end

  defp read_n(_, _, err), do: {:error, err}

  defp read_uint64(<<v::64-big-unsigned, rest::binary>>), do: {:ok, v, rest}
  defp read_uint64(_), do: {:error, :truncated_envelope}

  defp read_length_prefixed(<<len, rest::binary>>, _err) when byte_size(rest) >= len do
    <<data::binary-size(len), tail::binary>> = rest
    {:ok, data, tail}
  end

  defp read_length_prefixed(_, err), do: {:error, err}

  defp read_length_prefixed_16(<<len::16-big-unsigned, rest::binary>>)
       when byte_size(rest) >= len and len <= @max_payload_size do
    <<data::binary-size(len), tail::binary>> = rest
    {:ok, data, tail}
  end

  defp read_length_prefixed_16(<<len::16-big-unsigned, _rest::binary>>)
       when len > @max_payload_size do
    {:error, :payload_too_large}
  end

  defp read_length_prefixed_16(_), do: {:error, :truncated_envelope}

  defp nil_if_empty(<<>>), do: nil
  defp nil_if_empty(bin), do: bin

  defp generate_message_id, do: :crypto.strong_rand_bytes(16)
end
