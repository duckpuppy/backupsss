require 'backupsss/backup_dir'

module Backupsss
  # A class for cleaning up backup artifacts
  class LocalJanitor
    attr_reader :dir, :retention_count

    def initialize(dir, retention_count = 0)
      @dir             = Backupsss::BackupDir.new(dir)
      @retention_count = retention_count
    end

    def sift_trash
      trash = find_trash
      vocalize_progress(find_treasures, trash)
      trash
    end

    def find_treasures
      dir.ls_rt.take(retention_count)
    end

    def find_trash
      dir.ls_rt.drop(retention_count)
    end

    def rm_garbage(file_array)
      file_array.each { |f| throw_out(f) }
      display_finished
    end

    private

    def throw_out(item)
      dir.rm(item)
      display_cleanup(item)
    rescue SystemCallError => e
      display_error(e, item)
    end

    def vocalize_progress(treasure, garbage)
      if garbage.empty?
        puts 'No garbage found'
      else
        puts 'Found garbage...'
        tell_about(tag_treasure(treasure))
        tell_about(garbage)
      end
    end

    def tell_about(array)
      puts array
    end

    def tag_treasure(treasures)
      treasures.collect { |treasure| "#{treasure} (retaining)" }
    end

    def display_finished
      puts 'Finished cleaning up.'
    end

    def display_cleanup(item)
      puts "Cleaning up #{item}"
    end

    def display_error(e, item)
      puts "Could not clean up #{item}: #{e.message}"
    end
  end
end
