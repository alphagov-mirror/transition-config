#!/usr/bin/env ruby
require_relative '../../test_helper'

class RedirectorHostsTest < MiniTest::Unit::TestCase
  include FilenameHelpers

  def test_files_raises_error_when_no_files
    hosts = Redirector::Hosts.new(relative_to_tests('fixtures/nosites/*.yml'))
    assert_raises(RuntimeError) { hosts.files }
  end

  def test_files_returns_correct_number_of_filenames_when_files_exist
    hosts = Redirector::Hosts.new(relative_to_tests('fixtures/sites/*.yml'))
    assert_equal 3, hosts.files.size
  end

  def test_hosts_to_site_abbrs_when_a_host_appears_twice
    hosts = Redirector::Hosts.new(relative_to_tests('fixtures/duplicate_hosts_sites/*.yml'))
    expected_value = {
      'one.local'          => ['one'],
      'alias1.one.local'   => ['one'],
      'alias2.one.local'   => ['one'],
      'two.local'          => ['one', 'two'],
    }
    assert_equal expected_value, hosts.hosts_to_site_abbrs
  end

  def test_validate_unique_when_no_duplicates_exist
    # no error is raised
    Redirector::Hosts.new(relative_to_tests('fixtures/sites/*.yml')).validate!
  end

  def test_validate_unique_when_duplicate_hosts_exist
    assert_raises(Redirector::DuplicateHostsException) do
      Redirector::Hosts.new(relative_to_tests('fixtures/duplicate_hosts_sites/*.yml')).validate!
    end
  end

  def test_validate_lowercase_when_no_uppercase_hosts_exist
    # no error is raised
    Redirector::Hosts.new(relative_to_tests('fixtures/sites/*.yml')).validate!
  end

  def test_validate_lowercase_when_uppercase_hosts_exist
    assert_raises(Redirector::UppercaseHostsException) do
      Redirector::Hosts.new(relative_to_tests('fixtures/uppercase_hosts_sites/*.yml')).validate!
    end
  end
end
