# frozen_string_literal: true

module AmsfSurvey
  module Taxonomy
    # Parses XULE files to extract gate question dependencies.
    # Only extracts existence/gate rules, not sum validation rules.
    class XuleParser
      # Pattern for gate rules: output {gate}-{controlled} (two fields only)
      GATE_PATTERN = /^output\s+(\w+)-(\w+)$/

      # Pattern to identify existence checks (gate rules vs sum rules)
      # Matches: $a1 == Yes and $a2>0  (with flexible whitespace)
      EXISTENCE_PATTERN = /\$a1\s*==\s*Yes\s+and\s+\$a2\s*>\s*0/

      # Pattern to identify sum validation rules (skip these)
      SUM_PATTERN = /-Sum$/

      def initialize(xule_path)
        @xule_path = xule_path
      end

      def parse
        return empty_result unless File.exist?(@xule_path)

        content = File.read(@xule_path).gsub("\r\n", "\n") # Normalize line endings
        gate_rules = {}
        gate_fields = Set.new

        # Split into rule blocks (separated by output statements)
        blocks = content.split(/\n(?=output\s)/)

        blocks.each do |block|
          process_block(block, gate_rules, gate_fields)
        end

        {
          gate_rules: gate_rules,
          gate_fields: gate_fields.to_a
        }
      end

      private

      def process_block(block, gate_rules, gate_fields)
        return unless block.include?("output")

        output_line = block.lines.first&.strip
        return unless output_line

        # Skip sum validation rules
        return if output_line.match?(SUM_PATTERN)

        # Skip dimension rules (contain multiple hyphens)
        return if output_line.count("-") > 1

        # Try to match gate pattern
        match = output_line.match(GATE_PATTERN)
        unless match
          warn "[XuleParser] Skipped unrecognized output: #{output_line}" if ENV["AMSF_DEBUG"]
          return
        end

        # Verify this is an existence check, not some other rule type
        unless block.match?(EXISTENCE_PATTERN)
          warn "[XuleParser] Skipped non-existence rule: #{output_line}" if ENV["AMSF_DEBUG"]
          return
        end

        gate_field = match[1].to_sym
        controlled_field = match[2].to_sym

        gate_rules[controlled_field] = { gate_field => "Yes" }
        gate_fields << gate_field
      end

      def empty_result
        { gate_rules: {}, gate_fields: [] }
      end
    end
  end
end
