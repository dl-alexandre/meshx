defmodule MeshxMobileApp.BLE.LocalSecurityOperatorTrustPolicy do
  @moduledoc """
  Pure operator trust policy for authenticated local BLE peers.

  The policy records explicit operator trust states for supplied peer/key
  bindings. Entries are keyed by `peer_id` and Ed25519 `key_id`, so a
  trusted peer id with different key material does not inherit trust. This
  module does not discover keys, persist trust, rotate keys, verify
  signatures, persist replay state, fetch, route, ACK, retry, encrypt, or run
  background work.
  """

  alias MeshxMobileApp.BLE.LocalSecurityPeerIdentityBinding.Binding
  alias MeshxMobileApp.BLE.LocalSecurityTrustModel

  defmodule Entry do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :policy_version,
               :peer_id,
               :key_id,
               :peer_trust_state,
               :source,
               :updated_at,
               :reason
             ]}
    @enforce_keys [
      :policy_version,
      :peer_id,
      :key_id,
      :peer_trust_state,
      :source,
      :updated_at,
      :reason
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            policy_version: 1,
            peer_id: binary(),
            key_id: binary(),
            peer_trust_state: LocalSecurityTrustModel.peer_state(),
            source: :operator,
            updated_at: non_neg_integer(),
            reason: binary()
          }
  end

  defmodule Policy do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :policy_version,
               :entries
             ]}
    @enforce_keys [:policy_version, :entries]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            policy_version: 1,
            entries: [Entry.t()]
          }
  end

  @policy_version 1
  @entry_states [:trusted, :untrusted, :blocked, :revoked]

  @type error ::
          :invalid_policy
          | :invalid_binding
          | :invalid_peer_id
          | :invalid_key_id
          | :invalid_peer_trust_state
          | :invalid_updated_at
          | :invalid_reason

  @spec new([Entry.t() | map()]) :: {:ok, Policy.t()} | {:error, error()}
  def new(entries \\ [])

  def new(entries) when is_list(entries) do
    entries
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, acc} ->
      case normalize_entry(entry) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} ->
        {:ok, %Policy{policy_version: @policy_version, entries: Enum.reverse(normalized)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def new(_entries), do: {:error, :invalid_policy}

  @spec put(Policy.t(), Binding.t(), LocalSecurityTrustModel.peer_state(), keyword()) ::
          {:ok, Policy.t()} | {:error, error()}
  def put(policy, binding, peer_trust_state, opts \\ [])

  def put(%Policy{} = policy, %Binding{} = binding, peer_trust_state, opts) do
    with :ok <- validate_policy(policy),
         :ok <- validate_binding(binding),
         :ok <- validate_entry_state(peer_trust_state),
         :ok <- validate_updated_at(Keyword.get(opts, :updated_at, 0)),
         :ok <- validate_reason(Keyword.get(opts, :reason, "")) do
      entry = %Entry{
        policy_version: @policy_version,
        peer_id: binding.peer_id,
        key_id: binding.key_id,
        peer_trust_state: peer_trust_state,
        source: :operator,
        updated_at: Keyword.get(opts, :updated_at, 0),
        reason: Keyword.get(opts, :reason, "")
      }

      entries =
        policy.entries
        |> Enum.reject(&same_binding?(&1, binding))
        |> then(&[entry | &1])

      {:ok, %{policy | entries: entries}}
    end
  end

  def put(_policy, _binding, _peer_trust_state, _opts), do: {:error, :invalid_policy}

  @spec evaluate(Policy.t(), Binding.t()) :: {:ok, map()} | {:error, error()}
  def evaluate(%Policy{} = policy, %Binding{} = binding) do
    with :ok <- validate_policy(policy),
         :ok <- validate_binding(binding) do
      entry = Enum.find(policy.entries, &same_binding?(&1, binding))

      {:ok,
       %{
         operator_trust_policy?: true,
         peer_id: binding.peer_id,
         key_id: binding.key_id,
         peer_trust_state: trust_state(entry),
         trusted_peer_state?: trust_state(entry) == :trusted,
         policy_entry_found?: not is_nil(entry),
         policy_source: if(entry, do: entry.source, else: :none),
         policy_updated_at: if(entry, do: entry.updated_at, else: nil),
         policy_reason: if(entry, do: entry.reason, else: nil),
         notes: [
           "Operator trust policy is explicit supplied evidence, not key discovery or persistent trust storage.",
           "Trust is scoped to the peer id and key id in the supplied binding."
         ]
       }}
    end
  end

  def evaluate(_policy, _binding), do: {:error, :invalid_policy}

  @spec json_snapshot(Policy.t()) :: map()
  def json_snapshot(%Policy{} = policy) do
    %{
      "policy_version" => policy.policy_version,
      "entries" =>
        Enum.map(policy.entries, fn entry ->
          %{
            "policy_version" => entry.policy_version,
            "peer_id" => entry.peer_id,
            "key_id" => Base.encode64(entry.key_id),
            "peer_trust_state" => Atom.to_string(entry.peer_trust_state),
            "source" => Atom.to_string(entry.source),
            "updated_at" => entry.updated_at,
            "reason" => entry.reason
          }
        end)
    }
  end

  defp normalize_entry(%Entry{} = entry) do
    with :ok <- validate_entry(entry) do
      {:ok, entry}
    end
  end

  defp normalize_entry(%{} = entry) do
    normalize_entry(%Entry{
      policy_version: Map.get(entry, :policy_version, @policy_version),
      peer_id: Map.get(entry, :peer_id),
      key_id: Map.get(entry, :key_id),
      peer_trust_state: Map.get(entry, :peer_trust_state),
      source: Map.get(entry, :source, :operator),
      updated_at: Map.get(entry, :updated_at, 0),
      reason: Map.get(entry, :reason, "")
    })
  end

  defp normalize_entry(_entry), do: {:error, :invalid_policy}

  defp validate_policy(%Policy{policy_version: @policy_version, entries: entries})
       when is_list(entries) do
    entries
    |> Enum.reduce_while(:ok, fn entry, :ok ->
      case validate_entry(entry) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_policy(_policy), do: {:error, :invalid_policy}

  defp validate_entry(%Entry{
         policy_version: @policy_version,
         peer_id: peer_id,
         key_id: key_id,
         peer_trust_state: peer_trust_state,
         source: :operator,
         updated_at: updated_at,
         reason: reason
       }) do
    with :ok <- validate_peer_id(peer_id),
         :ok <- validate_key_id(key_id),
         :ok <- validate_entry_state(peer_trust_state),
         :ok <- validate_updated_at(updated_at),
         :ok <- validate_reason(reason) do
      :ok
    end
  end

  defp validate_entry(_entry), do: {:error, :invalid_policy}

  defp validate_binding(%Binding{peer_id: peer_id, key_id: key_id}) do
    with :ok <- validate_peer_id(peer_id),
         :ok <- validate_key_id(key_id) do
      :ok
    end
  end

  defp validate_binding(_binding), do: {:error, :invalid_binding}

  defp validate_peer_id(peer_id) when is_binary(peer_id) and byte_size(peer_id) > 0,
    do: :ok

  defp validate_peer_id(_peer_id), do: {:error, :invalid_peer_id}

  defp validate_key_id(key_id) when is_binary(key_id) and byte_size(key_id) > 0, do: :ok
  defp validate_key_id(_key_id), do: {:error, :invalid_key_id}

  defp validate_entry_state(peer_trust_state) when peer_trust_state in @entry_states, do: :ok
  defp validate_entry_state(_peer_trust_state), do: {:error, :invalid_peer_trust_state}

  defp validate_updated_at(updated_at) when is_integer(updated_at) and updated_at >= 0,
    do: :ok

  defp validate_updated_at(_updated_at), do: {:error, :invalid_updated_at}

  defp validate_reason(reason) when is_binary(reason), do: :ok
  defp validate_reason(_reason), do: {:error, :invalid_reason}

  defp same_binding?(%Entry{peer_id: peer_id, key_id: key_id}, %Binding{
         peer_id: peer_id,
         key_id: key_id
       }),
       do: true

  defp same_binding?(_entry, _binding), do: false

  defp trust_state(nil), do: :unknown
  defp trust_state(%Entry{peer_trust_state: peer_trust_state}), do: peer_trust_state
end
