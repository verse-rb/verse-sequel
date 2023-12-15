module Verse
  module Sequel
    module JsonEncoder
      module_function

      def encode(value)
        return value if value.is_a?(::Sequel::Postgres::JSONObject)
        ::Sequel.pg_json_wrap(value)
      end

      def decode(value)
        return value unless value.is_a?(String)
        JSON.parse(value)
      end
    end
  end
end
