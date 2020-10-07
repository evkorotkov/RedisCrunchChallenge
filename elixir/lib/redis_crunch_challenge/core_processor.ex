defmodule RedisCrunchChallenge.CoreProcessor do
  require Jason.Helpers

  @discounts %{
    0 => 0,
    1 => 5,
    2 => 10,
    3 => 15,
    4 => 20,
    5 => 25,
    6 => 30
  }

  @encode_order [:index, :wday, :payload, :price, :user_id, :total]

  def define_supported_atoms do
    @encode_order
  end

  def process_item(item) do
    %{index: index} = item = Jason.decode!(item, keys: :atoms!)

    item = item
      |> Map.put_new_lazy(:total, fn -> calculate_total(item) end)
      |> Jason.Helpers.json_map_take(@encode_order)
      |> Jason.encode!
      |> calc_signature

    unix_time = DateTime.utc_now() |> DateTime.to_unix()

    [unix_time, index, item]
  end

  defp calculate_total(%{price: price, wday: wday}) do
    Map.get(@discounts, wday, 0)
    |> calc_discount()
    |> Kernel.*(price)
    |> Kernel.*(100)
    |> Float.round()
    |> Kernel./(100)
  end

  defp calc_discount(discount_percentage) do
    1 - discount_percentage / 100.0
  end

  defp calc_signature(data) do
    :crypto.hash(:md5, data) |> Base.encode16(case: :lower)
  end
end
