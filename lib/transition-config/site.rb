require 'yaml'
require 'transition-config/abbr_filename_mismatches_exception'
require 'transition-config/required_fields_missing_exception'
require 'transition-config/slugs_missing_exception'
require 'transition-config/tna_timestamp'

module TransitionConfig
  class Site
    MASKS = [
      TransitionConfig.path('data/transition-sites/*.yml')
    ]

    REQUIRED_FIELDS = %w(site whitehall_slug host tna_timestamp homepage)

    attr_accessor :hash
    def initialize(hash)
      self.hash = hash
    end

    def sites_path
      'transition-sites'
    end

    def abbr
      hash['site']
    end

    def whitehall_slug
      hash['whitehall_slug']
    end

    def extra_organisation_slugs
      hash['extra_organisation_slugs']
    end

    def host
      hash['host']
    end

    def aliases
      hash['aliases'] || []
    end

    def all_hosts
      [host] + aliases
    end

    def tna_timestamp
      if timestamp = TransitionConfig::TNATimestamp.new(host).find
        timestamp.to_i
      else
        nil
      end
    end

    def filename
      File.expand_path("../../data/#{sites_path}/#{abbr}.yml", File.dirname(__FILE__))
    end

    attr_writer :organisations
    def organisations
      @organisations ||= Organisations.new
    end

    def slug_exists_in_whitehall?(slug)
      organisations.by_slug[slug]
    end

    def all_slugs
      [].tap do |all_slugs|
        all_slugs.push(whitehall_slug)
        all_slugs.concat(extra_organisation_slugs) if extra_organisation_slugs
      end
    end

    def missing_slugs
      all_slugs.reject { |slug| slug_exists_in_whitehall?(slug) }
    end

    def missing_fields
      REQUIRED_FIELDS - hash.keys
    end

    def ordered_output
      {
        'site'             => abbr,
        'whitehall_slug'   => whitehall_slug,
        'homepage'         => "https://www.gov.uk/government/organisations/#{whitehall_slug}",
        'tna_timestamp'    => tna_timestamp,
        'host'             => host,
      }
    end

    def save!
      File.open(filename, 'w') { |file| ordered_output.to_yaml(file) }
    end

    def to_s
      "#{abbr}: #{whitehall_slug}"
    end

    def self.all(masks = MASKS, options = {})
      files = Array(masks).inject([]) do |files, mask|
        files.concat(Dir[mask])
      end

      raise RuntimeError, "No sites yaml found in #{masks}" if files.empty?

      if block_given?
        files.map { |filename| yield(filename) }
      else
        files.map { |filename| Site.from_yaml(filename, options) }
      end
    end

    def self.check_all_slugs!(masks = MASKS)
      missing = {}
      TransitionConfig::Site.all(masks, organisations: Organisations.new).each do |site|
        unless site.missing_slugs.empty?
          missing[site.abbr] = site.missing_slugs
        end
      end
      raise TransitionConfig::SlugsMissingException.new(missing) unless missing.empty?
    end

    def self.validate!(masks = MASKS)
      Site.check_abbrs_match_filenames!(masks)
      Site.check_required_fields_present!(masks)
    end

    def self.check_abbrs_match_filenames!(masks = MASKS)
      sites_with_basenames = TransitionConfig::Site.all(masks) { |filename| [Site.from_yaml(filename), Site.basename(filename)] }

      mismatches = {}
      sites_with_basenames.each do |site, basename|
        mismatches[basename] = site.abbr unless basename == site.abbr
      end

      raise TransitionConfig::AbbrFilenameMismatchesException.new(mismatches) unless mismatches.empty?
    end

    def self.check_required_fields_present!(masks = MASKS)
      missing = {}
      TransitionConfig::Site.all(masks).each do |site|
        unless site.missing_fields.empty?
          missing[site.abbr] = site.missing_fields
        end
      end
      raise TransitionConfig::RequiredFieldsMissingException.new(missing) unless missing.empty?
    end

    def self.from_yaml(filename, options = {})
      Site.new(YAML.load(File.read(filename))).tap do |site|
        site.organisations = options[:organisations]
      end
    end

    def self.basename(filename)
      File.basename(filename, '.yml')
    end

    def self.create(abbr, whitehall_slug, host)
      organisation = Organisations.new.find(whitehall_slug)
      raise ArgumentError,
            "No organisation with whitehall_slug #{whitehall_slug} found. "\
            'Not creating site.' unless organisation

      Site.new(
        {
          'site'           => abbr,
          'whitehall_slug' => organisation.details.slug,
          'host'           => host
        }
      )
    end
  end
end
