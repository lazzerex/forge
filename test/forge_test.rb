require_relative "test_helper"

class ForgeVersionTest < Minitest::Test
  def test_version_exists
    refute_nil Forge::VERSION
  end
end
