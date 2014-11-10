#!/usr/bin/env ruby
require_relative '../../test_helper'

require 'minitest/unit'
require 'minitest/autorun'
require 'redirector/site'
require 'gds_api/test_helpers/organisations'

class RedirectorSiteTest < MiniTest::Unit::TestCase
  include GdsApi::TestHelpers::Organisations
  include FilenameHelpers

  def setup
    @old_app_domain = ORGANISATIONS_API_ENDPOINT
    ORGANISATIONS_API_ENDPOINT.gsub!(/^.*$/, 'https://www.gov.uk')
  end

  def teardown
    ORGANISATIONS_API_ENDPOINT.gsub!(/^.*$/, @old_app_domain)
  end

  def test_can_initialize_site_from_yml
    site = Redirector::Site.from_yaml(slug_check_site_filename('ago'))
    assert_equal 'attorney-generals-office', site.whitehall_slug
    assert_equal 'ago', site.abbr
  end

  def test_decodes_titles
    site = Redirector::Site.from_yaml(slug_check_site_filename('bis'))
    assert_equal 'Department for Business, Innovation & Skills', site.homepage_title
  end

  def test_all_hosts_with_aliases_present
    site = Redirector::Site.from_yaml(duplicate_hosts_site_filename('one'))
    assert_equal ['one.local', 'alias1.one.local', 'alias2.one.local', 'two.local'], site.all_hosts
  end

  def test_all_hosts_without_aliases_present
    site = Redirector::Site.from_yaml(duplicate_hosts_site_filename('two'))
    assert_equal ['two.local'], site.all_hosts
  end

  def test_can_enumerate_all_sites
    organisations_api_has_organisations(%w(attorney-generals-office))
    test_masks = [
      Redirector.path('tests/fixtures/sites/*.yml'),
      Redirector.path('tests/fixtures/slug_check_sites/*.yml')
    ]
    number_of_sites = test_masks.map {|mask| Dir[mask].length }.reduce(&:+)
    assert_equal number_of_sites, Redirector::Site.all(test_masks).length
  end

  def test_all_raises_error_when_no_files
    assert_raises(RuntimeError) do
      Redirector::Site.all(relative_to_tests('fixtures/nosites/*.yml'))
    end
  end

  def test_site_has_whitehall_slug
    slug = Redirector::Site.from_yaml(slug_check_site_filename('ago')).whitehall_slug
    assert_instance_of String, slug
  end

  def test_sites_never_existed_in_whitehall?
    %w(directgov directgov_microsite businesslink businesslink_microsite).each do |site_abbr|
      site = Redirector::Site.from_yaml(slug_check_site_filename(site_abbr))
      assert site.never_existed_in_whitehall?,
             "Expected that #{site_abbr} never_existed_in_whitehall? to be true, got false"
    end

    ago = Redirector::Site.from_yaml(slug_check_site_filename('ago'))
    refute ago.never_existed_in_whitehall?,
           'Expected ago to have existed in whitehall'
  end

  def test_existing_site_slug_exists_in_whitehall?
    organisations_api_has_organisations(%w(attorney-generals-office))
    ago = Redirector::Site.from_yaml(slug_check_site_filename('ago'))
    assert ago.slug_exists_in_whitehall?(ago.whitehall_slug),
           "expected #{ago.whitehall_slug} to exist in whitehall"
  end

  def test_non_existing_site_slug_does_not_exist_in_whitehall?
    organisations_api_has_organisations(%w(nothing-interesting))
    ago = Redirector::Site.from_yaml(slug_check_site_filename('ago'))
    refute ago.slug_exists_in_whitehall?(ago.whitehall_slug),
           'expected slug "attorney-generals-office" not to exist in Mock whitehall'
  end

  def test_all_slugs_with_extra_organisation_slugs
    bis = Redirector::Site.from_yaml(slug_check_site_filename('bis'))
    expected_slugs = ['department-for-business-innovation-skills',
                      'government-office-for-science',
                      'made-up-slug']
    assert_equal expected_slugs, bis.all_slugs
  end

  def test_all_slugs_with_only_whitehall_slug
    ago = Redirector::Site.from_yaml(slug_check_site_filename('ago'))
    assert_equal ['attorney-generals-office'], ago.all_slugs
  end

  def test_all_slugs_for_businesslink
    bl = Redirector::Site.from_yaml(slug_check_site_filename('businesslink'))
    assert_equal [], bl.all_slugs
  end

  def test_missing_slugs
    organisations_api_has_organisations(%w(government-office-for-science
                                           department-for-business-innovation-skills))

    bis = Redirector::Site.from_yaml(slug_check_site_filename('bis'))
    assert_equal ['made-up-slug'], bis.missing_slugs
  end

  def test_checks_all_slugs
    organisations_api_has_organisations(%w(attorney-generals-office
                                           department-for-business-innovation-skills
                                           government-office-for-science))

    exception = assert_raises(Redirector::SlugsMissingException) do
      Redirector::Site.check_all_slugs!(relative_to_tests('fixtures/slug_check_sites/*.yml'))
    end

    assert_equal ['non-existent-slug'], exception.missing['nonexistent']
    assert_equal ['made-up-slug'], exception.missing['bis']
    assert_nil exception.missing['directgov_microsite']
    assert_nil exception.missing['directgov']
  end

  def test_site_create_fails_when_no_slug
    organisations_api_does_not_have_organisation 'non-existent-whitehall-slug'

    assert_raises(ArgumentError) do
      Redirector::Site.create('foobar', 'non-existent-whitehall-slug', 'some.host.gov')
    end
  end

  def test_site_create_fails_on_unknown_type
    organisations_api_has_organisations(%w(uk-borders-agency))
    assert_raises(ArgumentError) do
      Redirector::Site.create('ukba', 'uk-borders-agency', 'www.ukba.homeoffice.gov.uk', type: :foobar)
    end
  end

  def test_site_creates_yaml_when_slug_exists
    tna_response = File.read(relative_to_tests('fixtures/tna/ukba.html'))
    stub_request(:get, "http://webarchive.nationalarchives.gov.uk/*/http://www.ukba.homeoffice.gov.uk").
        to_return(status: 200, body: tna_response)

    organisation_details = organisation_details_for_slug('uk-borders-agency').tap do |details|
      details['title'] = 'UK Borders Agency & encoding test'
    end
    organisations_api_has_organisation 'uk-borders-agency', organisation_details

    site = Redirector::Site.create('ukba', 'uk-borders-agency', 'www.ukba.homeoffice.gov.uk')

    assert site.filename.include?('data/transition-sites'),
           'site.filename should include data/transition-sites'

    assert_equal 'ukba', site.abbr
    assert_equal 'uk-borders-agency', site.whitehall_slug
    assert_equal 'www.ukba.homeoffice.gov.uk', site.host

    site.save!

    begin
      yaml = YAML.load(File.read(site.filename))

      assert_equal 'ukba', yaml['site']
      assert_equal 'uk-borders-agency', yaml['whitehall_slug']
      assert_equal 'https://www.gov.uk/government/organisations/uk-borders-agency', yaml['homepage']
      assert_equal 20140110181512, yaml['tna_timestamp']
    ensure
      File.delete(site.filename)
    end
  end

end
