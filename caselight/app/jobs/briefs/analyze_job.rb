module Briefs
  class AnalyzeJob < ApplicationJob
    queue_as :briefs

    def perform(brief_analysis_id)
      analysis = BriefAnalysis.find_by(id: brief_analysis_id)
      return if analysis.nil?

      Briefs::Analyzer.new(analysis).run!
      analysis.user.notifications.create!(
        kind: :brief_complete,
        title: "Brief analysis complete: #{analysis.uploaded_document.title}",
        body: "#{analysis.authorities_count} authorities — #{analysis.negative_count} negative, " \
              "#{analysis.cautionary_count} cautionary, #{analysis.unmatched_count} unmatched.",
        url: Rails.application.routes.url_helpers.upload_brief_analysis_path(analysis.uploaded_document, analysis)
      )
    rescue StandardError
      # Analyzer already recorded the failure on the record.
    end
  end
end
