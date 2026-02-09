# frozen_string_literal: true

RSpec.describe "AmsfSurvey locale support" do
  after(:each) { AmsfSurvey.locale = :fr }

  describe "AmsfSurvey.locale" do
    it "defaults to :fr" do
      AmsfSurvey.instance_variable_set(:@locale, nil)
      expect(AmsfSurvey.locale).to eq(:fr)
    end

    it "can be set to :en" do
      AmsfSurvey.locale = :en
      expect(AmsfSurvey.locale).to eq(:en)
    end

    it "converts string to symbol" do
      AmsfSurvey.locale = "en"
      expect(AmsfSurvey.locale).to eq(:en)
    end

    it "handles nil by falling back to :fr" do
      AmsfSurvey.locale = nil
      expect(AmsfSurvey.locale).to eq(:fr)
    end
  end

  describe "reset_registry! resets locale" do
    it "resets locale to default" do
      AmsfSurvey.locale = :en
      AmsfSurvey.reset_registry!
      expect(AmsfSurvey.locale).to eq(:fr)
    end
  end

  describe "locale propagation through model hierarchy" do
    let(:field) do
      AmsfSurvey::Field.new(
        id: :t001,
        type: :string,
        xbrl_type: "xbrli:stringItemType",
        label: { fr: "Libellé FR", en: "Label EN" },
        gate: false,
        verbose_label: { fr: "Détaillé FR", en: "Verbose EN" }
      )
    end

    let(:question) do
      AmsfSurvey::Question.new(
        number: 1,
        field: field,
        instructions: { fr: "Instructions FR", en: "Instructions EN" }
      )
    end

    let(:subsection) do
      AmsfSurvey::Subsection.new(
        number: "1.1",
        title: { fr: "Sous-section FR", en: "Subsection EN" },
        questions: [question],
        instructions: { fr: "Contexte FR", en: "Context EN" }
      )
    end

    let(:section) do
      AmsfSurvey::Section.new(
        number: 1,
        title: { fr: "Section FR", en: "Section EN" },
        subsections: [subsection]
      )
    end

    let(:part) do
      AmsfSurvey::Part.new(
        name: { fr: "Partie FR", en: "Part EN" },
        sections: [section]
      )
    end

    it "uses AmsfSurvey.locale for all no-arg accessors" do
      AmsfSurvey.locale = :fr
      expect(part.name).to eq("Partie FR")
      expect(section.title).to eq("Section FR")
      expect(subsection.title).to eq("Sous-section FR")
      expect(subsection.instructions).to eq("Contexte FR")
      expect(question.label).to eq("Libellé FR")
      expect(question.verbose_label).to eq("Détaillé FR")
      expect(question.instructions).to eq("Instructions FR")

      AmsfSurvey.locale = :en
      expect(part.name).to eq("Part EN")
      expect(section.title).to eq("Section EN")
      expect(subsection.title).to eq("Subsection EN")
      expect(subsection.instructions).to eq("Context EN")
      expect(question.label).to eq("Label EN")
      expect(question.verbose_label).to eq("Verbose EN")
      expect(question.instructions).to eq("Instructions EN")
    end

    it "supports explicit locale override regardless of module setting" do
      AmsfSurvey.locale = :fr
      expect(part.name(:en)).to eq("Part EN")
      expect(question.label(:en)).to eq("Label EN")
    end
  end

  describe "backward compatibility with string values" do
    it "string label works same as before" do
      field = AmsfSurvey::Field.new(
        id: :t001, type: :string, xbrl_type: "xbrli:stringItemType",
        label: "Plain string label", gate: false
      )
      expect(field.label).to eq("Plain string label")
      expect(field.label(:en)).to eq("Plain string label")
    end

    it "string title works same as before" do
      section = AmsfSurvey::Section.new(
        number: 1, title: "Customer Risk", subsections: []
      )
      expect(section.title).to eq("Customer Risk")
      expect(section.title(:en)).to eq("Customer Risk")
    end

    it "string instructions works same as before" do
      question = AmsfSurvey::Question.new(
        number: 1,
        field: AmsfSurvey::Field.new(
          id: :t001, type: :string, xbrl_type: "xbrli:stringItemType",
          label: "Label", gate: false
        ),
        instructions: "Help text"
      )
      expect(question.instructions).to eq("Help text")
      expect(question.instructions(:en)).to eq("Help text")
    end
  end
end
