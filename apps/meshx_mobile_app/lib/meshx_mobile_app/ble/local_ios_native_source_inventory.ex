defmodule MeshxMobileApp.BLE.LocalIOSNativeSourceInventory do
  @moduledoc """
  Source inventory for the current iOS BLE bridge parity boundary.

  This records whether expected native source files and foreground
  legacy-beacon observe markers are present in the repository. It is source
  evidence only: it does not build iOS, touch hardware, scan, advertise, fetch,
  route, persist, ACK, retry, encrypt, authenticate, or run background work.
  """

  @expected_files [
    %{
      id: :swift_bridge,
      path: "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift",
      markers: [
        "MeshxLegacyBeaconAdvertisement",
        "meshx_ble_emit_received_message_beacon"
      ]
    },
    %{
      id: :nif_bridge,
      path: "apps/meshx_mobile_app/ios/meshx_ble_nif.m",
      markers: [
        "meshx_ble_emit_received_message_beacon",
        "received_message_beacon"
      ]
    },
    %{
      id: :ios_info_plist,
      path: "apps/meshx_mobile_app/ios/Info.plist",
      markers: [
        "NSBluetoothAlwaysUsageDescription"
      ]
    }
  ]

  @blocked_claims [
    :ios_hardware_participation,
    :ios_legacy_beacon_observed,
    :ios_legacy_beacon_gossip,
    :ios_full_envelope_advert,
    :ios_background_ble,
    :ios_parity_claim
  ]

  @spec snapshot(keyword()) :: map()
  def snapshot(opts \\ []) do
    root = Keyword.get(opts, :root, File.cwd!())
    files = Enum.map(@expected_files, &file_evidence(&1, root))

    %{
      inventory_version: 1,
      boundary: :ios_native_source_inventory,
      source_inventory_complete?:
        Enum.all?(files, & &1.present?) and
          Enum.all?(files, &(&1.missing_markers == [])),
      ios_hardware_claim_allowed?: false,
      ios_parity_claim_allowed?: false,
      foreground_observe_source_present?: foreground_observe_source_present?(files),
      files: files,
      missing_files: files |> Enum.reject(& &1.present?) |> Enum.map(& &1.path),
      blocked_claims: @blocked_claims,
      notes: [
        "Source markers are implementation evidence, not iOS hardware proof.",
        "iOS hardware captures must still normalize through received_message_beacon replay before participation claims change.",
        "iOS beacon gossip emission remains unselected and unvalidated."
      ]
    }
  end

  @spec json_snapshot(keyword()) :: map()
  def json_snapshot(opts \\ []) do
    opts
    |> snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp file_evidence(file, root) do
    path = file.path
    full_path = resolve_path(root, path)

    case full_path && File.read(full_path) do
      {:ok, contents} ->
        missing_markers =
          file.markers
          |> Enum.reject(&String.contains?(contents, &1))

        %{
          id: file.id,
          path: path,
          present?: true,
          markers: file.markers,
          missing_markers: missing_markers,
          source_evidence_complete?: missing_markers == []
        }

      _missing ->
        %{
          id: file.id,
          path: path,
          present?: false,
          markers: file.markers,
          missing_markers: file.markers,
          source_evidence_complete?: false
        }
    end
  end

  defp resolve_path(root, path) do
    app_relative = String.replace_prefix(path, "apps/meshx_mobile_app/", "")

    [Path.join(root, path), Path.join(root, app_relative)]
    |> Enum.find(&File.exists?/1)
  end

  defp foreground_observe_source_present?(files) do
    Enum.any?(
      files,
      &(&1.id == :swift_bridge and &1.present? and
          "MeshxLegacyBeaconAdvertisement" in &1.markers and &1.missing_markers == [])
    ) and
      Enum.any?(
        files,
        &(&1.id == :nif_bridge and &1.present? and
            "received_message_beacon" in &1.markers and &1.missing_markers == [])
      )
  end
end
