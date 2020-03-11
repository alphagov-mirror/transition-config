# frozen_string_literal: true

module TransitionConfig
  class DuplicateHostsException < RuntimeError
    attr_reader :duplicates
    def initialize(duplicates)
      @duplicates = duplicates
    end

    def to_s
      "Hosts found in more than one site: \n"\
      "#{@duplicates.map { |host, site_abbrs| "#{host}: #{site_abbrs.to_a}" }.join("\n")}\n\n"
    end
  end
end
