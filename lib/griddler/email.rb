require 'htmlentities'

module Griddler
  class Email
    include ActionView::Helpers::SanitizeHelper
    attr_reader :to, :from, :subject, :body, :raw_body, :raw_text, :raw_html,
      :headers, :raw_headers, :attachments

    def initialize(params)
      @params = params

      @to = recipients
      @from = extract_address(params[:from], config.from)
      @subject = params[:subject]

      @body = extract_body
      @raw_text = params[:text]
      @raw_html = params[:html]
      @raw_body = @raw_text || @raw_html

      @headers = extract_headers
      @raw_headers = params[:headers]

      @attachments = params[:attachments]
    end

    def process
      processor_class  = config.processor_class
      processor_method = config.processor_method
      processor_class.public_send(processor_method, self)
    end

    private

    attr_reader :params

    def config
      @config ||= Griddler.configuration
    end

    def recipients
      params[:to].map { |recipient| extract_address(recipient, config.to) }
    end

    def extract_address(address, type)
      parsed = EmailParser.parse_address(address)

      if type == :hash
        parsed
      else
        parsed[type]
      end
    end

    def extract_body
      EmailParser.extract_reply_body(text_or_sanitized_html)
    end

    def extract_headers
      EmailParser.extract_headers(params[:headers])
    end

    def text_or_sanitized_html
      if params.key? :text
        clean_text(params[:text])
      elsif params.key? :html
        clean_html(params[:html])
      end
    end

    def clean_text(text)
      clean_invalid_utf8_bytes(text)
    end

    def clean_html(html)
      cleaned_html = clean_invalid_utf8_bytes(html)
      cleaned_html = strip_tags(cleaned_html)
      cleaned_html = HTMLEntities.new.decode(cleaned_html)
      cleaned_html
    end

    def clean_invalid_utf8_bytes(text)
      if !text.valid_encoding?
        text = text
          .force_encoding('ISO-8859-1')
          .encode('UTF-8')
      end

      text
    end
  end
end
