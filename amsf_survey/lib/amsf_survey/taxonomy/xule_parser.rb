# frozen_string_literal: true

module AmsfSurvey
  module Taxonomy
    # Parses XULE files to extract gate question dependencies.
    # Only extracts existence/gate rules, not sum validation rules.
    class XuleParser
      # Pattern for gate rules: output {gate}-{controlled}
      GATE_PATTERN = /^output\s+(\w+)-(\w+)$/

      # Pattern to identify existence checks (gate rules vs sum rules)
      EXISTENCE_PATTERN = /\$a1\s*==\s*Yes\s+and\s+\$a2\s*>0/

      def initialize(xule_path)
        @xule_path = xule_path
      end

      def parse
        return empty_result unless File.exist?(@xule_path)

        content = File.read(@xule_path).gsub("\r\n", "\n") # Normalize line endings
        gate_rules = {}
        gate_fields = Set.new

        # Split into rule blocks (separated by blank lines or output statements)
        blocks = content.split(/\n(?=output\s)/)

        blocks.each do |block|
          next unless block.include?("output")

          # Check if this is a gate/existence rule (not a sum rule)
          next unless block.match?(EXISTENCE_PATTERN)

          # Extract the gate and controlled field from the output line
          match = block.match(GATE_PATTERN)
          next unless match

          gate_field = match[1].to_sym
          controlled_field = match[2].to_sym

          gate_rules[controlled_field] = { gate_field => "Yes" }
          gate_fields << gate_field
        end

        {
          gate_rules: gate_rules,
          gate_fields: gate_fields.to_a
        }
      end

      private

      def empty_result
        { gate_rules: {}, gate_fields: [] }
      end
    end
  end
end
