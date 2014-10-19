
require 'tempfile'
require 'open3'

module Wicky
  module DiffTool

    PREFIX = 'wicky-difftool'
    DIFF_OPTIONS = '--unified'
    DIFF3_OPTIONS = '--merge --show-overlap'
    PATCH_OPTIONS = '--unified --batch --quiet --posix --force'

    class MergeFailed < StandardError; end
    class Conflicted < StandardError; end

    private
    def self.patch_impl(source, forward, patches, &block)
      direction = forward ? '--forward' : '--reverse'
      tmp = Tempfile.open(PREFIX)
      tmp.write source
      tmp.close
      patches.each do |patch_string|
        result, error, status = Open3.capture3 "patch #{direction} #{PATCH_OPTIONS} #{tmp.path}", stdin_data: patch_string
        if not status.success? then
          reject_file = "#{tmp.path}.rej"
          if File.exist?(reject_file) then
            block.call File.read(reject_file) if block_given?
            raise Conflicted
          else
            raise MergeFailed
          end
        end
      end
      tmp.open
      return tmp.read
    ensure
      File.delete "#{tmp.path}.rej", "#{tmp.path}.orig" rescue false
      tmp.close!
    end

    module_function

    def diff(str_a, str_b)
      tmp_a = Tempfile.open(PREFIX)
      tmp_b = Tempfile.open(PREFIX)
      tmp_a.write str_a
      tmp_b.write str_b
      tmp_a.flush
      tmp_b.flush
      return `diff #{DIFF_OPTIONS} #{tmp_a.path} #{tmp_b.path}`
    ensure
      tmp_a.close!
      tmp_b.close!
    end

    def patch(source, *patches, &block)
      patch_impl(source, true, patches, &block)
    end

    def reverse_patch(source, *patches, &block)
      patch_impl(source, false, patches, &block)
    end

    def merge3(my_string, old_string, your_string, &block)
      my_tmp = Tempfile.open(PREFIX)
      old_tmp = Tempfile.open(PREFIX)
      your_tmp = Tempfile.open(PREFIX)
      my_tmp.write my_string
      old_tmp.write old_string
      your_tmp.write your_string
      my_tmp.close
      old_tmp.close
      your_tmp.close
      merged_string, error, status = Open3.capture3 "diff3 #{DIFF3_OPTIONS} #{my_tmp.path} #{old_tmp.path} #{your_tmp.path}"
      puts merged_string, error, status
      if status.success? then
        return merged_string
      else
        if block_given? then
          merged_string.gsub!(/<{5,}\s*#{Regexp.escape(my_tmp.path)}/, "\n<<<<<<< HEAD")
          merged_string.gsub!(/={5,}\s*#{Regexp.escape(old_tmp.path)}/, "\n=======")
          merged_string.gsub!(/>{5,}\s*#{Regexp.escape(your_tmp.path)}/, "\n>>>>>>> YOURS")
          block.call merged_string
        else
          raise Conflicted
        end
      end
    ensure
      my_tmp.close!
      old_tmp.close!
      your_tmp.close!
    end

  end
end

