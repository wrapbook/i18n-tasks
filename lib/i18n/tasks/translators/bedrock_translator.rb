# frozen_string_literal: true

require 'i18n/tasks/translators/base_translator'
require 'active_support/core_ext/string/filters'

module I18n::Tasks::Translators
  class BedrockTranslator < BaseTranslator
    # max allowed texts per request
    BATCH_SIZE = 50
    DEFAULT_MODEL_ID = 'us.anthropic.claude-3-5-sonnet-20241022-v2:0'
    DEFAULT_SYSTEM_PROMPT = <<~PROMPT.squish
      You are a professional translator that translates content from the %{from} locale
      to the %{to} locale in an i18n locale array.

      The array has a structured format and contains multiple strings. Your task is to translate
      each of these strings and create a new array with the translated strings. Please return only
      an array with the translated values and nothing else.

      HTML markups (enclosed in < and > characters) must not be changed under any circumstance.
      Variables (starting with %%{ and ending with }) must not be changed under any circumstance.

      Keep in mind the context of all the strings for a more accurate translation.
    PROMPT

    def initialize(*)
      begin
        require 'aws-sdk-bedrockruntime'
      rescue LoadError
        raise ::I18n::Tasks::CommandError, "Add gem 'aws-sdk-bedrockruntime' to your Gemfile to use this command"
      end
      super
    end

    def options_for_translate_values(from:, to:, **options)
      options.merge(
        from: from,
        to: to
      )
    end

    def options_for_html
      {}
    end

    def options_for_plain
      {}
    end

    def no_results_error_message
      I18n.t('i18n_tasks.bedrock_translate.errors.no_results')
    end

    private

    def client
      @client ||= Aws::BedrockRuntime::Client.new(**@i18n_tasks.translation_config[:bedrock_client_options])
    end

    def model_id
      @model_id ||= @i18n_tasks.translation_config[:bedrock_model_id].presence || DEFAULT_MODEL_ID
    end

    def system_prompt
      @system_prompt ||= @i18n_tasks.translation_config[:bedrock_system_prompt].presence || DEFAULT_SYSTEM_PROMPT
    end

    def translate_values(list, from:, to:)
      results = []

      list.each_slice(BATCH_SIZE) do |batch|
        translations = translate(batch, from, to)
        result = JSON.parse(translations)
        results << result

        @progress_bar.progress += result.size
      end

      results.flatten
    end

    def translate(values, from, to)
      messages = [
        {
          role: 'user',
          content: values.to_json
        }
      ]

      response = client.invoke_model(
        body: {
          anthropic_version: 'bedrock-2023-05-31',
          max_tokens: 1024,
          messages: messages,
          system: format(system_prompt, from: from, to: to)
        }.to_json,
        model_id: model_id,
        content_type: 'application/json',
        accept: 'application/json'
      )

      JSON.parse(response.body.read).dig('content', 0, 'text')
    end
  end
end
