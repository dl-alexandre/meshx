defmodule Mix.Tasks.Meshx.PatchDeps do
  @moduledoc """
  Apply project-local patches to vendored deps.

  Patches live as unified-diff `.patch` files in `patches/` at the repo
  root and target paths under `apps/meshx_mobile_app/deps/`. They are
  applied with `git apply` from the repo root, which gives us standard
  diff format, reviewable in any tool, with well-understood failure
  modes.

  ## Usage

      mix meshx.patch_deps               # apply (idempotent)
      mix meshx.patch_deps --check       # CI: exit 1 if any patch is unapplied
      mix meshx.patch_deps --list        # show status of each patch, no writes
      mix meshx.patch_deps --quiet       # only print errors

  ## Wiring

  Hooked into `mix.exs` aliases so `mix deps.get`, `mix deps.update`,
  and `mix deps.compile` all run this afterwards.

  ## Idempotency

  Each `.patch` is tested with `git apply --reverse --check` first — if
  the reverse applies cleanly, the patch is already applied and gets
  skipped. Otherwise `git apply --check` runs; if that passes, the
  patch is applied. If neither check passes, the task fails — the
  upstream dep has diverged in a way the patch no longer covers, and
  silent skipping would let the build appear to succeed while shipping
  a binary missing critical pieces.

  ## When patches start failing

  When this task starts raising "patch does not apply" after a
  `mix deps.get`, the upstream dep has changed. Recovery:

    1. Inspect the relevant file in `apps/meshx_mobile_app/deps/<dep>/`
       and find the new context for the construct the patch targets.
    2. Regenerate the patch: revert to unpatched state, edit, run
       `diff -u` against the patched result, replace the corresponding
       file in `patches/`.
    3. Update the "Authored against:" version comment in the patch
       header.
    4. Re-run `mix meshx.patch_deps` to verify the patch applies.

  See `patches/README.md` for the patch authoring convention.
  """

  use Mix.Task

  @shortdoc "Apply project-local patches to mob_dev / mob iOS build for our Swift + NIF additions"

  @switches [check: :boolean, list: :boolean, quiet: :boolean]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: @switches)

    mode =
      cond do
        opts[:check] -> :check
        opts[:list] -> :list
        true -> :apply
      end

    quiet? = opts[:quiet] || false
    repo_root = find_repo_root!()
    patches = list_patches(repo_root)

    if patches == [] do
      Mix.shell().info("  ⏭  no patches in patches/")
      :ok
    else
      results = Enum.map(patches, fn p -> {p, classify(repo_root, p)} end)

      case mode do
        :list ->
          Enum.each(results, fn {p, s} -> say(quiet?, s, p, format(s)) end)

        :check ->
          Enum.each(results, fn {p, s} -> say(quiet?, s, p, format(s)) end)

          unapplied = Enum.count(results, fn {_p, s} -> s in [:needs_apply, :no_apply] end)

          if unapplied > 0 do
            Mix.raise(
              "meshx.patch_deps --check: #{unapplied} patch(es) unapplied or upstream-diverged"
            )
          end

        :apply ->
          Enum.each(results, fn {p, s} -> apply_one(repo_root, p, s, quiet?) end)
      end
    end
  end

  # Walk upward from cwd to find the directory containing patches/. The
  # task is invoked from the umbrella app dir but patches/ lives at the
  # repo root.
  defp find_repo_root!(start \\ File.cwd!()) do
    if File.dir?(Path.join(start, "patches")) and File.exists?(Path.join(start, ".git")) do
      start
    else
      parent = Path.dirname(start)

      if parent == start do
        Mix.raise("could not locate repo root (no ancestor with both patches/ and .git/)")
      else
        find_repo_root!(parent)
      end
    end
  end

  defp list_patches(repo_root) do
    Path.wildcard(Path.join([repo_root, "patches", "*.patch"]))
    |> Enum.sort()
  end

  # Returns :already_applied | :needs_apply | :no_apply
  defp classify(repo_root, patch_path) do
    cond do
      git_apply_ok?(repo_root, patch_path, ["--reverse", "--check"]) -> :already_applied
      git_apply_ok?(repo_root, patch_path, ["--check"]) -> :needs_apply
      true -> :no_apply
    end
  end

  defp apply_one(_repo_root, patch_path, :already_applied, quiet?),
    do: say(quiet?, :already_applied, patch_path, "already patched")

  defp apply_one(repo_root, patch_path, :needs_apply, quiet?) do
    case System.cmd("git", ["apply", patch_path], cd: repo_root, stderr_to_stdout: true) do
      {_, 0} ->
        say(quiet?, :needs_apply, patch_path, "patched")

      {output, _} ->
        Mix.raise("""
        ✗ #{Path.relative_to(patch_path, repo_root)}: git apply failed.

        #{String.trim(output)}
        """)
    end
  end

  defp apply_one(repo_root, patch_path, :no_apply, _quiet?) do
    Mix.raise("""
    ✗ #{Path.relative_to(patch_path, repo_root)}: patch does not apply (and is not already applied).

    The upstream dep has diverged from what this patch was authored
    against. Recovery is documented in `mix help meshx.patch_deps` and
    `patches/README.md` (regenerate the patch against the new upstream,
    update its "Authored against:" header, commit).

    See also: project memory entry `mob-dev-ios-build-vendored-patches`.
    """)
  end

  defp git_apply_ok?(repo_root, patch_path, args) do
    case System.cmd("git", ["apply" | args] ++ [patch_path],
           cd: repo_root,
           stderr_to_stdout: true
         ) do
      {_, 0} -> true
      _ -> false
    end
  end

  # Output formatting -------------------------------------------------

  defp say(true = _quiet?, status, _patch, _msg)
       when status in [:already_applied, :needs_apply, :file_missing] do
    :ok
  end

  defp say(_quiet?, status, patch_path, msg) when is_binary(patch_path) do
    rel = Path.basename(patch_path)
    Mix.shell().info("  #{icon(status)}  patches/#{rel}: #{msg}")
  end

  defp icon(:already_applied), do: "✓"
  defp icon(:needs_apply), do: "→"
  defp icon(:no_apply), do: "✗"

  defp format(:already_applied), do: "already patched"
  defp format(:needs_apply), do: "needs apply"
  defp format(:no_apply), do: "does not apply (upstream divergence)"
end
