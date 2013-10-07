require 'rubygems/test_case'
require 'rubygems/ext'

class TestGemExtCmakeBuilder < Gem::TestCase

  def setup
    super

    `cmake #{Gem::Ext::Builder.redirector}`

    skip 'cmake not present' unless $?.success?

    @ext = File.join @tempdir, 'ext'
    @dest_path = File.join @tempdir, 'prefix'

    FileUtils.mkdir_p @ext
    FileUtils.mkdir_p @dest_path
  end

  def test_self_build
    File.open File.join(@ext, 'CMakeLists.txt'), 'w' do |cmakelists|
      cmakelists.write <<-eo_cmake
cmake_minimum_required(VERSION 2.8)
install (FILES test.txt DESTINATION bin)
      eo_cmake
    end

    FileUtils.touch File.join(@ext, 'test.txt')

    output = []

    Dir.chdir @ext do
      Gem::Ext::CmakeBuilder.build nil, nil, @dest_path, output
    end

    output = output.join "\n"

    assert_match \
      %r%^cmake \. -DCMAKE_INSTALL_PREFIX=#{Regexp.escape @dest_path}%, output
    assert_match %r%#{Regexp.escape @ext}%, output
    assert_contains_make_command '', output
    assert_contains_make_command 'install', output
    assert_match %r%test\.txt%, output
  end

  def test_self_build_fail
    output = []

    error = assert_raises Gem::InstallError do
      Dir.chdir @ext do
        Gem::Ext::CmakeBuilder.build nil, nil, @dest_path, output
      end
    end

    output = output.join "\n"

    shell_error_msg = %r{(CMake Error: .*)}
    sh_prefix_cmake = "cmake . -DCMAKE_INSTALL_PREFIX="

    expected = %r(cmake failed:

#{Regexp.escape sh_prefix_cmake}#{Regexp.escape @dest_path}
#{shell_error_msg}
)

    assert_match expected, error.message

    assert_match %r%^#{sh_prefix_cmake}#{Regexp.escape @dest_path}%, output
    assert_match %r%#{shell_error_msg}%, output
  end

  def test_self_build_has_makefile
    File.open File.join(@ext, 'Makefile'), 'w' do |makefile|
      makefile.puts "clean:\n\t@echo ok\nall:\n\t@echo ok\ninstall:\n\t@echo ok"
    end

    output = []

    Dir.chdir @ext do
      Gem::Ext::CmakeBuilder.build nil, nil, @dest_path, output
    end

    output = output.join "\n"

    assert_contains_make_command '', output
    assert_contains_make_command 'install', output
  end

end

