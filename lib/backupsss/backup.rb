require 'parallel'

module Backupsss
  # A class for delivering a tar to S3
  class Backup
    MAX_FILE_SIZE = 1024 * 1024 * 100 # 100MB

    attr_reader :config, :client, :filename

    def initialize(config, client)
      @config   = config
      @client   = client
      @filename = config[:filename]
    end

    def put_file(file)
      large_file(file) ? multi_upload(file) : single_upload(file)
    end

    private

    def create_multipart_upload
      $stdout.puts 'Creating a multipart upload'

      client.create_multipart_upload(bucket_opts)
    end

    def large_file(file)
      $stdout.puts 'Checking backup size ...'
      is_lg  = file.size > MAX_FILE_SIZE
      status = is_lg ? 'greater than' : 'less than or equal to'
      $stdout.puts "Size of backup is #{status} 100MB"

      is_lg
    end

    def complete_multipart_upload_request(upload_id, parts)
      bucket_opts.merge(
        upload_id: upload_id, multipart_upload: { parts: parts }
      )
    end

    def timed_multipart_upload
      s = Time.now
      $stdout.puts "Starting multipart upload at #{s}"
      yield
      e = Time.now
      duration = ((e - s) / 60).round(2)
      output   = ["Completed multipart upload at #{e}"]
      output << "Completed in #{duration} minutes."

      $stdout.puts output.join("\n")
    end

    def abort_multipart_message(error, upload_id)
      "#{error}\nAborting multipart upload : #{upload_id}"
    end

    def multi_upload(file)
      upload_id = create_multipart_upload.upload_id

      bail_multipart_on_fail(upload_id) do
        timed_multipart_upload do
          parts = upload_parts(file, upload_id).sort do |a, b|
            a[:part_number] <=> b[:part_number]
          end

          req = complete_multipart_upload_request(upload_id, parts)
          client.complete_multipart_upload(req)
        end
      end
    end

    def upload_parts(file, upload_id)
      Parallel.map(1..part_count(file), in_threads: 10) do |part|
        bail_upload_part_on_fail(part, upload_id) do
          $stdout.puts "Uploading part number #{part} : #{upload_id}\n"
          r = client.upload_part(upload_part_params(file, part, upload_id))
          success_msg = "Completed uploading part number #{part} : #{upload_id}"
          r.on_success { $stdout.puts success_msg }

          { etag: r.etag, part_number: part }
        end
      end
    end

    def bail_multipart_on_fail(upload_id)
      yield
    rescue StandardError => e
      $stdout.puts abort_multipart_message(e, upload_id)
      client.abort_multipart_upload(bucket_opts.merge(upload_id: upload_id))
    end

    def bail_upload_part_on_fail(part, upload_id)
      yield
    rescue StandardError => e
      output = ["Failed to upload part number #{part} : #{upload_id}"]
      output << "because of #{e.message}"
      output << "Aborting remaining parts : #{upload_id}"
      raise output.join("\n")
    end

    def upload_part_params(file, part, upload_id)
      start = (part - 1) * MAX_FILE_SIZE
      body  = IO.read(file.path, MAX_FILE_SIZE, start)

      bucket_opts.merge(part_number: part, body: body, upload_id: upload_id)
    end

    def part_count(file)
      c = (file.size.to_f / MAX_FILE_SIZE.to_f).ceil
      $stdout.puts "Uploading backup as #{c} parts"

      c
    end

    def single_upload(file)
      client.put_object(bucket_opts.merge(body: file.read))
    end

    def bucket_opts
      { bucket: config[:s3_bucket],
        key:    "#{config[:s3_bucket_prefix]}/#{filename}" }
    end
  end
end
