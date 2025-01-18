defmodule Taskir.Context do
  def from_file(path) do
    with {:ok, filedata} <- File.read(path) do
      :erlang.binary_to_term(filedata)
    end
  end

  def to_file(path, context) do
    with :ok <- File.write(path, :erlang.term_to_binary(context)) do
      :ok
    end
  end
end
