defmodule Taskir do
  alias Yamlixir, as: Yaml

  @spec run_task(map, map) :: {atom, String.t}
  def run_task(context, task = %{"command" => command, "script" => script}) do
    {output, exit_code} =
      System.cmd(
        command,
        (task["args"] || []) ++ [script],
        cd: context["workdir"] || File.cwd!(),
        env: context["env"] || []
      )

    if exit_code == 0, do: {:ok, output}, else: {:error, output}
  end

  @spec run_task(map, map) :: {atom, String.t}
  def run_task(context, task = %{"command" => _, "body" => body}) do
    # This should be a much much better random file name generator (probably make a temp dir related to each task chain...)
    script_path = "/tmp/taskir-script-#{Enum.random(1..100)}-#{Enum.random(1..100)}.#{task["script_file_extension"]}"

    case File.open(script_path, [:write]) do
      {:ok, file} ->
        IO.binwrite(file, body)
        File.close(file)

      {:error, _} ->
        IO.puts("Failed to create file")
    end

    run_task(context, Map.put(task, "script", script_path))
  end

  @spec run_task(map, map) :: {atom, String.t}
  def run_task(context, task = %{"type" => "bash"}) do
    run_task(context, Map.put(task, "command", "bash"))
  end

  @spec run_task(map, map) :: {atom, String.t}
  def run_task(context, task = %{"type" => "python"}) do
    run_task(context, Map.put(task, "command", "python"))
  end

  @spec run_task(map, map) :: {atom, String.t}
  def run_task(context, task = %{"type" => "typescript"}) do
    run_task(
      context,
      Map.put(task, "command", "bash")
      |> Map.put("args", ["-c", "npx tsc \"$1\" && node \"${1/%.ts/.js}\"", "--"])
      |> Map.put("script_file_extension", "ts")
    )
  end

  def run(_context, []), do: :success

  def run(context, [task | tasks]) when is_map(task) do
    {status, output} = run_task(context, task)

    # What this _should_ do is transfer the data from stdout/stderr streams into a stream for these tasks
    IO.puts(output)
    if status == :ok, do: run(context, tasks), else: :error
  end

  def run(context, task_chains = [task_chain | _]) when is_list(task_chain) do
    # task_chains are independent (and soon to be run in parallel)
    # so they can be run w/o checking on the result (their lower level fns should handle output details)
    Enum.map(task_chains, fn task_chain -> run(context, task_chain) end)
  end

  @spec main(String.t, String.t) :: any
  def main(context_path, tasks_path) when is_binary(context_path) do
    case File.read!(context_path) |> Yaml.decode() do
      {:ok, [context | _]} -> main(context, tasks_path)

      {:error, error} ->
        IO.puts("Failed to decode context file #{error}")
    end
  end

  @spec main(map, String.t) :: any
  def main(context, tasks_path) when is_map(context) do
    case File.read!(tasks_path) |> Yaml.decode() do
      {:ok, tasks} -> run(context, tasks)
      {:error, error} -> IO.puts("Failed to decode tasks file #{error}")
    end
  end
end
