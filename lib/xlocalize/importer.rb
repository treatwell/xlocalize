module Xlocalize
  class Importer

    private
    def sanitize_target_value(value)
      # Convert common escaped sequences to raw characters first
      # Ensure any number of backslashes before a quote becomes a raw quote
      # Collapse any runs of backslashes to a single backslash
      value
        .gsub('\\n', "\n")
        .gsub(/\\+\"/, '"')
        .gsub(/\\{2,}/, '\\')
    end
    public

    def strings_content_from_translations_hash(translations_hash)
      result = StringIO.new
      translations_hash.each do |key, translations|
        translations.each do |target, note|
          target = sanitize_target_value(target)
          result << "/* #{note} */\n" if note.length > 0
          result << "\"#{key}\" = #{target.inspect};\n\n"
        end
      end
      return result.string
    end

    def translate_from_node(translations, node)
      (node > "body > trans-unit").each do |trans_unit|
        key = trans_unit["id"]
        target = (trans_unit > "target").text
        target = target.gsub('\\"', '"').gsub('\\\\n', "\n")
        note = (trans_unit > "note").text || ""
        if translations.key?(key)
          translations[key] = { target => note }
        end
      end
    end
  end
end