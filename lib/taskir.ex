defmodule Taskir do
  alias Yamlixir, as: Yaml

  @spec run_task(map, map) :: {atom, String.t()}
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

  @spec run_task(map, map) :: {atom, String.t()}
  def run_task(context, task = %{"command" => _, "body" => body}) do
    rand = for _ <- 1..40, into: "", do: <<Enum.random(~c"0123456789abcdef")>>

    script_path =
      "/tmp/taskir-script-#{rand}.#{task["script_file_extension"]}"

    case File.open(script_path, [:write]) do
      {:ok, file} ->
        IO.binwrite(file, body)
        File.close(file)

      {:error, _} ->
        IO.puts("Failed to create file")
    end

    run_task(context, Map.put(task, "script", script_path))
  end

  @spec run_task(map, map) :: {atom, String.t()}
  def run_task(context, task = %{"type" => "bash"}) do
    run_task(context, Map.put(task, "command", "bash"))
  end

  @spec run_task(map, map) :: {atom, String.t()}
  def run_task(context, task = %{"type" => "python"}) do
    run_task(context, Map.put(task, "command", "python"))
  end

  @spec run_task(map, map) :: {atom, String.t()}
  def run_task(context, task = %{"type" => "typescript"}) do
    run_task(
      context,
      Map.put(task, "command", "bash")
      |> Map.put("args", ["-c", "npx tsc \"$1\" && node \"${1/%.ts/.js}\"", "--"])
      |> Map.put("script_file_extension", "ts")
    )
  end

  def run(_, []), do: {:ok, ""}

  def run(context, [task | tasks]) when is_map(task) do
    with {:ok, task_output} <- run_task(context, task) do
      case run(context, tasks) do
        {:ok, rest_output} ->
          {:ok, task_output <> rest_output}

        {:error, rest_output} ->
          {:error, task_output <> rest_output}
      end
    end
  end

  def run(context, task_chains = [task_chain | _]) when is_list(task_chain) do
    Enum.map(task_chains, fn task_chain -> run(context, task_chain) end)
  end

  def print_results([]), do: IO.puts("")

  def print_results([{_, output} | results]) do
    IO.puts(output)
    print_results(results)
  end

  @spec main(String.t(), String.t()) :: any
  def main(context_path, tasks_path) when is_binary(context_path) do
    case File.read!(context_path) |> Yaml.decode() do
      {:ok, [context | _]} ->
        print_results(main(context, tasks_path))

      {:error, error} ->
        {:error, "Failed to decode context file #{error}"}
    end
  end

  @spec main(map, String.t()) :: list({atom, String.t()})
  def main(context, tasks_path) when is_map(context) do
    case File.read!(tasks_path) |> Yaml.decode() do
      {:ok, tasks} ->
        run(context, tasks)

      {:error, error} ->
        {:error, "Failed to decode tasks file #{error}"}
    end
  end
end
