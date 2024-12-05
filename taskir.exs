require OptionParser
require Taskir

# TODO:
# * take context from yaml file (apply BEFORE all other overrides)
# * take env from file (apply BEFORE cli flags)
case OptionParser.parse(System.argv(),
       strict: [workdir: :string, env_var: :keep]
     ) do
  {opts, [task_file], []} ->
    context = %{
      "env" =>
        Enum.reduce(
          Enum.reverse(opts),
          [],
          fn {opt_type, v}, acc ->
            case opt_type do
              :env_var -> [List.to_tuple(String.split(v, "=", parts: 2)) | acc]
              _ -> acc
            end
          end
        ),
      "workdir" => opts[:workdir] || File.cwd!()
    }

    Taskir.main(context, task_file)

  {_, _, errors} ->
    # TODO: improve!
    throw(errors)
end
