require 'multi_json'

module Grape
  module Middleware
    class Base
      attr_reader :app, :env, :options

      # @param [Rack Application] app The standard argument for a Rack middleware.
      # @param [Hash] options A hash of options, simply stored for use by subclasses.
      def initialize(app, options = {})
        @app = app
        @options = default_options.merge(options)
      end
      
      def default_options; {} end
      
      def call(env)
        dup.call!(env)
      end
      
      def call!(env)
        @env = env
        before
        @app_response = @app.call(@env)
        after || @app_response
      end
      
      # @abstract
      # Called before the application is called in the middleware lifecycle.
      def before; end
      # @abstract
      # Called after the application is called in the middleware lifecycle.
      # @return [Response, nil] a Rack SPEC response or nil to call the application afterwards.
      def after; end
      
      def request
        Rack::Request.new(self.env)
      end
      
      def response
        Rack::Response.new(@app_response)
      end


      module Formats

        CONTENT_TYPES = {
          :xml => 'application/xml',
          :json => 'application/json',
          :atom => 'application/atom+xml',
          :rss => 'application/rss+xml',
          :txt => 'text/plain'
        }
        FORMATTERS = {
          :json => :encode_json,
          :txt => :encode_txt,
        }
        PARSERS = {
          :json => :decode_json
        }

        def formatters
          FORMATTERS.merge(options[:formatters] || {})
        end

        def parsers
          PARSERS.merge(options[:parsers] || {})
        end

        def content_types
          CONTENT_TYPES.merge(options[:content_types] || {})
        end

        def content_type
          content_types[options[:format]] || 'text/html'
        end

        def mime_types
          content_types.invert
        end

        def formatter_for(api_format)
          spec = formatters[api_format]
          case spec
          when nil
            lambda { |obj| obj }
          when Symbol
            method(spec)
          else
            spec
          end
        end

        def parser_for(api_format)
          spec = parsers[api_format]
          case spec
          when nil
            nil
          when Symbol
            method(spec)
          else
            spec
          end
        end

        def decode_json(object)
          MultiJson.decode(object)
        end

        def encode_json(object)
          if object.respond_to? :serializable_hash
            MultiJson.encode(object.serializable_hash)
          elsif object.respond_to? :to_json
            object.to_json
          else
            MultiJson.encode(object)
          end
        end

        def encode_txt(object)
          object.respond_to?(:to_txt) ? object.to_txt : object.to_s
        end
      end

    end
  end
end
