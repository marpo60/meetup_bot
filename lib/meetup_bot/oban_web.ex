defmodule MeetupBot.ObanWeb do
  @moduledoc """
  A standalone Oban Web dashboard implementation that doesn't depend on Phoenix.
  Provides job monitoring, queue management, and job control features using Plug.
  """

  import Plug.Conn
  alias MeetupBot.Repo

  @default_limit 50

  @doc """
  Returns HTML for the main dashboard page showing jobs overview.
  """
  def dashboard(conn, params) do
    state = parse_state(params["state"] || "all")
    queue = params["queue"]
    worker = params["worker"]
    search = params["search"]
    limit = parse_limit(params["limit"])
    page = parse_page(params["page"])

    jobs = list_jobs(state: state, queue: queue, worker: worker, search: search, limit: limit, page: page)
    queues_info = get_queues_info()
    stats = get_stats()

    html = render_dashboard(jobs, queues_info, stats, %{
      state: state,
      queue: queue,
      worker: worker,
      search: search,
      limit: limit,
      page: page
    })

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  @doc """
  Returns HTML for a specific job detail page.
  """
  def job_detail(conn, job_id) do
    case get_job(job_id) do
      nil ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(404, "<h1>Job not found</h1>")

      job ->
        html = render_job_detail(job)

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)
    end
  end

  @doc """
  Handles job actions like retry, cancel, delete.
  """
  def job_action(conn, action, job_ids) when is_list(job_ids) do
    result = perform_action(action, job_ids)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{success: result.success, message: result.message}))
  end

  @doc """
  Handles queue actions like pause, resume, scale.
  """
  def queue_action(conn, action, queue_name, params \\ %{}) do
    result = perform_queue_action(action, queue_name, params)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{success: result.success, message: result.message}))
  end

  # Private functions

  defp list_jobs(opts) do
    import Ecto.Query

    query = from(j in Oban.Job, order_by: [desc: j.id])

    query =
      if opts[:state] && opts[:state] != :all do
        from(j in query, where: j.state == ^to_string(opts[:state]))
      else
        query
      end

    query =
      if opts[:queue] do
        from(j in query, where: j.queue == ^opts[:queue])
      else
        query
      end

    query =
      if opts[:worker] do
        from(j in query, where: j.worker == ^opts[:worker])
      else
        query
      end

    query =
      if opts[:search] do
        search_pattern = "%#{opts[:search]}%"
        from(j in query, where: fragment("? LIKE ?", j.args, ^search_pattern))
      else
        query
      end

    offset = (opts[:page] - 1) * opts[:limit]

    query
    |> limit(^opts[:limit])
    |> offset(^offset)
    |> Repo.all()
  end

  defp get_job(job_id) do
    Repo.get(Oban.Job, job_id)
  end

  defp get_queues_info do
    import Ecto.Query

    query =
      from(j in Oban.Job,
        group_by: [j.queue, j.state],
        select: %{queue: j.queue, state: j.state, count: count(j.id)}
      )

    results = Repo.all(query)

    results
    |> Enum.group_by(& &1.queue)
    |> Enum.map(fn {queue, states} ->
      counts = Map.new(states, fn s -> {s.state, s.count} end)

      %{
        name: queue,
        available: Map.get(counts, "available", 0),
        executing: Map.get(counts, "executing", 0),
        scheduled: Map.get(counts, "scheduled", 0),
        retryable: Map.get(counts, "retryable", 0),
        completed: Map.get(counts, "completed", 0),
        discarded: Map.get(counts, "discarded", 0),
        cancelled: Map.get(counts, "cancelled", 0)
      }
    end)
  end

  defp get_stats do
    import Ecto.Query

    query =
      from(j in Oban.Job,
        group_by: j.state,
        select: %{state: j.state, count: count(j.id)}
      )

    results = Repo.all(query)
    counts = Map.new(results, fn r -> {r.state, r.count} end)

    %{
      available: Map.get(counts, "available", 0),
      executing: Map.get(counts, "executing", 0),
      scheduled: Map.get(counts, "scheduled", 0),
      retryable: Map.get(counts, "retryable", 0),
      completed: Map.get(counts, "completed", 0),
      discarded: Map.get(counts, "discarded", 0),
      cancelled: Map.get(counts, "cancelled", 0),
      total: Enum.reduce(counts, 0, fn {_, count}, acc -> acc + count end)
    }
  end

  defp perform_action("retry", job_ids) do
    import Ecto.Query

    count =
      from(j in Oban.Job, where: j.id in ^job_ids and j.state in ["retryable", "discarded"])
      |> Repo.update_all(set: [state: "available", scheduled_at: DateTime.utc_now()])
      |> elem(0)

    %{success: true, message: "#{count} job(s) queued for retry"}
  end

  defp perform_action("cancel", job_ids) do
    import Ecto.Query

    count =
      from(j in Oban.Job, where: j.id in ^job_ids and j.state in ["available", "scheduled", "retryable"])
      |> Repo.update_all(set: [state: "cancelled"])
      |> elem(0)

    %{success: true, message: "#{count} job(s) cancelled"}
  end

  defp perform_action("delete", job_ids) do
    import Ecto.Query

    count =
      from(j in Oban.Job, where: j.id in ^job_ids)
      |> Repo.delete_all()
      |> elem(0)

    %{success: true, message: "#{count} job(s) deleted"}
  end

  defp perform_action(_, _) do
    %{success: false, message: "Unknown action"}
  end

  defp perform_queue_action("pause", queue_name, _params) do
    Oban.pause_queue(queue: queue_name)
    %{success: true, message: "Queue #{queue_name} paused"}
  end

  defp perform_queue_action("resume", queue_name, _params) do
    Oban.resume_queue(queue: queue_name)
    %{success: true, message: "Queue #{queue_name} resumed"}
  end

  defp perform_queue_action("scale", queue_name, params) do
    limit = String.to_integer(params["limit"] || "10")
    Oban.scale_queue(queue: queue_name, limit: limit)
    %{success: true, message: "Queue #{queue_name} scaled to #{limit}"}
  end

  defp perform_queue_action(_, _, _) do
    %{success: false, message: "Unknown queue action"}
  end

  defp parse_state("available"), do: :available
  defp parse_state("executing"), do: :executing
  defp parse_state("scheduled"), do: :scheduled
  defp parse_state("retryable"), do: :retryable
  defp parse_state("completed"), do: :completed
  defp parse_state("discarded"), do: :discarded
  defp parse_state("cancelled"), do: :cancelled
  defp parse_state(_), do: :all

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(limit) when is_binary(limit), do: String.to_integer(limit)
  defp parse_limit(limit) when is_integer(limit), do: limit

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_binary(page), do: String.to_integer(page)
  defp parse_page(page) when is_integer(page), do: page

  defp render_dashboard(jobs, queues, stats, filters) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Oban Dashboard</title>
      <style>#{css()}</style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>🔧 Oban Dashboard</h1>
          <div class="refresh-controls">
            <button onclick="location.reload()">🔄 Refresh</button>
            <button onclick="toggleAutoRefresh()">⏱️ Auto Refresh</button>
          </div>
        </header>

        <section class="stats">
          <div class="stat-card">
            <div class="stat-value">#{stats.total}</div>
            <div class="stat-label">Total Jobs</div>
          </div>
          <div class="stat-card available">
            <div class="stat-value">#{stats.available}</div>
            <div class="stat-label">Available</div>
          </div>
          <div class="stat-card executing">
            <div class="stat-value">#{stats.executing}</div>
            <div class="stat-label">Executing</div>
          </div>
          <div class="stat-card scheduled">
            <div class="stat-value">#{stats.scheduled}</div>
            <div class="stat-label">Scheduled</div>
          </div>
          <div class="stat-card retryable">
            <div class="stat-value">#{stats.retryable}</div>
            <div class="stat-label">Retryable</div>
          </div>
          <div class="stat-card completed">
            <div class="stat-value">#{stats.completed}</div>
            <div class="stat-label">Completed</div>
          </div>
          <div class="stat-card discarded">
            <div class="stat-value">#{stats.discarded}</div>
            <div class="stat-label">Discarded</div>
          </div>
          <div class="stat-card cancelled">
            <div class="stat-value">#{stats.cancelled}</div>
            <div class="stat-label">Cancelled</div>
          </div>
        </section>

        <section class="queues">
          <h2>Queues</h2>
          <div class="queue-list">
            #{render_queues(queues)}
          </div>
        </section>

        <section class="filters">
          <h2>Filter Jobs</h2>
          <form method="get" action="/oban">
            <div class="filter-row">
              <select name="state" onchange="this.form.submit()">
                <option value="all" #{if filters.state == :all, do: "selected", else: ""}>All States</option>
                <option value="available" #{if filters.state == :available, do: "selected", else: ""}>Available</option>
                <option value="executing" #{if filters.state == :executing, do: "selected", else: ""}>Executing</option>
                <option value="scheduled" #{if filters.state == :scheduled, do: "selected", else: ""}>Scheduled</option>
                <option value="retryable" #{if filters.state == :retryable, do: "selected", else: ""}>Retryable</option>
                <option value="completed" #{if filters.state == :completed, do: "selected", else: ""}>Completed</option>
                <option value="discarded" #{if filters.state == :discarded, do: "selected", else: ""}>Discarded</option>
                <option value="cancelled" #{if filters.state == :cancelled, do: "selected", else: ""}>Cancelled</option>
              </select>
              <input type="text" name="search" placeholder="Search args..." value="#{filters.search || ""}" />
              <input type="text" name="queue" placeholder="Queue name..." value="#{filters.queue || ""}" />
              <input type="text" name="worker" placeholder="Worker module..." value="#{filters.worker || ""}" />
              <button type="submit">Search</button>
              <a href="/oban" class="btn-reset">Reset</a>
            </div>
          </form>
        </section>

        <section class="jobs">
          <h2>Jobs</h2>
          <div class="bulk-actions">
            <button onclick="bulkAction('retry')" class="btn-retry">Retry Selected</button>
            <button onclick="bulkAction('cancel')" class="btn-cancel">Cancel Selected</button>
            <button onclick="bulkAction('delete')" class="btn-delete">Delete Selected</button>
          </div>
          <table>
            <thead>
              <tr>
                <th><input type="checkbox" id="select-all" onclick="toggleAll(this)" /></th>
                <th>ID</th>
                <th>State</th>
                <th>Queue</th>
                <th>Worker</th>
                <th>Args</th>
                <th>Attempt</th>
                <th>Scheduled At</th>
                <th>Attempted At</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              #{render_jobs(jobs)}
            </tbody>
          </table>
          <div class="pagination">
            #{render_pagination(filters)}
          </div>
        </section>
      </div>

      <script>#{javascript()}</script>
    </body>
    </html>
    """
  end

  defp render_queues(queues) do
    queues
    |> Enum.map(fn queue ->
      """
      <div class="queue-card">
        <h3>#{queue.name}</h3>
        <div class="queue-stats">
          <span class="queue-stat available">Available: #{queue.available}</span>
          <span class="queue-stat executing">Executing: #{queue.executing}</span>
          <span class="queue-stat scheduled">Scheduled: #{queue.scheduled}</span>
          <span class="queue-stat retryable">Retryable: #{queue.retryable}</span>
        </div>
        <div class="queue-actions">
          <button onclick="queueAction('pause', '#{queue.name}')">⏸️ Pause</button>
          <button onclick="queueAction('resume', '#{queue.name}')">▶️ Resume</button>
          <button onclick="scaleQueue('#{queue.name}')">📊 Scale</button>
        </div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_jobs([]), do: "<tr><td colspan='10'>No jobs found</td></tr>"

  defp render_jobs(jobs) do
    jobs
    |> Enum.map(fn job ->
      args_preview = Jason.encode!(job.args) |> String.slice(0..50)
      state_class = "state-#{job.state}"

      """
      <tr>
        <td><input type="checkbox" class="job-select" value="#{job.id}" /></td>
        <td><a href="/oban/jobs/#{job.id}">#{job.id}</a></td>
        <td><span class="badge #{state_class}">#{job.state}</span></td>
        <td>#{job.queue}</td>
        <td class="worker">#{format_worker(job.worker)}</td>
        <td class="args">#{args_preview}...</td>
        <td>#{job.attempt}/#{job.max_attempts}</td>
        <td>#{format_datetime(job.scheduled_at)}</td>
        <td>#{format_datetime(job.attempted_at)}</td>
        <td>
          <button onclick="jobAction('retry', [#{job.id}])" class="btn-small">Retry</button>
          <button onclick="jobAction('cancel', [#{job.id}])" class="btn-small">Cancel</button>
          <button onclick="jobAction('delete', [#{job.id}])" class="btn-small">Delete</button>
        </td>
      </tr>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_job_detail(job) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Job #{job.id} - Oban Dashboard</title>
      <style>#{css()}</style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1><a href="/oban">🔧 Oban Dashboard</a> / Job #{job.id}</h1>
        </header>

        <section class="job-detail">
          <div class="detail-row">
            <span class="label">ID:</span>
            <span class="value">#{job.id}</span>
          </div>
          <div class="detail-row">
            <span class="label">State:</span>
            <span class="value"><span class="badge state-#{job.state}">#{job.state}</span></span>
          </div>
          <div class="detail-row">
            <span class="label">Queue:</span>
            <span class="value">#{job.queue}</span>
          </div>
          <div class="detail-row">
            <span class="label">Worker:</span>
            <span class="value">#{job.worker}</span>
          </div>
          <div class="detail-row">
            <span class="label">Attempt:</span>
            <span class="value">#{job.attempt} / #{job.max_attempts}</span>
          </div>
          <div class="detail-row">
            <span class="label">Priority:</span>
            <span class="value">#{job.priority}</span>
          </div>
          <div class="detail-row">
            <span class="label">Scheduled At:</span>
            <span class="value">#{format_datetime(job.scheduled_at)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Attempted At:</span>
            <span class="value">#{format_datetime(job.attempted_at)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Completed At:</span>
            <span class="value">#{format_datetime(job.completed_at)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Inserted At:</span>
            <span class="value">#{format_datetime(job.inserted_at)}</span>
          </div>

          <h3>Arguments</h3>
          <pre class="json">#{Jason.encode!(job.args, pretty: true)}</pre>

          <h3>Meta</h3>
          <pre class="json">#{Jason.encode!(job.meta, pretty: true)}</pre>

          #{if job.errors && job.errors != [], do: render_errors(job.errors), else: ""}

          <div class="actions">
            <button onclick="jobAction('retry', [#{job.id}])" class="btn-retry">Retry Job</button>
            <button onclick="jobAction('cancel', [#{job.id}])" class="btn-cancel">Cancel Job</button>
            <button onclick="jobAction('delete', [#{job.id}])" class="btn-delete">Delete Job</button>
          </div>
        </section>
      </div>

      <script>#{javascript()}</script>
    </body>
    </html>
    """
  end

  defp render_errors(errors) do
    """
    <h3>Errors</h3>
    #{Enum.map_join(errors, "\n", fn error ->
      """
      <div class="error-block">
        <div class="error-attempt">Attempt #{error["attempt"]}</div>
        <div class="error-time">#{format_datetime(error["at"])}</div>
        <pre class="error-message">#{error["error"]}</pre>
      </div>
      """
    end)}
    """
  end

  defp render_pagination(filters) do
    prev_page = max(1, filters.page - 1)
    next_page = filters.page + 1

    query_string =
      [
        state: (if filters.state != :all, do: to_string(filters.state)),
        queue: filters.queue,
        worker: filters.worker,
        search: filters.search,
        limit: filters.limit
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")

    base_query = if query_string != "", do: "?#{query_string}&", else: "?"

    """
    <a href="/oban#{base_query}page=#{prev_page}" class="pagination-btn">← Previous</a>
    <span>Page #{filters.page}</span>
    <a href="/oban#{base_query}page=#{next_page}" class="pagination-btn">Next →</a>
    """
  end

  defp format_worker(worker) do
    worker
    |> String.split(".")
    |> List.last()
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end

  defp css do
    """
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; line-height: 1.6; }
    .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
    header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    header h1 { font-size: 28px; }
    header h1 a { color: #333; text-decoration: none; }
    header h1 a:hover { color: #0066cc; }
    .refresh-controls button { margin-left: 10px; padding: 8px 16px; background: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; }
    .refresh-controls button:hover { background: #0052a3; }
    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 30px; }
    .stat-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); text-align: center; }
    .stat-value { font-size: 32px; font-weight: bold; }
    .stat-label { font-size: 14px; color: #666; margin-top: 5px; }
    .stat-card.available { border-left: 4px solid #4CAF50; }
    .stat-card.executing { border-left: 4px solid #2196F3; }
    .stat-card.scheduled { border-left: 4px solid #FF9800; }
    .stat-card.retryable { border-left: 4px solid #FFC107; }
    .stat-card.completed { border-left: 4px solid #8BC34A; }
    .stat-card.discarded { border-left: 4px solid #f44336; }
    .stat-card.cancelled { border-left: 4px solid #9E9E9E; }
    section { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
    h2 { margin-bottom: 20px; font-size: 22px; }
    h3 { margin: 20px 0 10px 0; font-size: 18px; }
    .queue-list { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px; }
    .queue-card { background: #f9f9f9; padding: 15px; border-radius: 6px; border-left: 4px solid #0066cc; }
    .queue-stats { margin: 10px 0; }
    .queue-stat { display: inline-block; margin-right: 15px; font-size: 14px; }
    .queue-stat.available { color: #4CAF50; }
    .queue-stat.executing { color: #2196F3; }
    .queue-stat.scheduled { color: #FF9800; }
    .queue-stat.retryable { color: #FFC107; }
    .queue-actions button { margin-right: 5px; padding: 6px 12px; background: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px; }
    .queue-actions button:hover { background: #0052a3; }
    .filters form { display: flex; gap: 10px; flex-wrap: wrap; }
    .filter-row { display: flex; gap: 10px; flex: 1; }
    .filter-row select, .filter-row input[type="text"] { padding: 8px; border: 1px solid #ddd; border-radius: 4px; flex: 1; }
    .filter-row button { padding: 8px 20px; background: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; }
    .filter-row button:hover { background: #0052a3; }
    .btn-reset { padding: 8px 20px; background: #666; color: white; border-radius: 4px; text-decoration: none; display: inline-block; }
    .btn-reset:hover { background: #555; }
    .bulk-actions { margin-bottom: 15px; }
    .bulk-actions button { margin-right: 10px; padding: 8px 16px; border: none; border-radius: 4px; cursor: pointer; color: white; }
    .btn-retry { background: #4CAF50; }
    .btn-retry:hover { background: #45a049; }
    .btn-cancel { background: #FF9800; }
    .btn-cancel:hover { background: #e68900; }
    .btn-delete { background: #f44336; }
    .btn-delete:hover { background: #da190b; }
    table { width: 100%; border-collapse: collapse; }
    thead { background: #f0f0f0; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
    th { font-weight: 600; }
    .worker { font-family: monospace; font-size: 13px; }
    .args { font-family: monospace; font-size: 12px; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; }
    .state-available { background: #4CAF50; color: white; }
    .state-executing { background: #2196F3; color: white; }
    .state-scheduled { background: #FF9800; color: white; }
    .state-retryable { background: #FFC107; color: #333; }
    .state-completed { background: #8BC34A; color: white; }
    .state-discarded { background: #f44336; color: white; }
    .state-cancelled { background: #9E9E9E; color: white; }
    .btn-small { padding: 4px 8px; font-size: 11px; margin-right: 4px; background: #0066cc; color: white; border: none; border-radius: 3px; cursor: pointer; }
    .btn-small:hover { background: #0052a3; }
    .pagination { margin-top: 20px; text-align: center; }
    .pagination-btn { display: inline-block; padding: 8px 16px; margin: 0 5px; background: #0066cc; color: white; text-decoration: none; border-radius: 4px; }
    .pagination-btn:hover { background: #0052a3; }
    .job-detail { max-width: 900px; }
    .detail-row { display: flex; padding: 12px 0; border-bottom: 1px solid #eee; }
    .detail-row .label { font-weight: 600; width: 180px; }
    .detail-row .value { flex: 1; }
    .json { background: #f5f5f5; padding: 15px; border-radius: 4px; overflow-x: auto; font-family: monospace; font-size: 13px; line-height: 1.5; }
    .actions { margin-top: 30px; }
    .actions button { margin-right: 10px; padding: 10px 20px; font-size: 14px; border: none; border-radius: 4px; cursor: pointer; color: white; }
    .error-block { background: #fff3f3; border: 1px solid #ffcdd2; padding: 15px; margin-bottom: 10px; border-radius: 4px; }
    .error-attempt { font-weight: 600; color: #c62828; }
    .error-time { font-size: 12px; color: #666; margin: 5px 0; }
    .error-message { background: #ffebee; padding: 10px; border-radius: 3px; margin-top: 10px; font-family: monospace; font-size: 12px; white-space: pre-wrap; word-break: break-word; }
    """
  end

  defp javascript do
    """
    let autoRefreshInterval = null;

    function toggleAll(checkbox) {
      const checkboxes = document.querySelectorAll('.job-select');
      checkboxes.forEach(cb => cb.checked = checkbox.checked);
    }

    function getSelectedJobIds() {
      const checkboxes = document.querySelectorAll('.job-select:checked');
      return Array.from(checkboxes).map(cb => parseInt(cb.value));
    }

    async function jobAction(action, jobIds) {
      if (jobIds.length === 0) {
        alert('No jobs selected');
        return;
      }

      if (!confirm(`Are you sure you want to ${action} ${jobIds.length} job(s)?`)) {
        return;
      }

      try {
        const response = await fetch('/oban/jobs/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action, job_ids: jobIds })
        });

        const result = await response.json();
        alert(result.message);

        if (result.success) {
          location.reload();
        }
      } catch (error) {
        alert('Error: ' + error.message);
      }
    }

    function bulkAction(action) {
      const jobIds = getSelectedJobIds();
      jobAction(action, jobIds);
    }

    async function queueAction(action, queueName) {
      if (!confirm(`Are you sure you want to ${action} queue "${queueName}"?`)) {
        return;
      }

      try {
        const response = await fetch('/oban/queues/action', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action, queue: queueName })
        });

        const result = await response.json();
        alert(result.message);

        if (result.success) {
          location.reload();
        }
      } catch (error) {
        alert('Error: ' + error.message);
      }
    }

    function scaleQueue(queueName) {
      const limit = prompt(`Enter new limit for queue "${queueName}":`, '10');
      if (limit === null) return;

      fetch('/oban/queues/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'scale', queue: queueName, limit: limit })
      })
      .then(response => response.json())
      .then(result => {
        alert(result.message);
        if (result.success) location.reload();
      })
      .catch(error => alert('Error: ' + error.message));
    }

    function toggleAutoRefresh() {
      if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
        alert('Auto-refresh disabled');
      } else {
        autoRefreshInterval = setInterval(() => location.reload(), 5000);
        alert('Auto-refresh enabled (every 5 seconds)');
      }
    }
    """
  end
end
