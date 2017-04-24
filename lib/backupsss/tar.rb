require 'open3'

module Backupsss
  # The Tar class is used for creating a tar archive.
  class Tar
    attr_reader :src, :dest, :compress_archive

    def initialize(src, dest, compress_archive = true)
      @src              = src
      @dest             = dest
      @compress_archive = compress_archive
    end

    def make
      return unless valid_dest? && valid_src?
      _, err, status = Open3.capture3("#{tar_command} #{dest} #{src}")
      File.open(dest) if valid_exit?(status, err) && valid_file?
    end

    def valid_exit?(status, err)
      output = []
      output << "command.......#{tar_command}"
      output << "stderr........#{err}" unless err.empty?
      output << "status........#{status}"
      output << "exit code.....#{status.to_i}"
      $stdout.puts output.join("\n")

      return true if success_cases(status.to_i, err)
      raise "ERROR: #{tar_command} exited #{status.to_i}"
    end

    def valid_file?
      raise messages[:no_file] unless File.exist?(dest)
      raise messages[:zero_byte] if File.size(dest).zero?
      true
    end

    def messages
      {
        no_file:   'ERROR: Tar destination file does not exist.',
        zero_byte: 'ERROR: Tar destination file is 0 bytes.'
      }
    end

    def valid_dest?
      dir_exists?(dest_dir) && dest_writable?
    end

    def valid_src?
      dir_exists?(src) && src_readable?
    end

    def filename
      dest.split('/').last
    end

    def tar_command
      compress_archive ? 'tar -zcvf' : 'tar -cvf'
    end

    private

    def clean_exit(status)
      status.zero?
    end

    def dest_dir
      File.dirname(dest)
    end

    def dest_writable?
      File.writable?(dest_dir) || raise_sys_err(dest_dir, Errno::EPERM::Errno)
    end

    def dir_exists?(dir)
      File.exist?(File.open(dir)) || raise_sys_err(dir, Errno::ENOENT::Errno)
    end

    def file_changed?(err)
      err.match(/file changed as we read it/)
    end

    def src_readable?
      File.readable?(src) || raise_sys_err(src, Errno::EPERM::Errno)
    end

    def success_cases(signal_int, err)
      clean_exit(signal_int) || file_changed?(err)
    end

    def raise_sys_err(dir, err)
      raise SystemCallError.new(dir.to_s, err)
    end
  end
end
