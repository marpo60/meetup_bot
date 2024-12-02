defmodule MeetupBot.BackupDatabase do
  use Oban.Worker

  require OpenTelemetry.Tracer

  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "BackupDatabase"}])

      database_path = Application.get_env(:meetup_bot, MeetupBot.Repo)[:database]
      backup_path = create_backup(database_path)
      upload_to_s3(backup_path)
      delete_backup(backup_path)

      :ok
    end
  end

  def create_backup(db) do
    backup = "#{db}.backup"

    Tracer.with_span "backup" do
      System.shell(~s(sqlite3 #{db} ".backup '#{backup}'"))
    end

    Tracer.with_span "zip" do
      System.shell(~s(gzip -f #{backup}))
    end

    "#{backup}.gz"
  end

  def upload_to_s3(path) do
    Tracer.with_span "upload" do
      req =
        Req.new(
          base_url: System.fetch_env!("AWS_ENDPOINT_URL_S3"),
          aws_sigv4: [
            service: :s3,
            access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
            secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
          ]
        )

      now = DateTime.utc_now()
      size = File.stat!(path).size
      stream = File.stream!(path, 1024 * 1024 * 8)

      %{status: 200} =
        Req.put!(
          req,
          url: "/#{System.fetch_env!("AWS_BUCKET")}/backup-#{now.day}-#{now.month}.gz",
          headers: [content_length: size],
          body: stream
        )
    end
  end

  def delete_backup(path) do
    System.shell(~s(rm #{path}))
  end
end
