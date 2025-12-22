# frozen_string_literal: true

module AmsfSurvey
  module Taxonomy
    # Parses XULE files to extract gate question dependencies.
    #
    # XULE (XBRL Universal Language for Expressions) is used by AMSF to define
    # validation rules. This parser specifically extracts "gate" rules that
    # control field visibility based on Yes/No answers.
    #
    # == Gate Rules
    # Gate rules follow this pattern in XULE:
    #
    #   output tGATE-t001
    #   $a1 == Yes and $a2>0
    #   message { "Field t001 requires tGATE to be Yes" }
    #
    # Where:
    # - tGATE is the "gate" field (a Yes/No question)
    # - t001 is the "controlled" field (only visible when gate is Yes)
    # - $a1 refers to the gate field value, $a2 refers to the controlled field
    #
    # == Known Limitations
    # - Only supports "Yes" as the gate value (French "Oui" not yet supported in XULE)
    # - Does not handle complex boolean expressions (AND/OR combinations)
    # - Does not parse gate values other than "Yes" (e.g., specific enum values)
    # - Assumes AMSF's specific XULE convention for existence checks
    #
    # == Skipped Rule Types
    # - Sum validation rules (output ending in -Sum)
    # - Dimension rules (output with multiple hyphens)
    # - Any rule not matching the existence check pattern
    #
    class XuleParser
      # Pattern for gate rules: output {gate}-{controlled} (two fields only)
      # Example: "output tGATE-t001" captures tGATE and t001
      GATE_PATTERN = /^output\s+(\w+)-(\w+)$/

      # Pattern to identify existence checks (gate rules vs sum rules).
      # AMSF uses this specific pattern for gate validation:
      #   $a1 == Yes and $a2>0
      # Meaning: "If gate field ($a1) is Yes, then controlled field ($a2) must exist (>0)"
      #
      # Whitespace is flexible:
      #   - "$a1==Yes and $a2>0" matches
      #   - "$a1 == Yes and $a2 > 0" matches
      #   - "$a1  ==  Yes   and   $a2  >  0" matches
      EXISTENCE_PATTERN = /\$a1\s*==\s*Yes\s+and\s+\$a2\s*>\s*0/

      # Pattern to identify sum validation rules (skip these).
      # Sum rules validate that fields add up correctly, not visibility.
      # Example: "output a1101-a1102-a1103-Sum"
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
