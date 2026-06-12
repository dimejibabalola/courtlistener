module Citations
  # Facade choosing the citation-recognition backend:
  #   - eyecite (Free Law Project, via python shim) when importable — the
  #     production-grade recognizer, the same one CourtListener uses
  #   - the pure-Ruby Citations::Parser otherwise (and as the rescue path)
  # Force a backend with CITATION_PARSER=ruby|eyecite.
  module Extractor
    def self.backend
      case ENV["CITATION_PARSER"]
      when "ruby" then :ruby
      when "eyecite" then :eyecite
      else EyeciteParser.available? ? :eyecite : :ruby
      end
    end

    def self.parse(text)
      return Parser.parse(text) unless backend == :eyecite

      begin
        EyeciteParser.parse(text)
      rescue EyeciteParser::Error => e
        Rails.logger.warn("eyecite backend failed, using ruby parser: #{e.message}")
        Parser.parse(text)
      end
    end
  end
end
