module Ocr
  # Extracts text from uploaded files. Tries the best available tool and
  # degrades gracefully:
  #
  #   PDF  -> pdftotext (poppler) when installed, else pure-Ruby pdf-reader;
  #           scanned PDFs fall back to tesseract OCR when installed.
  #   DOCX -> unzip + parse word/document.xml with Nokogiri.
  #   TXT/MD/RTF-ish -> read as UTF-8.
  class TextExtractor
    Result = Struct.new(:text, :method, :pages_count, keyword_init: true)

    def self.call(io_or_path, filename:)
      new(io_or_path, filename:).call
    end

    def initialize(io_or_path, filename:)
      @source = io_or_path
      @filename = filename.to_s
    end

    def call
      case File.extname(@filename).downcase
      when ".pdf" then extract_pdf
      when ".docx" then extract_docx
      else extract_plain
      end
    end

    private

    def with_local_file
      if @source.respond_to?(:path) && @source.path && File.exist?(@source.path)
        yield @source.path
      else
        Tempfile.create(["upload", File.extname(@filename)], binmode: true) do |tmp|
          data = @source.respond_to?(:read) ? @source.read : @source
          tmp.write(data)
          tmp.flush
          yield tmp.path
        end
      end
    end

    def extract_pdf
      with_local_file do |path|
        if MineruClient.enabled?
          begin
            markdown = MineruClient.new.extract(path, filename: @filename)
            return Result.new(text: clean(markdown), method: "mineru-#{MineruClient.mode}",
                              pages_count: pdf_pages(path))
          rescue MineruClient::Error => e
            Rails.logger.warn("MinerU extraction failed, falling back: #{e.message}")
          end
        end

        if command_available?("pdftotext")
          text = `pdftotext -layout #{Shellwords.escape(path)} - 2>/dev/null`
          return Result.new(text: clean(text), method: "pdftotext", pages_count: pdf_pages(path)) if text.to_s.strip.length > 40
        end

        reader = PDF::Reader.new(path)
        text = reader.pages.map(&:text).join("\n\n")
        return Result.new(text: clean(text), method: "pdf-reader", pages_count: reader.page_count) if text.strip.length > 40

        # Likely a scanned PDF: rasterize + OCR when tools exist.
        if command_available?("pdftoppm") && command_available?("tesseract")
          return Result.new(text: clean(ocr_scanned_pdf(path)), method: "tesseract", pages_count: pdf_pages(path))
        end

        Result.new(text: clean(text), method: "pdf-reader", pages_count: reader.page_count)
      end
    end

    def ocr_scanned_pdf(path)
      Dir.mktmpdir do |dir|
        system("pdftoppm", "-r", "200", "-png", path, File.join(dir, "page"), exception: true)
        Dir.glob(File.join(dir, "page*.png")).sort.map do |png|
          `tesseract #{Shellwords.escape(png)} - 2>/dev/null`
        end.join("\n\n")
      end
    end

    def extract_docx
      with_local_file do |path|
        paragraphs = []
        Zip::File.open(path) do |zip|
          entry = zip.find_entry("word/document.xml")
          raise "not a DOCX file" if entry.nil?

          xml = Nokogiri::XML(entry.get_input_stream.read)
          xml.remove_namespaces!
          xml.xpath("//p").each do |p|
            text = p.xpath(".//t").map(&:text).join
            paragraphs << text if text.present?
          end
        end
        Result.new(text: clean(paragraphs.join("\n\n")), method: "docx-xml", pages_count: nil)
      end
    end

    def extract_plain
      data = @source.respond_to?(:read) ? @source.read : @source.to_s
      Result.new(text: clean(data), method: "plain", pages_count: nil)
    end

    def pdf_pages(path)
      PDF::Reader.new(path).page_count
    rescue StandardError
      nil
    end

    def command_available?(name)
      system("which #{Shellwords.escape(name)} > /dev/null 2>&1")
    end

    def clean(text)
      text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: " ")
          .gsub(/\r\n?/, "\n")
          .gsub(/[ \t]+\n/, "\n")
          .strip
    end
  end
end
