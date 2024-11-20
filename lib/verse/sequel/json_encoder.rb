# frozen_string_literal: true

module Verse
  module Sequel
    module JsonEncoder
      module_function

      def encode(value)
        return value if value.is_a?(::Sequel::Postgres::JSONBOp)

        # weird case handling by Sequel.
        return nil if value.nil?

        ::Sequel.pg_jsonb(value.is_a?(String) ? value : value.to_json)
      end

      def convert(jsonhash)
        if jsonhash.is_a?(Array)
          return jsonhash.map{ |v| convert(v) }
        end

        unless jsonhash.is_a?(::Sequel::Postgres::JSONBHash) || jsonhash.is_a?(Hash)
          return jsonhash
        end

        # Deep replace string keys with symbols:
        jsonhash.each_with_object({}) do |(k, v), h|
          h[k.to_sym] = convert(v)
        end
      end

      def decode(value)
        case value
        when ::Sequel::Postgres::JSONBHash
          convert(value)
        when Hash
          value
        when String
          JSON.parse(value, symbolize_names: true)
        when ::Sequel::Postgres::JSONBString
          value.to_s
        when ::Sequel::Postgres::JSONBArray
          value.to_a
        when ::Sequel::Postgres::JSONBFalse
          false
        when ::Sequel::Postgres::JSONBTrue
          true
        when nil, NilClass, ::Sequel::Postgres::JSONBNull
          nil
        when ::Sequel::Postgres::JSONBFloat
          value.to_f
        when ::Sequel::Postgres::JSONBInteger
          value.to_i
        else
          raise "cannot convert from `#{value.class}`"
        end
      end
    end
  end
end
