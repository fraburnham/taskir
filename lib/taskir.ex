defmodule Taskir do
  alias Yamlixir, as: Yaml

  @spec run_task(map, map) :: {atom, String.t()}
  def run_task(context, task = %{"command" => command, "script" => script}) do
    case System.cmd(
           command,
           (task["args"] || []) ++ [script],
           cd: context["workdir"] || File.cwd!(),
           env: context["env"] || [],
           into: context["output_collectable"] || IO.stream(),
           stderr_to_stdout: true
         ) do
      {_, 0} -> :ok
      _ -> :error
    end
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

  def run(_, []), do: :ok

  def run(context, [task | tasks]) when is_map(task) do
    with :ok <- run_task(context, task) do
      run(context, tasks)
    end
  end

  def run(context, task_chains = [task_chain | _]) when is_list(task_chain) do
    parent = self()

    # start processes
    task_chains
    |> Stream.with_index()
    |> Enum.map(fn {task_chain, id} ->
      spawn(fn ->
        send(parent, {run(context, task_chain), id})
      end)
    end)

    # get response, sort, strip metadata
    1..length(task_chains)
    |> Stream.map(fn _ ->
      receive do
        response ->
          response
      end
    end)
    |> Enum.sort(fn {_, a_id}, {_, b_id} ->
      a_id <= b_id
    end)
    |> Enum.map(fn {data, _} ->
      data
    end)
  end

  @spec main(String.t(), String.t()) :: any
  def main(context_path, tasks_path) when is_binary(context_path) do
    case File.read!(context_path) |> Yaml.decode() do
      {:ok, [context | _]} ->
        main(context, tasks_path)

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
