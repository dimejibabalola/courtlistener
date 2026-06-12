module Ai
  # Source-grounded answering (RAG): retrieve the most relevant passages
  # from the corpus, hand them to the configured provider with strict
  # grounding instructions, and persist the answer with its sources so the
  # UI can render citation links. Answers carry [n] markers tied to the
  # stored sources array.
  class ResearchAssistant
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a legal research assistant. Answer the user's question using ONLY
      the numbered sources provided. Rules:
      - Every factual or legal claim must cite a source as [n].
      - If the sources do not support an answer, say so plainly; never invent
        authority, citations, or holdings.
      - Quote pivotal language sparingly and attribute it.
      - Be concise: a short paragraph, then bullets only if genuinely needed.
      - This is research assistance, not legal advice.
    PROMPT

    RETRIEVAL_LIMIT = 6

    def initialize(conversation)
      @conversation = conversation
      @user = conversation.user
    end

    # Appends the user message + grounded assistant reply. Returns the
    # assistant AiMessage.
    def ask!(question)
      provider, model = Providers.resolve(@user)
      @conversation.update!(provider:, model:) if @conversation.provider != provider || @conversation.model != model
      @conversation.ai_messages.create!(role: :user_role, content: question)

      sources = retrieve_sources(question)
      answer = if sources.empty?
        "I could not find relevant passages in the corpus for this question. " \
          "Try different terms or broaden the scope."
      else
        Providers.client_for(provider, user: @user).complete(
          system: SYSTEM_PROMPT,
          user: build_prompt(question, sources),
          model: model
        )
      end

      @conversation.ai_messages.create!(
        role: :assistant, content: answer, provider:, model:,
        sources: sources.map { |s| s.except(:content) }
      )
    rescue Ai::ProviderError => e
      @conversation.ai_messages.create!(
        role: :assistant, provider:, model:,
        content: "#{e.message} Falling back is available: switch the provider in Settings."
      )
    end

    private

    # Pull the best chunks via the vector layer, scoped to the conversation's
    # anchor (a document or matter) when present.
    def retrieve_sources(question)
      hits = Search::VectorAdapter.new.search(question, scope_ids: anchor_scope_ids, limit: RETRIEVAL_LIMIT)
      documents = Document.where(id: hits.map(&:document_id)).index_by(&:id)
      hits.each_with_index.filter_map do |hit, index|
        document = documents[hit.document_id]
        next if document.nil?

        {
          n: index + 1,
          document_id: document.id,
          title: document.title,
          citation: document.display_citation,
          quote: hit.content.to_s.truncate(280),
          content: hit.content.to_s.truncate(1600)
        }
      end
    end

    def anchor_scope_ids
      case @conversation.context
      when Document then [@conversation.context.id]
      when Matter
        ids = FolderItem.where(folder_id: @conversation.context.folders.select(:id), item_type: "Document").pluck(:item_id)
        ids.presence
      end
    end

    def build_prompt(question, sources)
      blocks = sources.map do |s|
        %(<source n="#{s[:n]}" citation="#{ERB::Util.html_escape(s[:citation])}" title="#{ERB::Util.html_escape(s[:title])}">\n#{s[:content]}\n</source>)
      end
      <<~PROMPT
        <sources>
        #{blocks.join("\n")}
        </sources>

        <question>#{question}</question>
      PROMPT
    end
  end
end
