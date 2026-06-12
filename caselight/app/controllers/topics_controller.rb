class TopicsController < ApplicationController
  def index
    @roots = Topic.roots.includes(children: :children)
  end

  def show
    @topic = Topic.find(params[:id])
    @headnotes = @topic.headnotes_in_subtree.includes(document: :court)
    if params[:jurisdiction_id].present?
      @headnotes = @headnotes.joins(:document).where(documents: { jurisdiction_id: params[:jurisdiction_id] })
    end
    @headnotes = @headnotes.limit(100)
    @jurisdictions = Jurisdiction.order(:name)
  end
end
