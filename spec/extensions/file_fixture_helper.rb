require 'pathname'

module FileFixtureHelper
  FIXTURES_PATH = Pathname.new(File.expand_path("../fixtures", __dir__)).freeze
  FILE_FIXTURES_PATH = FIXTURES_PATH.join("files").freeze

  def file_fixture(relative_path)
    pathname = FILE_FIXTURES_PATH.join(relative_path)

    raise ArgumentError, "File '#{pathname}' not found" unless pathname.file?

    pathname
  end
end

