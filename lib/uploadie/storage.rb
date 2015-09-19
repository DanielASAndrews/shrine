require "uploadie"

require "forwardable"
require "stringio"
require "tempfile"

class Uploadie
  class LintError < Error
    attr_reader :errors

    def initialize(errors)
      @errors = errors
    end
  end

  module Storage
    class Lint
      def self.call(storage)
        new(storage).call
      end

      def initialize(storage)
        @storage = storage
        @errors = []
      end

      def call
        fakeio = FakeIO.new("image")

        storage.upload(fakeio, "foo.jpg")
        error! "#upload doesn't rewind the file" if !(fakeio.read == "image")

        file = storage.download("foo.jpg")
        error! "#download doesn't return a Tempfile" if !file.is_a?(Tempfile)
        error! "#download doesn't return the uploaded file" if !(file.read == "image")

        begin
          Uploadie.io!(storage.open("foo.jpg"))
        rescue Uploadie::InvalidFile => error
          error! "#open doesn't return a valid IO object"
        end

        error! "#read doesn't return content of the uploaded file" if !(storage.read("foo.jpg") == "image")
        error! "#exists? returns false for a file that was uploaded" if !storage.exists?("foo.jpg")
        error! "#url doesn't return a string" if !storage.url("foo.jpg").is_a?(String)

        storage.delete("foo.jpg")
        error! "#exists? returns true for a file that was deleted" if storage.exists?("foo.jpg")

        begin
          storage.clear!
          error! "#clear! should raise Uploadie::Confirm unless :confirm is passed in"
        rescue Uploadie::Confirm
        end

        storage.upload(FakeIO.new("image"), "foo.jpg")
        storage.clear!(:confirm)
        error! "a file still #exists? after #clear! was called" if storage.exists?("foo.jpg")

        raise LintError.new(@errors) if @errors.any?
      end

      private

      def error!(message)
        warn "Lint: #{message}"
        @errors << message
      end

      attr_reader :storage

      class FakeIO
        def initialize(content)
          @io = StringIO.new(content)
        end

        extend Forwardable
        delegate Uploadie::IO_METHODS.keys => :@io
      end
    end
  end
end