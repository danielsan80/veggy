defmodule Veggy.Projection.Pomodori do
  # TODO: @behaviour Projection
  # TODO: use Veggy.Mongo.Projection, collection: "projection.pomodori"
  @collection "projection.pomodori"

  # RECORD:
  # - pomodoro_id
  # - timer_id
  # - started_at
  # - ended_at
  # - squashed_at
  # - ticking
  # - description
  # - duration

  # "PomodoroStarted": aggregate_id, pomodoro_id, command_id, duration
  # "PomodoroEnded": aggregate_id, pomodoro_id

  def init do
    Veggy.EventStore.subscribe(self, &match?(%{event: "PomodoroStarted"}, &1))
    Veggy.EventStore.subscribe(self, &match?(%{event: "PomodoroSquashed"}, &1))
    Veggy.EventStore.subscribe(self, &match?(%{event: "PomodoroEnded"}, &1))
    # TODO: create appropriate indexes
  end


  def fetch(%{pomodoro_id: pomodoro_id}) do
    case Mongo.find(Veggy.MongoDB, @collection, %{"pomodoro_id" => pomodoro_id}) |> Enum.to_list do
      [] -> %{}
      [d] -> d
    end
  end


  def store(record) do
    Mongo.save_one(Veggy.MongoDB, @collection, record)
  end


  def process(%{event: "PomodoroStarted"} = event, %{}) do
    %{"pomodoro_id" => event.pomodoro_id,
      "timer_id" => event.aggregate_id,
      "started_at" => event.received_at,
      "ticking" => true,
      "duration" => event.duration}
  end

  def process(%{event: "PomodoroEnded"} = event, record) do
    record
    |> Map.put("ended_at", event.received_at)
    |> Map.put("ticking", false)
  end

  def process(%{event: "PomodoroSquashed"} = event, record) do
    record
    |> Map.put("squashed_at", event.received_at)
    |> Map.put("ticking", false)
  end


  # TODO: query("pomodori-by-day", %{"from-day" => _, "to-day" => _, "timer_id" => _})
  # TODO: query("pomodori-by-tag", %{"from-day" => _, "to-day" => _, "tag" => _, "timer_id" => _})

  def query("pomodori-of-the-day", %{"day" => day, "timer_id" => timer_id} = parameters) do
    timer_id = Veggy.MongoDB.ObjectId.from_string(timer_id)
    case Timex.parse(day, "{YYYY}-{0M}-{0D}") do
      {:ok, day} ->
        beginning_of_day =
          day |> Timex.beginning_of_day |> Timex.to_datetime |> Veggy.MongoDB.DateTime.from_datetime
        end_of_day =
          day |> Timex.end_of_day |> Timex.to_datetime |> Veggy.MongoDB.DateTime.from_datetime
        query = %{"started_at" => %{"$gte" => beginning_of_day, "$lte" => end_of_day},
                  "timer_id" => timer_id,
                 }
        Mongo.find(Veggy.MongoDB, @collection, query)
        |> Enum.to_list
        |> (&{:ok, &1}).()
      {:error, reason} ->
        {:error, "parameter (day=#{parameters["day"]}: #{reason}"}
    end
  end

  def query(_, _), do: nil
end
