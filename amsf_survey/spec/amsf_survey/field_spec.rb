# frozen_string_literal: true

RSpec.describe AmsfSurvey::Field do
  let(:minimal_attrs) do
    {
      id: :t001,
      name: :total_clients,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      source_type: :computed,
      label: "Total number of clients",
      section_id: :general,
      order: 1,
      gate: false
    }
  end

  describe "#initialize" do
    it "creates a field with required attributes" do
      field = described_class.new(**minimal_attrs)

      expect(field.id).to eq(:t001)
      expect(field.name).to eq(:total_clients)
      expect(field.type).to eq(:integer)
      expect(field.xbrl_type).to eq("xbrli:integerItemType")
      expect(field.source_type).to eq(:computed)
      expect(field.label).to eq("Total number of clients")
      expect(field.section_id).to eq(:general)
      expect(field.order).to eq(1)
      expect(field.gate).to eq(false)
    end

    it "accepts optional attributes" do
      field = described_class.new(
        **minimal_attrs,
        verbose_label: "Extended explanation",
        valid_values: %w[Option1 Option2],
        depends_on: { tGATE: "Oui" }
      )

      expect(field.verbose_label).to eq("Extended explanation")
      expect(field.valid_values).to eq(%w[Option1 Option2])
      expect(field.depends_on).to eq({ tGATE: "Oui" })
    end

    it "defaults optional attributes to nil or empty" do
      field = described_class.new(**minimal_attrs)

      expect(field.verbose_label).to be_nil
      expect(field.valid_values).to be_nil
      expect(field.depends_on).to eq({})
      expect(field.min).to be_nil
      expect(field.max).to be_nil
    end

    it "accepts min and max range constraints" do
      field = described_class.new(**minimal_attrs, min: 0, max: 100)

      expect(field.min).to eq(0)
      expect(field.max).to eq(100)
    end
  end

  describe "#has_range?" do
    it "returns false when neither min nor max is set" do
      field = described_class.new(**minimal_attrs)
      expect(field.has_range?).to be false
    end

    it "returns true when min is set" do
      field = described_class.new(**minimal_attrs, min: 0)
      expect(field.has_range?).to be true
    end

    it "returns true when max is set" do
      field = described_class.new(**minimal_attrs, max: 100)
      expect(field.has_range?).to be true
    end

    it "returns true when both min and max are set" do
      field = described_class.new(**minimal_attrs, min: 0, max: 100)
      expect(field.has_range?).to be true
    end
  end

  describe "type predicates" do
    it "#boolean? returns true for boolean type" do
      field = described_class.new(**minimal_attrs.merge(type: :boolean))
      expect(field.boolean?).to be true
      expect(field.integer?).to be false
    end

    it "#integer? returns true for integer type" do
      field = described_class.new(**minimal_attrs.merge(type: :integer))
      expect(field.integer?).to be true
      expect(field.boolean?).to be false
    end

    it "#string? returns true for string type" do
      field = described_class.new(**minimal_attrs.merge(type: :string))
      expect(field.string?).to be true
    end

    it "#monetary? returns true for monetary type" do
      field = described_class.new(**minimal_attrs.merge(type: :monetary))
      expect(field.monetary?).to be true
    end

    it "#enum? returns true for enum type" do
      field = described_class.new(**minimal_attrs.merge(type: :enum))
      expect(field.enum?).to be true
    end

    it "#percentage? returns true for percentage type" do
      field = described_class.new(**minimal_attrs.merge(type: :percentage))
      expect(field.percentage?).to be true
      expect(field.integer?).to be false
    end
  end

  describe "source type predicates" do
    it "#computed? returns true for computed source type" do
      field = described_class.new(**minimal_attrs.merge(source_type: :computed))
      expect(field.computed?).to be true
      expect(field.prefillable?).to be false
      expect(field.entry_only?).to be false
    end

    it "#prefillable? returns true for prefillable source type" do
      field = described_class.new(**minimal_attrs.merge(source_type: :prefillable))
      expect(field.prefillable?).to be true
    end

    it "#entry_only? returns true for entry_only source type" do
      field = described_class.new(**minimal_attrs.merge(source_type: :entry_only))
      expect(field.entry_only?).to be true
    end
  end

  describe "#visible?" do
    context "with no dependencies" do
      it "returns true regardless of data" do
        field = described_class.new(**minimal_attrs, depends_on: {})
        expect(field.visible?({})).to be true
        expect(field.visible?({ tGATE: "Non" })).to be true
      end
    end

    context "with dependencies" do
      let(:field) do
        described_class.new(**minimal_attrs, depends_on: { tGATE: "Oui" })
      end

      it "returns true when dependency is satisfied" do
        expect(field.visible?({ tGATE: "Oui" })).to be true
      end

      it "returns false when dependency is not satisfied" do
        expect(field.visible?({ tGATE: "Non" })).to be false
      end

      it "returns false when gate field is missing from data" do
        expect(field.visible?({})).to be false
      end

      it "returns false when gate field value is nil" do
        # Explicit nil in data hash should not satisfy "Oui" requirement
        expect(field.visible?({ tGATE: nil })).to be false
      end

      it "returns false when gate field value is empty string" do
        # Empty string should not satisfy "Oui" requirement
        expect(field.visible?({ tGATE: "" })).to be false
      end

      it "requires symbol keys (string keys do not match)" do
        # Dependencies use symbol keys, so string keys won't match
        # This documents the expected behavior - callers must use symbol keys
        expect(field.visible?({ "tGATE" => "Oui" })).to be false
      end
    end

    context "with multiple dependencies" do
      let(:field) do
        described_class.new(
          **minimal_attrs,
          depends_on: { tGATE: "Oui", tGATE2: "Oui" }
        )
      end

      it "returns true when all dependencies are satisfied" do
        expect(field.visible?({ tGATE: "Oui", tGATE2: "Oui" })).to be true
      end

      it "returns false when any dependency is not satisfied" do
        expect(field.visible?({ tGATE: "Oui", tGATE2: "Non" })).to be false
        expect(field.visible?({ tGATE: "Non", tGATE2: "Oui" })).to be false
      end
    end
  end

  describe "#gate?" do
    it "returns true when field is a gate" do
      field = described_class.new(**minimal_attrs, gate: true)
      expect(field.gate?).to be true
    end

    it "returns false when field is not a gate" do
      field = described_class.new(**minimal_attrs, gate: false)
      expect(field.gate?).to be false
    end
  end

  describe "#required?" do
    it "returns false for computed fields" do
      field = described_class.new(**minimal_attrs.merge(source_type: :computed))
      expect(field.required?).to be false
    end

    it "returns true for entry_only fields" do
      field = described_class.new(**minimal_attrs.merge(source_type: :entry_only))
      expect(field.required?).to be true
    end

    it "returns true for prefillable fields" do
      field = described_class.new(**minimal_attrs.merge(source_type: :prefillable))
      expect(field.required?).to be true
    end

    it "returns true for fields with dependencies (when visible)" do
      # Dependencies control visibility, not whether input is required
      field = described_class.new(**minimal_attrs.merge(source_type: :entry_only), depends_on: { tGATE: "Oui" })
      expect(field.required?).to be true
    end
  end

  describe "#cast" do
    it "delegates to TypeCaster with field type" do
      field = described_class.new(**minimal_attrs.merge(type: :integer))
      expect(field.cast("123")).to eq(123)
    end

    it "casts string to integer for integer field" do
      field = described_class.new(**minimal_attrs.merge(type: :integer))
      expect(field.cast("42")).to eq(42)
    end

    it "casts string to BigDecimal for monetary field" do
      field = described_class.new(**minimal_attrs.merge(type: :monetary))
      result = field.cast("1234.56")
      expect(result).to be_a(BigDecimal)
      expect(result).to eq(BigDecimal("1234.56"))
    end

    it "preserves string for boolean field" do
      field = described_class.new(**minimal_attrs.merge(type: :boolean))
      expect(field.cast("Oui")).to eq("Oui")
    end

    it "preserves string for enum field" do
      field = described_class.new(**minimal_attrs.merge(type: :enum))
      expect(field.cast("Option A")).to eq("Option A")
    end

    it "returns nil for nil input" do
      field = described_class.new(**minimal_attrs.merge(type: :integer))
      expect(field.cast(nil)).to be_nil
    end
  end
end
