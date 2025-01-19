defmodule Taskir do
  alias Yamlixir, as: Yaml

  @spec run_task(map, map) :: {atom, String.t()}
  def run_task(
        context,
        task = %{
          "command" => command,
          "script" => script,
          "output_collectable" => output_collectable
        }
      ) do
    case System.cmd(
           command,
           (task["args"] || []) ++ [script],
           cd: context["workdir"] || File.cwd!(),
           env: context["env"] || [],
           into: output_collectable,
           stderr_to_stdout: true
         ) do
      {_, 0} -> :ok
      _ -> :error
    end
  end

  @spec run_task(map, map) :: {atom, String.t()}
  def run_task(
        context,
        task = %{
          "command" => _,
          "script" => _
        }
      ) do
    run_task(
      context,
      Map.put(
        task,
        "output_collectable",
        File.stream!(
          "#{context["workdir"]}/.taskir-output.#{task["group_name"] || task["document_index"]}.#{task["task_name"] || task["task_index"]}",
          encoding: :utf8
        )
      )
    )
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
    |> Enum.map(fn {status, _} ->
      status
    end)
  end

  def add_indexes(tasks) do
    tasks
    |> Stream.with_index()
    |> Enum.map(fn {task_chain, doc_id} ->
      task_chain
      |> Stream.with_index()
      |> Enum.map(fn {task, task_id} ->
        task |> Map.put("document_index", doc_id) |> Map.put("task_index", task_id)
      end)
    end)
  end

  @spec main(map, String.t()) :: list({atom, String.t()})
  def main(context, tasks_path) do
    case File.read!(tasks_path) |> Yaml.decode() do
      {:ok, tasks} ->
        run(context, add_indexes(tasks))

      {:error, error} ->
        {:error, "Failed to decode tasks file #{error}"}
    end
  end
end
