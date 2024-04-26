defmodule MeetupBot.Sampler do
  def setup(attributes) when is_map(attributes) do
    attributes
  end

  def setup(_) do
    %{}
  end

  def description(_) do
    "MeetupBotSampler"
  end

  def should_sample(
        _ctx,
        _trace_id,
        _links,
        _span_name,
        _span_kind,
        %{"oban.plugin": o},
        _config_attributes
      ) when o in [Oban.Stager, Oban.Plugins.Pruner, Oban.Plugins.Cron] do
    {:drop, [], []}
  end


  def should_sample(
        _ctx,
        _trace_id,
        _links,
        _span_name,
        _span_kind,
        _attributes,
        _config_attributes
      ) do
    {:record_and_sample, [], []}
  end
end
