module Uploads
  # OCR / text extraction for an uploaded document; chains into brief
  # analysis for briefs.
  class ExtractTextJob < ApplicationJob
    queue_as :ocr

    def perform(uploaded_document_id)
      upload = UploadedDocument.find_by(id: uploaded_document_id)
      return if upload.nil? || !upload.file.attached?

      upload.update!(status: :processing)
      result = upload.file.open do |tempfile|
        Ocr::TextExtractor.call(tempfile, filename: upload.file.filename.to_s)
      end
      upload.update!(
        status: :ready,
        extracted_text: result.text,
        ocr_method: result.method,
        pages_count: result.pages_count
      )

      if upload.brief?
        analysis = upload.brief_analyses.create!(user: upload.user)
        Briefs::AnalyzeJob.perform_later(analysis.id)
      else
        upload.user.notifications.create!(
          kind: :ocr_complete,
          title: "Text extracted: #{upload.title}",
          body: "#{upload.word_count} words via #{result.method}.",
          url: Rails.application.routes.url_helpers.upload_path(upload)
        )
      end
    rescue StandardError => e
      upload&.update(status: :failed, error_message: e.message.truncate(250))
      raise
    end
  end
end
