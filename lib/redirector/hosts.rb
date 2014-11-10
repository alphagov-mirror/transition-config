require 'redirector/duplicate_hosts_exception'
require 'redirector/uppercase_hosts_exception'

module Redirector
  class Hosts
    MASKS = [
      Redirector.path('data/sites/*.yml'),
      Redirector.path('data/transition-sites/*.yml')
    ]

    attr_reader :masks

    def initialize(masks = MASKS)
      @masks = masks
    end

    def files
      files = Array(masks).inject([]) do |files, mask|
        files.concat(Dir[mask])
      end

      raise RuntimeError, "No sites yaml found in #{masks}" if files.empty?

      files
    end

    # This method iterates all the hosts for a specified site
    # according to its YAML.
    def each
      files.each do |filename|
        site = Site.from_yaml(filename)
        site.all_hosts.each do |host|
          yield site, host
        end
      end
    end

    # This is so that the first part of the validates! method can
    # check if there are multiple site abbreviations and
    # therefore duplicates.
    def hosts_to_site_abbrs
      # Default entries in the hash to empty array
      # http://stackoverflow.com/a/2552946/3726525
      Hash.new { |hash, key| hash[key] = [] }.tap do |hosts_to_site_abbrs|
        each do |site, host|
          hosts_to_site_abbrs[host] << site.abbr
        end
      end
    end

    def validate!
      duplicates     = {}
      has_uppercase  = Set.new

      hosts_to_site_abbrs.each do |host, abbrs|
        duplicates[host] = abbrs if abbrs.size > 1
        has_uppercase << host unless host == host.downcase
      end

      raise Redirector::DuplicateHostsException.new(duplicates) if duplicates.any?
      raise Redirector::UppercaseHostsException.new(has_uppercase) if has_uppercase.any?
    end
  end
end
