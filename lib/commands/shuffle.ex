defmodule BnBBot.Commands.Shuffle do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.SlashCmdFn

  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a shuffle command")

    resp =
      case inter.data.options do
        [stop, start] ->
          start_val = start.value
          stop_val = stop.value
          shuffle_two_nums(start_val, stop_val)

        [stop] ->
          stop_val = stop.value
          shuffle_single_num(stop_val)

        _ ->
          {:error, "An unknown error occurred"}
      end

    {:ok} =
      case resp do
        {:ok, resp_str} ->
          Api.create_interaction_response(
            inter,
            %{
              type: 4,
              data: %{
                content: resp_str
              }
            }
          )

        {:error, str} ->
          Api.create_interaction_response(
            inter,
            %{
              type: 4,
              data: %{
                content: str,
                flags: 64
              }
            }
          )
      end

    :ignore
  end

  def get_create_map() do
    %{
      type: 1,
      name: "shuffle",
      description: "Shuffle a series of numbers",
      options: [
        %{
          type: 4,
          name: "end",
          description: "The last number in the sequence",
          required: true
        },
        %{
          type: 4,
          name: "start",
          description: "The first number in the sequence, defaults to 1"
        }
      ]
    }
  end

  defp shuffle_nums(start, stop) when start < stop do
    Enum.shuffle(start..stop)
  end

  defp shuffle_nums(stop, start) when start < stop do
    Enum.shuffle(start..stop)
  end

  defp shuffle_single_num(num) when num <= 1 do
    {:error, "Cowardly refusing to shuffle a number less than 2"}
  end

  defp shuffle_single_num(num) when num <= 64 do
    vals = Enum.shuffle(1..num)
    {:ok, "From 1 to #{num} I made:\n```\n[#{Enum.join(vals, ", ")}]\n```"}
  end

  defp shuffle_single_num(_num) do
    {:error, "Cowardly refusing to shuffle a number greater than 64"}
  end

  defp shuffle_two_nums(first, second) when abs(first - second) <= 1 do
    {:error, "Cowardly refusing to shuffle numbers with a difference of less than 2"}
  end

  defp shuffle_two_nums(first, second) when abs(first - second) >= 64 do
    {:error, "Cowardly refusing to shuffle numbers with a difference greater than 64"}
  end

  defp shuffle_two_nums(first, second) do
    {low, high} = Enum.min_max([first, second])
    val = shuffle_nums(first, second)
    {:ok, "From #{low} to #{high} I made:\n```\n[#{Enum.join(val, ", ")}]\n```"}
  end
end
