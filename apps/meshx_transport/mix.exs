defmodule MeshxTransport.MixProject do
  use Mix.Project

  def project do
    [
      app: :meshx_transport,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_coverage: [
        ignore_modules: [MeshxTransport.QUIC],
        summary: [threshold: 90]
      ],
      deps: deps()
    ]
  end

  def application do
    [
      mod: {MeshxTransport, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Optional QUIC transport. `:quicer` requires building `msquic` (a large
      # native dependency with vendored OpenSSL submodules). Add it to your
      # own deps when you want QUIC, e.g.:
      #
      #     {:quicer, "~> 0.2"}
      #
      # `MeshxTransport.QUIC` detects availability via `Code.ensure_loaded?/1`
      # at runtime, so this dep is intentionally NOT declared here.
    ]
  end
end
