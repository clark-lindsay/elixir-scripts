# Example usage: 
# ```
# elixir http_stress.exs --url="https://www.google.com" --total-requests=32 --concurrency=1
# ```
defmodule Args do
  def valid?(args) do
    case args do
      {parsed_options, _argv, _errors} when length(parsed_options) == 3 ->
        Map.new(parsed_options)

      {parsed_options, _argv, errors} ->
        IO.inspect(parsed_options, label: "Valid args")
        IO.inspect(errors, label: "Invalid args")

        raise "Invalid arguments were provided"

      _ ->
        raise "Invalid arguments were provided"
    end
  end
end

cli_args = System.argv()

supported_options = [url: :string, total_requests: :integer, concurrency: :integer]

%{url: url, total_requests: total_requests, concurrency: concurrency} =
  options =
  OptionParser.parse(cli_args, strict: supported_options)
  |> Args.valid?()

:inets.start()
:ssl.start()

case :httpc.request(:get, {String.to_charlist(url), []}, [ssl: [verify: :verify_none]], []) do
  {:error, _} ->
    raise "Failed to connect to the provided url"

  _ ->
    :ok
end

test_start_time = System.monotonic_time()

results =
  1..total_requests
  |> Task.async_stream(
    fn _ ->
      start_time = System.monotonic_time()
      :httpc.request(:get, {String.to_charlist(url), []}, [ssl: [verify: :verify_none]], [])
      System.monotonic_time() - start_time
    end,
    max_concurrency: concurrency
  )
  |> Enum.map(fn
    {:ok, request_time} ->
      System.convert_time_unit(request_time, :native, :millisecond)

    _ ->
      :error
  end)

total_test_time =
  System.convert_time_unit(System.monotonic_time() - test_start_time, :native, :millisecond)

IO.inspect(options, label: "Options")

IO.puts("Total test time: #{total_test_time}ms")
IO.puts("Average request time: #{total_test_time / total_requests}ms")
IO.puts("Min response time: #{Enum.min(results)}")
IO.puts("Max response time: #{Enum.max(results)}")
IO.puts("Error count: #{Enum.count(results, &(&1 == :error))}")
